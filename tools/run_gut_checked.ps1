[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CommandPath,
    [string[]]$CommandArguments = @(),
    [string]$ExpectedTestPath = ''
)

$ErrorActionPreference = 'Stop'
# The runner is invoked from tools/ by the project test harness; resolve the
# stub paths against the repository root so inner shells see them.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$lines = @(& $CommandPath @CommandArguments 2>&1 | ForEach-Object { [string]$_ })
$nativeExit = $LASTEXITCODE
$ErrorActionPreference = $savedErrorActionPreference
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
exit 0
