param(
    [string]$Volume = 'vol2',
    [string]$Batch = '',
    [string]$BriefOut = '',
    [switch]$WriteState,
    [string]$RepoRoot = (Get-Location).Path
)

# 批次上下文简报生成器：为 AI 会话生成开工恢复简报，避免逐个全读台账/细纲/正文。
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_brief.ps1 -Volume vol2 -Batch 001-030
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_brief.ps1 -Volume vol2 -Batch 151-180 -BriefOut working\brief.md
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_brief.ps1 -Volume vol2 -Batch 151-180 -WriteState   # 同时生成批内状态卡模板
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_brief.ps1 -Volume vol2                                    # 仅进度总览
# 注意：简报是导航，不是原文；台账匹配行只列举与本批次相关的记录，未命中时仍需读全文。

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$previousEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

function Get-RepoPath([string]$relativePath) {
    return (Join-Path $RepoRoot $relativePath)
}

function Get-Relative([string]$path) {
    return ($path.Substring($RepoRoot.Length).TrimStart('\', '/'))
}

function Get-OutlinePath([string]$volumeId, [string]$range) {
    return (Get-RepoPath ('outlines\detail\{0}-sec{1}.md' -f $volumeId, $range))
}

function Invoke-GitSilent([string[]]$arguments) {
    # PS 5.1 下 $ErrorActionPreference='Stop' 会把 git 的 stderr 警告（如 CRLF）升级为终止错误，
    # 因此在函数内临时降级为 Continue，只取 stdout。
    $ErrorActionPreference = 'Continue'
    $lines = @(& git -C $RepoRoot @arguments 2>$null)
    $ErrorActionPreference = 'Stop'
    return $lines
}

$configPath = Get-RepoPath 'config\editorial-volumes.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw ('Missing editorial volume configuration: {0}' -f $configPath)
}
$volumeConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$volCfg = @($volumeConfig.volumes | Where-Object { $_.id -eq $Volume }) | Select-Object -First 1
if (-not $volCfg) {
    throw ('Unknown volume: {0}. Known ids: {1}' -f $Volume, (@($volumeConfig.volumes | ForEach-Object { $_.id }) -join ', '))
}

$volumeRoot = Get-RepoPath 'volumes'
$volumeDir = @(Get-ChildItem -LiteralPath $volumeRoot -Directory -ErrorAction SilentlyContinue | Where-Object Name -Like $volCfg.directoryPattern) | Select-Object -First 1

$lines = [System.Collections.Generic.List[string]]::new()
function Write-BriefLine([string]$text = '') {
    $script:lines.Add($text)
}

Write-BriefLine ('# 《蛊真人》批次上下文简报：{0}-sec{1}' -f $volCfg.id, $(if ($Batch -eq '') { 'ALL' } else { $Batch }))
Write-BriefLine ''
Write-BriefLine ('- 生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
try {
    $head = @(Invoke-GitSilent @('log', '-1', '--oneline'))
    if ($head.Count -gt 0) { Write-BriefLine ('- Git HEAD：' + $head[0]) }
} catch { }
Write-BriefLine ''

# 1. 进度总览
Write-BriefLine '## 1. 本卷批次进度（卷内所有批次）'
Write-BriefLine ''
Write-BriefLine '| 批次 | 正文 edited.txt | 细纲 |'
Write-BriefLine '| --- | --- | --- |'
foreach ($batchItem in $volCfg.batches) {
    $endpoint = '{0}-sec{1}' -f $volCfg.id, $batchItem.range
    $textInfo = '-'
    if ($volumeDir) {
        $textPath = Join-Path $volumeDir.FullName ($endpoint + '.edited.txt')
        if (Test-Path -LiteralPath $textPath -PathType Leaf) {
            $fileInfo = Get-Item -LiteralPath $textPath
            $mb = [math]::Round($fileInfo.Length / 1MB, 2)
            $textInfo = '{0} MB ({1})' -f $mb, $fileInfo.LastWriteTime.ToString('yyyy-MM-dd')
        } else {
            $textInfo = '缺'
        }
    } else {
        $textInfo = '卷目录未找到'
    }
    $detailInfo = if (Test-Path -LiteralPath (Get-OutlinePath $volCfg.id $batchItem.range) -PathType Leaf) { '有' } else { '缺' }
    Write-BriefLine ('| {0} | {1} | {2} |' -f $endpoint, $textInfo, $detailInfo)
}
Write-BriefLine ''

if ($Batch -eq '') {
    Write-BriefLine '未指定批次，仅输出进度总览。'
    Write-BriefLine ''
    Write-BriefLine '用法补充：-Batch 使用与本卷 batches 完全一致的范围，例如 -Batch 091-120。'
    $briefText = $lines -join [Environment]::NewLine
    if ($BriefOut) {
        $briefOutPath = Get-RepoPath $BriefOut
        $briefOutDir = Split-Path -Parent $briefOutPath
        if (-not (Test-Path -LiteralPath $briefOutDir)) { [void](New-Item -ItemType Directory -Path $briefOutDir -Force) }
        [IO.File]::WriteAllText($briefOutPath, $briefText, (New-Object System.Text.UTF8Encoding($false)))
        Write-Output ('简报已写入：' + (Get-Relative $briefOutPath))
    } else {
        Write-Output $briefText
    }
    exit 0
}

# 2. 批次定位
$batchDef = @($volCfg.batches | Where-Object { $_.range -eq $Batch }) | Select-Object -First 1
if (-not $batchDef) {
    throw ('Unknown batch range: {0}. Known ranges: {1}' -f $Batch, (@($volCfg.batches | ForEach-Object { $_.range }) -join ', '))
}
$batchIndex = -1
for ($i = 0; $i -lt $volCfg.batches.Count; $i++) {
    if ($volCfg.batches[$i].range -eq $Batch) { $batchIndex = $i; break }
}
$prevBatch = if ($batchIndex -gt 0) { $volCfg.batches[$batchIndex - 1] } else { $null }
$nextBatch = if ($batchIndex -lt $volCfg.batches.Count - 1) { $volCfg.batches[$batchIndex + 1] } else { $null }

Write-BriefLine ('## 2. 批次定位：{0}-sec{1}（本批 {2} 节）' -f $volCfg.id, $Batch, $batchDef.count)
Write-BriefLine ''
$textPath = $null
if ($volumeDir) {
    $textPath = Join-Path $volumeDir.FullName ('{0}-sec{1}.edited.txt' -f $volCfg.id, $Batch)
    if (Test-Path -LiteralPath $textPath -PathType Leaf) {
        $workInfo = Get-Item -LiteralPath $textPath
        Write-BriefLine ('- 正文文件：{0}（{1} MB，最后修改 {2}）' -f (Get-Relative $textPath), [math]::Round($workInfo.Length / 1MB, 2), $workInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
    } else {
        Write-BriefLine '- 正文文件：尚未生成'
        $textPath = $null
    }
} else {
    Write-BriefLine ('- 卷目录未找到：{0}' -f $volCfg.directoryPattern)
}
$detailOutline = Get-OutlinePath $volCfg.id $Batch
if (Test-Path -LiteralPath $detailOutline -PathType Leaf) {
    Write-BriefLine ('- 细纲：outlines/detail/{0}-sec{1}.md' -f $volCfg.id, $Batch)
} else {
    Write-BriefLine '- 细纲：缺'
    $detailOutline = $null
}
if ($prevBatch) {
    Write-BriefLine ('- 上一批：{0}-sec{1}（开工须读其尾节状态）' -f $volCfg.id, $prevBatch.range)
}
if ($nextBatch) {
    Write-BriefLine ('- 下一批：{0}-sec{1}（边界不得跨批）' -f $volCfg.id, $nextBatch.range)
}
Write-BriefLine ''

# 3. 细纲逐节标题与源文行
if ($detailOutline) {
    Write-BriefLine '## 3. 逐节标题与源文位置（细纲简表）'
    Write-BriefLine ''
    Write-BriefLine '| 节 | 标题 | 源文行 |'
    Write-BriefLine '| --- | --- | --- |'
    $content = Get-Content -LiteralPath $detailOutline -Encoding UTF8 -Raw
    $headingMatches = [regex]::Matches($content, '(?m)^#{2,3}\s+第\s*(\d+)\s*节[：:]\s*(.+?)\s*$')
    $sourceMatches = [regex]::Matches($content, 'source_line=(\d+)(?:[-—–]\s*(\d+))?')
    $sourceIndex = 0
    foreach ($match in $headingMatches) {
        $sectionNo = [int]$match.Groups[1].Value
        $title = $match.Groups[2].Value.Trim()
        $sourceLine = '细纲未注'
        if ($sourceIndex -lt $sourceMatches.Count) {
            $start = $sourceMatches[$sourceIndex].Groups[1].Value
            $end = $sourceMatches[$sourceIndex].Groups[2].Value
            if ($end) { $sourceLine = ('{0}—{1}' -f $start, $end) } else { $sourceLine = $start }
            $sourceIndex++
        }
        Write-BriefLine ('| {0} | {1} | {2} |' -f $sectionNo, $title, $sourceLine)
    }
    Write-BriefLine ''
}

# 4. 台账命中
Write-BriefLine '## 4. 台账命中（与批次号直接相关的记录）'
Write-BriefLine ''
$rangeSearch = $Batch -replace '-', '\s*[-—–]\s*'
$filePath = Get-RepoPath 'notes\ledger.md'
if (Test-Path -LiteralPath $filePath -PathType Leaf) {
    $file = Get-Item -LiteralPath $filePath
    $allLines = @(Get-Content -LiteralPath $filePath -Encoding UTF8)
    $lineCount = $allLines.Count
    Write-BriefLine ('- {0}（{1} 行，改于 {2}）：' -f (Get-Relative $filePath), $lineCount, $file.LastWriteTime.ToString('MM-dd'))
    $statusLine = @($allLines | Where-Object { $_ -match '^\s*>\s*台账状态行' } | Select-Object -First 1)
    if ($statusLine.Count -gt 0) {
        $statusLineText = ($statusLine[0] -replace '^\s*>\s*台账状态行[:：]\s*', '').Trim()
        Write-BriefLine ('  - 状态行：' + $statusLineText)
    }
    $entryLines = @($allLines | Where-Object { $_ -match '^\s*-\s*\[来源[:：]' })
    $matchedLines = @($entryLines | Where-Object { $_ -match $rangeSearch })
    $exactMatched = @($matchedLines | Where-Object { $_ -match ([regex]::Escape($Batch)) })
    $showLines = if ($exactMatched.Count -gt 0) { $exactMatched } else { $matchedLines }
    if ($showLines.Count -gt 0) {
        $shown = 0
        foreach ($lineMatch in $showLines) {
            if ($shown -ge 6) { break }
            $trimmed = $lineMatch.Trim()
            if ($trimmed -eq '') { continue }
            Write-BriefLine ('  - ' + $trimmed)
            $shown++
        }
        if ($showLines.Count -gt 6) {
            Write-BriefLine ('  - …（另 ' + ($showLines.Count - 6) + ' 行命中）')
        }
    } else {
        Write-BriefLine '  （无直接命中；涉及人物/资源续态仍须读 notes/ledger.md 相关小节）'
    }
}
Write-BriefLine '- 说明：命中行为唯一台账 notes/ledger.md 的条目行（`[来源:` 前缀）；须读全文时按来源 ID 在台账中检索，历史原文在 notes/archive/。'
Write-BriefLine ''

# 5. 工作区与 Git
Write-BriefLine '## 5. 工作区与 Git'
try {
    $status = @(Invoke-GitSilent @('status', '--short'))
    if ($status.Count -gt 0) {
        Write-BriefLine '- 未提交改动（编辑前先看 git diff，禁止覆盖用户改动）：'
        foreach ($statusLine in $status | Select-Object -First 10) {
            Write-BriefLine ('  - ' + $statusLine)
        }
    } else {
        Write-BriefLine '- 工作区干净'
    }
    $recent = @(Invoke-GitSilent @('log', '--oneline', '-6'))
    if ($recent.Count -gt 0) {
        Write-BriefLine '- 最近提交：'
        foreach ($commitLine in $recent) {
            Write-BriefLine ('  - ' + $commitLine)
        }
    }
} catch { }
Write-BriefLine ''

# 6. 原文底稿
Write-BriefLine '## 6. 原文底稿'
$sourceFile = Get-RepoPath '蛊真人.txt'
if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
    Write-BriefLine '- 完整源文：蛊真人.txt（对照细纲"源文位置"行号区间；编辑时必须读对应区间）'
} else {
    Write-BriefLine '- 完整源文：仓库根目录未找到 蛊真人.txt'
}
$workingFile = Get-RepoPath ('working\{0}-sec{1}.cp936.txt' -f $volCfg.id, $Batch)
if (Test-Path -LiteralPath $workingFile -PathType Leaf) {
    $workInfo = Get-Item -LiteralPath $workingFile
    Write-BriefLine ('- 本地底稿：{0}（{1} KB，GBK 编码）' -f (Get-Relative $workingFile), [math]::Round($workInfo.Length / 1KB))
}
Write-BriefLine ''

# 7. 批内状态卡
if ($WriteState) {
    $stateFile = Get-RepoPath ('working\batch-state-{0}-{1}.md' -f $volCfg.id, $Batch)
    if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) {
        $stateTemplate = @"
# 批内状态卡：{0}-sec{1}

> 本文件在批内维持：换会话、上下文压缩或间隔较久后，先读它恢复中间状态。
> 批末时把实际落地内容并入正式台账（由总编会话执行），随后删除本文件。
> 未落地为正文状态的内容禁止写入"已裁决"；只记录事实。

## 开场状态（开工前自台账核对）

- 时间：
- 人物（修为 / 蛊组 / 伤势）：
- 资源（现金 / 物资 / 债务）：
- 身份 / 位置：
- 读者已知信息边界：
- 本批关联冻结裁决（引用台账 ID）：

## 批内进程

（逐节或每数节记录：该节结束时的状态、裁决与变化）

## 批末状态（收尾并入正式台账）

- 时间：
- 人物：
- 资源：
- 信息边界：
- 待总编裁决项：
"@ -f $volCfg.id, $Batch
        [IO.File]::WriteAllText($stateFile, $stateTemplate, (New-Object System.Text.UTF8Encoding($false)))
        Write-BriefLine ('- 批内状态卡（模板已生成）：working/batch-state-{0}-{1}.md' -f $volCfg.id, $Batch)
    } else {
        Write-BriefLine ('- 批内状态卡（已存在）：working/batch-state-{0}-{1}.md' -f $volCfg.id, $Batch)
    }
}
Write-BriefLine ''

# 8. 使用提示
Write-BriefLine '## 8. 使用提示'
Write-BriefLine '- 简报只做导航与命中提示：台账无命中的记录、上批尾节状态、source 行区间仍须读取对应文件。'
Write-BriefLine '- 编辑前先 git diff（或 git diff HEAD^），检查用户批注，禁止覆盖用户改动。'
Write-BriefLine '- 批内流程：开状态卡 → 对原文与台账逐节 edit → 收尾更新台账（视为建议，由总编会话落账）→ 运行 AGENTS.md 验证命令。'

$brief = $lines -join [Environment]::NewLine
if ($BriefOut) {
    $briefOutPath = Get-RepoPath $BriefOut
    $briefOutDir = Split-Path -Parent $briefOutPath
    if (-not (Test-Path -LiteralPath $briefOutDir)) { [void](New-Item -ItemType Directory -Path $briefOutDir -Force) }
    [IO.File]::WriteAllText($briefOutPath, $brief, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('简报已写入：' + (Get-Relative $briefOutPath))
} else {
    Write-Output $brief
}