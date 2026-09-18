# 小说到游戏阶段 0 与阶段 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立一个本地优先、云端可选、可复现且证据可逐字回查的《蛊真人》知识引擎基准与真实原文纵向闭环，为阶段 2 全书扫描提供冻结的质量阈值、模型路由和数据契约。

**Architecture:** Python 3.12 标准库负责严格解码、稳定切块、SQLite/FTS5、规则发现、证据对齐、裁决、查询、报告与 CLI。所有模型工作都经过统一 `ModelTask` 契约；默认 `fixture`/`disabled` 后端离线运行，可选云端后端只生成待验证候选并写内容寻址缓存，任何失败都不得把未验证内容写入最终知识层。阶段 0 产出冻结基准包和准入裁定，阶段 1 只消费获准的阶段 0 配置打通端到端闭环。

**Tech Stack:** Python 3.12.10 standard library (`argparse`, `dataclasses`, `hashlib`, `json`, `pathlib`, `sqlite3`, `unittest`, `urllib`), SQLite 3.49.1 with FTS5, PowerShell 7, JSON/JSON Schema-like local validators, Markdown reports.

## Global Constraints

- 权威设计：`docs/superpowers/specs/2026-08-26-novel-to-game-lore-engine-design.md`。
- 机制边界：`docs/superpowers/specs/2026-08-25-mechanics-first-lockdown-design.md`；知识提取不因当前玩法需求删改原著信息。
- `分支：六卷精编版/` 全程只读；任务不得改写、转码或格式化其中任何文件。
- `蛊真人-clean.txt` 与《人祖传》必须分别声明编码并严格解码；禁止 `errors="ignore"` 或 `errors="replace"`。
- SQLite 是结构化真值；Markdown、JSON 报告、缓存和索引均为可重建派生产物。
- 默认离线运行；无 API key、断网、超时、非法 JSON、Schema 不符或引文不对齐时，正式结果仍须确定性可复现。
- 云端供应商、模型名、URL 和密钥不得写入知识语义、测试夹具或 Git；密钥只从环境变量读取。
- 二手资料与现有 `docs/lore` 只生成候选，不得单独升级为 `canonical`。
- 《人祖传》默认 `in_world_lore`；只有正文现实证据可生成另一个客观断言。
- 游戏适配层只能读取已发布严格知识快照；阶段 0/1 不修改 `data/*.json`、Godot 场景或 GDScript。
- 已确认断言的每个关键字段必须有正文证据，且完成反证检索；不确定内容必须降级。
- 运行生成物写入 `generated/lore/` 并保持 Git 忽略；只提交代码、迁移、配置、提示词、人工金标准、小型夹具和选择性报告样本。
- 当前工作树有并行 UI、依赖和原文状态改动；执行前创建独立 worktree，禁止清理、回退或格式化用户现有改动。

---

## 阶段边界与门禁

### 阶段 0：基准校准

阶段 0 只回答四个问题：源文件能否可靠定位；三类样本上哪些发现路线有效；什么确认阈值能防止错误事实进入严格层；全书处理的预计成本与耗时是否可接受。其产物不是“部分知识库”，而是冻结的基准、配置和 Go/No-Go 报告。

**阶段 0 出口条件：**

1. 三类样本均有固定原文字节范围、字符范围、哈希和人工金标准。
2. 严格解码、稳定切块、字符回查、FTS5 和迁移测试全绿。
3. `rule_scan`、`fixture_model`、`blind_audit` 三条发现路线进入同一候选契约。
4. 每条自动确认结果均通过字段级证据覆盖和反证检查；不确定项被降级。
5. 报告给出每条路线的 precision、recall、F1、漏检类型、耗时和估算成本。
6. `docs/lore/generated/phase0-gate.md` 明确记录 `GO`、`CONDITIONAL_GO` 或 `NO_GO`；只有前两者可进入阶段 1，`CONDITIONAL_GO` 必须列出阶段 1 的强制限制。

### 阶段 1：可验证纵向闭环

阶段 1 使用真实正文和阶段 0 冻结配置，打通：导入、发现、证据对齐、反证、裁决、SQLite、严格/研究查询、质量成本报告和只读适配边界。它不追求全书覆盖，也不量产游戏内容。

**阶段 1 出口条件：**

1. 同一输入和配置连续运行两次，发布快照逻辑内容哈希一致。
2. 离线模式完整通过；云端增强关闭或失败时不改变已发布严格结果。
3. 四个最低验收问题均返回完整答案契约、证据链、反例和未知项。
4. 严格模式零泄漏 `unconfirmed`、`character_claim`、`in_world_lore`、二手候选和游戏补全。
5. 阶段 1 报告给出覆盖、争议、质量、缓存命中、成本和失败恢复结果。
6. `data/` 边界守卫证明未经批准的知识记录无法进入 Godot 内容。

## 文件责任图

