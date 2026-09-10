# 技术债原子任务 — 执行方案与跟踪看板（2026-09-10）

- **上游拆分**：`docs/superpowers/plans/2026-09-09-tech-debt-atomic-tasks.md`（下称《原子》；子任务卡的操作步骤/验证命令/失败即停/回滚为唯一技术依据，本文件只做编排，不重复其细节）
- **源计划**：`docs/superpowers/plans/2026-09-09-tech-debt-remediation-plan.md`（状态回写目的地之一）
- **基准日 D0**：2026-09-10；**当前 master**：`90a44ed`
- **本文件用途**：把《原子》A/B/C 三轨 19 个未闭环子任务落实为「负责人 × 资源 × 时间窗 × 依赖 × 检查节奏」的执行编排，并承载**状态看板**（§6）作为跨会话持久跟踪载体。

---

## 1. 范围与实测基线

| 项 | 值 |
|----|-----|
| 覆盖范围 | 《原子》§1 轨道 A（W11.3，A1–A8）、§2 轨道 B（W12，B1–B9）、§3 轨道 C（W10 催办） |
| 已闭环（禁执行） | 《原子》§5 全清单（W1–W9/W13/W14/W11 m1/2/4），本方案不碰 |
| resolver.gd | **2407 行**（与《原子》基线一致） |
| run_snapshot_builder.gd | **2373 行**（《原子》头写 2058 已过时——视觉会话后续增改，以实测为准） |
| run_controller.gd | **1760 行**（《原子》头写 1407 已过时） |
| 三件套基线 | 最近实测：unit 1165/1165、integration 31/31、check exit 0（`90a44ed`，2026-09-09 夜） |
| 并行会话冲突门 | 每次触碰 `scripts/presentation/` 前 `ls -lt scripts/presentation/screens/ run_snapshot_builder.gd run_controller.gd`；**30 分钟内有视觉会话改动则不执行 B 轨相关步**（《原子》R3） |

> 行数注：B 轨目标是 `run_snapshot_builder.gd < 800`、`run_controller.gd < 900`——因实测基线高于《原子》成文时的数字，**以目标行数为准，不以"减了多少"为准**。

---

## 2. 依赖图与关键路径

```
轨道 A（worktree: .worktrees/resolver-split, 分支 chore/w11-resolver-split）
A1 ─→ A2 ─→ A3 ─→ A4 ─→ A5 ─→ A6 ─→ A7(合入 master) ══ 里程碑 M1
  └(A2.0 可选前置，若做先于 A2 单独提交)
A8（随时，独立，0.2h；无需依赖）

轨道 B（worktree: .worktrees/snapshot-split, 分支 chore/w12-snapshot-split）
B1 ─→ B2 ─→ B3 ─→ B4 ─→ B5 ─→ B6 ─→ B7 ─→ B8 ─→ B9(合入 master) ══ 里程碑 M2
（B5 内部一屏一提交：rest→shop→refine→npc→reward→encounter→settings→content_error/debug）

轨道 C（视觉会话）
C 随时独立；唯一约束是与 B **错峰**触碰 presentation（《原子》R3）
```

| 关系 | 说明 |
|------|------|
| A→B 串行依赖 | **推荐**：B1 基线取 A7 合入后的 master，避免两 worktree 同时改 `scripts/` 后在 master 上合入冲突。A 只改 `scripts/domain/`、B 只改 `scripts/presentation/` + 各自测试，文件簇零重叠，理论可并行；但合入顺序会造成额外协调成本，编排默认串行。 |
| B 内依赖 | B2–B5 依赖 B1（契约基线）；B5 每屏即独立子提交；B6–B8 依赖 B2–B5 完成（controller 委托模式在快照拆分后再做，减少交错）；B8 改 `submit_command` 内快照刷新路径，放最末。 |
| C 与 A/B | C 只催办不改代码（通用会话）；视觉会话若真改 `continue_run`，走自己的分支，B 轨执行前查 mtime 门。 |
| 用户决策点 | **A7**、**B9** 合入 master 前需用户批准；C 的方案甲/乙由视觉会话定，通用会话不猜。 |

