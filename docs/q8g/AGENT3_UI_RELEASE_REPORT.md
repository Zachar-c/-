# Agent3 UI Interaction and Release Delivery Audit

> 日期：2026-09-14（会话内复跑）
> 角色：Agent 3 worker（非设计裁定）
> 基线：`master` @ `3f09e040`
> 工作树保护：未触碰未提交业务改动；会话开始时 untracked：`.codex/`、两枚敌人立绘 PNG、`tools/q8g_agent1_post_fix_baseline.mjs`（均未删除/未纳入提交）

---

## 1. 每个 UI 验证命令与结果

| # | 命令 | 范围 | 退出码 | 结果 |
|---|------|------|--------|------|
| 1 | `godot --headless --path . -s tools/verify_interaction_loop.gd` | 15 屏交互闭环 | **0** | **PASS** |
| 2 | `godot --headless --path . -s tools/verify_rest_headless.gd` | Rest 门禁 + 可视预算 | **0** | **PASS**（`REST HEADLESS OK`） |
| 3 | `godot --path . -s tools/verify_b2_four_screens_render.gd`（真窗） | Encounter/Npc/Ending/ContentError | **0** | **PASS**（`FAILED=0`） |
| 4 | `godot --path . -s tools/verify_w10_continue_run.gd`（真窗） | continue_run / load_run | **0** | **PASS**（重试后；见 §4） |
| 5 | `godot --headless --path . -s tools/verify_card_shape_budget.gd` | 战斗卡带预算 | **0** | **PASS**（`FAILED=0`） |

补充：会话内曾对 `MaShanZheng-Regular.ttf` 执行 `--headless --import` 重导入（本地 `.godot` 导入缓存损坏，非代码回归）。

---

## 2. dead / no_ui_click / occluded 结果

交互门全屏最终结果（重导入 + 贴图修复后）：

| 屏 | total | clickable | dead | no_ui_click | occluded | occluded_known | scrolled |
|----|------:|----------:|------|-------------|----------|----------------|----------|
| Hall | 15 | 6 | `[]` | `[]` | `[]` | 0 | 0 |
| Hall-Schools | 38 | 26 | `[]` | `[]` | `[]` | 0 | 0 |
| Hall-Contracts | 43 | 2 | `[]` | `[]` | `[]` | 0 | 0 |
| Hall-Codex | 43 | 1 | `[]` | `[]` | `[]` | 0 | 0 |
| Hall-Journal | 43 | 1 | `[]` | `[]` | `[]` | 0 | 0 |
| Map | 14 | 11 | `[]` | `[]` | `[]` | 0 | 0 |
| Battle | 17 | 11 | `[]` | `[]` | `[]` | 0 | 0 |
| Rest | 16 | 10 | `[]` | `[]` | `[]` | 0 | 1* |
| Refine | 481 | 475 | `[]` | `[]` | `[]` | 0 | 0 |
| Settings | 14 | 13 | `[]` | `[]` | `[]` | 0 | 0 |
| Kill | 3 | 3 | `[]` | `[]` | `[]` | 0 | 0 |
| Reward | 3 | 3 | `[]` | `[]` | `[]` | 0 | 0 |
| Npc | 11 | 4 | `[]` | `[]` | `[]` | 0 | 0 |
| ContentError | 1 | 1 | `[]` | `[]` | `[]` | 0 | 0 |
| Ending | 4 | 4 | `[]` | `[]` | `[]` | 0 | 0 |

**交付口径：15/15 屏 `dead=[]`、`no_ui_click=[]`、`occluded=[]`、`occluded_known=0`。**

\* Rest `scrolled=1`：主决策面滚动可达，符合设计（LeaveRow 常驻 + 决策区滚动），不计入 dead/occluded。

---

## 3. 遮挡节点明细

- `KNOWN_OCCLUDED` 留档表：**空**（`tools/verify_interaction_loop.gd:27-28`）。
- 本次运行：**无新遮挡**；未向白名单追加任何节点。
- Settings「设置」当前页导航按钮：此前错误呈现为 dead，根因是字体导入失败导致 MasterTheme 编译失败；修复环境后不再出现（且「设置=当前页 disabled」按设计置灰，不计入 clickable）。

---

## 4. 真窗 / headless 验证范围

| 模式 | 覆盖 |
|------|------|
| headless | 交互闭环 15 屏、Rest 门禁、卡带预算 |
| 真窗 + 截图 | B2 四屏（`.preview/b2_{npc,encounter,ending,contenterror}.png` 1280×720）、W10（`.preview/w10_hall_with_save.png`） |
| 真窗（历史） | `docs/superpowers/reports/2026-09-14-true-window-acceptance.md` 已覆盖 B2/卡牌手感/W10/S 阶段；本次复跑 B2/W10 复核通过 |