```text
lore_engine/
  __init__.py
  cli.py                       # 唯一命令行入口和退出码
  config/default.json          # 本地优先路由、路径、阈值和预算
  config/phase0.lock.json      # 阶段 0 通过后冻结，阶段 1 只读消费
  schemas/*.json               # 模型输出和查询答案契约
  migrations/001_initial.sql   # SQLite 真值结构与 FTS5
  prompts/*.txt                # 开放发现、反证、盲审提示词，带显式版本
  src/source_manifest.py       # 源声明、严格解码、指纹
  src/chunker.py               # 章节/段落/块与稳定 ID
  src/database.py              # 迁移、事务、Repository API
  src/contracts.py             # dataclass 与枚举、JSON 验证
  src/discovery.py             # 规则扫描与共享候选池
  src/model_router.py          # disabled/fixture/cloud 路由和缓存
  src/evidence.py              # 引文对齐、证据覆盖、反证任务
  src/adjudication.py          # 状态降级和自动确认
  src/query.py                 # strict/research 查询与答案契约
  src/benchmark.py             # precision/recall/F1、成本与阶段门
  src/pipeline.py              # 可恢复任务编排和发布快照
  src/reports.py               # JSON/Markdown 派生报告
  tests/                       # unittest；不依赖网络
  tests/fixtures/sources/      # 小型 UTF-8/GB18030/冲突文本
  tests/fixtures/model/        # 录制的合法、非法、超时响应
  tests/fixtures/gold/         # 测试用金标准
lore_sources/
  manifest.json                # 权威源和二手源元数据，不复制原文
  benchmarks/phase0/*.json     # 三类人工金标准与抽样理由
docs/lore/generated/
  phase0-gate.md               # 提交选择性基准结果与裁定
  phase1-acceptance.md          # 提交阶段 1 验收摘要
generated/lore/                # knowledge.sqlite、缓存、全量报告；忽略
tools/lore.ps1                 # Windows 统一入口
```

## 稳定接口

以下接口在 Task 2 锁定，后续任务不得改名：

```python
@dataclass(frozen=True)
class SourceSpec:
    source_id: str
    path: str
    encoding: str
    authority: str
    default_claim_status: str
    expected_sha256: str

@dataclass(frozen=True)
class TextBlock:
    block_id: str
    source_id: str
    chapter_key: str
    char_start: int
    char_end: int
    text: str
    content_sha256: str
    previous_block_id: str | None
    next_block_id: str | None

@dataclass(frozen=True)
class CandidateClaim:
    candidate_id: str
    subject: str
    predicate: str
    object_value: str
    conditions: tuple[str, ...]
    scale: str
    claim_type: str
    source_block_ids: tuple[str, ...]
    discovery_routes: tuple[str, ...]
    raw_payload_sha256: str

@dataclass(frozen=True)
class ModelTask:
    task_type: str
    input_sha256: str
    prompt_version: str
    schema_version: str
    payload: dict[str, object]

@dataclass(frozen=True)
class ModelResult:
    status: str
    backend: str
    model: str
    output: dict[str, object] | None
    raw_sha256: str | None
    elapsed_ms: int
    estimated_cost_micros: int
    error_code: str | None

@dataclass(frozen=True)
class QueryAnswer:
    canonical_answer: list[dict[str, object]]
    derived_inference: list[dict[str, object]]
    reasoning_chain: list[dict[str, object]]
    counter_evidence: list[dict[str, object]]
    unknowns: list[str]
    confidence: str
    citations: list[dict[str, object]]
```

CLI 退出码固定为：`0=success`、`2=configuration/input error`、`3=quality gate failed`、`4=task quarantined`、`5=unexpected internal error`。

---

# 阶段 0：基准校准

### Task 0.1：隔离工作树与 Python 测试骨架

**Files:**
- Create: `lore_engine/__init__.py`
- Create: `lore_engine/cli.py`
- Create: `lore_engine/tests/__init__.py`
- Create: `tools/lore.ps1`
- Modify: `.gitignore`

**Produces:** 可在 Windows 从仓库根目录调用的离线测试入口；生成目录不会进入 Git。

- [ ] **Step 1: 创建隔离 worktree 并记录基线**

```powershell
git status --short
git worktree add .worktrees/lore-phase01 -b codex/lore-phase01 master
Set-Location .worktrees/lore-phase01
git status --short
```

Expected: 新 worktree 为干净的 `codex/lore-phase01`；主工作树改动未被带入或修改。

- [ ] **Step 2: 写失败的入口测试**

新增 `lore_engine/tests/test_cli_smoke.py`，断言 `python -m lore_engine.cli --help` 返回 `0` 且帮助文本包含 `ingest`、`benchmark`、`run`、`query`、`report`。

- [ ] **Step 3: 运行并确认失败**

```powershell
python -m unittest lore_engine.tests.test_cli_smoke -v
```

Expected: FAIL，因为 `lore_engine.cli` 尚不存在。

- [ ] **Step 4: 建立最小入口与忽略规则**

`tools/lore.ps1` 只负责定位仓库根目录并调用 `python -m lore_engine.cli @args`。在 `.gitignore` 增加：

```gitignore
generated/lore/
lore_engine/__pycache__/
**/__pycache__/
```

最小 `cli.py` 在 Task 0.2 实现；本任务可先提供带五个空子命令的 parser，使帮助测试通过。