**关键路径**：A1→A2→A3→A4→A5→A6→A7→B1→B2→B3→B4→B5→B6→B7→B8→B9。
A 轨任何红（失败即停）直接拖停整链——A1 的基线 unit 必须先绿。

---

## 3. 负责人与资源矩阵

### 3.1 负责人

| 角色 | 承担内容 | 备注 |
|------|---------|------|
| **执行代理 A（主 AI 会话）** | 轨道 A 全部（A1–A8） | 按《原子》R0：一子任务一次派发，完成回写后再领下一项 |
| **执行代理 A（后续会话接力）** | 轨道 B 全部（B1–B9） | 与 A 串行；若并行须各自独立 worktree + 合入前协调 |
| **视觉会话** | 轨道 C（W10）及 B 轨触碰 presentation 期间的排他窗口 | 通用会话只催办，不写 C 的代码 |
| **用户** | A7 / B9 合入批准；真窗键鼠验收（AGENTS AI 契约） | 回写时标注待验收项 |

### 3.2 资源清单

| 资源 | 说明 |
|------|------|
| worktree | `.worktrees/resolver-split`（A）、`.worktrees/snapshot-split`（B）；用完 `git worktree remove`。**禁**在 master 上直接大改（《原子》R4） |
| 测试入口 | `powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Suite unit`（unit）；`-Suite integration`（integration）；`tools/check.ps1`（check）。注意：`test.ps1 -Test` 参数用**空格分隔**传 `-gtest`，勿用 `=`（shell 拆分坑，2026-09-09 踩过） |
| 单文件 GUT | `"<GodotWinGet>/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://... -gexit` |
| 运行时 | Godot 4.7.2 console exe（WinGet 路径）；无 python 依赖（守门已 GDScript 化） |
| 共享 helper | 若 A2.0 执行：`_accepted`/`_rejected` → `scripts/domain/resolver_helpers.gd`（static 导出），A3/A4/A5 依赖此先例 |
| 禁改 | 命令 type 字符串；平衡数值；公开 API 名单（《原子》A0 禁止列）；快照键名（B 轨）；`test_legacy_abolition` / `test_snapshot_contract` |
| 需同步文档 | A6：`PONYTAIL-DEBT.md`、`docs/contracts/module-interfaces/07-domain-action-router.md`、`MODULE-INVENTORY.md`；B 轨若键漂移=违规=回滚该屏 |

### 3.3 执行环境注意（来自本仓库实测纪律）

- `.git` 已五次损坏：**禁** `reset --hard`/`stash`/`filter-branch`/`checkout -- .`；恢复走 MEMORY.md 六步。
- 推送用 wincred 直连：`git -c credential.helper= -c credential.helper="<PortableGit>/mingw64/bin/git-credential-wincred.exe" push origin master`；落地核对 `git ls-remote origin refs/heads/master`。
- GDScript 解析 JSON 数字为 float：测试断言需 `int()` 归一（项目惯例）。
- GDScript 警告当错误：`var x := dict.get(...)` 须显式类型标注。
- 单文件 `.gd` 新模块需 `class_name`，若 `class_name` 与既有冲突先 `grep -rn` 全库核对。

---

## 4. 原子任务执行卡

> 执行序列以《原子》对应子任务卡的「操作步骤/验证命令/失败即停」为准；下表只补负责人、依赖、资源、时间窗与**首个可执行动作**，避免双维护。

### 轨道 A（目标：resolver < 1200 行；行为零变化）

