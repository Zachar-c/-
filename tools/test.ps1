[CmdletBinding()]
param(
    [ValidateSet('unit', 'integration', 'all')]
    [string]$Suite = 'all',
    [string]$Test = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot 'godot.ps1'
$guitkxBuild = Join-Path $PSScriptRoot 'guitkx_build.ps1'
$gutChecked = Join-Path $PSScriptRoot 'run_gut_checked.ps1'

& $guitkxBuild
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Test) {
    $testArg = '-gtest=res://' + $Test
    & $gutChecked -CommandPath $godot -CommandArguments @('--headless','--path',$projectRoot,'-s','addons/gut/gut_cmdln.gd',$testArg,'-gexit','-glog=2') -ExpectedTestPath ('res://' + $Test)
    exit $LASTEXITCODE
}

$directories = switch ($Suite) {
    'unit' { @('tests/unit') }
    'integration' { @('tests/integration') }
    default { @('tests/unit', 'tests/integration') }
}

foreach ($directory in $directories) {
    $dirArg = '-gdir=res://' + $directory
    & $gutChecked -CommandPath $godot -CommandArguments @('--headless','--path',$projectRoot,'-s','addons/gut/gut_cmdln.gd',$dirArg,'-gexit','-glog=2')
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