- [ ] **Step 5: 验证并提交**

```powershell
python -m unittest discover -s lore_engine/tests -v
git diff --check
git add .gitignore lore_engine tools/lore.ps1
git commit -m "build(lore): scaffold offline knowledge engine"
```

Expected: tests PASS；提交不包含 `generated/lore/`。

### Task 0.2：源清单、严格解码与文件指纹

**Files:**
- Create: `lore_sources/manifest.json`
- Create: `lore_engine/config/default.json`
- Create: `lore_engine/src/source_manifest.py`
- Create: `lore_engine/tests/test_source_manifest.py`
- Create: `lore_engine/tests/fixtures/sources/utf8_sample.txt`
- Create: `lore_engine/tests/fixtures/sources/gb18030_sample.txt`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- Produces: `load_manifest(path: Path) -> tuple[SourceSpec, ...]`
- Produces: `read_source(root: Path, spec: SourceSpec) -> str`
- Produces: `fingerprint_source(root: Path, spec: SourceSpec) -> dict[str, object]`

- [ ] **Step 1: 写严格解码与只读守卫测试**

测试必须覆盖：UTF-8 正常读取、GB18030 正常读取、错误编码抛 `UnicodeDecodeError`、哈希不符抛 `SourceFingerprintError`、路径越出仓库抛错、读取前后 `mtime_ns` 和 SHA-256 不变。

- [ ] **Step 2: 运行并确认失败**

```powershell
python -m unittest lore_engine.tests.test_source_manifest -v
```

Expected: FAIL，因为 `SourceSpec` 与读取器不存在。

- [ ] **Step 3: 实现源清单**

`manifest.json` 至少声明 `gu_zhenren_main` 和 `ren_zu_zhuan`，字段使用稳定接口中的 `SourceSpec`。`default.json` 保存仓库相对路径、默认 `disabled` 后端、切块候选参数和空的云端配置，不保存密钥。实现时对整个字节流严格解码，不使用自动猜测，不标准化换行，不改写文件。

执行一次探针后把当前实际编码和 SHA-256 写入清单；若工作树中的原文与 `master` 指纹不同，停止并由用户裁定，不自行更新权威指纹。

- [ ] **Step 4: 增加 `ingest --verify-only`**

```powershell
./tools/lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
```

Expected: 输出两个 source ID、字节数、字符数、编码和 SHA-256；退出 `0`；原文 `git diff` 为空。

- [ ] **Step 5: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_source_manifest -v
git diff --check
git add lore_sources/manifest.json lore_engine
git commit -m "feat(lore): verify immutable source corpus"
```

### Task 0.3：稳定切块、字符定位与 SQLite 初始迁移

**Files:**
- Create: `lore_engine/migrations/001_initial.sql`
- Create: `lore_engine/src/chunker.py`
- Create: `lore_engine/src/database.py`
- Create: `lore_engine/tests/test_chunker.py`
- Create: `lore_engine/tests/test_database.py`

**Interfaces:**
- Produces: `iter_blocks(source_id: str, text: str, target_chars: int, overlap_chars: int) -> Iterator[TextBlock]`
- Produces: `LoreDatabase.open(path: Path)`, `.migrate()`, `.replace_source(spec, blocks)`, `.search_blocks(query, limit)`

- [ ] **Step 1: 写切块与迁移失败测试**

覆盖章节标题识别、段落边界优先、超长段落确定性切分、重叠上下文、稳定 block ID、相邻指针、`text[char_start:char_end] == block.text`、重复导入幂等、FTS5 命中和外键约束。

- [ ] **Step 2: 运行并确认失败**

```powershell
python -m unittest lore_engine.tests.test_chunker lore_engine.tests.test_database -v
```

- [ ] **Step 3: 实现迁移**

`001_initial.sql` 创建：`schema_migrations`、`sources`、`chapters`、`blocks`、`blocks_fts`、`entities`、`aliases`、`candidate_claims`、`candidate_routes`、`claims`、`evidence`、`cases`、`mechanisms`、`inferences`、`tasks`、`model_cache`、`adjudications`、`query_runs`、`release_snapshots`。所有 ID 为稳定文本 ID；JSON 字段存 canonical JSON；正式写入通过事务。

- [ ] **Step 4: 实现稳定切块**

block ID 公式固定为：

```python
sha256(f"block-v1\0{source_id}\0{char_start}\0{char_end}\0{content_sha256}".encode("utf-8")).hexdigest()[:24]
```

默认 `target_chars=2400`、`overlap_chars=300` 只是阶段 0 候选参数，不在源码硬编码；由配置传入。

- [ ] **Step 5: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_chunker lore_engine.tests.test_database -v
./tools/lore.ps1 ingest --database generated/lore/phase0.sqlite --sources gu_zhenren_main
git diff --check
git add lore_engine
git commit -m "feat(lore): add stable corpus index and sqlite schema"
```

Expected: 样本测试全绿；真实导入报告 `indexed_chars == decoded_chars`，且数据库被 Git 忽略。

### Task 0.4：三类人工金标准

