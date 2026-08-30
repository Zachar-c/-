[CmdletBinding()]
param(
    [string]$Preset = 'Windows Desktop',
    [string]$OutPath = ''
)

# Release 导出（§16.22 发布构建验证入口）。
# 预设定义见 export_presets.cfg（资源过滤/嵌入 PCK）；不带 -OutPath 时使用预设内 export_path。
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = & (Join-Path $PSScriptRoot 'resolve-godot.ps1') -Console

$exportArgs = @('--headless', '--path', $projectRoot, '--export-release', $Preset)
if ($OutPath -ne '') {
    $exportArgs += $OutPath
}

& $godot @exportArgs
exit $LASTEXITCODE
