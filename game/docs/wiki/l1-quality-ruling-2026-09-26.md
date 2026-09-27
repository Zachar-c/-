---
title: LLM Wiki 质量审查 L1 判决书
description: 双库质量审查七项方法论问题的 L1 判决（词表正典、脚注路径、失源政策、双库架构、同步触发、工具权威、原文边界）
date: 2026-09-26
tags: [l1, ruling, quality, methodology]
---

# LLM Wiki 质量审查 · L1 判决书

| 项 | 内容 |
|---|---|
| 评审对象 | `game/docs/wiki/` + `lore/wiki/` 双库质量（2026-09-26 审查结论） |
| 发起 | L0 指令「按原则上述 l1 判决」 |
| 拟稿 | L2 审查事实底稿（lint.mjs / check.ps1 / 页面抽查） |
| 判决人 | L1（知识架构与方法论） |
| 性质 | **方法论判决**，不改产品逻辑、不改游戏数值、不改 lore 语义 |

## 0. 原则（判决所依）

1. **原书事实才是正典**（L0 2026-09-26）：从 wiki 取原著已核验事实并优先化；**当前 game 实现全部存疑**，不得反向当作真源。核查从 Wiki 出发，再到 Runtime/数据。
2. **L0–L6 分层不可混**：原著事实（lore L0–L5）与游戏裁定（game L6）严格分离。
3. **多模型择一须可执行**：清单与实践冲突时，以**已验证有效的实践**为准绳，改清单，不为形式统一回改大量页面。
4. **证据缺口显式降级，不静默删除、不静默保留**。
5. **门禁本地可复跑**；外部工具只作第二意见。
6. **普通工程问题直接闭环**；仅方法论多解进 L1。

---

## 1. 判决一览

| # | 审查发现 | 层级 | 判决 |
|---|---|---|---|
| D1 | 清单要求 `[FACT]/[DESIGN]/[INFERRED]`，实践用「游戏裁定 / 游戏压缩 / 纯实现 / 差异声明」 | **L1 多模型** | **采认实践词表为正典**；清单改写对齐，不回改页面标签 |
| D2 | 脚注 `AGENTS.md` / `docs/superpowers/plans/` 在 game/root 双基准命中 | **L1 约定** | **强制仓库根相对全路径**（如 `game/AGENTS.md`）；lint 保持「默认按 game」仅作过渡 |
| D3 | 4 处 `[失源] MEMORY.md` | **L1 证据政策** | **维持显式降级**；优先重锚到 `game/AGENTS.md` 工具规则与 specs；禁止静默删主张 |
| D4 | 双库架构（lore / game wiki） | **L1 架构** | **维持分离**，不合并；lore=真源，game=转译+工程 |
| D5 | lore 新裁定是否自动回写 game wiki | **L1 同步策略** | **按需触发，不自动全量同步**；触发条件见 §3 |
| D6 | 外部 `wiki-lint` / `kb-review` 与本地门禁 | **L1 工具权威** | **本地 `lint.mjs` + `check.ps1` + benchmark 为唯一门禁**；外部 skill 只读建议 |
| D7 | 82 条 local-only 原文 WARN | **L1 数据边界** | **维持 WARN 不 FAIL**；原文不进 Git（根 AGENTS 既有红线） |
| D8 | meta-progression 缺可视化；date 未更新 | **L2 工程** | **直接闭环**，不进 L1 争议（见 §4） |
| D9 | game wiki 落后 lore 09-26 裁定节奏 | **L2 运维** | 排一次 routine 批；**是否扩写转译页由 D5 触发条件判定** |

---

## 2. 分项判决理由

### D1 · 标注词表（正典变更）

**冲突**：`maintenance.md` 要求 `[FACT]/[DESIGN]/[INFERRED]`；19 页实践统一使用：

| 实践词 | 语义 | 对应 |
|---|---|---|
| 原著锚点 / 原著真源 | 已核验原著事实（引 lore） | FACT |
| 游戏裁定 / 差异声明 | L6 设计选择，不得冒充原著 | DESIGN |
| 游戏压缩 | 数值/节奏压缩，语义不扭曲；**须三件套**（L0 补充）：原著锚点 + 压缩维度 + projection/ruling 依据 | DESIGN |
| 纯游戏 / 纯实现 | 无原著锚点的工程/玩法层 | DESIGN |
| （分析句显式声明） | 推断不得写成事实 | INFERRED |

**判决**：实践词表语义更细、与 `world-model-translation.md` 转译总则一致、已被抽查页面验证可读。**采认为 game wiki 正典**。

**执行**：
1. `maintenance.md` lint 清单第 7 条改为要求上述词表，删除 `[FACT]/[DESIGN]/[INFERRED]` 硬性要求。
2. **不**批量回改既有页面标注。
3. 新页/改页沿用正典词；推断句必须显式标「分析 / 推断 / 不得当作原著」。
4. **「游戏压缩」三件套（L0 补充 2026-09-26）**：写「游戏压缩」必须同时给——①原著锚点（lore 页/E-ID）②压缩维度（压了什么：数值/节奏/枚举/范围）③projection 或 ruling 依据（投影约定或 `RUL-*.json`/spec 条款）。缺一不得标「游戏压缩」。

