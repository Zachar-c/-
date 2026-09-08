# 合并 Windows 安装包分卷并校验（配合 README「下载安装包」章节使用）
# 用法: powershell -ExecutionPolicy Bypass -File tools/join_installer.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$p1 = Join-Path $root "build\win\gu-zhenren.exe.part1"
$p2 = Join-Path $root "build\win\gu-zhenren.exe.part2"
$out = Join-Path $root "build\win\gu-zhenren.exe"
if (-not (Test-Path $p1) -or -not (Test-Path $p2)) {
    throw "Missing part files; download both parts first."
}
$fs = [System.IO.File]::OpenWrite($out)
try {
    foreach ($p in @($p1, $p2)) {
        $bytes = [System.IO.File]::ReadAllBytes($p)
        $fs.Write($bytes, 0, $bytes.Length)
    }
} finally {
    $fs.Close()
}
$expected = "dda62eabbc1d0204a93e58672e0c05ee0075a717696fc14146f1ddf84c416667"
$actual = (Get-FileHash -Algorithm SHA256 $out).Hash.ToLowerInvariant()
if ($actual -ne $expected) {
    throw "SHA256 mismatch: expected $expected got $actual"
}
Write-Output "JOINED_OK $out"
