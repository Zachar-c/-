[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Inline the runner script so the test can call its function directly. The
# plan requires Assert-Exit 0 ... Assert-Exit 1 ... (eight cases). The runner
# captures combined stdout/stderr, preserves native exit, and rejects
# "Parse Error", "Ignoring script", "Nothing was run", "SCRIPT ERROR", zero or
# missing test counts, and mismatched ExpectedTestPath.

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot
$caseDir = Join-Path $RepoRoot 'tests/.run_gut_cases'
if (Test-Path $caseDir) { Remove-Item -Recurse -Force $caseDir }
New-Item -ItemType Directory -Path $caseDir | Out-Null

try {
function New-Stub ($Path, $Body) { Set-Content -Path $Path -Value $Body -Encoding utf8 }
New-Stub "$caseDir/ok.ps1"          "Write-Output 'Tests           1'`nWrite-Output 'Passing Tests   1'`nexit 0"
New-Stub "$caseDir/parse.ps1"       "Write-Output 'Parse Error: bad identifier'`nexit 1"
New-Stub "$caseDir/ignore.ps1"      "Write-Output 'Ignoring script res://x.gd'`nexit 0"
New-Stub "$caseDir/nothing.ps1"     "Write-Output 'Nothing was run.'`nexit 0"
New-Stub "$caseDir/script_err.ps1"  "Write-Output 'SCRIPT ERROR: something'`nWrite-Output 'Tests           1'`nWrite-Output 'Passing Tests   1'`nexit 0"
New-Stub "$caseDir/zero.ps1"        "Write-Output 'Tests           0'`nWrite-Output 'Passing Tests   0'`nexit 0"
New-Stub "$caseDir/path_match.ps1" "Write-Output 'Tests           1'`nWrite-Output 'res://tests/unit/test_ok.gd'`nexit 0"
New-Stub "$caseDir/path_miss.ps1"  "Write-Output 'Tests           1'`nexit 0"
New-Stub "$caseDir/diagnostic.ps1" "[Console]::Error.WriteLine('WARNING: non-fatal teardown diagnostic')`nWrite-Output 'Tests           1'`nWrite-Output 'Passing Tests   1'`nexit 0"

function Invoke-RunnerInline {
    param([string]$CommandPath, [string[]]$CommandArguments, [string]$ExpectedTestPath)
    $lines = @(& $CommandPath @CommandArguments 2>&1 | ForEach-Object { [string]$_ })
    $nativeExit = $LASTEXITCODE
    $lines | Write-Output
    $raw = $lines -join "`n"
    $plain = [regex]::Replace($raw, "`e\[[0-9;?]*[ -/]*[@-~]", '')
    if ($nativeExit -ne 0) { exit $nativeExit }
    if ($plain -match '(?im)Parse Error|Ignoring script|Nothing was run|SCRIPT ERROR') { exit 1 }
    $counts = [regex]::Matches($plain, '(?im)^\s*Tests\s*:?\s*(\d+)\s*$')
    if ($counts.Count -eq 0) { exit 1 }
    $executed = 0
    foreach ($match in $counts) { $executed += [int]$match.Groups[1].Value }
    if ($executed -le 0) { exit 1 }
    if ($ExpectedTestPath) {
        $normalized = $ExpectedTestPath.Replace('\\', '/')
        $basename = [IO.Path]::GetFileName($normalized)
        if ($plain.Replace('\\', '/') -notmatch [regex]::Escape($normalized) -and
            $plain -notmatch [regex]::Escape($basename)) { exit 1 }
    }
    return 0
}

function Assert-Exit {
    param([string]$Stub, [int]$Expected, [string]$Description, [string]$ExpectedPath = '')
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'run_gut_checked.ps1'
        if ($ExpectedPath) {
            & pwsh -NoProfile -File $runner -CommandPath $Stub -ExpectedTestPath $ExpectedPath 2>&1 | Out-Null
        } else {
            & pwsh -NoProfile -File $runner -CommandPath $Stub 2>&1 | Out-Null
        }
    } | Out-Null
    $ErrorActionPreference = $savedErrorActionPreference
    if ($LASTEXITCODE -ne $Expected) {
        Write-Output ("[FAIL] {0}: expected {1}, got {2}" -f $Description, $Expected, $LASTEXITCODE)
        exit 1
    }
    Write-Output ("[OK]   {0}" -f $Description)
}

Assert-Exit "$caseDir/ok.ps1"           0 'happy path exit 0'
Assert-Exit "$caseDir/parse.ps1"        1 'Parse Error exits 1'
Assert-Exit "$caseDir/ignore.ps1"       1 'Ignoring script exits 1'
Assert-Exit "$caseDir/nothing.ps1"      1 'Nothing was run exits 1'
Assert-Exit "$caseDir/script_err.ps1"   1 'SCRIPT ERROR exits 1'
Assert-Exit "$caseDir/zero.ps1"         1 'zero test count exits 1'
Assert-Exit "$caseDir/path_match.ps1"  0 'matching ExpectedTestPath exits 0' -ExpectedPath 'res://tests/unit/test_ok.gd'
Assert-Exit "$caseDir/path_miss.ps1"   1 'mismatched ExpectedTestPath exits 1' -ExpectedPath 'res://tests/unit/test_missing.gd'
Assert-Exit "$caseDir/diagnostic.ps1"  0 'non-fatal stderr diagnostic preserves successful GUT result'

Write-Output 'all runner self-tests passed'
exit 0
} finally {
    if (Test-Path $caseDir) {
        Remove-Item -Recurse -Force $caseDir
    }
}
