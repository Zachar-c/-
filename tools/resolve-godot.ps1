[CmdletBinding()]
param(
    [switch]$Console
)

$envName = if ($Console) { 'GODOT_CONSOLE_PATH' } else { 'GODOT_PATH' }
$candidates = @(
    [Environment]::GetEnvironmentVariable($envName),
    (Join-Path $env:USERPROFILE 'DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'),
    (Join-Path $env:USERPROFILE 'DevEnv\tools\Godot_v4.7.2-stable_win64.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe'),
    (Get-Command godot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

if ($Console) {
    $candidates = $candidates | Where-Object { $_ -match 'console\.exe$' }
}

if (-not $candidates) {
    throw "Godot executable was not found. Set $envName to the full executable path."
}

$candidates | Select-Object -First 1
