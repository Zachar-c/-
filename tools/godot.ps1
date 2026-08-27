[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$candidates = @(@(
    $env:GODOT_CONSOLE_PATH,
    (Join-Path $env:USERPROFILE 'DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'),
    (Get-Command godot -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) })

if ($candidates.Count -eq 0) {
    throw 'Godot console executable was not found. Set GODOT_CONSOLE_PATH to the full Godot console executable path.'
}

& $candidates[0] @GodotArgs
exit $LASTEXITCODE
