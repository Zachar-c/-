# tools/import.ps1
# Import project resources before headless testing. Dialogue Manager compiles
# .dialogue files into .tres under .godot/imported (git-ignored), so a fresh
# checkout must run this once before tests that load dialogue resources.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot 'godot.ps1'

& $godot --headless --import --path $projectRoot
exit $LASTEXITCODE