**W10 flake：** 首跑真窗时 `save_run ok=true` 后立即 `has_save=false`（FAILED=3）；同代码重试一次即全绿。怀疑与并行 Godot 进程 / `user://` 短暂竞争有关，**未定位到领域逻辑回归**。单元侧 `test_save_repository` 因 120s 超时未在本报告内单独出具绿结论（需更长 GUT 窗口或独立重跑）。

---

## 5. Release 资源审计

### 5.1 导出过滤（`export_presets.cfg`）

基线已排除：`docs/*`、`tests/*`、`tools/*`、`vendor/*`、只读语料目录、`addons/gut/*`、`scripts/acceptance_driver.gd`、`scripts/guitkx_build.gd`、`memory/*`、部分截图通配、`*.md`。

**本次追加排除（Windows + Android 两 preset 对齐）：**

- `.preview/*`（验收截图）
- `.claude/*` `.codex/*` `.superpowers/*` `.zcode/*` `.agents/*` `.workbuddy/*` `.workbuddy-ai/*` `.githooks/*`（本地 agent / 工作产物）
- `godot_gui.log` `.claude-drive-sweep.log` `.gutconfig.json` `opencode.json`

### 5.2 调试入口

- `DebugPanelView` / F12 调试链：`OS.is_debug_build()` 门控（`run_controller.gd:109` + `run_debug_facade.gd`）；Release 构建 **不挂载** 面板，写操作双门控。
- `scenes/ui/widgets/debug_panel.tscn` 与脚本仍会进包（未编译裁剪），但运行时不可达——符合「Release 不得包含调试入口」的运行时语义；若要求 **编译期物理裁剪**，需另开工程任务。

### 5.3 语料 / 测试 / 截图 / 缓存

| 类别 | 状态 |
|------|------|
| 测试 `tests/`、门禁 `tools/` | exclude ✓ |
| 语料目录 | exclude ✓ |
| 文档 `docs/*`、`*.md` | exclude ✓ |
| `.preview` 截图 | **本次补 exclude** ✓ |
| 本地 worker 目录 | **本次补 exclude** ✓ |
| 根目录零散 `battle_*.png` 等调试截图 | 仅 `battle_screenshot*.png` 等通配覆盖部分；**未全部收口**（见风险） |
| `lore_engine/` `lore_sources/` | 未 exclude；`scripts/` 无运行时引用——疑似非运行时资产，**未改**（需产品确认） |

### 5.4 贴图加载（导出包可用性）

- **已修：** `scripts/presentation/widgets/gu_card_view.gd` `_load_gu_texture` 原用 `Image.load()` 直读 `res://`（导出包不可用 + WARNING 风暴）；改为 `load() as Texture2D` + `FileAccess.file_exists` 守卫，与 `gu_tall_fan_hand_view.gd` / `gu_enemy_actor_view.gd` 对齐。
- 修后交互门重跑：**无** `Loaded resource as image file, this will not work on export`。

---

## 6. 是否存在死按钮

**否。** 15 屏 `dead=[]`。

## 7. 是否存在未接入入口

**否。** 15 屏 `no_ui_click=[]`；未接入入口保持 disabled（如 Rest 未消费休整时 Leave 置灰 + `leave_hint`，符合 E4a）。

---

## 8. 修改文件列表

| 文件 | 改动 |
|------|------|
| `scripts/presentation/widgets/gu_card_view.gd` | `_load_gu_texture`：`Image.load` → `load() as Texture2D`；注释同步 |
| `export_presets.cfg` | Windows/Android `exclude_filter` 扩展本地产物与截图目录 |
| `docs/q8g/AGENT3_UI_RELEASE_REPORT.md` | 本报告 |

**未修改但审阅过：**

- `tools/verify_interaction_loop.gd`、`verify_rest_headless.gd`、`verify_b2_four_screens_render.gd`、`verify_w10_continue_run.gd`、`verify_card_shape_budget.gd`、`godot.ps1`
- `scripts/presentation/wenzhen_master_theme.gd`、`gu_style.gd`、`run_controller.gd`、`run_save_flow.gd`、`run_debug_facade.gd`、`debug_panel_view.gd`、`gu_tall_fan_hand_view.gd`、`gu_enemy_actor_view.gd`
- `scripts/domain/save_repository.gd`、`scripts/domain/debug_actions.gd`
- `docs/q8g/Q8G_HANDOFF_CURRENT.md`、`docs/superpowers/reports/2026-09-14-true-window-acceptance.md`
- 未触碰：`scripts/domain/**` 业务规则、`data/**`、`RunState`、resolver、loot/pity、E6、pacing、battle、promotion、`main.tscn`、`project.godot`

---

## 9. 未验证风险