**Files:**
- Create: `lore_sources/benchmarks/phase0/high_density.json`
- Create: `lore_sources/benchmarks/phase0/social_mechanism.json`
- Create: `lore_sources/benchmarks/phase0/later_correction.json`
- Create: `lore_sources/benchmarks/phase0/README.md`
- Create: `lore_engine/src/contracts.py`
- Create: `lore_engine/tests/test_gold_contract.py`
- Create: `lore_engine/schemas/candidate-claim-v1.json`

**Interfaces:**
- Produces: `load_gold_set(path: Path, source_text: str) -> GoldSet`
- Produces: `validate_candidate_claim(payload: object) -> CandidateClaim`

- [ ] **Step 1: 先定义金标准校验测试**

断言每个样本包含：选择理由、源 ID、字节/字符范围、原文哈希、正例断言、明确非断言项、实体别名、证据短引文、冲突/例外、知识类型和人工备注。引文必须逐字存在于声明范围；断言 ID 不得重复。

- [ ] **Step 2: 从正文只读选取三类样本**

使用 FTS 和现有 `canon-index.md` 作为定位线索，但人工回读完整上下文：

1. 高密度：资质、修为或蛊虫规则连续出现的片段；
2. 低密度社会机制：散修资源获取、交易、组织约束或信息差案例；
3. 后文修正：同一说法在后文被限定、纠正或推翻的跨章节片段。

每类建议 8,000–20,000 字；实际范围在 JSON 中固定，不复制整段原文，只保存短引文和位置。

- [ ] **Step 3: 双人/双代理独立标注后合并**

标注者 A 与 B 各自提交候选清单；协调者只合并双方一致项，并把分歧保留在 `adjudication_notes`。不得让同一模型输出充当两名独立标注者。

- [ ] **Step 4: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_gold_contract -v
./tools/lore.ps1 benchmark validate-gold --gold lore_sources/benchmarks/phase0
git add lore_sources/benchmarks lore_engine/src/contracts.py lore_engine/schemas lore_engine/tests
git commit -m "test(lore): establish phase zero gold standard"
```

Expected: 三类样本全部逐字对齐；分歧有显式状态，无待填字段。

### Task 0.5：共享候选池与三路发现

**Files:**
- Create: `lore_engine/src/discovery.py`
- Create: `lore_engine/prompts/open-discovery-v1.txt`
- Create: `lore_engine/prompts/blind-audit-v1.txt`
- Create: `lore_engine/tests/test_discovery.py`
- Create: `lore_engine/tests/fixtures/model/open_discovery_valid.json`
- Create: `lore_engine/tests/fixtures/model/blind_audit_valid.json`

**Interfaces:**
- Produces: `rule_scan(block: TextBlock, patterns: dict) -> tuple[CandidateClaim, ...]`
- Produces: `merge_candidates(items: Iterable[CandidateClaim]) -> tuple[CandidateClaim, ...]`
- Consumes: `validate_candidate_claim()`

- [ ] **Step 1: 写失败测试**

覆盖定义、条件、限制、尺度、因果、变化、修正模式召回；模式只能生成待判断候选，不能直接成为 confirmed claim。测试同一语义由三路命中时合并路线但不伪增证据；开放输出中的未知类型保留为 `unclassified_claim`。

- [ ] **Step 2: 实现确定性规则扫描**

模式与版本写入 `config/default.json`；候选 ID 基于规范化主体/谓词/客体/条件与源块 ID 生成。规范化只折叠空白和受控标点，不做同义词脑补。

- [ ] **Step 3: 接入 fixture 模型和盲审夹具**

此任务只读取录制 JSON，不发网络请求。两条模型路线输出同一个 `CandidateClaim` 契约；原始 payload 哈希必须保留。

- [ ] **Step 4: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_discovery -v
./tools/lore.ps1 benchmark discover --gold lore_sources/benchmarks/phase0 --backend fixture
git add lore_engine
git commit -m "feat(lore): unify three candidate discovery routes"
```

### Task 0.6：本地优先模型路由、缓存与云端隔离

**Files:**
- Create: `lore_engine/src/model_router.py`
- Create: `lore_engine/schemas/model-task-v1.json`
- Create: `lore_engine/tests/test_model_router.py`
- Create: `lore_engine/tests/fixtures/model/invalid_json.txt`
- Create: `lore_engine/tests/fixtures/model/schema_invalid.json`
- Modify: `lore_engine/config/default.json`

**Interfaces:**
- Produces: `ModelRouter.run(task: ModelTask) -> ModelResult`
- Backends: `DisabledBackend`, `FixtureBackend`, `JsonHttpBackend`

- [ ] **Step 1: 写离线、缓存和失败隔离测试**

覆盖：默认 backend 为 `disabled`；fixture 完全离线；同一任务第二次命中缓存；prompt/schema/model/backend 任一变化产生新 cache key；API key 不入数据库；超时、HTTP 错误、非法 JSON、Schema 错误返回隔离状态；失败结果不能创建 claims/evidence。

- [ ] **Step 2: 实现内容寻址缓存**

cache key：

```python
sha256(canonical_json({
    "task": task,
    "backend": backend_id,
    "model": model_id,
    "prompt_version": task.prompt_version,
    "schema_version": task.schema_version,
}).encode("utf-8")).hexdigest()
```

