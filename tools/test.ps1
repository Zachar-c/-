[CmdletBinding()]
param(
    [ValidateSet('unit', 'integration', 'all')]
    [string]$Suite = 'all',
    [string]$Test = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot 'godot.ps1'

if ($Test) {
    & $godot --headless --path $projectRoot -s addons/gut/gut_cmdln.gd "-gtest=res://$Test" -gexit -glog=2
    exit $LASTEXITCODE
}

$directories = switch ($Suite) {
    'unit' { @('tests/unit') }
    'integration' { @('tests/integration') }
    default { @('tests/unit', 'tests/integration') }
}

foreach ($directory in $directories) {
    & $godot --headless --path $projectRoot -s addons/gut/gut_cmdln.gd "-gdir=res://$directory" -gexit -glog=2
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
