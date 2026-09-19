[CmdletBinding()]
param(
    [ValidateSet('home', 'work')]
    [string]$Profile = 'home',
    [switch]$VerifyModel,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$systemRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $systemRoot
$commonPath = Join-Path $systemRoot 'config/common.json'
$profilePath = Join-Path $systemRoot ("config/{0}.json" -f $Profile)
$examplePath = Join-Path $systemRoot ("config/{0}.example.json" -f $Profile)

# Console encoding here is gb2312; Windows PowerShell 5.1 Get-Content defaults to the
# ANSI codepage, which mangles the Chinese text in config/*.json and makes
# ConvertFrom-Json throw. Read those files as UTF8 explicitly.
# Keep this file ASCII-only: PS 5.1 parses BOM-less .ps1 as ANSI.
function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

$common = Read-JsonFile $commonPath
if ($null -eq $common) { throw "Missing shared config: $commonPath" }
$machine = Read-JsonFile $profilePath
if ($null -eq $machine) { $machine = Read-JsonFile $examplePath }
if ($null -eq $machine) { throw "Missing profile config: $profilePath" }

function Resolve-Command([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    return (Get-Command $Name -ErrorAction SilentlyContinue).Source
}

$workbuddyCliPath = Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\resources\app.asar.unpacked\cli\bin\codebuddy'
$workbuddyAiCliPath = Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\bin\codebuddy'
$checks = [ordered]@{
    workbuddyCli = if (Test-Path -LiteralPath $workbuddyCliPath) { $workbuddyCliPath } else { $null }
    workbuddyAiCli = if (Test-Path -LiteralPath $workbuddyAiCliPath) { $workbuddyAiCliPath } else { $null }
    opencode = Resolve-Command $machine.opencodeCommand
}
$secretsPath = Join-Path $systemRoot 'config/secrets.json'
$result = [ordered]@{
    profile = $Profile
    repoRoot = $repoRoot
    plannerModel = $common.planner.model
    productionWorker = $common.productionWorker.surface
    productionWorkerStatus = $common.productionWorker.status
    productionWorkerDefault = [bool]$common.productionWorker.default
    localFallbackModel = $common.localFallbackWorker.model
    modelLabel = $common.localFallbackWorker.modelLabel
    exactModelRequired = [bool]$common.localFallbackWorker.verifyExactModel
    workbuddyTokenPresent = -not [string]::IsNullOrWhiteSpace($env:WORKBUDDY_ACCESS_TOKEN)
    profileConfig = if (Test-Path -LiteralPath $profilePath) { $profilePath } else { $examplePath }
    secretsFilePresent = Test-Path -LiteralPath $secretsPath
    commands = $checks
}

if ($VerifyModel) {
    if ([string]::IsNullOrWhiteSpace($checks.opencode)) {
        throw "OpenCode CLI is not available. Install/configure the CLI before verifying $($common.localFallbackWorker.model)."
    }
    $models = @( & $checks.opencode models 2>&1 | ForEach-Object { $_.ToString() } )
    $target = [regex]::Escape([string]$common.localFallbackWorker.model)
    $result.modelVerified = [bool]($models | Select-String -Pattern $target -Quiet)
    if (-not $result.modelVerified) {
        throw "Exact OpenCode model not found: $($common.localFallbackWorker.model). No fallback is allowed."
    }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

$result.GetEnumerator() | ForEach-Object {
    if ($_.Value -is [hashtable] -or $_.Value -is [ordered]) {
        "{0}:" -f $_.Key
        $_.Value.GetEnumerator() | ForEach-Object { "  {0}={1}" -f $_.Key, $_.Value }
    } else {
        "{0}={1}" -f $_.Key, $_.Value
    }
}
