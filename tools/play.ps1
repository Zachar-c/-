[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = & (Join-Path $PSScriptRoot 'resolve-godot.ps1')

Start-Process -FilePath $godot -ArgumentList @('--path', $projectRoot)
