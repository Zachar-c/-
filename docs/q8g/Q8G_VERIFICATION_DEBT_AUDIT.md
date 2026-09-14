# Verification Debt Audit（VDA / 2026-09-14）

**执行者**：Agent 2（执行 worker，非设计裁定者）
**授权**：用户 2026-09-14 直接派发（相当于 inbox §29 待解项 ⑤）
**性质**：验证债务归因 + 低风险修复。**未修改 `scripts/domain/**`、`data/**`、RunState/save/event、正式 pity/E6/pacing/battle**

---

## 0. 结论摘要

| 项 | 结论 |
|---|---|
| **全部 5 项遗留的真因排序** | **导入缓存缺失** > 测试断言缺陷 > 第三方 addon UID > 生产代码生命周期 |
| 36 个 unit 失败 + 572 条 SCRIPT ERROR | **不是回归，是 `.godot` 导入缓存陈旧**：`--import` 后 **1445/1445 全绿、SCRIPT ERROR 1 条** |
| §28 的归因 | 🔴 **错了两处**（详 §4.5、§5） |
| `tools/check.ps1` rc=1 真因 | **沙箱不转发 Godot 子进程 stdout** ⇒ `run_gut_checked.ps1:27` 找不到 GUT 汇总 ⇒ `exit 1`。**不是** SCRIPT ERROR 扫描 |
| 最重要策略发现 | 🔴 **`.gutconfig.json` 把 `engine` 从 `failure_error_types` 移除 ⇒ 36 个真实失败被 GUT 报成 0 failing**（"不可见"比"误报"危险得多） |
| 已修 | 2 个文件（1 测试断言 + 1 工具前置），**均属允许范围** |
| 需 Luna 裁定 | **4 项**（§8） |

---

## 1. 实际修改的文件（仅 2 个，均为允许范围）

### 1.1 `tests/unit/test_slay_gu_final_chapter.gd`（测试断言，+19/−4）

**病灶**：`test_slay_gu_catalog_entry_is_test_only` 把 `loot_tables` 的**每个顶层 value** 赋给 `Dictionary`：

```gdscript
# 旧（有缺陷）
for table_value in catalog.get("loot_tables", {}).values():
    var table: Dictionary = table_value          # ← :149 运行期错误点
    for bucket_value in table.get("by_rarity", {}).values():
        assert_false(SLAY_GU_ID in (bucket_value as Array), "杀蛊不进稀有度桶")
```

三处问题：

1. `data/loot_tables.json` 顶层现有 **元数据键**：`school_material_resonance`（数值 5）、`school_material_resonance_note`（字符串）。赋给 `Dictionary` 抛
   `SCRIPT ERROR: Trying to assign value of type 'float' to a variable of type 'Dictionary'`
   ⇒ **中断该测试函数，第 151 行断言永不执行**（实测断言执行 **0 次**）。
2. 真实池位是 **`loot.<tier>.gu_pool.by_rarity`**；顶层根本没有 `by_rarity` ⇒ 即使不崩，**也是空转**。
3. 该错误在 GUT 里属 `engine` 类 ⇒ **不计入 Failing**（见 §5），所以长期无人发现。

**改法**：显式走到真实池位，并跳过非 Dictionary 的顶层值。断言执行 **0 → 6 次**（覆盖 common/elite/boss 全部 6 个稀有度桶）。

### 1.2 `tools/test.ps1`（测试包装器，+15）

新增 **`--import` 前置**（沿用 `check.ps1` 既有的 `$ErrorActionPreference` 降级 + 吞 stderr 写法，成败以 exit code 判定）。

理由：`docs/superpowers/plans/2026-09-07-repo-hygiene-data-driven-tests.md:72` **早已把 `--import` 写为约定**，但 `test.ps1` / `check.ps1` 从未自动化它。本次实测的代价是 36 个失败 + 572 条 SCRIPT ERROR 的假警报。

语法校验：`Parser::ParseFile` → **0 errors**（见 §3）。包装层端到端**未能验证**（§7）。

---

## 2. 未修改但审阅过的文件

