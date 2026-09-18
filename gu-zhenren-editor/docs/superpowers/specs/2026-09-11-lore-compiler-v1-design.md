# Lore Compiler V1 设计规格

> 日期：2026-09-11
> 状态：设计已获用户确认，等待规格复核
> 范围：首卷前 10 节的可恢复、可验证、证据优先 dry-run

## 1. 目标与边界

Lore Compiler V1 不尝试理解整部小说，也不直接生成游戏数值。它只把局部、可验证、带证据的原文知识转换为下一个结构化状态：

```text
原文 TXT
  -> 章节索引
  -> 不重叠文本块
  -> 受控结构化抽取
  -> 证据与 Schema 校验
  -> SQLite 中间真值
  -> 可恢复 checkpoint
```

本版本的成功标准是：对 `分支：六卷精编版/蛊真人-clean.txt` 中第一卷标题之后的前 10 个 canonical section，完成索引、切块、离线抽取、校验、入库、中断恢复和幂等重跑。

本版本明确不做：

- 不处理全书 700 万字；
- 不生成最终 Godot `data/*.json`；
- 不修改 `ContentCatalog`、Godot 场景、领域规则或现有游戏数据；
- 不生成敌人数值、战斗数值、商店价格或其他平衡参数；
- 不让模型裁决随机、战斗、地图、存档、结局或其他游戏规则；
- 不修改、覆盖、删除或重排原文和已有人工整理成果；
- 不把推断、改编和原创内容伪装成原著事实。

## 2. 仓库接入

Lore Compiler 作为 Godot 项目旁边的本地开发工具存在，不作为 Godot 运行时模块加载。采用已有阶段 0/1 实施计划中的 `lore_engine/` 命名，避免另起一套平行数据体系。

```text
lore_engine/
  cli.py
  config/
  migrations/
  schemas/
  prompts/
  src/
    chunker.py
    contracts.py
    database.py
    model_router.py
    pipeline.py
    seeds.py
    validator.py
  tests/
  fixtures/

lore_sources/
  manifest.json
  seeds/

generated/lore/
  *.sqlite
  checkpoints/
  reports/
  cache/

tools/lore.ps1
```

职责边界：

- `lore_engine/` 保存代码、Schema、提示词版本和测试夹具；
- `lore_sources/manifest.json` 保存原文源声明、相对路径、编码和已核验指纹；
- `lore_sources/seeds/` 保存从现有登记册导入的人工内容，不覆盖 `docs/lore`；
- `generated/lore/` 保存可重建数据库、缓存、checkpoint 和报告，默认不进入 Git；
- `data/*.json` 仍只由现有 Godot 内容体系消费批准后的游戏适配产物，本版本不写入。

工具默认使用 Python 3.12 标准库和 SQLite。实现阶段通过统一入口定位 Python，不把本机绝对路径、密钥或供应商 SDK 写入代码和数据库语义。SQLite 需要启用 FTS5；FTS 只是检索派生能力，不替代规范化表。

## 3. 语料与解析口径

### 3.1 固定 dry-run 选择

本版本只读取：

```text
分支：六卷精编版/蛊真人-clean.txt
```

选择第一卷标题 `第一卷：魔性不改` 之后的前 10 个**无前导缩进**的节标题。清洗稿中的缩进重复标题只作为解析诊断，不创建重复章节。第一卷前 10 个节标题的原著节号为 1 至 10，工具同时保存全局 `sequence=1..10`。

`《人祖传》.txt` 在 V1 中登记为独立 source，但不进入这次 10 节 dry-run；其内容默认属于 `in_world_lore`，不能仅凭自身文本进入客观 canonical 层。

### 3.2 原文只读与严格解码

源清单至少包含：

```json
{
  "source_id": "gu_zhenren_main",
  "path": "分支：六卷精编版/蛊真人-clean.txt",
  "encoding": "utf-8",
  "authority": "primary_text",
  "default_claim_type": "CANON",
  "expected_sha256": "BF78D41427E28BB8B64F1AD6D93B971D1A77458ABF273E554AABE7F27A155D34"
}
```

读取器必须：

- 以二进制读取并严格 UTF-8 解码；
- 不使用 `errors=ignore` 或 `errors=replace`；
- 不自动规范化换行、空白、标点或 Unicode；
- 读取前后验证文件指纹没有变化；
- 指纹不匹配、路径越出仓库或编码失败时停止，不自行修复原文。

当前主语料核验结果作为实现测试基线：SHA-256 为 `BF78D41427E28BB8B64F1AD6D93B971D1A77458ABF273E554AABE7F27A155D34`，大小为 `23609617` bytes，严格 UTF-8 解码通过。若工作树指纹变化，工具报错并要求重新确认，不自动更新 manifest。