### D2 · 脚注路径

**判决**：脚注源一律写**仓库根相对路径**（`game/AGENTS.md`、`game/docs/superpowers/...`、`lore/wiki/...`）。仅当目标不在仓库内时写外部标识（如 `lucasastorian/llmwiki`）并允许 lint 备注。

**理由**：多基准命中导致「按 game 计」属隐式规则，换机/换工具易漂移；全路径与 lint.mjs 的仓库根解析一致，零歧义。

### D3 · 失源主张

**判决**：维持现行三件套——①脚注 `[失源] <原名>（说明）`；②`plan.md` 已知缺口登记；③优先重锚到现存权威（`game/AGENTS.md`、specs、rulings）。重锚成功后移除标记。

**禁止**：静默删除主张；把失源主张升格为无引用事实。

**重锚优先序**：工具/纪律类 → `game/AGENTS.md`；规格类 → `docs/superpowers/specs/`；流程废止类 → 对应 `RUL-*.json`。

### D4 · 双库架构

**判决**：维持 `lore/wiki`（L0–L5 原著真源）与 `game/docs/wiki`（L6 转译 + 工程实现）分离。**禁止合并、禁止在 game wiki 重新发明世界观、禁止把 L6 数值写入 lore**。

与 L0 既定方向（2026-09-25 Schema v2 改造）及 `schema-v2.1-l1-review.md` 边界声明一致。

### D5 · 同步触发

**判决**：lore → game **按需触发**，不做 nightly 全量镜像。

**同步语义（L0 补充 2026-09-26）**：同步 = **更新受影响的 L6 / Game Semantics**（转译页主张、Game Semantics 契约、受牵连数据口径），**不做页面镜像**——不把 lore 页抄进 game wiki，不搞双库同文。

| 触发条件 | 动作 |
|---|---|
| 游戏数据/规则/契约将改，且依赖某原著事实 | 先核 lore 对应页，再改 L6/Game Semantics |
| lore 出现**推翻性** `[已修正]` / CAN 状态变更 | 评估是否波及 L6/Game Semantics；波及则同批改 |
| 仅 lore 增密（补锚点、扩事件、待核对） | **不**强制回写 game |
| L0/L1 明令同步 | 执行 routine 批（仍只改受影响 L6，不镜像） |

### D6 · 工具权威

**判决（L0 收窄 2026-09-26）**：

- **Wiki 内容质量门禁（本文 D6 范围）**：`game/docs/wiki/lint.mjs`、`lore/wiki/tools/check.ps1`、各簇 `benchmark-*.md`。
- **Canon → Game 另册**：落地一致性仍需**独立 Runtime / Conformance 门禁**（`tools/check.ps1`、GUT、compile_runtime、conformance 断言等）。Wiki 门禁绿 ≠ 实现正确；现现实现按原则 1 **全部存疑**，以 Wiki 为出发点核对。
- **外部 skill**（`wiki-lint` / `kb-review` / SkillHub llmwiki 系）：允许只读体检报告，**不得**替代上述任一门禁、不得自动改 wiki、不得把其 schema（`wiki-config.md` 等）强加本仓。

### D7 · 原文 local-only

**判决**：维持。`source/蛊真人-clean.txt` 等原文不进 Git；check2 对已知路径 WARN 不 FAIL。换机验收能力降级属已知代价，登记在案即可。

---

## 3. 不在本判决范围

- lore Schema 字段增减、目录重构 → 既有冻结条款 + `schema-v2.1-l1-review.md` 通道。
- 游戏数值、转数曲线、战斗语义 → 既有 `RUL-*.json` / L1 架构裁决。
- 具体页面内容对错（碧玉歌、成尊四条件等） → 已由各簇批次与 GOVERNANCE 质量债台账处理。

---

## 4. L2 直接闭环清单（无争议）

1. `meta-progression.md` 补一表或 mermaid（消除 lint WARN）。
2. 实质修订页更新 `date`。
3. 脚注按 D2 逐步改全路径（触碰页顺手改，不单开迁移批）。
4. `maintenance.md` 按 D1 改写 lint 清单。

---

## 5. 签署

| 角色 | 状态 |
|---|---|
| L1 判决 | 本文件，2026-09-26 |
| L0 追认 | **通过并补充，2026-09-26**：①原书事实=正典、现实现全部存疑、从 Wiki 出发；②D5 同步=更新受影响 L6/Game Semantics，不做页面镜像；③D6 限 Wiki 内容质量门禁，Canon→Game 仍要独立 Runtime/Conformance 门禁；④D1「游戏压缩」须原著锚点+压缩维度+projection/ruling 依据。其余按本文执行。 |

生效：D1–D7 及 L0 补充即时生效；D5 表为运维约定；L2 清单可同批执行。