| 文件 | 审阅结论 | 为何不改 |
|---|---|---|
| `tools/run_gut_checked.ps1` | `:24` 全局 `SCRIPT ERROR` 扫描；`:27` 无输出即 `exit 1` | 改扫描规则＝改交付门语义 ⇒ 需裁定（§8-①） |
| `tools/check.ps1`、`tools/godot.ps1`、`tools/guitkx_build.ps1` | 分段各自 rc=0；探针写法正确 | 无缺陷 |
| `.gutconfig.json` | `failure_error_types=["gut","push_error"]`（GUT 默认含 `engine`） | 🔴 策略取舍，需裁定（§8-③） |
| `data/loot_tables.json` | 顶层 2 个元数据键触发类型错误 | `data/**` 禁止修改 |
| `addons/dialogue_manager/**`（18 个 `.tscn`） | ext_resource `uid` 与 `.gd.uid` 不一致 | 第三方 addon，需授权（§8-②） |
| `scripts/presentation/widgets/gu_tall_fan_hand_view.gd:338` | 实测报点（`btn.mouse_filter`，`btn` 来自返回 null 的 `_build_face`） | `scripts/**` 禁用；且修复导入后不再复现 |
| `scripts/presentation/screens/map_screen_view.gd` | `_clear_children` 用 `remove_child + queue_free`（延迟释放） | 同上 |
| `project.godot:53` | 🔴 引用 `.claude/worktrees/battle-visual-implementation/.../events.dialogue`（跨 worktree 污染） | Shared 单写者文件（§8-④） |
| `docs/q8g/Q8G_HANDOFF_CURRENT.md`、`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md`、`export_presets.cfg`、`scripts/presentation/widgets/gu_card_view.gd` | **其他 agent 的未提交改动** | 一律未触碰 |

---

## 3. 验证命令与退出码

### 3.1 直连 Godot（等价命令）

| 命令 | rc | 关键输出 |
|---|---|---|
| `--headless --path . --import` | **0** | 13 条 `invalid UID` 警告；无字体错误 |
| `--headless --path . -s scripts/guitkx_build.gd` | **0** | `compiled=0 errors=0 held=0 total=16` |
| `-s addons/gut/gut_cmdln.gd -gdir res://tests/unit -gexit` | **0** | `Tests 1445 / Passing 1445 / Asserts 47771 / Orphans 2 / 234.5s` |
| `-s addons/gut/gut_cmdln.gd -gdir res://tests/integration -gexit` | **0** | `Tests 32 / Passing 32 / Asserts 1476 / 64.3s` |
| `-s tools/check_contract_drift.gd` | **0** | `contract drift: ok (168 identifiers resolved)` |
| `git diff --check` | **0** | 无空白错误 |

unit 遗留退出期资源：`WARNING: 18 ObjectDB instances were leaked at exit`、`ERROR: 6 resources still in use at exit`、**RID 泄漏 0**。

### 3.2 包装层（`tools/*.ps1`）

| 命令 | rc | 用时 | 输出行数 |
|---|---|---|---|
| `tools/test.ps1 -Suite unit` | **1** | ~0 s | **0** |
| `tools/test.ps1 -Suite integration` | **1** | ~1 s | **0** |
| `tools/check.ps1` | **1** | ~0 s | **0** |

> ⚠️ 上述 rc=1 **不是真实测试结论**（§5）。本环境（agent 的 PowerShell 沙箱）无法给出包装层判定。

### 3.3 `--import` 前后对照（唯一变量）

| 指标 | 陈旧导入缓存 | `--import` 后 | 断言修复后 |
|---|---|---|---|
| unit rc | 1 | **0** | **0** |
| Tests / Passing / Failing | 1445 / **1409** / **36** | 1445 / **1445** / **0** | 1445 / 1445 / 0 |
| **SCRIPT ERROR** | **572** | **1** | **0** |
| Orphans | 135 | 2 | 2 |
| ObjectDB 泄漏 | 361 | 18 | 18 |
| RID 泄漏 | 63（17 TextureStorage + 45 ShapedTextData + 1 Font）+ 133 CanvasItem | **0** | **0** |
| unit 用时 | 674 s | 413 s | **234 s** |

SCRIPT ERROR 构成（陈旧缓存）：`Invalid call 283 / Invalid access 257 / Invalid assignment 15 / Cannot call 11 / Parse Error 3 / Compile Error 2 / Trying to 1`。

---

## 4. 五项验证遗留逐项归因

### 4.1 Dialogue Manager invalid UID —— 第三方 addon UID 不一致

**静态审计（全仓 `.tscn`/`.tres` 的 `ext_resource` vs `.gd.uid`）**：

```
主工作树 .tscn/.tres 71 个 | ext_resource(带 path) 171 条
① .gd 的 uid 与 .uid 不一致      : 18   ← 全部位于 addons/dialogue_manager/**
② .gd 有 uid 引用但缺 .uid 文件  : 0
③ 引用的目标文件不存在           : 0
```

**运行时警告（逐字）**：

```
WARNING: res://addons/dialogue_manager/views/main_view.tscn:3 - ext_resource, invalid UID: uid://cipjcc7bkh1pc - using text path instead: res://addons/dialogue_manager/views/main_view.gd
WARNING: res://addons/dialogue_manager/components/code_edit.tscn:3 - ext_resource, invalid UID: uid://klpiq4tk3t7a - using text path instead: ...
WARNING: res://addons/dialogue_manager/components/code_edit.tscn:4 - ext_resource, invalid UID: uid://djeybvlb332mp - using text path instead: ...
```

