[CmdletBinding()]
param(
    [ValidateSet('unit', 'integration', 'all')]
    [string]$Suite = 'all',
    [string]$Test = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot 'godot.ps1'
$guitkxBuild = Join-Path $PSScriptRoot 'guitkx_build.ps1'
$gutChecked = Join-Path $PSScriptRoot 'run_gut_checked.ps1'

# 导入缓存前置（VDA 2026-09-14）。新增或替换资产（字体 / 音频等）后，若 `.godot`
# 的导入缓存还是旧的，脚本里的 `preload("res://assets/...")` 会在**编译期**失败，
# 并级联成大量 SCRIPT ERROR 与用例失败。实测：`MaShanZheng-Regular.ttf` 入库后
# 未重建导入缓存即跑 unit —— 36 个用例失败、572 条 SCRIPT ERROR（重建后
# 1445/1445 全绿、残留 1 条与导入无关的错误）。
# 该步只重建缓存，不改变任何测试语义；沿用 check.ps1 的探针写法：降级错误偏好
# 并吞 native stderr（PS5.1 在 Stop 模式下会把 stderr 当终止错误），成败以 exit code 判定。
$ErrorActionPreference = 'Continue'
& $godot --headless --path $projectRoot --import 2>$null
$import_rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($import_rc -ne 0) {
    exit $import_rc
}

& $guitkxBuild
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Test) {
    & $gutChecked -CommandPath $godot -CommandArguments @('--headless','--path',$projectRoot,'-s','addons/gut/gut_cmdln.gd','-gtest',('res://' + $Test),'-gexit','-glog=2') -ExpectedTestPath ('res://' + $Test)
    exit $LASTEXITCODE
}

$directories = switch ($Suite) {
    'unit' { @('tests/unit') }
    'integration' { @('tests/integration') }
    default { @('tests/unit', 'tests/integration') }
}

foreach ($directory in $directories) {
    # -gdir/-gtest must be space-separated; the =-form is split by the
    # shell into '-gdir=res:' + '//tests/unit', so GUT never sees a path.
    & $gutChecked -CommandPath $godot -CommandArguments @('--headless','--path',$projectRoot,'-s','addons/gut/gut_cmdln.gd','-gdir',('res://' + $directory),'-gexit','-glog=2')
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