### 3.3 章节记录

章节是原文索引的稳定单位，字段包括：

```text
source_id       稳定章节 ID，例如 V01-C001
source_file_id  源清单 ID，例如 gu_zhenren_main
volume          解析得到的卷号，本批为 1
chapter         原著节号，本批为 1..10
title           原始标题文本，去除标题行外层空白但不改正文
sequence        出现顺序，本批为 1..10
start_offset    章节正文在解码后字符流中的起点
end_offset      下一 canonical 章节前的终点
start_byte      UTF-8 字节起点
end_byte        UTF-8 字节终点
text_hash       章节原始文本 SHA-256
parse_status    parsed 或 needs_review
```

`source_id` 不使用节标题文本作为唯一键，也不依赖可能重置的局部节号。基础格式为 `V{volume:02d}-C{chapter:03d}`；若未来同一卷出现无法消歧的重复章节号，解析器必须保留诊断并使用明确的 occurrence 后缀，不能静默覆盖。

### 3.4 Chunk 记录

每个章节内部按原文顺序生成不重叠 chunk：

```text
chunk_id        例如 V01-C001-S01
source_id       所属章节 source_id
volume/chapter  所属卷和原著节号
title           所属章节标题
sequence        章节全局顺序
chunk_sequence  章节内顺序
start_offset    解码后字符起点，包含边界
end_offset      解码后字符终点，不包含边界
start_byte      UTF-8 字节起点
end_byte        UTF-8 字节终点
text            原始 chunk 文本
chunk_hash      原始 chunk 文本 SHA-256
previous_id     前一 chunk，可为空
next_id         后一 chunk，可为空
status          PENDING/RUNNING/SUCCESS/FAILED/NEEDS_REVIEW
```

切分优先级为段落边界、小节或场景边界、必要时的确定性字符边界。3000 至 8000 中文字是软目标；首 10 节中长度不足 3000 字的章节不跨章节拼接，不为满足目标复制或丢弃内容。

canonical chunk 必须满足：

```text
source_text[start_offset:end_offset] == text
相邻 chunk 不重叠
同一章节所有 chunk 首尾连续
chunk 按 sequence/chunk_sequence 可稳定重建
```

相邻上下文通过 `previous_id`、`next_id` 和提取时的相关上下文查询提供，不通过重复写入 canonical chunk 实现。

## 4. Lore V1 数据契约

### 4.1 内容等级

所有事实和候选都必须携带内容等级：

```text
CANON
INFERRED
ADAPTATION
GAME_ORIGINAL
```

等级优先级为 `CANON > INFERRED > ADAPTATION > GAME_ORIGINAL`。优先级只用于审查和冲突展示，不能让低等级内容覆盖高等级内容。

### 4.2 模型输出

模型输出的顶层结构固定为：

```json
{
  "entities": [],
  "facts": [],
  "events": [],
  "relations": [],
  "rule_candidates": [],
  "uncertain_items": []
}
```

模型不得输出自由文本作为正式事实。每条 `fact` 至少包含：

```json
{
  "fact_id": "fact-v1-example-001",
  "subject": "实体或原文主体",
  "predicate": "关系或属性",
  "object": "实体、值或描述",
  "fact_type": "CANON",
  "confidence": 0.0,
  "source_id": "V01-C001",
  "chunk_id": "V01-C001-S01",
  "source_quote": "逐字可回查的短引文",
  "sequence": 1,
  "conditions": [],
  "uncertainty": ""
}
```

实体类型至少包括 `character`、`faction`、`location`、`resource`、`item`、`creature`、`cultivation`、`concept`、`organization`。别名先保存为 `possible_match`；除非名称、类型、上下文和证据足以支持合并，否则不自动将不同称呼视为同一实体。

事件必须支持 `type`、`participants`、`location`、`cause`、`effects`、`sequence` 和 `source_refs`。关系至少支持 `belongs_to`、`controls`、`located_at`、`allied_with`、`enemy_of`、`uses`、`produces`、`consumes`、`knows`、`kills`、`trades_with`、`causes` 和 `affected_by`。

规则候选只保存结构化方向，例如 `realm_gap`、`condition`、`effect` 和 `source_refs`，不直接生成 HP、伤害、倍率、价格或掉落概率。

### 4.3 SQLite 表

SQLite 至少包含以下规范化表：