| ID | 任务 | 负责人 | 依赖 | 时间窗 | 执行入口（首个动作） | 完成定义（验证） |
|----|------|--------|------|--------|---------------------|------------------|
| A1 | worktree + 基线快照 | 代理 A | master 干净 + unit 绿 | D0, 0.3h | `git worktree add .worktrees/resolver-split -b chore/w11-resolver-split master` → worktree 内跑 unit | unit 全绿；`resolver.gd` 行数=2407 写入回执 |
| A2 | rest 族 → `rest_rules.gd` | 代理 A | A1 | D0, 1.5h | `rg -n "^static func _rest|^const REST_" scripts/domain/resolver.gd` 圈搬移闭包 | unit+integration 绿；resolver 无 `_rest(` 定义；回执两文件行数 |
| A2.0 | （可选）`_accepted`/`_rejected` → `resolver_helpers.gd` | 代理 A | A1（先于 A2 单独提交） | D0, +0.3h | 若 A2 搬移时发现私有依赖无法跨模块 → 执行 | unit 绿 |
| A3 | shop 族 → `shop_command_rules.gd` | 代理 A | A2 | D1, 1.5h | `shop_layer_price`/`shop_max_tier` 留一行转发，dispatch 改指向 | unit 绿；resolver 仍有转发定义 |
| A4 | refine 族 → `refine_command_rules.gd` | 代理 A | A3 | D1, 2h | dispatch 的 rest-class 消费包装留 resolver，只搬核心函数 | unit+integration 绿；`test_legacy_abolition` 绿 |
| A5 | npc/social → `social_command_rules.gd` | 代理 A | A4 | D2, 2.5h | 大批量搬移 + 常量随使用点迁移 | unit+integration+check 绿；**resolver < 1200 行** |
| A6 | 文档收口 | 代理 A | A5 | D2, 0.5h | 改 PONYTAIL-DEBT 门限行→1200；更新 07-domain-action-router 文件清单 | 新文件名真实存在；无「2407」残留 |
| A7 | 全量回归 + 合入 | 代理 A + **用户批准** | A6 | D2, 1h | worktree 内三件套 → A2–A6 各一提交 → 推送 → 用户批准 merge → remove worktree | master 三件套绿；ls-remote 对齐 |
| A8 | school_rules 复核 | 代理 A | 无 | 随时, 0.2h | `rg "SchoolRules\\." scripts/` → 4 函数均被引用则回执「无需再动」 | 无误删；unit 绿 |

### 轨道 B（目标：snapshot_builder < 800、controller < 900；契约键零漂移）

| ID | 任务 | 负责人 | 依赖 | 时间窗 | 执行入口 | 完成定义（验证） |
|----|------|--------|------|--------|---------|------------------|
| B1 | worktree + 契约基线 | 代理 A | **A7 合入后** | D3, 0.3h | `git worktree add .worktrees/snapshot-split -b chore/w12-snapshot-split master` → 跑 `test_snapshot_contract` + unit | 契约测试绿；记录 HEAD |
| B2 | hall → `snapshots/hall_snapshot.gd` | 代理 A | B1 | D3, 2h | 搬 `hall` + 私有闭包；共享小函数（`_cn_number` 等）抽 `snapshot_text_util.gd`，**禁复制两份** | 契约 Hall 段绿；unit 绿 |
| B3 | map → `map_snapshot.gd` | 代理 A | B2 | D3, 1.5h | `for_screen("Map")` 一行转发 | 契约 Map 键不变；unit 绿 |
| B4 | battle/kill → `battle_snapshot.gd` | 代理 A | B3 | D4, 2.5h | 搬 V1 私有闭包；**不改 V1 数值** | battle 契约键绿；`test_v1_*` 绿 |
| B5 | 其余屏逐个拆 | 代理 A | B4 | D4–D5, 4–5h | rest→shop→refine→npc→reward→encounter→settings→content_error/debug，**一屏一提交** | 每步契约绿；终局 builder < 800 行 |
| B6 | save/load → `run_save_flow.gd` | 代理 A | B5 | D5, 1.5h | controller public 方法留同名一行委托 | public API 不变；save/load 测试绿 |
| B7 | debug → `run_debug_facade.gd` | 代理 A | B6 | D5, 1h | `OS.is_debug_build` 门控只留一处 | Release 门控不变；`test_debug_actions*` 绿 |
| B8 | 视图挂载 → `run_screen_router.gd` | 代理 A | B7 | D5–D6, 2h | `submit_command` 仍调 Resolver，成功后经 router 刷快照挂屏 | master flow integration 绿；controller < 900 行 |
| B9 | W12 全量回归 + 合入 | 代理 A + **用户批准** | B8 | D6, 1h | 三件套 → 按屏合并提交 → 推送 → 用户批准 merge → remove worktree | 三件套绿；契约文档无需改键 |

