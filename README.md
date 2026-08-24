# 《蛊真人》授权文本精编版

本仓库用于完本小说的出版级精编。工作包括正文重构、世界观校准、编辑台账和回归检查，不是续写、同人或剧情摘要。

## 唯一规范源

所有 AI 会话开始工作前必须先读 [`AGENTS.md`](AGENTS.md)。它是编辑边界、裁决优先级、文风判据和验证流程的唯一完整规范源。

README 只负责分工和启动，不复制完整规则。README、提示词或模型记忆与 `AGENTS.md` 冲突时，以 `AGENTS.md` 为准。

## Git 同步保护

每个 clone 或 worktree 初始化一次版本化 hooks：

```powershell
git config core.hooksPath .githooks
```

提交或推送前可手动校验远程基准；命令会先获取 `origin/main`，再阻止本地 `HEAD` 落后于该基准：

```powershell
py -3 scripts/check_remote_base.py
```

完整处理规则见 `AGENTS.md`「提交保护」。

## 目录

- `volumes/`：分卷精编正文；卷一卷二已冻结，实验产物在 `volumes/_archive/`。
- `outlines/detail/`：批次细纲。
- `notes/`：唯一台账 `ledger.md` + 事实争议队列 + 工具索引 CSV；历史台账在 `notes/archive/`。
- `scripts/`：极简线核心工具；退役脚本在 `scripts/_archive/`。
- `docs/knowledge-base/`：世界观与审查知识库；`docs/archive/`：历史规范与实验设计。

## 提效工具

### 批次上下文简报 `scripts/gen_brief.py`

开工前恢复上下文的导航工具（只读，不修改正文或台账），一次汇总本卷批次进度、本批定位、逐节标题与源文行号、台账命中、Git 状态：

```powershell
# 生成具体批次简报（控制台）
py -3 scripts/gen_brief.py -Volume vol2 -Batch 091-120

# 写简报文件 + 生成批内状态卡模板
py -3 scripts/gen_brief.py -Volume vol2 -Batch 091-120 -WriteState -BriefOut working/brief.md

# 仅查看某卷全部批次进度
py -3 scripts/gen_brief.py -Volume vol2
```

参数：`-Volume` 卷 id（vol1/vol2），`-Batch` 与 `config/editorial-volumes.json` 中 `range` 一致的节范围，`-WriteState` 生成 `working/batch-state-<卷id>-<范围>.md` 状态卡模板，`-BriefOut` 简报写盘。

### 批次审阅简报 `scripts/gen_report.py`

批末交付给用户审阅的报告生成器（只读 + 运行验证），自动采集本批改动范围、关联提交、台账命中与落账情况、validate 和 `git diff --check` 结果：

```powershell
py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120
py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120 -OutFile notes/batch-report.md
py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120 -SkipValidate
```

"关键裁决及理由"和"遗留问题"两节由编辑会话填写后交付审阅；审阅通过后按批次提交（commit message 含批次范围 + 裁决要点 + 审阅状态）。

### 全卷源文净化 `scripts/clean_full_source.py`

对授权源文 `蛊真人.txt` 做一次性批量清洗（站点广告、作者 ps 碎碎念、打赏/月票拉票、`未完待续` 与 `</dd>` 章尾标记、HTML 标签、微信导流广告、页码水印），产出净版 `蛊真人-clean.txt`：

```powershell
py -3 scripts/clean_full_source.py -SourcePath 蛊真人.txt -OutputPath 蛊真人-clean.txt -ReportPath working/source-clean-candidates.tsv
```

- **行号零漂移**：只行内替换与整行置空，绝不删行；`蛊真人-clean.txt` 与 `蛊真人.txt` 行数一致，挂靠在原文上的 `source_line`、台账行号与 source-map 全部继续有效。
- **已裁决词表自动替换**：淬不及防→猝不及防、幸-运→幸运、爱生离→爱别离、青矛山→青茅山、黒豕→黑豕 等历批确认项。
- **上下文敏感项只出候选**：漠尘/漠北、王大/王二、拼音残留（sè→色 等 OCR 形态）、英文残留等写入 `working/source-clean-candidates.tsv`，仅供人工/LLM 逐条审阅，脚本不自动改。
- 重跑是幂等的；`gen_brief.py` 已优先指向净版（行号不变），校验白名单含 `蛊真人-clean.txt`。

单人单批次串行推进；并行协作规则已在 2026-08-24 极简线重构中移除，如需恢复见 docs/archive/AGENTS-v2-full-2026-08-24.md。

## 会话启动模板

给正文会话提供以下短提示即可；完整规则由模型自行读取文件：

```text
你负责《蛊真人》精编第XXX—YYY节，只处理这一批。
先读 AGENTS.md，然后运行 py -3 scripts/gen_brief.py -Volume <卷id> -Batch <节范围> -WriteState 生成批次简报，按其中指引读取细纲、notes/ledger.md 相关小节与源文对应行区间。
逐节编辑并在批末运行验证：py -3 scripts/validate_editorial_assets.py -Phase detail 与 git diff --check。
完成后 py -3 scripts/gen_report.py -Volume <卷id> -Batch <节范围> 生成交付报告，补全裁决理由后交用户审阅。
```

总编会话职责已并入单会话流程；跨批冲突标为待裁决并记入 notes/ledger.md 待核问题，不在单个批次内自行创造设定。

## 30节交付门槛

每批交付至少满足：

- 章节标题数量与顺序正确。
- 人物、修为、蛊虫、伤势、资源、时间和地点首尾连续。
- 战斗过程、关键哲思、伏笔、高潮及章末推进未被压成梗概。
- 作者怨怼得到压缩，但作品的魔性、黑暗、残酷和人物锋芒没有被中和。
- 共享台账的建议单独列出，未经总编裁决不擅自写成全书规则。

基础验证：

```powershell
py -3 scripts/validate_editorial_assets.py -Phase detail
git diff --check
```

验证通过只说明结构和格式合格，正文仍须由用户或总编会话审阅。