| 表 | 作用 | 关键幂等键 |
| --- | --- | --- |
| `schema_migrations` | 迁移版本 | `version` |
| `sources` | 源文件声明和指纹 | `source_file_id` |
| `chapters` | 章节索引 | `source_id` |
| `chunks` | 原文块和 checkpoint 状态 | `chunk_id` |
| `entities` | 实体候选和类型 | `entity_key` |
| `entity_aliases` | 别名及匹配状态 | `entity_id + alias + match_status` |
| `facts` | 结构化事实 | `fact_key` |
| `events` | 带因果字段的事件 | `event_key` |
| `relations` | 实体关系 | `relation_key` |
| `rule_candidates` | 尚未转成游戏规则的候选 | `rule_key` |
| `conflicts` | 冲突及证据引用 | `conflict_key` |
| `extraction_runs` | 运行、模型、校验和重试状态 | `run_id`，另有 chunk/input/version 唯一约束 |

JSON 数组和模型原始 payload 以 canonical JSON 保存；正式记录的 `source_quote` 不能脱离 source/chunk 引用单独存在。所有跨表写入必须通过事务完成。

## 5. Seed Data 导入

现有人工成果作为 V0 seed data 导入，保持来源文件、原始文本、内容哈希和人工状态：

```text
seed_canon       已登记的 CAN-* 原著事实
seed_inferred    已登记的稳定推断
seed_note        待验证假设、勘误和备注
seed_game_design 已登记的游戏规则或改编内容
```

seed 导入是追加或幂等 upsert，不删除原文、不重写 `docs/lore`，也不把 seed note 自动升级成 canonical。`seed_canon` 的审查优先级高于模型新提取内容，但仍须保留模型记录及其证据，不能通过删除模型候选来制造一致性。

V1 首先覆盖 `docs/lore/canon-index.md`、`adaptation-register.md` 和 `game-rule-register.md` 中可稳定解析的条目；无法可靠解析的人工条目进入 `NEEDS_REVIEW`，不丢失、不猜测。

## 6. 抽取器与模型路由

### 6.1 固定提示词边界

提示词由固定前缀和变化 payload 组成：

```text
固定：SYSTEM RULE + SCHEMA + ENTITY TYPES + RELATION TYPES + OUTPUT FORMAT
变化：chapter metadata + chunk text + relevant context
```

核心规则保持短小固定：只抽取输入支持的信息；区分 CANON 与 INFERRED；每条事实必须有证据；保留不确定性；不覆盖已有 canonical；只输出符合 Schema 的 JSON。无关 Lore DB 不进入 prompt。

### 6.2 Adapter 与默认后端

抽取器通过统一 `ModelTask -> ModelResult` 接口调用后端：

- 默认配置为 `gpt-5.6-luna`、`low`；
- `fixture` 后端用于离线 dry-run 和测试，输出录制的合法 JSON；
- `disabled` 后端用于仅索引/仅校验流程，不联网；
- HTTP Luna adapter 只在显式 `--allow-network` 时启用，密钥只从环境变量读取；
- 只有实体歧义、跨 chunk 关系、多事件因果、冲突候选、规则候选整合等情况才允许升级到 Luna Medium/High；
- 不默认调用 Terra。

缓存键包含输入哈希、提示词版本、Schema 版本、backend 和 model。命中缓存时不重复调用，但仍重新执行本地 Schema、证据和引用校验。

## 7. Validation 与失败隔离

每次模型输出按以下顺序验证：

1. JSON parse；
2. 顶层及记录级 JSON Schema；
3. `source_id`、`chunk_id` 和 sequence 引用；
4. 实体引用和 relation/event participant 引用；
5. enum、confidence 范围和必填字段；
6. `source_quote` 在对应 chunk 中逐字匹配；
7. 稳定事实键和重复检测；
8. seed 优先级、事实等级和冲突状态。

模型失败或校验失败自动重试一次。第二次仍失败时，不写正式 Lore 记录，只保留失败响应摘要、错误码、输入哈希和重试次数，将 chunk 标记为 `FAILED` 或 `NEEDS_REVIEW`，并写入 `extraction_runs` 隔离记录。不能通过空结果伪装为成功。

引文无法唯一对齐时证据无效。不能因为引文在全文中出现过，就静默选择第一处。

## 8. Checkpoint、Resume 与幂等

每个 chunk 独立拥有以下状态：

```text
PENDING -> RUNNING -> SUCCESS
                   -> FAILED
                   -> NEEDS_REVIEW
```

执行流程：

1. 以 input hash、prompt version、schema version 和 source/chunk hash 领取 `PENDING` 或已过期的 `RUNNING` chunk；
2. 写入 lease、started_at 和当前 `run_id`；
3. 执行模型调用和本地验证；
4. 在同一短事务中写入通过校验的结构化记录并将 chunk 标记为 `SUCCESS`；
5. 失败只提交隔离运行记录和失败状态，不提交正式 Lore 记录；
6. 进程中断后，过期 lease 可回收；
7. `resume` 只处理未成功或输入版本发生变化的 chunk；
8. `retry` 只处理 `FAILED`/`NEEDS_REVIEW` chunk；
9. 相同 chunk、相同输入和相同版本重复执行不得生成重复记录。