### 轨道 C（视觉会话）

| ID | 任务 | 负责人 | 依赖 | 时间窗 | 产出 |
|----|------|--------|------|--------|------|
| C | W10 `continue_run` 语义对齐（甲/乙二选一） | **视觉会话** | 无 | 视觉会话自估 0.5–1h | 通用会话产出 = 状态表催办一行（本节看板标记），**零代码** |

---

## 5. 任务跟踪机制

### 5.1 状态机

```
pending → in_progress → done
             └→ blocked ─→(解除条件满足)→ in_progress
```
- **blocked 条件**：验证红（《原子》§7 回滚策略逐条走完仍红）；并行视觉会话 mtime 门命中；等用户批准 merge。
- 严禁 `done` 状态带红；严禁为变绿改断言（《原子》R5）。

### 5.2 检查节奏（谁、何时、看什么）

| 时机 | 动作 |
|------|------|
| 每个子任务收尾 | 执行者把 §6 看板该行更新为 done/blocked，附提交 SHA + 验证输出要点（≤3 行），同步回写 remediation-plan 状态表 |
| 每次会话开工 | 读 §6 看板 → 取第一个 pending 且依赖满足的子任务 → `git status` + mtime 门 → 开工 |
| 每日一次（或每批 2–3 子任务后） | 主会话/用户核对：pending 数、blocked 原因、是否有子任务超过预估窗 2× 未完成（超时即触发 5.3 升级） |
| 合入前 | 核对 ls-remote = 本地 HEAD；三件套输出贴回执 |

### 5.3 问题识别与升级

| 症状 | 处置 |
|------|------|
| 子任务超预估窗 2× | 停下当前子任务，报告用户：已完成/卡点/建议（继续 vs 回滚该次搬迁） |
| 验证红（unit/integration/check） | 《原子》§7 逐条：契约红→回滚当前屏/命令族该次提交；基线已红→非本任务，停并报告；dispatch 红→恢复原样调用再二分搬迁 |
| 发现无关改动 | 保护并忽略（《原子》R1），回执记录 |
| 并行会话冲突 | 命中 mtime 门 → 立即停 B 轨相关步，报告用户协调错峰 |
| `.git` 异常 | 立即停，按 MEMORY.md 恢复流程，勿自行 `git gc`/reset |

### 5.4 回写链路

```
子任务 done → 看板 §6 + remediation-plan 状态表（双写）
里程碑 M1（A7） → remediation-plan W11 措施 3 关闭
里程碑 M2（B9） → remediation-plan W12 关闭
C done → remediation-plan W10 关闭（视觉会话写）
```

---

## 6. 状态看板（跨会话回写区）

> 规则：状态 ∈ pending/in_progress/blocked/done；每个子任务只允许一行，追加历史放当日 memory。
> 时间窗基准：D0=2026-09-10，D+n 顺延（周末/并行会话占用则顺延并在备注注明）。

