[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskFile,
    [ValidateSet('domestic', 'overseas')]
    [string]$Body = 'overseas',
    [ValidateSet('hunyuan4', 'deepseekV41')]
    [string]$ModelSlot = 'deepseekV41',
    [switch]$AutoApprove,
    [string]$CliPath = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$systemRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $systemRoot
$commonPath = Join-Path $systemRoot 'config\common.json'
$common = Get-Content -Raw -LiteralPath $commonPath | ConvertFrom-Json
$bodyConfig = $common.workerBodies.PSObject.Properties[$Body].Value
$modelConfig = $bodyConfig.models.PSObject.Properties[$ModelSlot].Value
if ($null -eq $bodyConfig -or $null -eq $modelConfig) {
    throw "Unknown Worker Body/model slot: $Body/$ModelSlot"
}

$taskPath = (Resolve-Path -LiteralPath $TaskFile).Path
$protocolPath = Join-Path $systemRoot 'WORKER_PROTOCOL.md'
$productDir = if ($bodyConfig.product -eq 'WorkBuddyAI') { 'WorkBuddyAI' } else { 'WorkBuddy' }
$defaultCliPath = Join-Path $env:LOCALAPPDATA "Programs\$productDir\resources\app.asar.unpacked\cli\bin\codebuddy"
$cliPath = if ([string]::IsNullOrWhiteSpace($CliPath)) { $defaultCliPath } else { (Resolve-Path -LiteralPath $CliPath).Path }

if (-not (Test-Path -LiteralPath $cliPath)) {
    throw "WorkBuddy CLI was not found at $cliPath. Install or open WorkBuddy first."
}

$taskBody = Get-Content -Raw -LiteralPath $taskPath
$protocolBody = Get-Content -Raw -LiteralPath $protocolPath
$workerPrompt = @"
You are the execution Worker for Codex.

Repository workspace: $repoRoot
Task file: $taskPath

Read and follow this Worker Protocol:
--- WORKER PROTOCOL ---
$protocolBody
--- END WORKER PROTOCOL ---

Execute the task in the current workspace. Protect existing user changes. Stay within scope.
Do not commit, push, merge, or modify secrets.
Return the required Worker Protocol summary, test results, and unverified risks.

--- TASK ---
$taskBody
--- END TASK ---
"@

$args = @($cliPath, '--print', '--output-format', 'json', '--model', [string]$modelConfig.selector)
if ($AutoApprove) {
    $args += @('--permission-mode', 'auto')
} else {
    $args += @('--permission-mode', 'acceptEdits')
}
$args += $workerPrompt

if ($DryRun) {
    Write-Output 'mode=dry-run'
    Write-Output ('body={0}' -f $Body)
    Write-Output ('product={0}' -f $bodyConfig.product)
    Write-Output ('modelSlot={0}' -f $ModelSlot)
    Write-Output ('modelSelector={0}' -f $modelConfig.selector)
    Write-Output ('costPolicy={0}' -f $modelConfig.costPolicy)
    Write-Output ('cli={0}' -f $cliPath)
    Write-Output ('autoApprove={0}' -f [bool]$AutoApprove)
    Write-Output ('task={0}' -f $taskPath)
    exit 0
}

Push-Location $repoRoot
try {
    & node @args
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