出现次数：import 期 **13**、unit 期 **54**（同一批 .tscn 被反复加载）。

**性质**：引擎 **WARNING**，Godot 自动回退到 `path=`，**不影响功能**；GUT 归为 `engine` 类，而 `.gutconfig.json` 已移除 `engine` ⇒ **不计入 Failing**。这正是它长期"挂账不红"的机制。

**归因**：`addons/dialogue_manager/**` 上游 `.tscn` 写死了作者本机的 uid；本项目 import 后为 `.gd` 生成了不同的 `.uid`。**未修**（改第三方 addon 需授权）。

**复现条件**：任何加载 `dialogue_manager` 的 `.tscn` 的路径（import、unit、真窗）。

### 4.2 ObjectDB/RID 泄漏 —— 大部分是导入缓存产物

修复导入后：**18 ObjectDB + 0 RID + 6 resources**（旧记 20601 / 本次 361 主要来自陈旧缓存）。

**复现条件**：测试进程退出时；`WARNING: N ObjectDB instances were leaked at exit`。

残留孤儿（GUT 计数，最终 2；`test_tall_fan_hand_view` 类测试里逐次累计）：

```
9 / 18 / 27 Orphans   * [card_box_gu_inst_1:<Control#...>] + 6
```

即每次重挂手牌泄漏一棵 `card_box_*` Control 子树（1 父 + 6 子）。**未定位到具体代码路径**（`scripts/**` 禁用），已在 §7 列为未验证风险。

### 4.3 `test_slay_gu_final_chapter.gd:149` —— 已修（见 §1.1）

### 4.4 `BattleScreenView._clear locked object` —— 导入缓存级联，非真实回归

**实测报点**（不是 `battle_screen_view.gd`，行号在旧提交后已漂移）：

```
SCRIPT ERROR: Invalid assignment of property or key 'mouse_filter' with value of type 'int' on a base object of type 'Nil'.
   at: GuTallFanHandView._build_card (res://scripts/presentation/widgets/gu_tall_fan_hand_view.gd:338)
   [1] setup (gu_tall_fan_hand_view.gd:193)
```

**链**：`MaShanZheng-Regular.ttf` 未导入 → `gu_style.gd:157` 的 `preload` 编译期失败 → `GuStyle` 整脚本编译失败 → `GuStyle.CARD_UI_FONT` / `apply_seal` / `resource_label` 全部"不存在"（`Invalid access/call` 540 条）→ `_build_face` 中途报错**返回 null** → `btn.mouse_filter` 落在 Nil 上 → 36 个战斗屏/手牌/tooltip 用例断言 `Expected [<null>] to be anything but NULL` 失败。

**修复导入后全部消失** ⇒ **不是 `b82950e1` UI 重构引入的真实回归**。

### 4.5 `tools/check.ps1` 包装层误报 —— 真因是 stdout 不可达

**§28 的归因（"`run_gut_checked.ps1` 的 `SCRIPT ERROR` 扫描会把 unit 判为 FAIL"）在本环境不成立。** 分段探测：

| 探测 | rc | 输出 |
|---|---|---|
| `godot.ps1 -Console` | 0 | **1 行**（解析出的 exe 路径）✅ |
| `godot.ps1 --headless --version` | 0 | **0 行** ❌ |
| `godot.ps1 --headless --path . --quit-after 3` | 0 | **0 行** ❌ |
| `guitkx_build.ps1` | 0 | 0 行 |

⇒ Godot 子进程**确实启动**（rc=0），但其 **stdout/stderr 在本沙箱不被转发**。于是 `run_gut_checked.ps1`：

```powershell
$lines = @(& $CommandPath @CommandArguments 2>&1 | ...)   # → 空
$plain = ...                                              # → ""
if ($plain -match '...SCRIPT ERROR') { exit 1 }           # 不命中
$counts = [regex]::Matches($plain, '(?im)^\s*Tests\s*:?\s*(\d+)\s*$')
if ($counts.Count -eq 0) { exit 1 }                       # ← 真因（:26-27）
```

**⇒ rc=1 来自"看不到任何输出"，不是"看到了 SCRIPT ERROR"。**

**同时确认该扫描仍是第二个独立风险**：修复导入后 unit 仍残留 **1 条** SCRIPT ERROR（即 4.3），足以让扫描判 rc=1。我的 §1.1 修复把它清零（`1 → 0`），因此在**输出可被捕获的环境**（正常 dev shell / CI）里该扫描也应转绿。

---

## 5. 🔴 最重要的策略发现：失败被"静默降级"

