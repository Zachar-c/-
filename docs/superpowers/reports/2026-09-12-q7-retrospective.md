# Q7 实施复盘总结报告（2026-09-12）

> 范围：架构纠偏（M0–M3）→ Exit Review → Q7 辅助蛊实义化全阶段（0/A/B1/B2/C/D）。
> 性质：历史脉络 + 数据结构演变 + 架构决策 + 完成度 + 需求对照 + 未来方向。
> 证据：本日提交链 `4dc20cd…f6ca4fe` 共 10+ 提交，终验 unit 1286/1287 · integration 32/32 · 交互门 17 屏全空。

---

## 一、历史脉络（2026-09-12 单日时间线）

| 时点 | 事件 | 产出 |
|---|---|---|
| 上午 | 内容向审计（上一会话遗留） | `reports/2026-09-12-project-audit.md`：第一风险=内容方差非技术债 |
| 上午 | 架构接管审查（Principal/TD 口径） | Project Health 六维评级、风险清单、Agent Contract 草案 |
| 中午 | 纠偏计划获批，M0–M3 执行 | `2ac586a`/`7f4d984`/`87b987f`/`f9546d8`；**顺带修复 invalid_event_log 潜伏存档 bug** |
| 午后 | 用户冒烟通过 → Exit Review | M4 复审**取消**（`4dc20cd`），登记 3 条重启触发条件 |
| 下午 | Q7 计划批复（含 5 前置条件 + D1–D4 裁定） | `d55cb16` |
| 下午 | Q7 阶段 A→B1→B2→C→D 实施 | `3fe4143`→`a25d6a6`→`38302e8`→`4f5eb61`→`a701dfa` |
| 傍晚 | 三门终验全绿 | unit 1286/1287 · integration 32/32 · 交互门 17 屏 |

## 二、数据结构的设计与演变

### 1. 蛊定义（gu.json，802 只）
- **既有 schema**：`id/rank(1-5)/role/school/rarity/value/tags/combat/v1_effect`。role 是项目自造的行为分类（attack/defense/healing/movement/recon/logistics），**非原文分类**。
- **演变线**：早期 151 只 recon/logistics `v1_effect` 为空 → 依赖 role 兜底表（ponytail 注释登记"上限≈200 legacy，逐个进 slice 时迁显式"）→ **Q7 后**：剑道 10 只显式化（intent 1/2、heal 1），其余 141 只经升级后的兜底表获得活通道。显式优先、兜底次之的双层设计保持不变。

### 2. 兜底表（v1_battle.json `default_effect_by_role`）
- 六档齐全 + 校验（C3 已有）；**Q7 演变**：
  - `recon`：`status/marked/1` → `status/marked/1 + support_school:"self" + support_bonus:1`（双活通道）
  - `logistics`：`status/bound/1`（**死状态**，全仓无消费者）→ `heal/1`
- 新增哨兵机制：`"self"` 在 `default_v1_effect` 注入 `definition.school`——规则留在数据、流派在实例上。

### 3. 效果系统（v1_effect）
- kind 从 7 → **8**（`sword_intent`）；登记点 **两处**：`content_catalog.V1_EFFECT_KIND_IDS`（数据校验）+ `v1_battle_resolver.effect_reason.SUPPORTED`（引擎闸门）——后者漏登记会静默拒蛊，本日教训。
- 支援骑键（`support_school/support_bonus`，S4 已有）升格为可携于任意 kind 的通用披露位；Q7 增 `"self"` 哨兵 + rank 梯度（bonus += rank−1）。
- **纪律**：未引入 trigger/priority/condition——M4 复审裁定不造 status framework。

### 4. 战斗态（battle Dictionary）
- 纯函数流（`_dup`→改→写回）不变；新增顶层键 `sword_intent`（0–5，跨回合存续、回合末减半）；**删除** `player.position` 及 cfg 三键（`shift_damage_reduction_*`/`enemy_pursuit_per_turn`，Q8 死路径）。
- 快照面新增 `sword_intent` 透出（battle_snapshot，契约文档已回写）。