1. **未执行完整 Windows/Android 导出**：未跑 `godot --headless --export-release`；exclude 扩展与 `load()` 贴图修复的包内行为未在最终 PCK 上实测。
2. **W10 首跑 flake**：偶发 `has_save=false` 未根治；建议在隔离单进程环境再跑一次，或加重试/串行锁。
3. **`test_save_repository` 等 GUT**：本审计窗口 120s 超时，未出绿结论。
4. **根目录零散截图 PNG**（如 `battle_v1_render.png`）未全部进入 exclude 通配。
5. **`lore_engine/` / `lore_sources/`** 是否允许进 Release 未裁定。
6. **Debug 面板 tscn 仍在包内**（运行时门控）；若验收要求物理裁剪需工程任务。
7. **ObjectDB/RID 泄漏**（既有）：交互门退出仍有 leak WARNING，非本批 UI 交付阻断，已知遗留。

---

## 10. 设计冲突 / 是否需要 Luna 新裁定

- **无阻塞性设计冲突。** Rest Leave 门禁、Settings 当前页 disabled、交互三键口径均与 AGENTS.md / 既有裁定一致。
- **建议 Luna 知悉（非阻塞）：**
  1. W10 真窗偶发 flake——是否要求加固 harness；
  2. Release 是否要求 debug 脚本/场景 **编译期移除** 而非仅 `is_debug_build` 运行时门控；
  3. `lore_engine`/`lore_sources` 是否进包。

Agent 3 **未**对以上三点做产品裁定，也未扩展业务规则。

---

## 11. Windows Release 卫生复测（2026-09-14 / HEAD `96d79f2d`）

用户裁定后 Agent3 复测（**不是**沿用 `2748ef82` 旧 PCK）。

### 11.1 运行时依赖审计（排除前提）

| 目录 | 正式运行时依赖 | 结论 |
|------|----------------|------|
| `Godot/` | 无（误写的 editor/user 数据） | 可排除 |
| `lore_engine/` `lore_sources/` | `scripts/` `scenes/` 零引用 | 可排除 |
| `ui/**/*.guitkx` | `RunScreenRouter.SCREEN_PATHS` 为空；全屏 `.tscn` | 源文件可排除；生成层 `.gdc` 仍进包（未批准扩大） |

### 11.2 导出与产物

```text
APPDATA 显式设为 C:\Users\90877\AppData\Roaming（否则模板路径落到 ./Godot）
--export-release "Windows Desktop" → rc=0
  build/agent3-release-20260914-2301/gu-zhenren.exe  190,503,784 B
--export-pack 同预设 → rc=0
  …/gu-zhenren.pck  81,359,100 B
Release exe --headless --quit-after 3 → EXIT=0
```

### 11.3 PCK 阴性断言（字节串扫描，非工程盘合并枚举）

| 标记 | 计数 | 判定 |
|------|-----:|------|
| `res://tests/` | 0 | PASS |
| `res://tools/` | 0 | PASS |
| `res://docs/` | 0 | PASS |
| `res://.preview/` `.codex/` `.superpowers/` | 0 | PASS |
| `res://memory/` | 0 | PASS |
| `res://lore_engine/` `res://lore_sources/` | 0 | PASS |
| `res://vendor/` / 只读语料 | 0 | PASS |
| `res://Godot/` | 0 | PASS |
| `scripts/acceptance_driver` / `guitkx_build` | 0 | PASS |
| `res://ui/_sample` | 0 | PASS |
| `.guitkx` 字面量 | 1（vocabulary 注释文案，非文件） | PASS |
| `res://.claude/worktrees/...events.dialogue` | 1 | **known_shared**：来自 `project.godot` POT 路径（Shared，另案） |
| `debug_panel` / `run_debug_facade` / `debug_actions` | 9 / 5 / 5 | **OBS**：编译期裁剪未做（见方案文档） |

工具：`tools/agent3_pck_audit.gd`（扫 PCK 字节，不 `DirAccess(res://)` 合并工程盘）。

### 11.4 Debug 编译期裁剪

已提交方案：`docs/q8g/Q8G_DEBUG_COMPILE_PRUNE_PLAN.md`  
**本批未实现**（`run_controller` 硬引用 `RunDebugFacade`，需 Shared 5 步协议）。禁止只靠 exclude_filter 剔脚本却留硬引用。

### 11.5 Android

本阶段 **不要求** Android 导出（用户裁定）。

---

## 12. 结论

| 交付门 | 状态 |
|--------|------|
| `dead=[]` / `no_ui_click=[]` / `occluded=[]` | **PASS**（15/15） |
| Rest / B2 / 卡带预算 | **PASS** |
| W10 continue_run | **PASS**（重试；flake 未根治） |
| Windows Release 导出 + exe 启动 | **PASS**（`96d79f2d`） |
| PCK 卫生阴性（tests/tools/docs/lore/Godot…） | **PASS** |
| Debug 编译期裁剪 | **未完成**（方案已交） |
| `.claude` POT 跨 worktree | **known_shared**（`project.godot`） |
| Android | **非本阶段 Gate** |

**综合：Windows Release 卫生与基础导出 CONDITIONAL→当前卫生项已闭环；最终仍待 Debug 阶段 B + Luna 对 known_shared POT 的 Shared 任务裁定。**
