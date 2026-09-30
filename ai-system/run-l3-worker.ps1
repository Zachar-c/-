[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskFile,
    [ValidateSet('cheap', 'normal', 'hard')]
    [string]$WorkerClass = 'cheap',
    [string]$Title = 'L3 Auto-Fallback Worker Task',
    [switch]$AutoApprove = $true,
    [switch]$DryRun,
    [int]$MaxAttempts = 0,
    [string[]]$ExcludeCandidate = @()
)

$ErrorActionPreference = 'Stop'

$systemRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $systemRoot
$taskPath = (Resolve-Path -LiteralPath $TaskFile).Path
$policyPath = Join-Path $systemRoot 'config/model-rules.json'
$policy = Get-Content -Raw -Encoding UTF8 -LiteralPath $policyPath | ConvertFrom-Json
$chain = @($policy.chains.PSObject.Properties[$WorkerClass].Value)
if ($chain.Count -eq 0) {
    throw "Unknown worker class: $WorkerClass"
}

function Test-MimoReady {
    $common = Get-Content -Raw -Encoding UTF8 (Join-Path $systemRoot 'config/common.json') | ConvertFrom-Json
    $name = [string]$common.localL3Worker.command
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $true }
    }
    $fb = [string]$common.localL3Worker.fallbackCommandPath
    return (-not [string]::IsNullOrWhiteSpace($fb)) -and (Test-Path -LiteralPath $fb)
}

function Test-WorkbuddyBodyReady([string]$Body) {
    if ($Body -eq 'domestic') {
        $p = Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\resources\app.asar.unpacked\cli\bin\codebuddy'
        return Test-Path -LiteralPath $p
    }
    if ($Body -eq 'overseas') {
        $p = Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\bin\codebuddy'
        return Test-Path -LiteralPath $p
    }
    return $false
}

function Get-PowerShellHost {
    $pwsh = Get-Command 'pwsh' -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) { return $pwsh.Source }
    $winps = Get-Command 'powershell' -ErrorAction SilentlyContinue
    if ($null -ne $winps) { return $winps.Source }
    throw 'No PowerShell host found (pwsh/powershell).'
}

$psHost = Get-PowerShellHost