```
GUT 默认 failure_error_types = ["engine", "gut", "push_error"]
项目 .gutconfig.json       = ["gut", "push_error"]      ← 移除了 "engine"
```

GUT 的归类（`addons/gut/gut_tracked_error.gd:60-71`）：`SCRIPT ERROR:` 一类的运行期错误 **不是** `push_error`（其 `function` 是脚本函数名）⇒ **归入 `engine` 类**。

**后果**：导入缓存陈旧时，36 个用例真实失败 + 572 条 SCRIPT ERROR，而 **GUT 汇总仍报 `Failing 0`**（因为失败源于 `engine` 类错误而非断言）。

> 这解释了用户给的基线"unit 1441/1441 通过"与"36 个失败"**同时为真**：断言层面确实全过，但 36 个用例其实被运行期错误截断了。

**`engine` 的移除原本是为了绕开 addon 的 invalid UID 警告**（合法目的），但代价是**把"编译失败 / 方法不存在 / 空引用赋值"这类硬错误一并降级为不可见**。

⇒ 建议（**需裁定，我未改**）：改用 `-gfailure_error_types` 白名单或 `assert_no_new_errors` 计数阈值，把 `push_warning`（UID）与 `SCRIPT ERROR`（硬错误）分开对待。

---

## 6. 是否需要 Luna 新裁定 —— 是，4 项

| # | 议题 | 为什么需要裁定 |
|---|---|---|
| ① | `run_gut_checked.ps1:24` 全局 `SCRIPT ERROR` 扫描的语义：任意 1 条非致命错误即 rc=1 是否合适？ | 这是**交付门策略**，改它就是改门 |
| ② | `addons/dialogue_manager/**` 18 处 UID 对齐：改第三方文件是否授权？改 uid 还是删 `uid=` 属性？ | 触碰 vendor addon；且两种改法升级 addon 时都需重做 |
| ③ | 🔴 `.gutconfig.json` 是否恢复 `engine` 到 `failure_error_types`（或改为只忽略 `push_warning`）？ | **本次最重要**：当前配置会把编译/运行期硬错误静默成"Failing 0" |
| ④ | `project.godot:53` 的跨 worktree POT 引用（`.claude/worktrees/...`）是否清理？ | `project.godot` 是 Shared 单写者文件；`.claude/` 不入库 ⇒ 干净 clone 缺文件 |

---

## 7. 未验证风险

1. **包装层端到端未验证**：我改了 `tools/test.ps1`，但本环境无法取得包装层的真实判定（stdout 不可达）。已验证的只有：PowerShell 语法 0 错误、分段组件各自 rc=0、直连 Godot 全绿。**`--import` 前置在正常环境的行为（耗时、干净 clone 下的全量导入、CI 可用性）未验证。**
2. **包装层在非沙箱环境是否真能工作**：无法在本环境确证。若正常环境也存在"输出不可达"，则 §3.2 的 rc=1 是普遍现象而非沙箱特例。
3. **`card_box_gu_inst_1` 孤儿泄漏**：`+6` 子树逐次累计，未定位代码路径（`scripts/**` 禁用）。
4. **18 处 UID 不一致中仅 13 处运行时可观测**：静态 18 vs import 期 13 的差集未逐条对齐（另外 5 处对应的 `.tscn` 未被加载）。
5. **未运行** `tools/verify_interaction_loop.gd`（交互门）——不在本任务清单内，故未采信其状态。
6. **`ObjectDB 18 / resources 6`**：已量化但未归因到具体对象类型（需 `--verbose`，输出量过大）。

---

## 8. 交付物与仓库状态

| 文件 | 性质 |
|---|---|
| `docs/q8g/Q8G_VERIFICATION_DEBT_AUDIT.md` | 本报告（新增） |
| `tests/unit/test_slay_gu_final_chapter.gd` | **修改**（测试断言，+19/−4） |
| `tools/test.ps1` | **修改**（`--import` 前置，+15） |

- **未触碰** `scripts/domain/**`、`data/**`、`RunState`/save/event、正式 pity/E6/pacing/battle/promotion。
- **未触碰其他 agent 的未提交改动**：`docs/q8g/Q8G_HANDOFF_CURRENT.md`、`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md`、`export_presets.cfg`、`scripts/presentation/widgets/gu_card_view.gd`，以及未跟踪的 `docs/q8g/AGENT{1,3}_*.md`、`tools/q8g_agent1_*.mjs`、`.codex/`、`assets/wenzhen/enemies/enemy_thunder_crown_*.png`。
- **未提交**（未获提交指令）。
- **未使用** `git reset --hard` / 强制检出 / 递归删除。

---

**记录时间**：2026-09-14
**状态**：5 项遗留全部归因；2 项已修；4 项待裁定；包装层判定在本环境不可得（需在非沙箱环境复验）。
