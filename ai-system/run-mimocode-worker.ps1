[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskFile,
    [ValidateSet('mimo-v2.6-flash', 'mimo-v2.5', 'mimo-v2.6-pro')]
    [string]$ModelSlot = 'mimo-v2.6-flash',
    [string]$Title = 'MiMoCode L3 Worker Task',
    [switch]$AutoApprove,
    [switch]$DryRun,
    [int]$TimeoutSeconds = 900
)

$ErrorActionPreference = 'Stop'

$systemRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $systemRoot
$common = Get-Content -Raw -Encoding UTF8 (Join-Path $systemRoot 'config/common.json') | ConvertFrom-Json
$l3 = $common.localL3Worker
$modelConfig = $l3.models.PSObject.Properties[$ModelSlot].Value
if ($null -eq $modelConfig) {
    throw "Unknown MiMoCode model slot: $ModelSlot"
}

$commandPath = $null
$cmd = Get-Command $l3.command -ErrorAction SilentlyContinue
if ($null -ne $cmd) {
    $commandPath = $cmd.Source
} elseif (-not [string]::IsNullOrWhiteSpace($l3.fallbackCommandPath) -and (Test-Path -LiteralPath $l3.fallbackCommandPath)) {
    $commandPath = $l3.fallbackCommandPath
} else {
    throw 'MiMoCode CLI is not available on PATH or at fallbackCommandPath.'
}

$taskPath = (Resolve-Path -LiteralPath $TaskFile).Path
$protocolPath = Join-Path $systemRoot 'WORKER_PROTOCOL.md'
# Keep the CLI message short and pass it as the positional message BEFORE --file.
# --file is a yargs array and will swallow following bare tokens as filenames.
$workerPrompt = "Read the worker protocol at $protocolPath before acting. Execute the task described in $taskPath inside repository $repoRoot. Use only the requested scope. Protect existing user changes. Do not commit or push. Return the protocol-required summary and test results."

$mimoArgs = @(
    'run',
    $workerPrompt,
    '--model', [string]$modelConfig.selector,
    '--dir', $repoRoot,
    '--title', $Title,
    '--format', 'json'
)
if ($AutoApprove) {
    $mimoArgs += '--yolo'
}
$mimoArgs += @('--file', $taskPath)

if ($DryRun) {
    Write-Output 'mode=dry-run'
    Write-Output ('surface={0}' -f $l3.surface)
    Write-Output ('modelSlot={0}' -f $ModelSlot)
    Write-Output ('model={0}' -f $modelConfig.selector)
    Write-Output ('costPolicy={0}' -f $modelConfig.costPolicy)
    Write-Output ('cli={0}' -f $commandPath)
    Write-Output ('autoApprove={0}' -f [bool]$AutoApprove)
    Write-Output ('task={0}' -f $taskPath)
    Write-Output ('timeoutSeconds={0}' -f $TimeoutSeconds)
    exit 0
}

$logDir = Join-Path $systemRoot 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outPath = Join-Path $logDir ("mimo-l3-{0}.out.txt" -f $stamp)
$errPath = Join-Path $logDir ("mimo-l3-{0}.err.txt" -f $stamp)

# Start-Process -ArgumentList does not preserve spaces unless each token is quoted.
function Quote-ProcessArg([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}
$commandLine = ($mimoArgs | ForEach-Object { Quote-ProcessArg $_ }) -join ' '

$proc = Start-Process -FilePath $commandPath -ArgumentList $commandLine -WorkingDirectory $repoRoot `
    -NoNewWindow -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (-not $proc.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
}

if (-not $proc.HasExited) {
    try {
        # Kill the whole tree; bare Kill() leaves mimo child processes behind.
        & taskkill /PID $proc.Id /T /F 2>$null | Out-Null
        if (-not $proc.HasExited) { $proc.Kill() }
    } catch { }
    throw "MiMoCode worker timed out after ${TimeoutSeconds}s. model=$($modelConfig.selector) out=$outPath err=$errPath"
}

if (Test-Path -LiteralPath $outPath) {
    Get-Content -LiteralPath $outPath | Write-Output
}
if (Test-Path -LiteralPath $errPath) {
    $errText = Get-Content -LiteralPath $errPath -Raw
    if (-not [string]::IsNullOrWhiteSpace($errText)) {
        Write-Output '--- stderr ---'
        Write-Output $errText
    }
}

# mimo run can return exit code 0 even when the model API fails (e.g. 402).
# Success must be judged from the JSONL event stream / stderr, not from $proc.ExitCode alone.
$outText = ''
if (Test-Path -LiteralPath $outPath) {
    $outText = Get-Content -LiteralPath $outPath -Raw
}
$errRaw = ''
if (Test-Path -LiteralPath $errPath) {
    $errRaw = Get-Content -LiteralPath $errPath -Raw
}

$failureReason = $null
if ($proc.ExitCode -ne 0) {
    $failureReason = "exit-code:$($proc.ExitCode)"
} elseif ($outText -match '"type"\s*:\s*"error"' -or
    $outText -match '"is_error"\s*:\s*true' -or
    $outText -match 'Insufficient account balance' -or
    $outText -match '"statusCode"\s*:\s*402' -or
    $errRaw -match 'Insufficient account balance') {
    # xiaomi/mimo API returns 402 "Insufficient account balance" as an anti-reverse-proxy
    # defense, not as a real billing state. Desktop official client still works.
    $failureReason = 'anti-proxy-blocked'
} elseif ($errRaw -match 'Model not found' -or $outText -match 'ProviderModelNotFoundError') {
    $failureReason = 'model-not-found'
} elseif ($errRaw -match 'MiMo free API service has ended') {
    $failureReason = 'free-api-ended'
} elseif ($errRaw -match 'Error: .*(not found|Unauthorized|rate limit|invalid)') {
    $failureReason = 'cli-error'
} elseif ([string]::IsNullOrWhiteSpace($outText) -and [string]::IsNullOrWhiteSpace($errRaw)) {
    $failureReason = 'empty-output'
}

if ($null -ne $failureReason) {
    Write-Output ('L3_MIMO_RESULT=FAIL reason={0} model={1}' -f $failureReason, $modelConfig.selector)
    exit 1
}

Write-Output ('L3_MIMO_RESULT=PASS model={0}' -f $modelConfig.selector)
exit 0
