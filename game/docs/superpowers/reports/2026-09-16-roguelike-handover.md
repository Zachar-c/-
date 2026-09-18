# 交接文档：肉鸽化改造 D1 + D4（2026-09-16）

> **用途**：新会话读这一份即可恢复本轮全部上下文 —— 做了什么、为什么这样做、哪些结论被推翻、
> 工作树边界在哪、下一步的前置是什么。**不需要重跑语料检索或地图探针。**
>
> **维护约定**：只追加、不重写既有条目。结论被推翻时保留原条目并追加 `⚠️ 已修正`。
>
> **上游文档**（本文是索引，不复制内容）：
> - 调研与方向对比：`docs/superpowers/reports/2026-09-16-roguelike-audit-and-directions.md`
> - D4 实施报告（含原文考据频次表）：`docs/superpowers/reports/2026-09-16-d4-event-pool-expansion.md`
> - D2 预审：`docs/superpowers/specs/2026-09-16-rogue-layer-temperament-spec.md`

---

## §0 三十秒速览

| 项目 | 状态 |
|---|---|
| 分支 | `master`，本地领先 `origin/master`（推送前请实时核对，见 §6） |
| 本轮主线 | 肉鸽化改造：**D1 关底 Boss 随机化** + **D4 事件池扩容**，均已落地 |
| 验证 | unit **1514/1514**（51598 断言，SCRIPT ERROR 0，退出期零泄漏）；D1/D4 双门禁 40 种子 PASS |
| 未触碰 | `pacing.json`、`loot_resolver.gd`、`v1_battle.json` 数值、Q8 冻结语法 —— **零红线** |
| 回滚 | 两个单点数据开关（删 `boss_pool` / 删 `event_pool`），**无需回滚代码** |
| 下一前置 | **`pacing.json` 红线裁定**（同时卡住 D2 与 D4 的频率提升） |
| 工作树 | ⚠️ **含另外三个在途工作流的改动，且与本轮改动逐行混编**（见 §2） |

---

## §1 本轮交付

### 1.1 D1 关底 Boss 随机化

**问题**：5 个关底台的 `enemy_kind` 硬编码，生成时 `instance_anchor == true` 会跳过 E6 抽取
⇒ **每一局、每一层、每个玩家看到的 Boss 组合完全相同**；7 个 boss 里 2 个从未上场。

**落地**（4 个池，L5 保持固定）：

| 层 | boss_pool | 有效 HP（hp × `boss_layer_mult`） |
|---|---|---|
| L1 | `crag_serpent_matriarch`, `marrow_gu_adept` | 15.0 / 17.6 |
| L2 | `marrow_gu_adept`, `thunder_crown_sovereign` | 17.6 / 21.6 |
| L3 | `thunder_crown_sovereign`, `clan_patriarch` | 21.6 / 22.8 |
| L4 | `clan_patriarch`, `blood_vein_bishop`, `blue_fur_jiangshi` | 25.7 / 27.0 / 27.0 |
| L5 | **固定** `miasma_vein_lord` | 21.0 |

池是按 hp 排序的**滑动窗口**（层内差 ≤2、层间单调递增、原关底 Boss 恒在池内保证连续性）；
`_roll_boss_for` 额外排除**相邻层**已抽中的 Boss。

**门禁 40 种子 PASS**：`stand slots seen: 200`，
`crag 21 / marrow 27 / thunder 38 / clan 36 / blood 21 / blue_fur 17 / miasma 40(fixed)`，
`topology_mismatch=0`、`adjacency_repeat=0` ⇒ **7 个 boss 全部上场**（改动前 5 个）。

### 1.2 D4 事件池扩容

**问题**：`events.json` 只有 2 条；且这 2 条**只有代价、没有发放**，却在 `expected_gain` 里
写着"取得回声允诺的机缘"——承诺不实。

**扩容前先修了一个阻塞缺陷**：