- [ ] **Step 3: 实现通用 JSON HTTP 后端**

使用 `urllib.request`；URL、模型和 API key 环境变量名来自配置。后端只接受/返回 `ModelTask`/`ModelResult`，不得导入供应商 SDK。`--allow-network` 是发网必要条件；没有该参数即使配置了 key 也不得联网。

- [ ] **Step 4: 验证无网可运行**

```powershell
Remove-Item Env:LORE_API_KEY -ErrorAction SilentlyContinue
python -m unittest lore_engine.tests.test_model_router -v
./tools/lore.ps1 benchmark discover --backend disabled --gold lore_sources/benchmarks/phase0
```

Expected: tests PASS；命令退出 `0`；无网络调用。

- [ ] **Step 5: 提交**

```powershell
git add lore_engine
git commit -m "feat(lore): add local-first optional model routing"
```

### Task 0.7：证据对齐、反证搜索与裁决状态机

**Files:**
- Create: `lore_engine/src/evidence.py`
- Create: `lore_engine/src/adjudication.py`
- Create: `lore_engine/prompts/counter-evidence-v1.txt`
- Create: `lore_engine/tests/test_evidence.py`
- Create: `lore_engine/tests/test_adjudication.py`

**Interfaces:**
- Produces: `align_quote(source_text: str, quote: str, expected_start: int | None) -> Alignment`
- Produces: `field_coverage(candidate, evidence) -> dict[str, bool]`
- Produces: `find_counter_evidence(candidate, repository) -> tuple[Evidence, ...]`
- Produces: `adjudicate(candidate, evidence, policy) -> AdjudicationDecision`

- [ ] **Step 1: 写证据与裁决矩阵测试**

至少覆盖：可靠旁白强支持、实际案例支持、角色转述、角色谎言、后文修正、地域/时期差异、只证明 possible 却被泛化为 always、《人祖传》默认世界内传说、引文多处匹配需消歧、关键字段无证据时禁止确认。

- [ ] **Step 2: 实现逐字证据对齐**

引文保存 source ID、char start/end、block ID、quote SHA-256、narrative type、direction、conditions。若引文零匹配或多匹配且无法凭上下文消歧，证据状态为 invalid，不得静默选第一处。

- [ ] **Step 3: 实现反证优先与降级状态机**

允许状态仅为：`confirmed`、`unconfirmed`、`in_world_lore`、`character_claim`、`best_supported_inference`、`conflicted`、`unknown`、`superseded`。自动确认必须满足字段覆盖、强证据/多独立证据、反证任务完成、无未解释强冲突、范围明确和影响等级阈值。

- [ ] **Step 4: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_evidence lore_engine.tests.test_adjudication -v
git add lore_engine
git commit -m "feat(lore): enforce evidence-first adjudication"
```

### Task 0.8：基准指标、成本估算与阶段 0 门

**Files:**
- Create: `lore_engine/src/benchmark.py`
- Create: `lore_engine/src/reports.py`
- Create: `lore_engine/tests/test_benchmark.py`
- Create: `docs/lore/generated/phase0-gate.md`
- Create: `lore_engine/config/phase0.lock.json`

**Interfaces:**
- Produces: `score(gold: GoldSet, predicted: Iterable[CandidateClaim]) -> BenchmarkScore`
- Produces: `evaluate_phase0(report: BenchmarkReport, gate_policy: dict) -> GateDecision`

- [ ] **Step 1: 写指标和门禁测试**

测试 precision/recall/F1 的空集合、重复候选、部分字段命中、路线分项与宏/微平均；测试证据完整率或反证检查率低于 100% 时无条件 `NO_GO`；测试报告排序和 JSON 输出确定性。

- [ ] **Step 2: 运行完整阶段 0 参数矩阵**

至少比较两组切块参数、规则扫描单路、规则+fixture、规则+fixture+盲审。云端增强如启用，必须单独列出，不与离线基线混算；记录请求数、缓存命中、输入/输出字符或 token、耗时和估算成本。

```powershell
./tools/lore.ps1 benchmark run --gold lore_sources/benchmarks/phase0 --backend fixture --out generated/lore/phase0
```

- [ ] **Step 3: 冻结阶段 0 配置**

`phase0.lock.json` 必须包含源清单 SHA、Schema/提示词版本、切块参数、发现路线、裁决阈值、预算上限、基准结果 SHA 和生成时间。不可包含绝对路径、密钥或模型原始回复。

- [ ] **Step 4: 写阶段门报告**

`phase0-gate.md` 记录实际数据、漏检类别、争议、成本、选定配置和 `GO`/`CONDITIONAL_GO`/`NO_GO`。禁止先写结论再虚构数字；若为 `NO_GO`，停止，不执行阶段 1。

- [ ] **Step 5: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_benchmark -v
./tools/lore.ps1 benchmark gate --report generated/lore/phase0/report.json --lock lore_engine/config/phase0.lock.json
git diff --check
git add lore_engine docs/lore/generated/phase0-gate.md
git commit -m "test(lore): calibrate and freeze phase zero gate"
```