function Invoke-Candidate([string]$CandidateId) {
    $candidate = $policy.candidates.PSObject.Properties[$CandidateId].Value
    if ($null -eq $candidate) {
        return [pscustomobject]@{ ok = $false; reason = 'not-configured'; runner = $null; output = $null }
    }

    $runner = [string]$candidate.runner
    if ([string]::IsNullOrWhiteSpace($runner)) {
        $body = [string]$candidate.workerBody
        if ($body -eq 'mimocode') {
            $runner = 'run-mimocode-worker.ps1'
        } elseif ($body -eq 'domestic' -or $body -eq 'overseas') {
            $runner = 'run-workbuddy-cli-worker.ps1'
        } else {
            return [pscustomobject]@{ ok = $false; reason = "no-runner-for-body:$body"; runner = $null; output = $null }
        }
    }

    $runnerPath = Join-Path $systemRoot $runner
    if (-not (Test-Path -LiteralPath $runnerPath)) {
        return [pscustomobject]@{ ok = $false; reason = "runner-missing:$runner"; runner = $runner; output = $null }
    }

    $output = @()
    $exitCode = 0
    try {
        $escapedTask = $taskPath -replace "'", "''"
        $escapedTitle = $Title -replace "'", "''"
        if ($runner -eq 'run-mimocode-worker.ps1') {
            $slot = ([string]$candidate.modelSlot) -replace "'", "''"
            $auto = if ($AutoApprove) { ' -AutoApprove' } else { '' }
            $invokeCommand = "& '$runnerPath' -TaskFile '$escapedTask' -ModelSlot '$slot' -Title '$escapedTitle'$auto"
        } elseif ($runner -eq 'run-workbuddy-cli-worker.ps1') {
            $body = ([string]$candidate.workerBody) -replace "'", "''"
            $slot = ([string]$candidate.modelSlot) -replace "'", "''"
            $auto = if ($AutoApprove) { ' -AutoApprove' } else { '' }
            $invokeCommand = "& '$runnerPath' -TaskFile '$escapedTask' -Body '$body' -ModelSlot '$slot'$auto"
        } else {
            return [pscustomobject]@{ ok = $false; reason = "unsupported-runner:$runner"; runner = $runner; output = $null }
        }

        $output = @(& $psHost -NoProfile -Command $invokeCommand 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    } catch {
        return [pscustomobject]@{ ok = $false; reason = "exception:$($_.Exception.Message)"; runner = $runner; output = @($_.Exception.Message) }
    }

    $looksFailed = Test-OutputLooksFailed $output
    $looksPassed = Test-OutputLooksPassed $output $runner
    $ok = ($exitCode -eq 0 -and -not $looksFailed -and $looksPassed)
    $reason = if ($ok) {
        'success'
    } elseif ($exitCode -ne 0) {
        "exit-code:$exitCode"
    } elseif ($looksFailed) {
        'output-indicates-failure'
    } else {
        'missing-success-marker'
    }

    return [pscustomobject]@{
        ok = $ok
        reason = $reason
        runner = $runner
        exitCode = $exitCode
        output = $output
    }
}

function Test-OutputLooksFailed($Lines) {
    if ($null -eq $Lines) { return $false }
    $joined = ($Lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    # Prefer runner-authored markers and structured API errors over broad substrings
    # that can appear in task text and produce false FAIL.
    return ($joined -match 'L3_MIMO_RESULT=FAIL' -or
        $joined -match 'L3_WORKBUDDY_RESULT=FAIL' -or
        $joined -match '"type"\s*:\s*"error"' -or
        $joined -match '"is_error"\s*:\s*true' -or
        $joined -match '"subtype"\s*:\s*"error"' -or
        $joined -match 'Authentication required\. Please use /login' -or
        $joined -match 'Insufficient account balance')
}

function Test-OutputLooksPassed($Lines, [string]$Runner) {
    if ($null -eq $Lines) { return $false }
    $joined = ($Lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($Runner -eq 'run-mimocode-worker.ps1') {
        return [bool]($joined -match 'L3_MIMO_RESULT=PASS')
    }
    if ($Runner -eq 'run-workbuddy-cli-worker.ps1') {
        return [bool]($joined -match 'L3_WORKBUDDY_RESULT=PASS')
    }
    return $true
}

$mimoReady = Test-MimoReady
$domesticReady = Test-WorkbuddyBodyReady 'domestic'
$overseasReady = Test-WorkbuddyBodyReady 'overseas'

$excluded = @($ExcludeCandidate)
$attempts = @()
$limit = if ($MaxAttempts -gt 0) { $MaxAttempts } else { $chain.Count + 2 }

for ($i = 0; $i -lt $limit; $i++) {
    # powershell -File flattens repeated -ExcludeCandidate / comma strings into one
    # token. Build a -Command invocation so the string[] binds as real elements.
    $readyFlags = @()
    if ($mimoReady) { $readyFlags += '-MimoReady' }
    if ($domesticReady) { $readyFlags += '-DomesticReady' }
    if ($overseasReady) { $readyFlags += '-OverseasReady' }
    $exclusionLiteral = if ($excluded.Count -gt 0) {
        '@(' + (($excluded | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ',') + ')'
    } else {
        '@()'
    }
    $selectorPath = Join-Path $systemRoot 'choose-worker-model.ps1'
    $selectorCommand = "& '$selectorPath' -WorkerClass '$WorkerClass' $($readyFlags -join ' ') -ExcludeCandidate $exclusionLiteral"

    $selectionJson = @(& $psHost -NoProfile -Command $selectorCommand 2>&1 | ForEach-Object { $_.ToString() })
    $selectionExit = $LASTEXITCODE
    $selection = $null
    try {
        $selectionText = ($selectionJson -join [Environment]::NewLine)
        $selection = $selectionText | ConvertFrom-Json
    } catch {
        $attempts += [pscustomobject]@{ candidate = $null; status = 'selector-error'; detail = ($selectionJson -join [Environment]::NewLine) }
        break
    }

    if ($selectionExit -ne 0 -or $null -eq $selection.primary) {
        $attempts += [pscustomobject]@{ candidate = $null; status = 'blocked'; detail = $selection.reason }
        break
    }

    $candidateId = [string]$selection.primary.candidate
    if ($DryRun) {
        Write-Output 'mode=dry-run'
        Write-Output ('workerClass={0}' -f $WorkerClass)
        Write-Output ('wouldRun={0}' -f $candidateId)
        Write-Output ('fallbackChain={0}' -f (($selection.fallbackChain | ForEach-Object { $_.candidate }) -join ', '))
        exit 0
    }

    Write-Output ('attempt={0} candidate={1}' -f ($i + 1), $candidateId)
    $result = Invoke-Candidate $candidateId
    $attempts += [pscustomobject]@{
        candidate = $candidateId
        status = if ($result.ok) { 'success' } else { 'failed' }
        reason = $result.reason
        runner = $result.runner
        exitCode = $result.exitCode
    }

    if ($result.ok) {
        if ($null -ne $result.output) {
            $result.output | ForEach-Object { Write-Output $_ }
        }
        Write-Output '---'
        Write-Output ('finalStatus=success candidate={0} attempts={1}' -f $candidateId, ($i + 1))
        $attempts | ConvertTo-Json -Depth 6 | Write-Output
        exit 0
    }

    Write-Output ('candidate-failed candidate={0} reason={1}' -f $candidateId, $result.reason)
    if ($null -ne $result.output) {
        $result.output | Select-Object -First 40 | ForEach-Object { Write-Output $_ }
    }
    $excluded += $candidateId
}

Write-Output '---'
Write-Output 'finalStatus=all-candidates-failed'
$attempts | ConvertTo-Json -Depth 6 | Write-Output
exit 3