| ID | 任务 | 负责人 | 状态 | 时间窗 | 提交 SHA | 验证结果 | 备注 |
|----|------|--------|------|--------|---------|----------|------|
| A1 | worktree+基线 | 代理 A | done | D0 | 分支 `chore-w11-resolver-split` @ 7158d1c | unit 1167/1167 | 分支名改无斜杠（.git refs 斜杠目录被沙箱拦）；.godot 缓存复制入 worktree 才能跑 headless |
| A2.0 | helpers 前置(可选) | 代理 A | done | D0 | — | — | design-skip：GDScript 无私有 static，命令族模块经全局 `Resolver._xxx` 直调共享 helper，无需抽取 |
| A2 | rest 族拆分 | 代理 A | done | D0 | c56b8fe | unit 1167/1167 + integration 31/31 + rest 组 59/59 | resolver 2407→2188；rest_rules.gd 新 237；encounter_session_resolver 接线 |
| A3 | shop 族拆分 | 代理 A | done | D1 | 9322d25 | 相关测试 53/53 | resolver 2188→1943；shop_command_rules.gd 新 274；`_npc_trade` 4 分支接线 |
| A4 | refine 族拆分 | 代理 A | done | D1 | 49a2590 | unit 1167/1167 + integration 31/31 | **resolver 1943→1182（破 <1200）**；refine_command_rules.gd 新 828（37 func）；rest↔refine 经 Resolver 桥接；3 测试跟随修正 |
| A5 | social 族拆分 | 代理 A | done | D2 | a5fb1f1 + c7e0ffd | unit 1167 + integration 31 绿 | A5a 社交簇 17 函数 + A5b 行动/升仙簇 24 函数；resolver 1182→264 行；social_command_rules.gd 新 945 |
| A6 | 文档收口 | 代理 A | done | D2 | 49ffbe5 | 新文件名真实存在；无过时行数描述 | PONYTAIL-DEBT + 07-domain-action-router + MODULE-INVENTORY + resolver.gd:4 门限注释 + §6 看板回写 |
| A7 | 回归+合入 M1 | 代理 A→用户 | done | D2 | master=49ffbe5（ff 自 7158d1c） | master 三件套绿：unit 1167/1167 + integration 31/31 + guitkx 16 确定性 | 用户批准后 ff 合入；看板 A1–A4 详注与 A5/A6/A8 两版并集合并；worktree 已 remove；M1 达成 |
| A8 | school 复核 | 代理 A | done | 随时 | — | unit 绿 | 4 函数均存活（is_soul→relic_hook_resolver:82；blood/add_blood/material_fuel→test_school_framework）；经 preload 别名 SchoolRulesScript 引用（按 SchoolRules. 查会漏）→ 无需再动 |
| B1 | worktree+契约基线 | 代理 A | done | D3(A7后) | 分支 `chore-w12-snapshot-split` @ 2830dd0 | unit 1167/1167（含 test_snapshot_contract） | mtime 门核查：9:21 批量 mtime 为 A7 ff 合入 checkout 产物（git status 干净），非视觉会话；.godot 缓存已复制入 worktree |
| B2 | hall 快照 | 代理 A | done | D3 | c8fb6b8 | unit 全绿 | `snapshots/hall_snapshot.gd` + `snapshot_text_util.gd`；builder 保留 `_codex` 转发（verify 工具直调） |
| B3 | map 快照 | 代理 A | done | D3 | 4a3f6cd | unit 全绿 | `snapshots/map_snapshot.gd`；共享 helper 经 `RunSnapshotBuilder._node_label/_inventory` 等 |
| B4 | battle 快照 | 代理 A | done | D4 | f27ef42 | unit 全绿；V1 键零漂移 | `snapshots/battle_snapshot.gd`（battle+kill）；`battle_turn_supports` 留转发 |
| B5 | 其余屏快照 | 代理 A | done | D4–D5 | 714d011/6559b6c/b9bc1da/9389f24/d041738 | unit 1155+ 全绿；契约测试绿 | rest→shop→refine→npc→reward 单独提交；encounter/settings/content_error/debug 合并提交（此前 reward 提交误带其他屏转发器，已 soft-reset 重做）；`_v1_hand` 留转发（test_central_gu_economy 直调）；builder 767 行（<800 达标） |
| B6 | save flow | 代理 A | done | D5 | 71da214 | unit 1155 + integration 31 绿 | `run_save_flow.gd`（8 方法静态化，controller 同名一行委托）；public API 不变 |
| B7 | debug facade | 代理 A | done | D5 | 52faa7c | unit + integration 绿；`test_t5d_debug_panel` 绿 | `run_debug_facade.gd`；门控 `_debug_enabled_for_test` 留 controller（OS.is_debug_build 单一来源）；DEBUG_* 常量随迁；`DEBUG_RESOURCE_LABELS` 用 `static var`（const 不能调用静态函数初始化）；8acd695 修 test 直调 `controller.DEBUG_STONE_CAP` |
| B8 | screen router | 代理 A | done | D6 | 4280176 | unit + integration 绿；`test_wenzhen_ui_flow` 绿 | `run_screen_router.gd`（路由表+挂载机制）；controller 同名委托；UI_RULES.md 与 module-interfaces/08 已同步路由表新位置 |
| B9 | 回归+合入 M2 | 代理 A→用户 | done | D6 | 8acd695→master=fc7cb3e（ff，用户批准） | worktree 合入后 master `check.ps1` rc=0 全绿（guitkx+unit 1167+integration 31+启动探针+契约漂移 157 标识符+diff --check）；已推送 origin/master | builder 767<800 ✓；controller 1241>900 ✗（_show_* 家族与命令构建未在 B6–B8 输入清单内，未达 <900 目标，如实披露，转后续债务条目）；worktree 已 remove（长路径残留目录经 `\\?\` 前缀清理）；合入前 master 工作树遗留的 B1-done 未提交行经核对被 fc7cb3e 完全包含，stash 已 drop |
| C | W10 continue_run | 视觉会话 | done | 2026-09-10 | `158aef4`（master） | unit 1167 + integration 31 全绿；`verify_interaction_loop` 全屏 `dead=[] no_ui_click=[]` | **方案甲**：continue_run = 读档继续（经 `submit_command load_run`，对齐 2026-09-05 存档体验裁定）；load_run 失败留原屏显拒绝文案；`test_map_exit_persistence` 改判直读直恢复；真窗键鼠验收待办 |

---

## 7. 里程碑与全局完成定义

- **里程碑 M1（A7）**：master 上 resolver < 1200 行，A2–A6 新模块入 `scripts/domain/`，三件套绿，行为零变化（unit/integration/check 与拆分前同数或更绿）。
- **里程碑 M2（B9）**：`run_snapshot_builder.gd < 800`、`run_controller.gd < 900`，`for_screen`/public API 唯一入口不变，快照契约键零漂移（`test_snapshot_contract` 全文未改即绿）。
- **轨道 C**：✅ remediation-plan W10 已关闭，`test_map_exit_persistence` 直读直恢复语义回绿（方案甲，`158aef4`）。
- **整批完成定义**：§6 看板全部 done + 三件套全绿 + 关键提交推送且 `git ls-remote origin refs/heads/master` 对齐（《原子》§0 全局完成定义）。

---

## 8. 风险登记

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| worktree 拆分期间并行会话清目录（已发生 5 次 .git 损坏/4 次整目录删除） | 中 | 高 | 只在独立 worktree 改；每子任务后 commit；禁并行会话同时碰 `scripts/`；见 MEMORY.md 防御条款 |
| A5 大批量搬迁引入行为回归（dispatch 指错/私有依赖漏搬） | 中 | 高 | A2/A3/A4 先建立「搬一簇绿一批」节奏；integration 是主网；红即《原子》§7.3 二分 |
| B 轨契约键意外漂移 | 低 | 高 | `test_snapshot_contract` 全程未改；键漂移即回滚该屏 |
| 视觉会话同窗改 presentation（mtime 门） | 中 | 中 | 每次开工查 `ls -lt`；命中即停并协调 |
| GDScript 细节坑（float 断言/类型推断/class_name 冲突） | 高 | 低 | 执行卡 §3.3 前置检查清单 |
| 行数目标不达（B 轨实测基线 2373/1760 高于《原子》成文数） | 中 | 低 | 以 <800/<900 绝对目标为验收，不以减量为准；不达标则该屏不强行再拆，记录偏差 |

---

## 9. 首个执行批次建议（待用户确认后开工）

**批次 1（D0，单会话可完成）**：A1（0.3h）→ A2（1.5h）→ A2.0 若需（0.3h）→ 每步 unit/integration 验证 → 看板回写。
完成即停，等用户验收后再领 A3/A4。
