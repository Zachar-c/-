[CmdletBinding()]
param(
    [string]$Preset = 'Windows Desktop',
    [string]$OutPath = ''
)

# Release 导出（§16.22 发布构建验证入口）。
# 预设定义见 export_presets.cfg（资源过滤/嵌入 PCK）；不带 -OutPath 时使用预设内 export_path。
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$candidates = @(@(
    $env:GODOT_CONSOLE_PATH,
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'),
    (Join-Path $env:USERPROFILE 'DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) })

if ($candidates.Count -eq 0) {
    throw 'Godot console executable was not found. Set GODOT_CONSOLE_PATH to the full Godot console executable path.'
}

$exportArgs = @('--headless', '--path', $projectRoot, '--export-release', $Preset)
if ($OutPath -ne '') {
    $exportArgs += $OutPath
}

& $candidates[0] @exportArgs
exit $LASTEXITCODE
