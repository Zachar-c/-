[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot 'godot.ps1'

& $godot --headless --path $projectRoot -s scripts/guitkx_build.gd
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