### 5. 会话与存档
- M3 后 `RunState.encounter_session` 是会话唯一真状态（controller 镜像已删）。
- M1 后事件校验器容忍归因 after 键（`battle_turn` 等）——战斗中存档语义被 `test_battle_save_load_semantics` 钉死：**丢战斗现场、保已同步 hp、回地图**。

## 三、整体架构与关键设计决策

### 架构（实测依赖图）
```
data/*.json ─▶ content_catalog(校验/白名单) ─▶ RunState(不可变, copy-on-write)
UI(快照只读) ─▶ RunController.submit_command ─▶ Resolver.apply(_dispatch 表)
                     │                              ├─ 命令族(rest/shop/refine/…)
                     └─ BattleCommandFacade.is_battle_command ─▶ RunBattleFlow ─▶ V1 纯函数战斗
UI ◀── 快照(13 模块, 只读投影+feedback) ◀── run_snapshot_builder ◀── 新 state
```

### 本日关键决策（按影响排序）
1. **Ownership 契约成为硬门槛**（M0）：Logic/Visual/Test/Astra 四角色 + Shared 单写者区 + 5 步修改协议——针对历史 4 次并行删除事故的流程性 P0。
2. **战斗命令知识单点化**（M2）：类型表唯一归属 `BattleCommandFacade`，controller 零命令 ID 字面量 + 源码卫生测试防回潮。
3. **单一真状态原则**（M3）：`current_session` 镜像删除；`current_battle` 判定为有界会话语义（非缺陷），M1 测试钉死。
4. **M4 取消**：status handler 表驱动无消费者，登记 3 条重启触发条件——"不为设计模式而设计模式"的实例。
5. **Q7 数据驱动杠杆**：151 只辅助蛊不逐只手写，改兜底表一行规则全量实义化；剑意是唯一真正的引擎件（桩→接线 3 函数级改动）。
6. **不消费剑意**：持续增益+衰减即代价；strike 作用域硬边界（只在 `_apply_effect` strike 分支按 `slot.school=="sword"` 加成，`_strike_enemy` 零改动 ⇒ 杀招/刻痕/拳脚结构性隔离）。

## 四、代码实现的核心模块与完成度

| 模块 | 状态 | 本日变化 |
|---|---|---|
| `scripts/domain/resolver.gd`（205 行路由核） | ✅ 达标不动 | 无 |
| `v1_battle_resolver.gd`（纯函数战斗） | ✅ | +sword_intent 分支/strike 加成/end_turn 衰减；−Q8 死路径 |
| `school_rules.gd` | ✅ 桩转正 | add/decay_sword_intent 获得生产调用点 |
| `content_catalog.gd`（1540 行） | ⚠️ 达拆分阈值未到（Triggered） | +sword_intent 登记、兜底表 support 键校验 |
| `run_controller.gd`（903 行） | ✅ 非 God Object（~460 行一行委托） | −current_session 字段、命令类型表 |
| `run_snapshot_builder` + snapshots ×13 | ✅ | battle_snapshot +sword_intent；text util +支援披露 |
| `save_repository.gd` | ✅ | _has_valid_event_log 容忍归因键（M1 修复） |
| `default_effect_by_role` | ✅ | recon/logistics 双通道实义化 |
| 测试面 | ✅ 1288 测试（新增 5 个文件） | wiring/q7_sword/q7_role_defaults/q7_text/语义钉死 |

**Q7 完成度：100%**（0/A/B1/B2/C/D 全绿；151 只全部实义化；文案=结算机器验证）。

## 五、需求的理解、落实与变更

### 需求 → 落实对照
| 需求（出处） | 落实 | 变更 |
|---|---|---|
| 辅助蛊实义化（Q7 规格："recon/logistics 10 只+全流派"） | 151 只全覆盖 | **范围演变**：实测 151 只≠规格口径 10 只 → 方案从"逐只手写"改为"兜底表规则化 + 剑道特例显式" |
| 剑道辅助蛊五类语义（Q7 五通道表） | 4 通道落地，T10 mark_sword 留接口位 | 底蕴属长线道痕（1 道≈0.1%），本批不做 |
| 用户 5 前置条件 | 全部落实 | D1 消费语义（不消费）、strike 作用域（结构性隔离）、B2 抽查（流派×role×rank）、C 机器可验证（802 只 sweep）、Q8 独立提交 |
| 透明度红线（文案=结算） | 机器可验证 | 红测抓出 sword_rec 5 只"效果未明"+支援键漏披露，全修 |
| M4 复审指令 | 取消+触发条件 | 用户裁定"机械式去分支，禁造 framework"——复审发现连去分支都无消费者 |

