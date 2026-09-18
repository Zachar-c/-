#Requires -Version 7.0
<#
  lore/wiki 验收脚本（Batch 0 新增，Batch 0b 增加 check6/check7）。
  从仓库根运行：pwsh -NoProfile -File lore\wiki\tools\check.ps1
  无外部依赖。逐项输出 PASS/FAIL 明细；全部通过退出码 0，任一失败退出码 1。
  check6 校验概念页被分类索引收录，check7 校验 frontmatter 的 type 与所在目录一致。
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $repoRoot

$failures = [System.Collections.Generic.List[string]]::new()
function Add-Fail([string]$msg) { $failures.Add($msg); Write-Output "FAIL: $msg" }

function Get-FrontMatter([string]$path) {
  $raw = Get-Content -LiteralPath $path -Raw -Encoding utf8
  $lines = $raw -split "`r?`n"
  if ($lines.Count -lt 3) { return $null }
  if ($lines[0].TrimStart("﻿") -ne '---') { return $null }
  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*---\s*$') { $end = $i; break }
  }
  if ($end -lt 0) { return $null }
  return ($lines[1..($end - 1)] -join "`n")
}

$conceptDirs = @('characters', 'gu', 'events', 'world', 'themes')
$conceptPages = @(foreach ($d in $conceptDirs) {
  Get-ChildItem -LiteralPath (Join-Path 'lore/wiki' $d) -Filter '*.md' -File |
    Where-Object { $_.Name -ne 'index.md' }
})
$allWikiMd = @(Get-ChildItem -LiteralPath 'lore/wiki' -Filter '*.md' -File -Recurse)

# 1. 概念页 frontmatter：以 --- 开头且含 type、name、aliases、sources 四个键
$c1ok = 0; $c1total = 0
foreach ($f in $conceptPages) {
  $c1total++
  $fm = Get-FrontMatter $f.FullName
  if ($null -eq $fm) { Add-Fail "check1 frontmatter 缺失或不以 --- 开头: $($f.FullName)"; continue }
  $missing = foreach ($k in @('type', 'name', 'aliases', 'sources')) {
    if ($fm -notmatch "(?m)^\s*$k\s*:") { $k }
  }
  if ($missing) { Add-Fail "check1 缺少键 $($missing -join ','): $($f.FullName)" }
  else { $c1ok++ }
}
if ($c1ok -eq $c1total) { Write-Output "PASS: check1 frontmatter 完整 ($c1ok/$c1total 概念页)" }
else { Write-Output "FAIL: check1 frontmatter 完整 ($c1ok/$c1total 概念页)" }

# 2. frontmatter 里 source:/notes:/memory: 的值在仓库内真实存在（相对仓库根解析）
$c2ok = 0; $c2total = 0
foreach ($f in $conceptPages) {
  $fm = Get-FrontMatter $f.FullName
  if ($null -eq $fm) { continue }
  foreach ($m in [regex]::Matches($fm, '"(source|notes|memory):([^"]+)"')) {
    $c2total++
    $rel = $m.Groups[2].Value
    if (Test-Path -LiteralPath (Join-Path $repoRoot $rel)) { $c2ok++ }
    else { Add-Fail "check2 来源路径不存在 [$($m.Groups[1].Value):$rel]: $($f.FullName)" }
  }
}
if ($c2ok -eq $c2total) { Write-Output "PASS: check2 来源路径存在 ($c2ok/$c2total 条 source:/notes:/memory:)" }
else { Write-Output "FAIL: check2 来源路径存在 ($c2ok/$c2total 条 source:/notes:/memory:)" }

# 3. 所有 canon-index:CAN-... 的 ID 能在 game/docs/lore/canon-index.md 里找到
$canonPath = Join-Path $repoRoot 'game/docs/lore/canon-index.md'
$canonText = Get-Content -LiteralPath $canonPath -Raw -Encoding utf8
$c3ok = 0; $c3total = 0
foreach ($f in $conceptPages) {
  $fm = Get-FrontMatter $f.FullName
  if ($null -eq $fm) { continue }
  foreach ($m in [regex]::Matches($fm, '"canon-index:([^"]+)"')) {
    $c3total++
    $id = $m.Groups[1].Value
    if ($canonText.Contains($id)) { $c3ok++ }
    else { Add-Fail "check3 canon-index ID 不存在 [$id]: $($f.FullName)" }
  }
}
if ($c3ok -eq $c3total) { Write-Output "PASS: check3 canon-index ID 可查 ($c3ok/$c3total 条)" }
else { Write-Output "FAIL: check3 canon-index ID 可查 ($c3ok/$c3total 条)" }

