# 《蛊真人》授权文本精编版

本仓库用于完本小说的出版级精编。工作包括正文重构、世界观校准、编辑台账和回归检查，不是续写、同人或剧情摘要。

## 唯一规范源

所有 AI 会话开始工作前必须先读 [`AGENTS.md`](AGENTS.md)。它是编辑边界、裁决优先级、文风判据和验证流程的唯一完整规范源。

README 只负责分工和启动，不复制完整规则。README、提示词或模型记忆与 `AGENTS.md` 冲突时，以 `AGENTS.md` 为准。

## 目录

- `volumes/`：分卷、分批次精编正文。
- `working/`：本地原文底稿，不作为最终正文。
- `outlines/detail/`：每个 30 节批次的功能细纲。
- `notes/`：全书审查、卷级裁决及战力、资源、信息、时间、人物台账。
- `scripts/`：拆分、建档和验证脚本。

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

### 批内状态卡 `working/batch-state-<卷id>-<范围>.md`

批次进行中的临时状态记录（人物修为/蛊组/伤势、资源、身份位置、信息边界、每节结束状态）。批次中间换会话或上下文压缩时，先读状态卡恢复进度。批末内容并入正式台账后删除，不随批次提交。

### 批次审阅简报 `scripts/gen_report.py`

批末交付给用户审阅的报告生成器（只读 + 运行验证），自动采集本批改动范围、关联提交、台账命中与落账情况、validate 和 `git diff --check` 结果：

```powershell
py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120
py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120 -OutFile notes/batch-report.md
py -3 scripts/gen_report.py -Volume vol2 -Batch 091-120 -SkipValidate
```

"关键裁决及理由"和"遗留问题"两节由编辑会话填写后交付审阅；审阅通过后按批次提交（commit message 含批次范围 + 裁决要点 + 审阅状态）。

### 台账追加式维护

所有 `notes/vol*-*.md` 台账第 2 行为状态行（`> 台账状态行：最后落地批次…`）；新批记录只追加到文件底部，不重写中部历史行；修正历史裁决时在底部加"勘误"行并注明原行 ID。批末更新状态行的"最后落地批次"与"最后更新"。

## 多对话并行

OpenCode 可同时启动多个 DeepSeek 对话，但每个正文会话只能领取一个互不重叠的 30 节批次，例如：

```text
会话 A：第001—030节
会话 B：第031—060节
会话 C：第061—090节
会话 D：第091—120节
```

并行时遵守以下边界：

1. 一个正文文件同时只允许一个会话修改。
2. 正文会话只修改获配的 `volumes/...edited.txt` 和对应 `outlines/detail/*.md`。
3. `AGENTS.md`、卷级 `decision-register` 和共享专项台账由单独的总编会话维护，正文会话只提交更新建议。
4. 相邻批次开工前读取前一批结尾状态和后一批细纲，禁止改变跨批伏笔、人物终局或信息释放顺序。
5. 发现全书级冲突时标为待裁决，不在单个正文会话中自行创造设定。
6. 每批独立校验、独立审阅、独立提交；未通过审阅的批次不得作为后续冻结依据。

同一工作区并行写文件仍可能产生覆盖。实际并行开发应让每个对话使用独立 Git 分支或 worktree，最后由总编会话按批次合并。

## 会话启动模板

给每个正文会话提供以下短提示即可；完整规则由模型自行读取文件：

```text
你负责《蛊真人》精编第XXX—YYY节，只处理这一批。
先读 AGENTS.md，然后运行 py -3 scripts/gen_brief.py -Volume <卷id> -Batch <节范围> -WriteState 生成批次简报，再按其中台账命中和源文行号指引读取对应文件。
不得修改其他批次正文或共享裁决文件。先报告范围、冻结裁决、人物/资源/时间起止状态，再开始工作。
完成后运行 AGENTS.md 规定的验证命令，输出改动摘要、台账更新建议和回归结果。
```

总编会话负责：裁决跨批冲突、更新共享台账、检查相邻批次衔接、吸收用户审阅意见并决定是否冻结。

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
