[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$candidates = @(@(
    $env:GODOT_PATH,
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) })

if ($candidates.Count -eq 0) {
    throw 'Godot executable was not found. Set GODOT_PATH to the full Godot executable path.'
}

Start-Process -FilePath $candidates[0] -ArgumentList @('--path', $projectRoot)
