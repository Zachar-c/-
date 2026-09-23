# 2026-09-22 · 可玩游戏本体 · 当前状态与 W0 基线

> 顶部为当前进度，下方保留 W0 历史基线，不能把历史缺口当作当前代码状态。证据分级见实施计划 §2。
> 移交记录：`2026-09-22-playable-game-handoff.md`。

## CURRENT PHASE（2026-09-22 W3–W7 推进后）

GOAL: lab.html 可交付 Web 游戏（G01–G10）。

ACTIVE: G07 获胜轨迹未闭合，整体 **BLOCKED**。

COMPLETED: W1/W2（7f43b91）；W3 战斗接缝修复与 lab_combat；W4 杀招实例/买卖账本与 lab_transactions；W5 路径/文案/演武覆盖/逆息禁用；W6 autoplay_lab smoke/lifecycle/full；W7 package_lab + README + 验收文档。复跑：combat 56/56、transactions 39/39、full 种子 101–103 均合法终局且无软锁。

BLOCKED: **G07 无获胜轨迹**——自动 balanced/refine 仅得 defeat（魂魄/气血耗尽）。未改数值。需人工获胜轨迹或 L1 平衡裁定。11 条经济警报保留。

NEXT: 提交 G07 轨迹给 L1/L0；或补人工两种构筑获胜录像后再标 PASS。

DECISIONS: Web only、lab.html；不把 fixture 通过当成整局可胜。

验收详情：docs/2026-09-22-playable-game-acceptance.md。

W1/W2 代码和测试已经存在（`js/lab_save.js`、`tests/helpers/lab_browser.mjs`、`tests/lab_save.test.mjs`、`tests/lab_lifecycle.test.mjs`）；下方「无存档」「文件不存在」仅描述 W0。当时的 NEXT 已执行至 W1/W2，不再作为当前待办。

### 本任务独立浏览器核查（修复前）

- 空 profile、seed `20260924`、1280×720；经可见按钮新局 → `L1D0N0` 石甲散修 → 观察。气血保持 24，念头 2→1，`revealed=false→true`；`currentCounter` 从空字符串变为缺失。调用点 `observe()` 向单参数 `revealCounter(enemy)` 传了错误首参，需回归保护。
- 首战截图出现敌人画像缺失。本机不存在 `game/wenzhen-web-lab/assets/`，而 `battle.js` 使用 `assets/wenzhen/enemies/...`；原资产在 `game/assets/wenzhen/enemies/`。列入 W5/W7 资源路径验收，本批不扩大为资产搬运。
- 本地证据：`%TEMP%/wenzhen-w3-first-battle-before.json`、`%TEMP%/wenzhen-w3-first-battle-before.png`。仅首战观察链，不能当多敌/层主或整局通关证明。

## 以下为 W0 历史基线（保留供比较）

## 目标与边界

- 目标：经 `lab.html` 交付可开局、可构筑成长、可走完五段胜负、可自动保存续玩、可重新开始的 Web 游戏本体。
- 入口：`game/wenzhen-web-lab/lab.html`（不是 `index.html` / `mvp.html`）。
- 本阶段 **不做 Godot**，不改 `.gd`，不跑 Godot 验收。
- 不新建战斗/Rank/定价引擎；不扩 30/24/50 手填；不批量改价；不推导 26 杀招。

## 代码与真源地图

| 角色 | 路径 | 说明 |
| --- | --- | --- |
| 玩家入口 | `lab.html` | 普通脚本顺序加载；`document.documentElement.dataset.ready='1'` |
| 状态与命令 | `js/main.js` | 全局 `state` / `act`；`fresh(difficulty)` 重建整局 |
| 地图/大厅/整备 UI | `js/journey.js` | 只绑定 `data-*` → `act.*`，不直改 state |
| 战斗 UI | `js/battle.js` | 消费 `CombatCore` / `act` |
| 唯一战斗核 | `js/combat_core.js` | `MvpLogic` 别名 + Lab 适配；禁第二套结算 |
| 规则核 | `js/{mvp_logic,gu_rules,run_rules,run_flow,loot_rules,shop_rules,alchemy,killmove,rules}.js` | 纯规则；Owner 见契约 |
| 数值报警 | `js/balance.js` | 消费 `WORLD_BALANCE`，不定价 |
| 内容桥 | `tools/build_data.mjs` → `js/data.js` | 从 `game/data/*.json` 生成；不手改 data.js |
| 真源 | `game/data/{balance,gu,v1_battle,refinement_recipes}.json` | 本阶段只读 |
| MVP 短剧本 | `mvp.html` + `js/mvp*.js` | 夹具；禁第二套战斗 |
| 纵向研究 | `vertical/` `balance/` | FROZEN 研究，不进玩家链 |

## 移交时基线测量（V1：只认输出文本）

| 命令 | 结果 |
| --- | --- |
| `node --test game/wenzhen-web-lab/tests/*.test.mjs` | **126 pass / 0 fail** |
| `node tools/check_projection.mjs` | **34/34**（含突变 thoughtsPerTurn=999 必须检出） |
| `node tools/check_balance.mjs` | **38/38** |
| `node tools/check_l1_phases.mjs` | **pass=41 fail=0 alarm=11** |
| `node tools/check_progression_loop.mjs` | **10/10（fixture）** — 不计入 G05/G07 |

### 既有警报（不改价，必须保持可见）