# 4. 所有相对 Markdown 链接（](xxx.md)）能解析到真实文件（跳过行内代码段与外部/锚点链接）
$c4ok = 0; $c4total = 0
foreach ($f in $allWikiMd) {
  $lines = (Get-Content -LiteralPath $f.FullName -Encoding utf8)
  $ln = 0
  foreach ($line in $lines) {
    $ln++
    $text = $line -replace '`[^`]*`', ''
    foreach ($m in [regex]::Matches($text, '\]\(([^)]+)\)')) {
      $target = ($m.Groups[1].Value -split '#')[0]
      if ([string]::IsNullOrWhiteSpace($target)) { continue }
      if (-not $target.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
      if ($target -match '^(https?://|mailto:|/|#)') { continue }
      $c4total++
      $base = Split-Path $f.FullName -Parent
      if (Test-Path -LiteralPath (Join-Path $base $target)) { $c4ok++ }
      else { Add-Fail "check4 断链 [$target]: $($f.FullName):$ln" }
    }
  }
}
if ($c4ok -eq $c4total) { Write-Output "PASS: check4 相对链接可解析 ($c4ok/$c4total 条)" }
else { Write-Output "FAIL: check4 相对链接可解析 ($c4ok/$c4total 条)" }

# 5. 不存在 [[双括号链接]]，不存在行尾空白
$c5total = $allWikiMd.Count; $c5bad = 0
foreach ($f in $allWikiMd) {
  $lines = (Get-Content -LiteralPath $f.FullName -Encoding utf8)
  $ln = 0
  foreach ($line in $lines) {
    $ln++
    if ($line.Contains('[[')) { Add-Fail "check5 发现 [[双括号链接]]: $($f.FullName):$ln"; $c5bad++ }
    if ($line -match '[ \t]+$') { Add-Fail "check5 发现行尾空白: $($f.FullName):$ln"; $c5bad++ }
  }
}
if ($c5bad -eq 0) { Write-Output "PASS: check5 无双括号链接、无行尾空白 ($c5total 个 Markdown 文件)" }
else { Write-Output "FAIL: check5 无双括号链接、无行尾空白 ($c5bad 处问题)" }

# 6. 概念页必须被所在分类的 index.md 收录
$c6ok = 0; $c6total = 0
foreach ($d in $conceptDirs) {
  $indexPath = Join-Path 'lore/wiki' (Join-Path $d 'index.md')
  $indexText = if (Test-Path -LiteralPath $indexPath) { Get-Content -LiteralPath $indexPath -Raw -Encoding utf8 } else { '' }
  if (-not $indexText) { Add-Fail "check6 分类索引缺失: lore/wiki/$d/index.md" }
  foreach ($f in ($conceptPages | Where-Object { $_.Directory.Name -eq $d })) {
    $c6total++
    if ($indexText.Contains($f.Name)) { $c6ok++ }
    else { Add-Fail "check6 概念页未被索引收录 [$($f.Name)]: lore/wiki/$d/index.md" }
  }
}
if ($c6ok -eq $c6total) { Write-Output "PASS: check6 概念页均被分类索引收录 ($c6ok/$c6total)" }
else { Write-Output "FAIL: check6 概念页均被分类索引收录 ($c6ok/$c6total)" }

# 7. frontmatter 的 type 与所在目录一致
$typeByDir = @{ characters = 'character'; gu = 'gu'; events = 'event'; world = 'world'; themes = 'theme' }
$c7ok = 0; $c7total = 0
foreach ($f in $conceptPages) {
  $c7total++
  $fm = Get-FrontMatter $f.FullName
  if ($null -eq $fm) { continue }
  $declared = ([regex]::Match($fm, '(?m)^\s*type\s*:\s*(\S+)')).Groups[1].Value
  $expected = $typeByDir[$f.Directory.Name]
  if ($declared -eq $expected) { $c7ok++ }
  else { Add-Fail "check7 type 与目录不一致 [type=$declared 期望=$expected]: $($f.FullName)" }
}
if ($c7ok -eq $c7total) { Write-Output "PASS: check7 type 与目录一致 ($c7ok/$c7total)" }
else { Write-Output "FAIL: check7 type 与目录一致 ($c7ok/$c7total)" }

if ($failures.Count -eq 0) { Write-Output 'ALL CHECKS PASSED'; exit 0 }
else { Write-Output "TOTAL FAILURES: $($failures.Count)"; exit 1 }