> 🔴 `_append_event_cards(cards, state, catalog)` **不接收 node 参数**，遍历 events 全表出卡。
> 池子=2 时看不出来，**扩到 12 会直接铺出 12 张卡**。已改为 node-aware（只渲染宿主事件）。
> ⇒ 「D4 是纯内容工作」的原判断**不成立**，它是"先修结构、再加内容"。

**落地**：

- `events.json` 2 → **12 条**，母题全部落在原文高频词上（`遗藏`144 / `兽潮`144 / `赌斗`165 /
  `斗蛊`51 / `秘境`368 / `血脉`359 / `元石`2027 / `本命蛊`213）
- **4 个真实杠杆**：`health_cost` / `delayed_soul_cost`（延后抽魂）/ `curse_id`（3 条诅咒全用上）/
  **新增 `stone_gain`**（本轮唯一新增的结算类型）
- 事件节点加 `event_pool`，宿主事件用**独立派生流** `mixed_seed(seed, "event_node_"+实例id, 0)` 抽
- 卡片文案由数值杠杆**派生**（`executable ← state.health > health_cost` 与 resolver 同一判据），
  谁只改 JSON 不改正则，反漂移守卫当场炸
- 对话气球侧选项内联写明代价（红线要求执行前明确提示）

**门禁 40 种子 PASS**：12/12 覆盖、`topology_mismatch=0`、93 个事件槽、每条事件均有对话标题
+ accept/leave 分支（反空转 canary）。`test_event_pool.gd` 10/10、99 断言。

**明确不做的三件事**（越界即撞红线，已记录理由）：
赠蛊要碰 `GuInstance` + transaction_ledger；赠材料撞 `LootResolver` 红线；
赠寿元动摇单局时长基线。

### 1.3 改动文件清单

| 文件 | 归属 | 内容 |
|---|---|---|
| `data/nodes.json` | 纯本轮 | 4 个 `boss_pool` + 2 个 `event_pool` |
| `data/events.json` | 纯本轮 | 2 → 12 条，新增 `title/summary/known_risk/unknown_note/expected_gain/stone_gain` |
| `data/dialogues/events.dialogue` | 纯本轮 | 12 条事件的 `~ <event_id>` 菜单块 |
| `scripts/domain/map_generator.gd` | 纯本轮 | `+_roll_boss_for` `+_roll_event_for` `+prev_boss_id` 追踪 |
| `scripts/domain/action_preview_service.gd` | ⚠️ **混编** | 本轮：`_append_event_cards` 改 node-aware + 杠杆派生文案 |
| `scripts/domain/content_catalog.gd` | ⚠️ **混编** | 本轮：`boss_pool` / `event_pool` / `stone_gain` 校验 |
| `scripts/domain/social_command_rules.gd` | ⚠️ **混编** | 本轮：`_accept_event` 结算 `stone_gain` |
| `tests/unit/test_boss_pool_variety.gd` | 新增 | 5 用例 / 175 断言 |
| `tests/unit/test_event_pool.gd` | 新增 | 10 用例 / 99 断言 |
| `tools/verify_boss_variety.gd` | 新增 | 40 种子门禁（B0 canary / 覆盖 / 确定性 / 相邻不重复 / 终局固定 / 拓扑冻结） |
| `tools/verify_event_variety.gd` | 新增 | 40 种子门禁 + 对话标题反空转 canary |
| `tools/verify_b2_four_screens_render.gd` | 顺带修 | 假事件夹具（用 hazard id 冒充事件节点）已改为真事件 `echo_cave` |
| 报表与规格 | 新增 | 见本文头部「上游文档」 |

---

## §2 ⚠️ 工作树边界（提交前必读）

施工时工作树已含**另外三个在途工作流**，且其中三个文件与本轮改动**逐行混编，文件级无法分离**：