11 ALARM：R1–R5 蛊价/I 过贵、突破/I 过便宜、R3–R5 炼制失败损失过便宜。
属经济数据债；无自动调价授权。

### 工具身份标注

- `tools/autoplay.mjs`：**只证明 mvp 短剧本**（10 分钟夹具），不是 lab 整局证据。
- `tools/check_progression_loop.mjs`：**fixture**（注资/手写配置），只能证明主链字段可串，不能当玩家可通关证据。
- `tests/*.test.mjs`：规则单测 + 受控 fixture；不能证明玩家能获得这些资源。

## 浏览器首屏证据（W0 · 独立 profile · 1280×720 · file:// lab.html）

证据目录：`%TEMP%/wenzhen-lab-w0-peek/`（`boot.json` `state.json` `console*.txt` `lab-hall.png` `lab-map.png` `lab-first-node.png`）。

| 项 | 实测 |
| --- | --- |
| ready | `dataset.ready='1'`，无 `#bootfail` |
| 脚本异常 | **无** exception；console 仅 4 条 AudioContext 手势警告（`js/audio.js`） |
| 缺图 | **0**；`document.images` 14 张全部 `naturalWidth>0` |
| HUD | 丙等 · 1 转初阶 · 真元 20/20 · 念头 **2** · 元石 3 · 气血 24 · 寿元 60 · 魂魄 1/4 |
| READY.owned | **14 类 ×1**（与代码一致） |
| READY.wild | `small_light_gu ×2` |
| 难度 / 图 | 默认 `normal`；**155 nodes**；`graph.nodes` 是**数组**（`nodes.find`），不是字典 |
| roots | `L1D0N0` / `L1D0N1` / `L1D0N2` |
| 首批可选 | 山脊猎犬（战斗）· 石甲散修（战斗）· 山村短工（市集） |
| 首战 | 点入 `L1D0N0` → `ridge_hound` 山脊猎犬 **hp 3/3**（balance 建议 battle_1 HP=8；记观察，W3/W4 核） |
| 存档 | **无** localStorage；刷新即丢局（W1） |

开发向 UI（W5 收口，W0 只记录）：大厅仍写「Web **拼装局**」；顶栏「**覆盖**」页；「演武」目录对玩家可见。

## 初始状态（代码读取，已与浏览器对照）

`READY`（`js/main.js`）：

- `seed: DATA.runSeed ?? 1`（W1 前固定，不消费 URL seed）
- `stones:3 blood:24 bloodMax:24 lifeTime:60 soul:1/4`
- `cultivation:1 cultivationStage:0 aptitude:'bing' stage:'one'`
- 持有蛊 14 类 ×1：`moonlight/small_light/stone_shell/vitality_grass/jade_skin/white_boar_strength/blood_farewell/blood_droplet/light_rec_1_10/fire_atk_2_01/water_atk_3_05/wisdom_rec_1_20/wisdom_atk_3_13/blood_atk_5_02`
- 野生：`small_light_gu ×2`
- 图：`RunFlow.generateGraph({seed, difficulty, …})`；`journey.nodeId=null`，`availableNodeIds=graph.roots`，`started=false`
- 首屏：`page='hall'`；难度默认 `normal`
- **无 `localStorage` / 无继续游戏** — 刷新即丢局（W1 关闭）

## 已知缺口（进入后续批次，不在 W0 重做研究）

| ID | 缺口 | 批次 |
| --- | --- | --- |
| G-SAVE | 无浏览器存档；`fresh()` 每次加载重建 | W1 |
| G-SEED | `?seed=` 未接入；GAP-SEED 无方差 | W1 |
| G-END | `endBattle()` 会清未结束 battle；胜负 outcome 不显式 | W2 |
| G-SHOP | 买卖/掉落账本闭环未证；SHOP-BUY 扣款待验 | W4 |
| G-KM | 杀招仍 declared；组件实例占用待 UI 侧复用 `GuRules.killMoveRecipeInstances` | W4 |
| G-UI | 开发向文案/覆盖页混在玩家流 | W5 |
| G-E2E | 无 lab 整局 DOM 驱动；autoplay 只覆盖短剧本 | W6 |
| G-PKG | 无离线发行包 | W7 |
| G-ECON | 11 经济 ALARM | 数据债，本阶段不改价 |

## 与计划成功标准的对照

- 计划交付物文件（存档适配、lab_browser helper、lifecycle/transactions 测试、autoplay_lab、package_lab、README）**目前不存在**，不得假称可运行。
- 绿灯数量 ≠ 游戏已完成。G01–G10 以 W6/W7 真实整局与发行验收为准。
- 正式单局是否五转 UNRESOLVED；本版本沿用五段节点 + 第五层主终点。

## W0 完成判定（L2 PASS）

- [x] 移交信号完整（移交者/接手者/HEAD/工作树/时间/停写范围）→ `2026-09-22-playable-game-handoff.md`
- [x] 空 profile 首屏：无脚本异常、无缺图、14 蛊、难度/roots/首节点/首战已记
- [x] 套件与警报数字已记；`autoplay`/`check_progression_loop` fixture 身份已标注
- [x] 本地接口契约 `lab-runtime-contract.md`：act 唯一写入口、规则 Owner、禁双核

已知缺口进 W1–W7，不在 W0 重做研究。

## NEXT

W1：`LabSave` + 浏览器 helper + 种子接入 + 持久化提交边界。
