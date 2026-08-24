param(
    [string]$Volume = 'vol2',
    [string]$Batch = '',
    [string]$OutFile = '',
    [switch]$SkipValidate,
    [string]$RepoRoot = (Get-Location).Path
)

# 批次审阅简报生成器：批末为 AI 与用户生成审阅报告，浓缩改动范围、决策、台账、验证与遗留问题。
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_report.ps1 -Volume vol2 -Batch 091-120
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_report.ps1 -Volume vol2 -Batch 151-180 -OutFile working\batch-report.md
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\gen_report.ps1 -Volume vol2 -Batch 091-120 -SkipValidate
# 注意：-OutFile 缺省时写入 working\batch-report.md（每批覆盖）；关键裁决与遗留问题两节必须由编辑会话或总编会话填写，脚本只给骨架、自动采集与验证结果。

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

$endpoint = '{0}-sec{1}' -f $volCfg.id, $Batch
if ($Batch -eq '') {
    throw '必须提供 -Batch，例如 -Batch 091-120。'
}

$lines = [System.Collections.Generic.List[string]]::new()
function Write-ReportLine([string]$text = '') {
    $script:lines.Add($text)
}

Write-ReportLine ('# 批次审阅简报：{0}' -f $endpoint)
Write-ReportLine ''
Write-ReportLine ('- 生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
try {
    $head = @(Invoke-GitSilent @('log', '-1', '--oneline'))
    if ($head.Count -gt 0) { Write-ReportLine ('- Git HEAD：' + $head[0]) }
} catch { }
Write-ReportLine '- 审阅方式：本简报 + git diff（第一节列出的改动范围）；简报是导航，不是正文替代。'
Write-ReportLine ''

# 1. 本批改动范围
Write-ReportLine '## 1. 本批改动范围'
Write-ReportLine ''
$relatedCommits = @(Invoke-GitSilent @('log', '--oneline', '-20', '--grep', $Batch))
if ($relatedCommits.Count -gt 0) {
    Write-ReportLine '- 关联提交（git log 命中本批号）：'
    foreach ($commitLine in $relatedCommits) {
        Write-ReportLine ('  - ' + $commitLine)
    }
    $relatedHash = ($relatedCommits[0] -split ' ')[0]
    Write-ReportLine ''
    Write-ReportLine ('- 最近一次命中本批的提交（{0}）改动文件：' -f $relatedHash)
    $nameList = @(Invoke-GitSilent @('show', '--name-only', '--format=', $relatedHash) | Where-Object { $_ -ne '' })
    if ($nameList.Count -gt 0) {
        foreach ($name in $nameList) {
            Write-ReportLine ('  - ' + $name)
        }
    } else {
        Write-ReportLine '  （无文件，可能是合并提交）'
    }
    Write-ReportLine ''
    Write-ReportLine '- 该提交统计（--stat）：'
    $statLines = @(Invoke-GitSilent @('show', '--stat', '--format=', $relatedHash) | Where-Object { $_ -ne '' })
    foreach ($statLine in $statLines) {
        Write-ReportLine ('  - ' + $statLine)
    }
} else {
    Write-ReportLine '- 未找到命中本批号的提交：本批可能在当前未提交改动中，见下。'
}
Write-ReportLine ''
$statusShort = @(Invoke-GitSilent @('status', '--short'))
$batchPattern = [regex]::Escape($Batch)
$batchStatus = @($statusShort | Where-Object { $_ -match $batchPattern })
if ($batchStatus -and $batchStatus.Count -gt 0) {
    Write-ReportLine '- 工作区与本批相关的未提交改动：'
    foreach ($statusLine in $batchStatus) {
        Write-ReportLine ('  - ' + $statusLine)
    }
} else {
    Write-ReportLine '- 工作区未见本批号的未提交改动（若未提交且改了文件，请核对文件名是否含本批范围）。'
}
Write-ReportLine ''
Write-ReportLine '- 手改核对命令：'
Write-ReportLine '```'
Write-ReportLine '  git diff HEAD -- volumes/ notes/ outlines/   # 未提交改动的完整 diff'
Write-ReportLine '  git log --oneline -5                       # 分批提交记录'
Write-ReportLine '```'
Write-ReportLine ''

# 2. 关键裁决及理由（骨架，须编辑会话填写）
Write-ReportLine '## 2. 关键裁决及理由'
Write-ReportLine ''
Write-ReportLine '> 批末由编辑会话填写；每条注明台账 ID、正文落地节号与理由。脚本只附台账命中。'
Write-ReportLine ''
$rangeSearch = $Batch -replace '-', '\s*[-—–]\s*'
$filePath = Get-RepoPath 'notes\ledger.md'
$anyHit = $false
if (Test-Path -LiteralPath $filePath -PathType Leaf) {
    $allLedgerLines = @(Get-Content -LiteralPath $filePath -Encoding UTF8)
    foreach ($lineMatch in $allLedgerLines) {
        if ($lineMatch -notmatch '^\s*-\s*\[来源[:：]') { continue }
        if ($lineMatch -notmatch $rangeSearch) { continue }
        $anyHit = $true
        $trimmed = $lineMatch.Trim()
        if ($trimmed -ne '') { Write-ReportLine ('- 台账命中（{0}）：{1}' -f (Get-Relative $filePath), $trimmed) }
    }
}
if (-not $anyHit) {
    Write-ReportLine '- （台账未命中本批号；如本批有裁决请手工登记到台账并回填此处）'
}
Write-ReportLine ''

# 3. 台账落地清单
Write-ReportLine '## 3. 台账落地清单'
Write-ReportLine ''
Write-ReportLine '| 台账 | 本批落账情况 | 顶部状态行 |'
Write-ReportLine '| --- | --- | --- |'
$notesStatus = @($statusShort | Where-Object { $_ -match 'notes/' })
$notesTouched = ($notesStatus.Count -gt 0)
$filePath = Get-RepoPath 'notes\ledger.md'
if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    Write-ReportLine '| ledger.md | 无此文件 | — |'
} else {
    $allLines = @(Get-Content -LiteralPath $filePath -Encoding UTF8)
    $hitCount = @($allLines | Where-Object { $_ -match $rangeSearch }).Count
    $touched = @($notesStatus | Where-Object { $_ -like '*ledger.md*' })
    if ($hitCount -gt 0) {
        $statusText = '已落账（命中 {0} 行）' -f $hitCount
    } elseif ($touched.Count -gt 0) {
        $statusText = '文件有未提交改动但未命中本批'
    } else {
        $statusText = '未落账'
    }
    $statusLine = @($allLines | Where-Object { $_ -match '^\s*>\s*台账状态行' } | Select-Object -First 1)
    if ($statusLine.Count -gt 0) {
        $statusLineText = ($statusLine[0] -replace '^\s*>\s*台账状态行[:：]\s*', '').Trim()
    } else {
        $statusLineText = '（缺状态行，见台账维护规范）'
    }
    Write-ReportLine ('| ledger.md | {0} | {1}' -f $statusText, $statusLineText)
}
Write-ReportLine ''
if ($notesTouched) {
    Write-ReportLine '- 说明：notes/ 有未提交改动，请按台账约定（顶部状态行 + 底部追加式维护）核对。'
} else {
    Write-ReportLine '- 说明：notes/ 无未提交改动；若本批产生了裁决记录，请更新台账后重跑本脚本。'
}
Write-ReportLine ''