---

# 阶段 1：可验证纵向闭环

### Task 1.1：可恢复任务队列与事务边界

**Files:**
- Create: `lore_engine/src/pipeline.py`
- Create: `lore_engine/tests/test_pipeline_resume.py`
- Modify: `lore_engine/src/database.py`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- Produces: `Pipeline.run(stage: str, selection: Selection, resume: bool) -> PipelineSummary`
- Task states: `pending`, `running`, `succeeded`, `failed`, `quarantined`, `stale`

- [ ] **Step 1: 写崩溃恢复测试**

在第三个任务注入异常，断言前两个已提交、第三个 failed、后续 pending；`--resume` 只重跑第三个以后。输入哈希变化时旧任务标记 stale；同输入重跑不重复插入候选和证据。

- [ ] **Step 2: 实现每任务事务与 lease**

任务领取写 `started_at` 和 lease；进程异常后超时 lease 可回收。模型原始输出先写缓存/隔离记录，验证通过后才在另一个短事务写候选；禁止半条 claim。

- [ ] **Step 3: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_pipeline_resume -v
./tools/lore.ps1 run --phase 1 --selection lore_sources/benchmarks/phase0 --backend fixture --stop-after discover
./tools/lore.ps1 run --phase 1 --selection lore_sources/benchmarks/phase0 --backend fixture --resume
git add lore_engine
git commit -m "feat(lore): add resumable transactional pipeline"
```

### Task 1.2：实体对齐、原子化断言、案例与机制

**Files:**
- Create: `lore_engine/src/normalization.py`
- Create: `lore_engine/tests/test_normalization.py`
- Modify: `lore_engine/src/contracts.py`
- Modify: `lore_engine/src/database.py`

**Interfaces:**
- Produces: `align_entity(name, aliases, context) -> EntityMatch`
- Produces: `atomize(candidate: CandidateClaim) -> tuple[AtomicClaim, ...]`
- Produces: `build_case(payload, evidence) -> CaseRecord`
- Produces: `build_mechanism(payload, evidence) -> MechanismRecord`

- [ ] **Step 1: 写实体与原子化测试**

覆盖同名异物、别名、称号、身份变化、同一句多结论拆分、条件与尺度不丢失、重复案例只聚合证据、无专名社会机制保留参与者/资源/信息差/约束/策略/后果/反例。

- [ ] **Step 2: 实现保守对齐**

只有名称、别名、上下文和类型一致才自动合并；歧义项生成 alignment task，不猜测。原子化不得扩写原文未给出的主客体或频率。

- [ ] **Step 3: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_normalization -v
git add lore_engine
git commit -m "feat(lore): normalize entities claims cases and mechanisms"
```

### Task 1.3：严格/研究双模式查询

**Files:**
- Create: `lore_engine/src/query.py`
- Create: `lore_engine/schemas/query-answer-v1.json`
- Create: `lore_engine/tests/test_query_modes.py`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- Produces: `QueryEngine.answer(question: str, mode: str) -> QueryAnswer`

- [ ] **Step 1: 写泄漏防线测试**

构造 confirmed、unconfirmed、in_world_lore、character_claim、inference、game_adaptation 各一条。strict 只能把 confirmed 放入 `canonical_answer`，获准推论单列；research 可展示全部但必须保留状态。每个 canonical 结论至少一条 citation；没有答案时返回 unknowns，不调用模型脑补。

- [ ] **Step 2: 实现结构查询 + FTS 补召回**

先解析实体/别名和关键词，再查结构关系与证据，最后 FTS 补充反例。首期答案组织使用确定性模板；可选模型只能重述已检索的 answer payload，输出后再次校验引用 ID 集合不得扩大。

- [ ] **Step 3: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_query_modes -v
./tools/lore.ps1 query --mode strict --question "小光蛊有什么能力和限制？"
git add lore_engine
git commit -m "feat(lore): add strict and research query modes"
```

### Task 1.4：四个验收问题的数据选择与答案回归

**Files:**
- Create: `lore_sources/benchmarks/phase1/acceptance-questions.json`
- Create: `lore_engine/tests/test_acceptance_questions.py`
- Modify: `lore_engine/config/phase0.lock.json` only if Phase 0 gate explicitly required a constrained selection amendment

**Produces:** 四个问题各自的真实正文选择范围、预期关键结论、允许未知项和禁入说法。

- [ ] **Step 1: 固定四个问题与选择策略**

问题必须逐字为：

1. `丁等资质改变命运有哪些已证实方法？`
2. `小光蛊的原著能力、限制、实际案例和游戏改编分别是什么？`
3. `散修通常通过哪些机制获得资源，各自受什么约束？`
4. `《人祖传》中哪些内容只是世界内传说，哪些得到现实验证？`

选择策略可由实体反查、FTS 命中和后文扩搜组成，不得手工把预期答案直接写入知识表。

- [ ] **Step 2: 写答案契约测试**

每题断言六个答案字段存在、canonical 条目有正文 citation、未知部分显式列出。第二题必须把 `game_adaptation` 排除出原著能力；第四题必须证明《人祖传》原文自身不能升级客观事实。

- [ ] **Step 3: 跑真实正文闭环并人工复核**

```powershell
./tools/lore.ps1 run --phase 1 --selection lore_sources/benchmarks/phase1/acceptance-questions.json --backend fixture --resume
./tools/lore.ps1 query-suite --questions lore_sources/benchmarks/phase1/acceptance-questions.json --mode strict --out generated/lore/phase1/answers.json
```

人工逐项点击/回查字符位置；发现错误时修正发现、对齐或裁决逻辑，不直接改答案快照掩盖问题。

- [ ] **Step 4: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_acceptance_questions -v
git add lore_sources/benchmarks/phase1 lore_engine/tests
git commit -m "test(lore): lock phase one acceptance questions"
```

