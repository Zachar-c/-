[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$guitkxBuild = Join-Path $PSScriptRoot 'guitkx_build.ps1'

& $guitkxBuild
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& (Join-Path $PSScriptRoot 'test.ps1') -Suite all
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Godot 在正常退出时也会向 stderr 写 WARNING（如 ObjectDB leak 统计）；
# PS5.1 在 Stop 模式下把 native stderr 当终止错误，会误杀 exit-0 的探针。
# 探针段降级错误偏好并吞 stderr，启动成败以 exit code 判定。
$ErrorActionPreference = 'Continue'
& (Join-Path $PSScriptRoot 'godot.ps1') --headless --path $projectRoot --quit-after 3 2>$null
$probe_rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($probe_rc -ne 0) {
    exit $probe_rc
}

# git 也会向 stderr 写 warning（CRLF 归一化提示等），同样会误杀 Stop 模式；
# 以 diff --check 的 exit code 判定空白错误。
$ErrorActionPreference = 'Continue'
git -C $projectRoot diff --check 2>$null
$diff_rc = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
exit $diff_rc
