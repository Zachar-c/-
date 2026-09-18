[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot 'godot.ps1'

# 2>&1 merges Godot stderr (e.g. addon UID warnings) into the pipeline so
# PSNativeCommandUseErrorActionPreference cannot turn a warning into a
# terminating error and silently kill the build/test chain.
$output = @(& $godot --headless --path $projectRoot -s scripts/guitkx_build.gd 2>&1 | ForEach-Object { [string]$_ })
$exitCode = $LASTEXITCODE
$output | Write-Output
if ($exitCode -ne 0) {
    exit $exitCode
}