### 需求理解偏差的纠偏记录
- 初版 Q7 计划把范围写成"10 只"——取证后修正为 151 只，方案随之重构（这是"先取证再设计"纪律的直接收益）。
- rec_5 被 `insufficient_qi_quality` 拦截曾被当作 bug 排查，实为转数门禁正确行为——改为行为测试用 rec_1 + 补门禁回归断言。

## 六、与原始材料的对照分析

| 机制 | 原著依据 | 项目映射 | 标注 |
|---|---|---|---|
| 剑意（sword_intent） | **原文仅 4 次，非成体系** | 跨回合叠层（cap 5、回合末减半）= 项目自造映射，沿用 T8 任务书 | ⚠️ 自造，不可宣称原文 |
| 刻痕（marked/T15） | 「刻印不会消失」、道痕自寻弱点 | 独立伤害通道：不吃护盾/不吃增益/不衰减 | 原句支撑（重查报告 §2-M3） |
| bound（束缚） | 原文有束缚语义项 | role 兜底曾映射 bound 但引擎无消费 → Q7 改 heal（后勤=恢复） | role 分类本身是自造 |
| 位移/距离 | 「拉开距离」意象 | Q8 推翻距离减伤模型，转译护盾 | 用户裁定，spec 留横幅 |
| 后勤/侦察 | 原文蛊虫有探查/辅助类用途 | recon/logistics role 体系 | 自造分类，数值自控 |
| 万剑劫等杀招 | 原文杀招名 | kill_moves 配方化（steps=多段宿主） | specs/2026-09-11-sword-kill-move-list v2 |

**方法论纪律**（贯穿）：断言 A→B 必查共现；引用原文必须给原句；推断必须标注；自造概念不披原文外衣。

## 七、当前状态与未来方向

### 当前状态
- **架构：Stable**——M0–M3 落地、M4 取消、五核（resolver/v1 纯函数/RunState/save/snapshot）列入 Do Not Touch。
- **内容：Q7 闭环**——辅助蛊实义化完成，effect 系统扩展成本 = 新 kind 两处登记 + 数据。
- **测试：1288 测试**，唯一红 = t5a（既有，与功能无关）。

### 待办（按优先级）
| # | 项 | 性质 | 备注 |
|---|---|---|---|
| 1 | **t5a 既有红测** | Must Fix | 半小时级；修复或登记 KNOWN，恢复"全绿交付"纪律 |
| 2 | **Q7 真窗验收** | 验收 | 剑道局（剑意积层→出剑）+ 非剑道局（后勤回血/侦察支援）数值体感；headless 三门已绿，按 AI 契约以用户真窗结论为准 |
| 3 | **Q5 剑道跨道配方** | 纯数据 | 386 条配方管线现成；跨道=原料来源语义，零引擎改动 |
| 4 | **Q4 商店分栏+固定栏+卖出入口** | 功能+UI | 卖出命令/预览钩子已有，缺接线——玩家感知缺口最大 |
| 5 | **节点模板接回 pacing 池** | 内容 | 37 模板 2/3 闲置，留存侧第一风险 |
| 6 | **遗物补至 10–15 条** | 内容 | relic_codex 容器现成 |
| 7 | seed 扫描工具（seed_sweep） | 护栏 | 数值回调（B2 heal 梯度）回归可复扫 |
| 8 | mark_sword / T10 底蕴 | 长线 | Q7 已留接口位 |

### 风险提示
- B2 让 logistics 普遍回血、recon 普遍带支援——战斗数值面整体上浮，建议真窗体感 + Q5/Q4 批次间跑一次 seed 抽查。
- content_catalog 仍在涨（本日 +2 处校验），补新流派前先做拆分（Triggered 条件已登记）。