| 工作流 | 代表改动 | 与本轮关系 |
|---|---|---|
| **剑道 T16 残锋降转** | `sword_mark_rules.gd`、`test_sword_mark_cost.gd`、`gu_instance.gd`、`battle_command_facade.gd` | 独立文件 |
| **一脉一突破 / 收口** | `balance.json`（`cultivate_rank_three/four/five_stone_cost`）、`refine_command_rules.gd`、`resolver.gd`、`run_command_builder.gd`、`rejection_text.gd`、`run_battle_flow.gd`、`v1_battle_resolver.gd`、`test_action_preview_service.gd`、`test_data_driven_guard.gd`、`test_breakthrough_chain.gd`、`test_closure_choice.gd`、`docs/contracts/*`、`AGENTS.md` | **混编于 3 个文件** |
| **Q8G 调试裁剪** | `docs/q8g/*`、`.codex/`、`scripts/acceptance_driver.gd`、`scenes/ui/screens/map_screen.tscn` | 独立文件 |
| **美术** | `assets/wenzhen/enemies/enemy_thunder_crown_*.png` | 独立文件 |

**结论**：本轮**无法产出"只含肉鸽化"的干净 commit**。三个混编文件的分离只能靠
`git apply --cached` 手工拆 patch，而拆出的中间态因跨工作流依赖（`breakthrough` 命令
需要 `refine_command_rules` + `resolver` 同步在位）会**不可编译**。

⇒ 采用**单次包含多工作流的提交**，在提交信息中分节如实列出。若后续要拆分，请用
`git rebase -i` 而非在本轮补拆。

**判据**：提交前工作树整体为绿（全量 unit 1514/1514），**不是**"单工作流绿"。

---

## §3 未完成 / 待裁定

### 3.1 🔴 第一前置：`pacing.json` 红线裁定（同时卡住 D2 与 D4）

- **D4 只买到"种类"多样性，没买到"频率"** —— 事件仍 ≈2.3 个/局，因为 `pacing.json` 全程未动。
- **D2 层性向**要改 `pacing.layers[].category_weights`，直接违反 Reachability 轨道的
  「不改 pacing」红线，且会让 f1 的 32 局语料 population 再次作废。
- ⇒ **两者应合并裁定**：确认「强化肉鸽」优先级高于 pacing 冻结、并同意改动后重建语料，
  才能同时推进。D2 预审已出（含 Shared ownership 声明与受影响测试清单）。

### 3.2 D1 第二阶段（未做）

1. **L5 终局随机化** —— 阻塞于 `miasma_vein_lord` **强度倒挂**（rank 3 / hp 14，却是全场最弱
   boss，有效 HP 21 低于 L4 候选的 27）。要么抬数值（平衡裁定），要么为终局另立叙事中性候选。
2. **Boss 掉落差异化** —— 当前所有 Boss 共用 boss tier 规则。要碰 `LootResolver` 红线。

### 3.3 后续方向（按 ROI 排序，详见调研报告 §3.6）

`D7 精英节点显性化`（改动极小，可顺手做）→ `D2 层性向`（待裁定）→ `D3 遗物扩容` /
`D5 杀招自由组装`（大工程，需独立立项）。

> D5 虽收益高，但会同时撞 Q8 冻结语法 + 战斗结算 + 杀招屏 UI，本轮明确不碰。

---

## §4 本轮新增的硬事实

