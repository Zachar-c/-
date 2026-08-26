[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'test.ps1') -Suite all
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& (Join-Path $PSScriptRoot 'godot.ps1') --headless --path $projectRoot --quit-after 3
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

git -C $projectRoot diff --check
exit $LASTEXITCODE