稳定自然键和唯一约束负责幂等，不能依赖自增行号。`dry_run` 只执行读取、切块、prompt 组装、fixture/disabled 抽取和验证预览，可选择不提交正式事实，但必须报告将要写入的记录数及失败项。

## 9. CLI 入口

V1 统一通过 `tools/lore.ps1` 调用，至少提供：

```text
tools/lore.ps1 ingest --verify-only
tools/lore.ps1 index --source gu_zhenren_main --limit 10
tools/lore.ps1 run --backend fixture --dry-run
tools/lore.ps1 run --backend fixture --stop-after 3
tools/lore.ps1 run --backend fixture --resume
tools/lore.ps1 retry --status FAILED
tools/lore.ps1 validate --database generated/lore/lore-v1.sqlite
tools/lore.ps1 report --database generated/lore/lore-v1.sqlite
```

CLI 退出码固定为 `0=success`、`2=configuration/input error`、`3=validation/quality gate failure`、`4=task quarantined`、`5=unexpected internal error`。实现阶段可以调整参数名称，但必须保留索引、dry-run、显式停止、resume、retry、validation 和报告行为。

## 10. 测试与验收

测试使用 Python `unittest`，不依赖网络、不依赖 Godot 场景。真实 10 节 dry-run 只读取已登记原文，并将生成物写入 `generated/lore/`。

单元测试至少覆盖：

- 源文件严格解码、SHA-256 和只读守卫；
- 第一卷标题和前 10 个无缩进 section 标题解析；
- 缩进重复标题不会生成重复章节；
- `source_id`、`chunk_id`、sequence 和字符/字节偏移稳定；
- chunk 不重叠、不丢字、不重复，首尾可重建；
- 长段落确定性切分和短章节软目标；
- SQLite 迁移、外键、唯一约束、FTS5 和幂等导入；
- 模型 Schema、枚举、confidence、引用和引文逐字校验；
- 无法对齐、多义引用和非法 JSON 隔离；
- seed 四种类型的优先级和保留规则；
- checkpoint 状态迁移、lease 回收、stop/resume/retry；
- 相同输入两次运行的逻辑内容哈希一致。

10 节 dry-run 必须实际验证：

1. 识别第一卷和前 10 节标题；
2. 建立 10 个稳定章节 ID 和有序 chunk；
3. 使用 fixture 后端产生结构化抽取结果；
4. 成功事实均有合法 `source_id`、`chunk_id` 和逐字引文；
5. 中途停止后数据库保留已提交 chunk 状态；
6. `resume` 只继续未完成 chunk；
7. 重复执行不增加重复记录；
8. 非法模型输出重试一次并隔离，不污染正式表；
9. `data/`、Godot 脚本、场景和原文目录的 Git diff 保持为空；
10. 报告包含成功、失败、重试、待审和记录数量。

真实 Luna adapter 在本阶段只验证协议、显式网络开关、密钥不入库、响应 Schema 校验和失败隔离；离线 fixture dry-run 是稳定回归基线。

## 11. 与现有 Godot 体系的边界

现有 `ContentCatalog` 继续作为 Godot 数据的唯一加载入口。Lore Compiler 只产生中间 SQLite 和待审报告，不直接把 Lore 实体转换成 `data/gu.json`、`data/events.json` 或其他运行时表。

未来适配层必须引用已批准的 Lore entity/fact/event/rule candidate ID，并另外记录 `ADAPTATION` 或 `GAME_ORIGINAL`。只有人工批准的适配产物才允许进入 Godot 数据目录；那是 V1 之后的独立阶段。

现有 `docs/lore/canon-index.md`、`adaptation-register.md` 和 `game-rule-register.md` 在迁移期继续保留，Lore Compiler 不能把 SQLite 导出结果反写覆盖它们。

## 12. 已知限制与后续决策

- 当前清洗稿只有一个显式卷标题，后续卷边界需要新增来源解析策略，本批次不猜测；
- 清洗稿存在缩进重复标题和节号重置，首期只处理已确认的第一卷前 10 个 canonical section；
- 3000 至 8000 字 chunk 目标不是硬约束，后续需用高密度、低密度和跨场景样本校准；
- V1 只保证结构化抽取和证据保存，不承诺全书召回率或复刻级知识覆盖；
- 100 至 300 条人工评测集、严格/研究双查询、后文反证、发布快照和 Godot 适配导出留待后续阶段；
- 真实 Luna 成本、token 统计和升级阈值必须在离线闭环稳定后，用明确预算单独校准。