### Task 1.5：发布快照、确定性与局部失效

**Files:**
- Create: `lore_engine/src/release.py`
- Create: `lore_engine/tests/test_release_snapshot.py`
- Modify: `lore_engine/src/pipeline.py`
- Modify: `lore_engine/cli.py`

**Interfaces:**
- Produces: `publish_snapshot(database, lock_config) -> ReleaseManifest`

- [ ] **Step 1: 写双运行确定性测试**

同一夹具运行两次，忽略运行时间和自增行号后，实体、断言、证据、案例、机制、裁决与查询结果的 canonical JSON 哈希必须一致。改单个 source block 后只使依赖该块的任务、证据和答案 stale。

- [ ] **Step 2: 实现逻辑快照清单**

清单记录 corpus SHA、phase0 lock SHA、migration version、prompt/schema versions、各表逻辑行数与内容哈希、质量门结果。只有 gate 通过且无 running/quarantined critical task 才可发布。

- [ ] **Step 3: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_release_snapshot -v
./tools/lore.ps1 publish --database generated/lore/knowledge.sqlite --out generated/lore/releases/phase1
git add lore_engine
git commit -m "feat(lore): publish deterministic knowledge snapshots"
```

### Task 1.6：原著层与游戏适配层自动边界

**Files:**
- Create: `lore_engine/src/adaptation_boundary.py`
- Create: `lore_engine/tests/test_adaptation_boundary.py`
- Create: `lore_engine/schemas/adaptation-candidate-v1.json`
- Create: `docs/lore/adaptation/README.md`

**Interfaces:**
- Produces: `export_adaptation_candidates(snapshot, ids) -> list[dict]`
- Produces: `validate_runtime_import(record) -> ValidationResult`

- [ ] **Step 1: 写边界失败测试**

断言 unconfirmed、world lore、无 citation、未批准 adaptation、游戏平衡值混入 canon claim 均被拒绝；导出只能生成 `generated/lore/adaptation_candidates.json`，不得直接写 `data/`。测试扫描 Git diff，若阶段 0/1 命令修改 `data/*.json` 则失败。

- [ ] **Step 2: 实现只读候选导出**

候选必须包含引用的 entity/claim/evidence/case/mechanism IDs、保留项、抽象项、原创补全、平衡数值占位域和 `review_status: pending`。只有未来人工批准工具可转换为 Godot 数据，本阶段不实现该转换。

- [ ] **Step 3: 验证并提交**

```powershell
python -m unittest lore_engine.tests.test_adaptation_boundary -v
./tools/lore.ps1 export-adaptation --ids small_light_gu --out generated/lore/adaptation_candidates.json
git diff --exit-code -- data
git add lore_engine docs/lore/adaptation/README.md
git commit -m "test(lore): enforce canon to game adaptation boundary"
```

### Task 1.7：质量、成本、隔离队列与阶段 1 报告

**Files:**
- Create: `docs/lore/generated/phase1-acceptance.md`
- Create: `lore_engine/tests/test_phase1_report.py`
- Modify: `lore_engine/src/reports.py`
- Modify: `lore_engine/cli.py`

**Produces:** `generated/lore/phase1/report.json`、选择性提交的 Markdown 验收摘要。

- [ ] **Step 1: 写报告完整性测试**

报告必须含：解析覆盖、发现路线覆盖、候选/确认/降级/冲突数、证据完整率、反证检查率、查询泄漏数、盲审漏检、缓存命中、失败/隔离任务、按任务类型耗时和成本、快照哈希、四题验收结果。

- [ ] **Step 2: 跑离线完整闭环**

```powershell
./tools/lore.ps1 run --phase 1 --selection lore_sources/benchmarks/phase1/acceptance-questions.json --backend fixture --resume
./tools/lore.ps1 report --phase 1 --database generated/lore/knowledge.sqlite --out generated/lore/phase1
```

Expected: 退出 `0`；严格模式泄漏数 `0`；证据完整率和反证检查率均 `100%`；无 unresolved critical conflict。

- [ ] **Step 3: 可选云端增强审计**

仅在用户明确提供配置和预算后执行：

```powershell
./tools/lore.ps1 run --phase 1 --selection lore_sources/benchmarks/phase1/acceptance-questions.json --backend cloud --allow-network --candidate-only
```

云端结果单列比较新增召回、误报、成本和耗时。`--candidate-only` 禁止自动发布；关闭云端后重跑 strict 查询，已发布答案哈希必须不变，除非候选经过正式证据与裁决流程并发布新快照。

- [ ] **Step 4: 写实际验收摘要并提交**

`phase1-acceptance.md` 只写实测数字、四题结论摘要、已知未知项、阶段 2 建议和快照哈希。若任一硬门失败，状态写 `NOT_ACCEPTED`，不得声称阶段 1 完成。

```powershell
python -m unittest lore_engine.tests.test_phase1_report -v
git add docs/lore/generated/phase1-acceptance.md lore_engine
git commit -m "docs(lore): record phase one acceptance evidence"
```

### Task 1.8：全套回归、仓库接线与交付审查

**Files:**
- Modify: `tools/check.ps1`
- Modify: `docs/lore/README.md`
- Test: all `lore_engine/tests/test_*.py`

**Produces:** 主仓检查同时覆盖 Godot 与知识引擎，但知识引擎测试不需要网络或生成数据库已存在。

- [ ] **Step 1: 先写检查入口失败测试**

在临时测试中故意注入一个失败的 lore unittest，确认 `tools/check.ps1` 返回非零；随后删除临时失败夹具。不要提交故意失败文件。

- [ ] **Step 2: 接入仓库检查**

在 `tools/check.ps1` 的 Godot 检查前运行：

```powershell
python -m unittest discover -s (Join-Path $projectRoot 'lore_engine/tests') -p 'test_*.py' -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

更新 `docs/lore/README.md`，说明手工登记册是迁移期审查视图，SQLite 是新结构化真值；不得改写现有登记内容的事实结论。

- [ ] **Step 3: 执行知识引擎全验收**

```powershell
python -m unittest discover -s lore_engine/tests -p 'test_*.py' -v
./tools/lore.ps1 ingest --manifest lore_sources/manifest.json --verify-only
./tools/lore.ps1 benchmark gate --report generated/lore/phase0/report.json --lock lore_engine/config/phase0.lock.json
./tools/lore.ps1 query-suite --questions lore_sources/benchmarks/phase1/acceptance-questions.json --mode strict --out generated/lore/phase1/answers-final.json
./tools/lore.ps1 report --phase 1 --database generated/lore/knowledge.sqlite --out generated/lore/phase1-final
git diff --exit-code -- data scenes scripts/domain scripts/presentation ui
git diff --check
```

- [ ] **Step 4: 执行现有项目回归**

```powershell
./tools/check.ps1
```

Expected: lore tests 全绿；现有 Godot unit/integration 基线不回退；若并行分支导致与本任务无关的失败，记录精确失败和基线对照，不修改用户 UI 工作来“修复”知识引擎任务。

- [ ] **Step 5: 独立审查清单**

- 原文两文件 Git diff 为零。
- 无密钥、绝对用户路径、模型供应商硬编码和生成数据库入 Git。
- 所有 strict 结论可逐字回查且反证检查完成。
- 《人祖传》没有仅凭自身文本进入客观 canonical。
- 二手资料没有单独进入 canonical。
- 云端关闭时全流程仍可运行。
- `data/`、Godot 规则和 UI 未被阶段 0/1 改写。
- 阶段报告中的数字来自生成报告，不是手填推测。

- [ ] **Step 6: 提交接线**

```powershell
git add tools/check.ps1 docs/lore/README.md
git commit -m "build(lore): add offline knowledge checks to repository gate"
git status --short
```

Expected: 只剩被忽略的 `generated/lore/`；所有已跟踪变更均属于本计划。

---

## 实施节奏与审查点

| 审查点 | 完成任务 | 决策 |
| --- | --- | --- |
| A 源可信 | 0.1–0.3 | 编码、指纹、位置和 SQLite 是否足以支持逐字回查 |
| B 金标准可信 | 0.4 | 三类样本是否代表高密度、社会机制和后文修正风险 |
| C 发现/裁决可信 | 0.5–0.7 | 三路发现是否共享契约，确认状态是否足够保守 |
| D 阶段 0 门 | 0.8 | `GO`/`CONDITIONAL_GO` 才进入阶段 1 |
| E 纵向闭环 | 1.1–1.4 | 四题能否用真实正文回答且不泄漏弱证据 |
| F 发布边界 | 1.5–1.7 | 快照是否确定、云端是否隔离、游戏适配是否只读 |
| G 仓库验收 | 1.8 | 全套离线测试、Godot 回归和只读边界是否同时成立 |

## 阶段 2 准入输出

阶段 1 完成后只提出阶段 2 方案，不在本计划内启动全书昂贵扫描。交付给阶段 2 的输入必须是：

1. `phase0.lock.json` 的冻结路由、参数和阈值；
2. 真实语料吞吐量、缓存率与成本曲线；
3. 三类金标准及阶段 1 四题回归集；
4. 未解决 Schema 缺口和高影响争议清单；
5. 可恢复任务队列与发布快照格式；
6. 推荐的全书分批策略、预算上限、停止条件和人工审核容量。

在用户审阅这些实测结果并批准前，不执行阶段 2 或阶段 3。
