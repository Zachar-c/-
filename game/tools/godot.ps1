[CmdletBinding()]
param(
    [switch]$Console,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

# 单一 Godot 入口：无参时输出解析到的可执行路径，带参时执行并透传退出码。
# ponytail: 上限=候选路径写死本机布局；升级触发=换机器/CI 时优先设 GODOT_PATH/GODOT_CONSOLE_PATH。
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
$godot = $candidates | Select-Object -First 1

if ($GodotArgs) {
    & $godot @GodotArgs
    exit $LASTEXITCODE
}
$godot