| 事实 | 出处 | 用途 |
|---|---|---|
| **终局 Boss 强度倒挂**：`miasma_vein_lord` rank 3 / hp 14 是全场最弱 | `enemies.json`【实测】 | L5 随机化的阻塞理由 |
| 7 个 boss 的 `rank` 只有 3/4/5，**无 rank 1/2** | 同上 | ⇒ 无法按 rank 严格分层，必须用**有效 HP**（× `boss_layer_mult`） |
| `boss_layer_mult` 按 stage 缩放 hp/damage（1.0 → 1.5） | `v1_battle.json`【实测】 | 分层依据 |
| ⚠️ **`core_replacement_token` 不需要迁到 boss 定义** | `core_gu_rules.gd:136` + `content_catalog:555`【代码】 | **我先前写的风险项被证伪，已撤回** |
| `_append_event_cards` 不接收 node ⇒ 池子一大就全量铺卡 | `action_preview_service.gd`【代码】 | D4 的硬前置 |
| `kind` 字段是**惰性**的（只做白名单校验，resolver 不读） | 【代码】 | 本轮刻意**不**为"看起来完整"加枚举值 |
| 诅咒共 **3 条**（蛊蚀 / 元石滞胀 / 经脉封蛊），非 1 条 | `curse.json`【实测】 | 事件杠杆比预想宽 |
| Dialogue Manager 是真 autoload（`project.godot:20`） | 【代码】 | 事件主界面是**对话气球**，遭遇卡是次界面 |
| `save_repository.gd:68` **整张 route 序列化**进存档 | 【代码】 | ⇒ 本轮改动**不影响进行中存档**（读档不重新生成地图） |
| 原文考据：`陪葬`8 次全是"拖你陪葬"威胁语义；`瘴气`21 次多数是"瘴气界壁" | 语料【实测】 | **两条先验被推翻**，初版设计文案已删 |
| 原文考据：`蛊契`/`残响`/`毒瘴`/`虫潮`/`尸傀` 均为 **0 次** | 语料【实测】 | 已内化为项目机制词，不扩用 |

---

## §5 环境坑（本轮踩到并沉淀）

| # | 坑 | 应对 |
|---|---|---|
| 1 | **PowerShell 工具不转发 stdout**（只回 "exit code 0"） | 一律 `\| Out-File -Encoding utf8 <file>` 或 `> file`，再 Read 读文件 |
| 2 | **bash shim 会整个坏掉**（`dirname: command not found` / `cd: null directory`，exit 127，`ls`/`head` 全废） | 别重试，直接换 PowerShell 工具 |
| 3 | **同一消息里批量发多个 Edit，可能报 success 但没落地** | 本轮实测 2 个丢 1 个，**是被单元测试的负例断言抓出来的**。批量改完必须 grep 回验 |
| 4 | ⚠️ **`tools/*.ps1` 在 agent 沙箱不可用**（子进程 stdout 不转发 ⇒ rc=1、0 行输出） | **这不是测试结论**；判据一律直连 Godot 二进制 |
| 5 | **GUT 汇总行不可全信** | `.gutconfig.json` 把 `SCRIPT ERROR` 归 engine 类不计 Failing ⇒ "全过"与"36 失败"可同时为真。必须另数 SCRIPT ERROR / Orphans / 退出期 ObjectDB 泄漏 |
| 6 | **全量 GUT 必须带 `-gdir`** | 只给 `-gexit` 会报"未配置目录"；正确形如 `-gdir res://tests/unit -gexit -glog=2` |
| 7 | **Boss 池随机化必须走派生流且层号进 salt 不进 tick** | `mixed_seed` 的 tick 是仿射混入，连续 tick 会退化（`seeded_roll.gd:43`） |

---

## §6 推送前检查表

- [ ] `git status --short --branch` + `git log --oneline -5` 核对工作树与提交
- [ ] `git ls-remote origin master` 取远程 sha（**`refs/remotes/` 写入会静默失败，不要信本地 remote ref**）
- [ ] `git merge-base --is-ancestor <远端sha> HEAD` 看退出码（**不要用 `branch --contains` / `log --all`**）
- [ ] 凭证挂起：`git -c credential.helper= -c credential.helper="/tmp/gcw.exe" push origin master`
- [ ] 推完用 `git ls-remote origin master` 验证落地（**不要靠 push 的输出**）

---

## §7 一句话结论

本轮以**零红线**的代价兑现了肉鸽化里感知最强的两项（关底 Boss 身份 + 事件内容），
把「7 个 boss 全部上场」和「事件 2 → 12 条」落到了门禁可复现的程度；
**真正的下一步不是再选新方向，而是裁定 `pacing.json` 是否解冻** —— 它同时卡住
D2（节奏方差）与 D4 的第二步（事件频率），不裁定就只能继续在数据层做加法。