# 4. 验证结果
Write-ReportLine '## 4. 验证结果'
Write-ReportLine ''
$validatePath = Get-RepoPath 'scripts\validate_editorial_assets.ps1'
if (-not $SkipValidate -and (Test-Path -LiteralPath $validatePath -PathType Leaf)) {
    Write-ReportLine '- 运行 validate_editorial_assets.ps1 -Phase detail：'
    try {
        $validateOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $validatePath -Phase 'detail' -Volume $Volume -RepoRoot $RepoRoot 2>&1
        $validateExit = $LASTEXITCODE
        foreach ($lineOut in $validateOutput) {
            Write-ReportLine ('  - ' + $lineOut)
        }
        if ($validateExit -eq 0) {
            Write-ReportLine '  - 结果：PASS'
        } else {
            Write-ReportLine ('  - 结果：FAIL（exit={0}）' -f $validateExit)
        }
    } catch {
        Write-ReportLine ('  - 运行失败：{0}' -f $_.Exception.Message)
    }
    Write-ReportLine ''
} else {
    Write-ReportLine '- 跳过自动验证（-SkipValidate 或脚本缺失），请手动运行：'
    Write-ReportLine '```'
    Write-ReportLine '  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate_editorial_assets.ps1 -Phase detail'
    Write-ReportLine '  git diff --check'
    Write-ReportLine '```'
    Write-ReportLine ''
}
$diffCheck = @(Invoke-GitSilent @('diff', '--check'))
if ($diffCheck.Count -eq 0) {
    Write-ReportLine '- git diff --check：无空白错误'
} else {
    Write-ReportLine '- git diff --check：发现以下问题：'
    foreach ($lineDiff in $diffCheck) {
        Write-ReportLine ('  - ' + $lineDiff)
    }
}
Write-ReportLine ''

# 5. 遗留问题
Write-ReportLine '## 5. 遗留问题 / 待总编裁决项'
Write-ReportLine ''
Write-ReportLine '> 由编辑会话填写：本批未决的 P2/P3、待核算口径、跨批伏笔、待用户裁决项。'
Write-ReportLine '- '

$report = $lines -join [Environment]::NewLine
$target = if ($OutFile) { $OutFile } else { 'working\batch-report.md' }
$outPath = Get-RepoPath $target
$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) { [void](New-Item -ItemType Directory -Path $outDir -Force) }
[IO.File]::WriteAllText($outPath, $report, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ('审阅简报已写入：' + (Get-Relative $outPath))