# Release Hygiene Preflight（inbox §36 六项，2026-09-14）

**执行者**：Agent3（worker）。**性质**：delivery/export hygiene，**不改生产代码**。
**基线 HEAD**：`96d79f2d`（`git rev-list --count origin/master..HEAD` = 0，已推送）。
**禁止项遵守**：未改 `scripts/domain/**`、`data/**`、RunState、loot/pity/E6/pacing/battle、`project.godot`、
未删除任何 debug panel 生产引用、未安装 Android SDK/模板。

---

## 0. 一句话结论

四项发布卫生裁定（`/Godot/` · `lore_*` · `ui/*.guitkx` · `ui/_sample.*`）**已施工、已落 HEAD、并在最终 HEAD 上实测闭环**：
新 Release 可导出、可启动、包内零残留、载荷完整、`load()` 全成功、12 项阴性对照全 NULL。
**Debug 编译期裁剪**按裁定只做设计与量化预审——实证出「2 个叶子文件可纯过滤器裁剪」，
另 3 个是**已入包文件的编译期依赖**，**必须改 Shared 代码才能裁**，故登记待裁定。

### 0.1 git 状态（2026-09-15 复核，**更正 inbox §38 的两处事实错误**）

| 事项 | inbox §38 的表述 | **实测** | 证据 |
|---|---|---|---|
| HEAD | `96d79f2d` | **`bccc3983`** | `git rev-parse HEAD`；`git log --oneline -1` |
| `bccc3983` 是否在历史 | 「不在当前提交历史」 | **在，且就是 HEAD** | `git merge-base --is-ancestor bccc3983 master` → **退出码 0** |
| `export_presets.cfg` 卫生修改是否已应用 | 「尚未应用」 | **已应用且已在 HEAD** | `git diff HEAD -- export_presets.cfg` = **0 行**；worktree md5 **=** `git show HEAD:export_presets.cfg` md5 = `e07a9bcd70c5f303b6ae9279cf54c639` |
| `origin/master` | `96d79f2d` | ✔ 一致 | `git ls-remote origin master` |
| 是否已推送 | 「未推送」 | ✔ **成立**（本地领先 1） | `git rev-list --count origin/master..HEAD` = 1 |

**⇨ 唯一成立的差异是「未推送」**；「不在历史 / 未应用」两条不成立。

### 0.2 🔴 为什么会被误判为「不在历史」——可复现的陷阱

本仓有 **11 个历史坏对象**（`a3a153d2` 等，六次 `.git` 损坏的遗留）。凡是要 walk **全部 ref** 的命令都会撞上它们：

```bash
$ git branch --contains bccc3983
error: Could not read a3a153d211784d1a0f8042989e5daf4ea4a2cac9
error: could not parse commit a3a153d211784d1a0f8042989e5daf4ea4a2cac9
* master                      ← 其实 master 就在这一行，但上面的 error 极易被读成「找不到该提交」
```

**正确判据（本仓必须用这两个）**：

```bash
git merge-base --is-ancestor <sha> master     # 退出码 0 = 在历史里
git log master --oneline | grep <sha>         # 单分支 walk 不受坏对象影响
```

**禁用** `git branch --contains` / `git log --all` / 任何跨全 ref 的 walk —— 它们在本仓会**报错而非返回结果**，
「命令报错」≠「对象不存在」。

---

## 1. 依赖审计（§36 第 1 项）

> 裁定要求：**不得用一次包列表猜测运行时依赖**。以下每一条都是静态引用闭合 + 正向证据。

### 1.1 逐类引用闭合

| 目标 | 包内条目 | 全部引用者 | 归类 | 判定 |
|---|---|---|---|---|
| `ui/_sample.guitkx` | 4 | `scripts/acceptance_driver.gd`（**已排除**）、`scripts/guitkx_build.gd`（**已排除**） | 编辑器/验收链 | **非运行期** |
| `ui/widgets/*.guitkx`（15） | 15 | 同上 | 编辑器/验收链 | **非运行期** |
| `ui/**/*.guitkx.diags.json`（16） | 16 | `addons/reactive_ui_toolkit_editor/**` LSP 诊断渲染器（**已排除**） | 编辑器 LSP | **非运行期** |
| `lore_engine/` | 4 | 仅 `tools/lore.ps1`（**已排除**） | 离线 Python 工具 | **非运行期** |
| `lore_sources/` | 1 | 仅 `tools/lore.ps1` | 离线语料 | **非运行期** |
| `Godot/` | 4（含 1 条探针自身） | **零代码引用**；`.gitignore:45` `/Godot/` | 本机 editor + `user://` 数据 | **非运行期** |

### 1.2 正向证据（比「找不到引用」更强）

1. **`RunScreenRouter.SCREEN_PATHS := {}`**（`scripts/presentation/run_screen_router.gd:14`），注释自述：
   > 「RUITK 屏已全部迁离：本表留空是「RUITK 屏必须为零」的锚点——非空即代表有屏回退到 `.guitkx`」
2. **`MASTER_SCENE_PATHS` 13 屏全部指向 `res://scenes/ui/screens/*.tscn`**（`run_screen_router.gd:15-31`）。
3. **`scenes/**` 的 31 个 script `ext_resource` 全部指向 `res://scripts/presentation/**`**——对 `res://ui/**` **零引用**。
4. **全仓 `.tscn` / `.tres` 对 `res://ui/**` 零引用**（任何形式）。
5. `ui/widgets/*.guitkx` 的编译产物 `ui/widgets/*.gd`（**同目录、`.gitignore:9` `ui/**/*.gd` 忽略**）**无运行期文件读取**——
   唯一含 `guitkx` 字样的行是 `## AUTO-GENERATED from gu_card.guitkx -- do not edit.` 注释。
6. `project.godot` autoload 仅 **`DialogueManager` + `AudioManager`**，**无 HMR / watcher**（RUITK 运行期轮询不存在）。
7. `class_name` 命名空间**不相交**：生成侧 `GuCard/GuPanel/...`，正式侧 `GuCardView/GuPanelView/...`
   ⇒ 排除生成侧不会造成全局类冲突。
8. `ui/widgets/` 下**无任何 `.tscn`**——正式场景在 `scenes/ui/widgets/`，两套树物理隔离。

**结论**：`.guitkx` / `lore_*` / `Godot/` 均为**非运行时依赖**，批准排除成立。

### 1.3 脚本化静态审计（`build/static_dep_audit.py`，可复跑）

手工 grep 容易得出错结论，因此固化成脚本：以 `export_presets.cfg` preset.0 的 `exclude_filter` 为
**唯一真值来源**（不手抄），取「保留集 = 未被排除的文件」，逐目标判定。

**脚本自身踩过的两个口径错误（保留在注释里，避免再犯）**：

1. **v1** 把 `export_presets.cfg`（**过滤器定义自身**）与 `addons/reactive_ui_toolkit/**`
   （**`.guitkx` 语言的实现方**：编译器 / 编辑器插件）算成「引用者」⇒ 全假阳性。
2. **v2** 用裸 `\.guitkx` 匹配 ⇒ 把**注释**算成依赖。实测 32 个保留文件命中，**逐条查证全是注释文案**，
   例：`battle_screen_view.gd:4`「替代 ui/screens/battle_screen.guitkx」。

**v3 判据**——只有三类算运行时依赖：① 路径字面量 `res://…<target>`；② `load(`/`preload(`/`ResourceLoader.*(` 实参含 target；
③ `FileAccess.*(` 实参含 target。裸词只作 INFO。

```text
$ python build/static_dep_audit.py
exclude_filter 模式数 = 43 | 保留集文件数 = 322

PASS  ui/_sample.guitkx        RETAINED 运行时依赖=0   仅提及(注释/文案)=0
PASS  ui/widgets/*.guitkx      RETAINED 运行时依赖=0   仅提及(注释/文案)=32
PASS  lore_engine/             RETAINED 运行时依赖=0   仅提及(注释/文案)=0
PASS  lore_sources/            RETAINED 运行时依赖=0   仅提及(注释/文案)=0
PASS  Godot/ editor-userdata   RETAINED 运行时依赖=0   仅提及(注释/文案)=0
PASS  res://ui/ 整棵树          RETAINED 运行时依赖=0   仅提及(注释/文案)=4
AUDIT_PASS   (exit 0)
```

仅有的 2 处真实 `.guitkx` 引用都在**已排除**的文件里：`acceptance_driver.gd:42` 的路径字面量
与 `acceptance_driver.gd:26` / `guitkx_build.gd:5` 的 `preload(...guitkx...)`。

---

## 2. `export_presets.cfg` 排除修复（§36 第 2 项）

两个 preset（Windows Desktop / Android）的 `exclude_filter` **行尾追加同一组模式**，未改动任何既有条目：

```text
Godot/*, Godot/**, lore_engine/*, lore_sources/*, ui/*.guitkx, ui/**/*.guitkx,
ui/*.guitkx.diags.json, ui/**/*.guitkx.diags.json, ui/_sample.*
```

**diff = 2 行（±2）**，不涉及其它字段。`Godot/**` 与 `ui/**/...` 为显式冗余（Godot 的
`String::matchn` 中 `*` 已跨 `/`），保留是为了让规则**按裁定原文可读**。

**未做**（未获批）：`ui/**/*.gd`（编译产物残留，见 §7-①）。

---

## 3. Debug 编译期裁剪设计（§36 第 3 项，只设计 + 量化预审）

### 3.1 依赖闭合（这是决定方案的关键）

```text
run_controller.gd:404-462        → RunDebugFacade.*        静态类引用（12 处）      ← 已入包文件
run_debug_facade.gd:18           → preload(debug_actions.gd) 编译期 preload        ← 待裁对象
run_debug_facade.gd:19,20        → preload(run_snapshot_builder.gd, resource_vocabulary.gd)（均为正式文件，保留）
run_debug_facade.gd:259          → load(DEBUG_PANEL_PATH)   运行期字符串 load（门控之后）  ← 可裁
run_snapshot_builder.gd:52       → DebugSnapshot.build()   静态类引用                ← 已入包文件
scenes/ui/widgets/debug_panel.tscn:3 → ext_resource debug_panel_view.gd            ← 可裁
acceptance_driver.gd / tests     → 均已在 exclude_filter 中（不影响）
```

### 3.2 结论：必须分两层，且第二层**不能靠过滤器**

| 文件 | 是否可纯过滤器裁剪 | 原因 |
|---|---|---|
| `scenes/ui/widgets/debug_panel.tscn` | ✅ **可以** | 唯一运行期引用是 `run_debug_facade.gd:259` 的**字符串 `load()`**，且在 `_debug_enabled()` 之后；Release 下该门为 false |
| `scripts/presentation/widgets/debug_panel_view.gd` | ✅ **可以** | 唯一引用者是上面那个 `.tscn`（叶子） |
| `scripts/presentation/run_debug_facade.gd` | ❌ **不可以** | `run_controller.gd` 有 **12 处静态类引用** `RunDebugFacade.x(self)`；排除后 Release 直接**编译失败** |
| `scripts/domain/debug_actions.gd` | ❌ **不可以** | `run_debug_facade.gd:18` **`preload()`** —— 编译期依赖（且该文件属**冻结区** `scripts/domain/**`） |
| `scripts/presentation/snapshots/debug_snapshot.gd` | ❌ **不可以** | `run_snapshot_builder.gd:52` 静态类引用 `DebugSnapshot.build()`（正式文件） |

### 3.3 Layer 1 —— 已**实测**（measurement-only，已还原）

在 `preset.0` 临时追加 `scenes/ui/widgets/debug_panel.tscn, scripts/presentation/widgets/debug_panel_view.gd`
（**实验后已按 md5 逐字节还原**，见 §5.4）：

```text
--export-pack "Windows Desktop"    rc=0   无致命 ERROR
--export-release "Windows Desktop" rc=0
Release exe 启动（--headless --quit-after 3）  rc=0   ERROR=0  SCRIPT ERROR=0
scratch pck 路径审计：debug_panel.tscn=0  debug_panel_view.gd=0
                      run_debug_facade=5  debug_actions=5  debug_snapshot=5（仍入包，符合预期）
```

⇒ **Layer 1 无需任何代码改动即可裁剪，且 Release 启动零错误**（证明 Release 确实不触达该场景）。

### 3.4 Layer 2 —— 设计（**未实施，需 Shared ownership 裁定**）

最小侵入方案 **D1：单点间接 + 运行期解析**

```gdscript
# run_controller.gd（仅示意；正式实现需单独立项）
static func _debug_facade() -> Object:
    if not OS.is_debug_build():
        return null                                  # Release：不 load
    return load("res://scripts/presentation/run_debug_facade.gd")   # 运行期解析，非静态类引用

# 12 处调用点改为：
#   var f := _debug_facade()
#   if f == null: return <空返回值>
#   return f.call("debug_add_gu", self, gu_id)
```

配套：`run_snapshot_builder.gd:52` 的 `DebugSnapshot.build(controller)` 同样改为运行期 `load()` + 门控。
此后 `run_debug_facade.gd` / `debug_actions.gd` / `debug_snapshot.gd` 才成为可过滤器裁剪的叶子。

**不推荐的替代**：
- **D2 移动文件**（`scripts/debug/**`）：改动面大、触碰 Shared 引用，收益无差别。
- **D3 仅运行时 `is_debug_build` 门控**：§36 已明确**不批准**（节点/脚本仍进包，只是不挂载）。
- **D4 `EditorExportPlugin`**：只解决「怎么排除」，不解决**静态引用**；可作为 D1 的等价交付机制，
  但当前 `exclude_filter` 更简单可审计。**建议不引入。**

**D1 的验收矩阵（供立项时沿用）**

| # | 断言 | 判据 |
|---|---|---|
| T-D1 | 裁剪后导出 | `--export-release` rc=0，无致命 ERROR |
| T-D2 | Release 启动 | exe rc=0，ERROR/SCRIPT ERROR 均 0 |
| T-D3 | 包内零 debug | 5 个路径字符串命中 0；`load()` 全 NULL |
| T-D4 | **Debug 构建不回归** | `--headless` 调试运行下 `debug_panel_mounted()` 为 true；`test_t5d_debug_panel.gd` 通过 |
| T-D5 | 全量回归 | unit + integration + `check_contract_drift` 全绿 |
| T-D6 | 交互门 | 13 屏 `verify_interaction_loop.gd` 通过 |
| 回滚 | 单 commit revert | 不涉存档/`SAVE_VERSION`，无状态迁移 |

**红线**：D1 会改动 `run_controller.gd`（Shared 单写者文件）——**必须先做 Shared ownership 声明**。

---

## 4. 重新导出最终 HEAD 的 Windows Release（§36 第 4 项）

### 4.1 第一次（对应 `96d79f2d` 工作树）

```text
APPDATA=C:\Users\90877\AppData\Roaming        ← 显式设置（§36 环境要求）
--import                                      rc=0  ERROR=0
--export-release "Windows Desktop"            rc=0  无致命 ERROR   约 21 s
产物  build/verify-hygiene-96d79f2d/gu-zhenren.exe   190,503,688 B
对照  旧 build/verify-2748ef82/gu-zhenren.exe        190,567,104 B   ⇒ −63,416 B
启动  rc=0，仅 2 行 banner，ERROR=0 / SCRIPT ERROR=0 / WARNING=0
```

### 4.2 第二次（**最终 HEAD `bccc3983`**，2026-09-15 复核）

```text
build/verify-hygiene-bccc3983/gu-zhenren.exe   190,503,688 B
build/verify-hygiene-bccc3983/verify.pck        81,359,100 B
--import rc=0 · --export-release rc=0（无致命 ERROR）· --export-pack rc=0
启动 rc=0，仅 2 行 banner，ERROR=0 / SCRIPT ERROR=0 / WARNING=0
```

### 4.3 两次导出的可复现性

```text
exe 大小        190,503,688  ==  190,503,688     ✅ 一致
pck 大小         81,359,100  ==   81,359,100     ✅ 一致
包清单（691 行）  逐条 diff 为空                   ✅ 完全一致
pck 字节 md5     5f5b8c35…   !=   6f09f4ec…      ⚠️ 不一致
```

⇒ **包内容与包大小可复现；pck 字节流不可（含导出器元数据/压缩差异）。**
**报告包内容时用「清单 + 大小」，不要拿 pck md5 当同一性判据。**

启动零错误同时证明：内嵌 PCK 可读、主场景 + 两个 autoload + `GuStyle` 字体 `preload` 均正常。

---

## 5. 用 Godot loader 验证包内资源（§36 第 5 项）

探针 `build/pckprobe/probe.gd`（**不入库**，`build/` 已 gitignore）。包内交叉验证：

```text
内嵌 PCK（exe） FILE_COUNT=691   ←→   独立 pck（--export-pack） FILE_COUNT=691   完全一致
```

### 5.1 断言结果

```text
SHOULD_PRESENT                18 / 18 命中          missing=0
SHOULD_ABSENT(前缀/精确)      违规 0
SHOULD_ABSENT(后缀 .guitkx 家族)  违规 0
SHOULD_ABSENT(*.md)          违规 0
INFO  *.import = 168（Godot 4 必需项，1:1 对应 .godot/imported 载荷）
从包内 load()                 失败 0
阴性对照（12 项，必须 NULL）    违规 0
```

### 5.2 从包内实际 `load()`（真实尺寸，非「路径存在」）

| 资源 | 类型 | 证据 |
|---|---|---|
| `assets/wenzhen/gu/gu_force.png` | CompressedTexture2D | **1254×1254** |
| `assets/wenzhen/gu/gu_sword.png` | CompressedTexture2D | 1254×1254 |
| `assets/wenzhen/gu/gu_light.png` | CompressedTexture2D | 1024×1024 |
| `assets/wenzhen/gu/gu_blood.png` | CompressedTexture2D | 1024×1024 |
| `MaShanZheng-Regular.ttf` / `LXGWZhiSongCL-Regular.ttf` | FontFile | ✅ |
| `scenes/main.tscn` / `scenes/ui/screens/battle_screen.tscn` | PackedScene | ✅ |
| `data/gu.json` / `data/nodes.json` | JSON | ✅ |

### 5.3 阴性对照（12 项，全部 NULL）

```text
tests/unit/test_map_generator.gd · tools/check.ps1 · docs/q8g/Q8G_HANDOFF_CURRENT.md
scripts/guitkx_build.gd · scripts/acceptance_driver.gd
ui/_sample.guitkx · ui/_sample.gd · ui/widgets/gu_card.guitkx          ← 本轮新裁
lore_engine/config/default.json · lore_engine/tests/fixtures/model/valid_extraction.json
lore_sources/manifest.json · Godot/editor_settings-4.7.tres            ← 本轮新裁
```

### 5.4 两次自我更正的判据（避免误报/漏报）

1. **`FILE_COUNT` 是环境敏感的，不能跨会话比较。** 上一轮记录的 937/894 包含了
   `res://.godot/**` 204 条与探针自身 `res://Godot/app_userdata/pckprobe/**`——那是**探针环境**产物
   （未导出工程的 `res://` = 自身磁盘目录 ∪ 包），**不是包内容差异**。
   本轮统一探针+统一环境后：**旧 exe 730 → 新 exe 691，移除 39 / 新增 0**。
2. **不可依赖 `DirAccess` 列举来判定缺失。** 但直读 pck **必须用正确的 needle 形态** —— 这里我上一版写错过，更正如下：

   🔴 **PCK 文件表不带 `res://` 前缀**。证据：同一份包 `project.binary` 命中 **1**，而 `res://project.binary` 命中 **0**；
   带前缀的命中**全部来自文件内容**（`.import` 的 `dest_files`、`.remap` 的 `path=`、脚本源码字符串）。
   ⇒ 要判「文件表里有没有」，必须写**去前缀**形态。（点号保留：`.godot/imported/` 与 `godot/imported/` 计数相同。）

   **正确 needle 的真值表**：

   | needle（去前缀） | 新 pck（HEAD `bccc3983`） | 旧 pck（修复前） |
   |---|---|---|
   | `tools/` | **0** | 1 |
   | `lore_engine/` | **0** | 4 |
   | `lore_sources/` | **0** | 1 |
   | `Godot/editor_settings` | **0** | 2 |
   | `Godot/app_userdata/` | **0** | 2 |
   | `ui/_sample.guitkx` | **0** | 3 |
   | `.guitkx.diags.json` | **0** | 16 |
   | `ui/widgets/gu_card.guitkx` | **0** | 3 |
   | canary `project.binary` | 1 | 1 |
   | canary `run_screen_router.gd` | 5 | 5 |
   | canary `gu_card_view.gd` | 6 | 6 |
   | canary `MaShanZheng-Regular.ttf` | 4 | 4 |
   | `.godot/imported/` | 336 | 336 |
   | `.godot/exported/` | 66 | 68 |

   ⇒ **排除项目全部归零、canary 全部非零、载荷完整。**
   （顺带澄清：旧包里 2 处 `分支：六卷精编版/` 命中来自 **`lore_engine/config/default.json` 自身的内容**
   （`"path": "分支：六卷精编版/蛊真人-clean.txt"`），不是泄漏到包里的独立文件。）

   ⚠️ **两种字符串解码在 PCK 上都不可用**（这曾导致一个「假 PASS」的审计工具，见 §6.1）：
   `get_string_from_utf8()` 在首个非法 UTF-8 续字节处截断（实测 **offset 34** → 34 字符）；
   `get_string_from_ascii()` 在首个 **NUL** 字节处截断（实测 → **5 字符**）。
   **只能用 `PackedByteArray` 原语做字节级检索。**

3. **实验用预设变更已逐字节还原**：`md5 = e07a9bcd70c5f303b6ae9279cf54c639`（还原前后一致），
   `git diff export_presets.cfg` 恰为 **2 行（±2）**，`grep -c debug_panel export_presets.cfg = 0`。

---

## 6. PCK 文件清单与阴性断言（§36 第 6 项）

```text
build/verify-hygiene-96d79f2d/pack_list.txt       691 条（内嵌 PCK）
build/verify-hygiene-96d79f2d/pack_list_pck.txt   691 条（独立 pck，逐条一致）
build/verify-hygiene-96d79f2d/verify.pck          81,359,100 B
```

顶层分布（前 10）：`scripts/presentation/` 128 · `scripts/domain/` 122 · `assets/wenzhen/` 114 ·
`addons/reactive_ui_toolkit/` 105 · `addons/dialogue_manager/` 69 · `assets/audio/` 41 ·
**`ui/widgets/` 30**（见 §7-①）· `scenes/ui/` 27 · `assets/icon/` 11 · `assets/theme/` 7

**同环境差集（旧 730 → 新 691）= 移除 39 / 新增 0**：

```text
34  ui/          16 .guitkx + 16 .guitkx.diags.json + ui/_sample.gd.remap + ui/_sample.gdc
 4  lore_engine/ config/default.json · schemas/extraction-v1.json · tests/fixtures/model/{valid,invalid}_extraction.json
 1  lore_sources/ manifest.json
```

与批准的排除模式**精确对应**，**无附带损失**。

### 6.1 🔴 `tools/agent3_pck_audit.gd` 曾是「假 PASS」——已修复并验证

**我上一版在这里写错了**（原文称「两份不同实现给出同一结论」）。实测该工具**什么都没扫**：

```gdscript
var text := bytes.get_string_from_utf8()   # ← 病灶
var n := text.count(needle)
```

PCK 头部本身就是二进制，`get_string_from_utf8()` 在 **byte offset 34** 遇到非法 UTF-8 续字节即截断：

```text
总字节 81,359,100 → 解码后字符串只有 34 字符（0.00%）
run_debug_facade  全文件=5   截断后=0
debug_panel       全文件=9   截断后=0
```

⇒ 所有 `HIT … = 0` 都是**空转的 0**，`AUDIT_PASS` 恒成立。这属于本项目反复出现的那类缺陷
（`gutconfig.json` 移除 `engine` 让 SCRIPT ERROR 不可见；`test_five_layer_map_contract` 只断言 `reachable == is_start` 而镜像同一 flag）——
**「通过了」与「检查过了」不是一回事**。

**修复（本次改动，仅 `tools/agent3_pck_audit.gd`）**：

1. 改字节级检索（`find(int)` 定位首字节 → 末字节预筛 → 逐字节校验）；
   附注：`PackedByteArray.find(PackedByteArray)` 在 4.7 **只接受 int**；`get_string_from_ascii()` 同样会截断。
2. **加反空转 canary 自检**：`CANARIES = [project.binary, run_screen_router.gd, gu_card_view.gd, MaShanZheng-Regular.ttf]`，
   任一为 0 即 `AUDIT_FAIL` —— 扫描器坏了必须 FAIL，不能再 PASS。
3. needle 改为**去 `res://` 前缀**的文件表形态（见 §5.4-2），并补入 `Godot/editor_settings`、`Godot/app_userdata/`、
   `ui/widgets/gu_card.guitkx`、`guitkx.diags.json`。

**修复后（新包）**：

```text
SCAN_BYTES=81359100
CANARY project.binary = 1   run_screen_router.gd = 5   gu_card_view.gd = 6   MaShanZheng-Regular.ttf = 4
FORBIDDEN 全部 = 0
OBS_debug_panel=9  OBS_run_debug_facade=5  OBS_debug_actions=5  OBS_debug_snapshot=5  OBS_claude_pot=1
AUDIT_PASS   (rc=0，3.1 s)
```

**反向对照（修复前的旧包）——证明该 PASS 不是空转**：

```text
AUDIT_FAIL   (rc=1)
VIOLATION tools/ x1 · lore_engine/ x4 · lore_sources/ x1 · 分支：六卷精编版/ x2
        · Godot/editor_settings x2 · Godot/app_userdata/ x2
        · ui/_sample.guitkx x3 · guitkx.diags.json x16 · ui/widgets/gu_card.guitkx x3
```

⇒ 工具现在**有判别力**：坏包 FAIL、好包 PASS，且 canary 计数与我的独立 Python 真值逐一吻合。

---

## 7. 开放项（需裁定，未自行扩展）

### ① `ui/widgets/*.gd` 编译产物残留 **30 条**（15 `.gd.remap` + 15 `.gdc`）

`gitignore:9` 已忽略 `ui/**/*.gd` ⇒ 这是**只在开发者本机存在的生成物**，进包纯属 `all_resources` 兜进来的死重。
运行期无引用（§1.2 第 5 条）。
**拟定模式**：`ui/**/*.gd`（`ui/_sample.*` 已覆盖 `_sample.gd`）。
**为何没做**：§36 只批了 `ui/*.guitkx` / `ui/**/*.guitkx` / `ui/_sample.*` / `ui/**/*.guitkx.diags.json`，`*.gd` 不在其中。

### ② Debug Layer 2（D1 代码间接方案）——`run_controller.gd` 属 Shared 单写者文件，需先声明

### ③ `scripts/domain/debug_actions.gd` 属冻结区

若按 D1 裁掉 facade，它随之成为可裁剪叶子。但它是 `scripts/domain/**`（冻结点名范围）。
**两种读法需你选**：(a) 冻结的是**代码内容**，只加 export 过滤条目不算改冻结区；
(b) 冻结含「该路径下的文件不进/出包」⇒ 需显式放行。

### ④ 过程风险：包 = 工作树，不是纯 HEAD

当前工作树含**他人未跟踪**素材 `assets/wenzhen/enemies/enemy_thunder_crown_{wolf,sovereign}.png`
（mtime 09-13 05:01，**两版包内均有 17 处命中**）与 `.codex/`（已被排除）。
⇒ **「基于某 HEAD 的 Release」实际包含未提交内容**。建议在发布批次里加一条
「导出前 `git status --porcelain --untracked-files=all` 快照 + 记录到包清单旁」。

### ⑤ 已闭合（供状态更新）

- **根目录零散截图**：仓库根已无任何 `*.png/*.jpg`（`git ls-files | grep -v /` 与 untracked 均为空）⇒ **无对象**。
- **`build/` 是否进包**：实测 `grep -c "^res://build/" pack_list.txt` = **0** ⇒ 导出产物目录不会递归进包。
- **`Godot/` 磁盘残留**：仓库内 `Godot/` 仍在（6 个文件，gitignored）。它会在**任何不带 `APPDATA` 的 Godot 调用**后重建；
  现已**同时**被 gitignore 与 export 过滤覆盖，不再影响发布。

### ⑥ 过程观察：并发写入者提交了本次修复

本轮运行期间，工作区出现并随后被**他人提交**的文件（提交 `bccc3983`，23:05:57）：

```text
docs/q8g/AGENT3_UI_RELEASE_REPORT.md      +76
docs/q8g/Q8G_DEBUG_COMPILE_PRUNE_PLAN.md  新增 171 行
tools/agent3_pck_audit.gd                 新增 76 行
export_presets.cfg                        正是本报告 §2 的 2 行改动
```

⇒ **§2 的排除修复已随该提交进入 HEAD**（`bccc3983`，本地领先 origin 1 个提交）。
该提交的 PCK 字节扫描结论（`tests/tools/docs/lore/Godot = 0`）与本报告 §5.4 的直读结果**互相独立印证**。

**但存在重复交付**：`Q8G_DEBUG_COMPILE_PRUNE_PLAN.md` 与 `tools/agent3_pck_audit.gd` 分别与本报告的
**§3（Debug 裁剪设计）**、**§5/§6（PCK 审计）**主题重叠。我**未读取、未修改、未合并**它们（**唯一例外**：⑨ 中修复了该工具的假 PASS 缺陷）。
**请裁定该子项的唯一权威交付**，否则会出现两份口径不同的 debug-pruning 设计。

### ⑦ 启动残留（我自己产生，在 gitignored `build/` 内）

`--quit-after 3` 启动 exe 时未设 `APPDATA`（为隔离真实存档），导出程序把 `user://` 落在
`build/verify-hygiene-96d79f2d/Godot/app_userdata/蛊真人/logs/godot.log`。
位置在 `build/` 内、已 gitignore，**不影响仓库与包**；如需彻底避免，启动时也应设 `APPDATA`。

### ⑧ 新残留：`.godot/` 编辑器缓存进包（INFO，**不建议**在无证据下排除）

字节级实测：`.godot/global_script_class_cache.cfg` 与 `.godot/uid_cache.bin` **两版包内均存在**（各 1 处）。

- `global_script_class_cache.cfg` 是全局类名→脚本路径映射；**Godot 导出可能有意包含它**（运行期类名解析）。
- `uid_cache.bin` 是编辑器 uid 缓存，属编辑器侧元数据。
- 两者都可能列到已排除脚本的路径（陈旧引用），但**我不主张排除**——没有证据表明运行期不需要它们，
  且排除它们的收益（几 KB）远低于「导出后启动即崩」的风险。
- **建议**：如需处理，先单独做一次「排除 + 导出 + 启动 + 交互门」实验，不要顺手加进 `exclude_filter`。

### ⑨ 并发写入者的审计工具：已修复（不再是重复交付）

`tools/agent3_pck_audit.gd` 与我的 `build/pckprobe/probe.gd` 曾主题重叠且**前者是假 PASS**（§6.1）。
本次我只**修复**该工具（字节级检索 + canary 自检 + 正确 needle），**没有**再提交第二份工具。
两者的分工现在是清晰的：

```text
tools/agent3_pck_audit.gd   → PCK 文件表级「不该进的有没有进」（字节级、可判别、带反空转自检）
build/pckprobe/probe.gd     → Godot loader 级「该有的在不在、能不能 load」（load_resource_pack + load()，不入库）
```

---

## 8. 验证命令与退出码

| 命令 | rc | 结果 |
|---|---|---|
| `--import` | **0** | ERROR=0 |
| `--export-release "Windows Desktop"`（批准过滤器） | **0** | 无致命 ERROR；190,503,688 B |
| `--export-pack "Windows Desktop"` | **0** | 81,359,100 B |
| `./gu-zhenren.exe --headless --quit-after 3` | **0** | ERROR=0 / SCRIPT ERROR=0 / WARNING=0 |
| 探针（内嵌 PCK） | **0** | 691 文件；断言 0 违规；LOAD 失败 0；阴性对照 0 违规 |
| 探针（独立 pck） | **0** | 与内嵌包逐条一致 |
| 实验：裁剪配置 `--export-pack` ×2 | **0 / 0** | ERROR=0 / 0；两个叶子路径命中 0 |
| 实验：裁剪配置 `--export-release` + 启动 | **0** | 启动 ERROR=0 / SCRIPT ERROR=0 |
| **最终 HEAD `bccc3983`：`--import` / `--export-release` / `--export-pack`** | **0 / 0 / 0** | exe 190,503,688 B；pck 81,359,100 B；无致命 ERROR |
| **最终 HEAD 启动 exe** | **0** | ERROR=0 / SCRIPT ERROR=0 / WARNING=0 |
| **静态依赖审计** `python build/static_dep_audit.py` | **0** | `AUDIT_PASS`；6 目标 RETAINED 运行时依赖全 0 |
| **PCK 文件表审计** `tools/agent3_pck_audit.gd`（新包） | **0** | `AUDIT_PASS`；4 canary 非 0；20 项 FORBIDDEN 全 0（3.1 s） |
| ↳ 反向对照：同一工具跑**修复前旧包** | **1** | `AUDIT_FAIL`，9 项违规（证明 PASS 非空转） |
| 回归：unit / integration / contract drift / `git diff --check` | 见 §8.1 | — |

### 8.1 回归结果（最终 HEAD，直连 Godot）

```text
unit             rc=0   1445/1445   Asserts 47771   Orphans 2   219.6 s   SCRIPT ERROR 0
integration      rc=0     32/32     Asserts  1476               72.6 s   SCRIPT ERROR 0
contract drift   rc=0   ok (168 identifiers resolved)
git diff --check rc=0
```

与上一轮 VDA 基线（同为 1445/1445、32/32、SCRIPT ERROR 0）**完全一致**，无回归。
（`git diff --check` 对 `docs/q8g/Q8G_HANDOFF_CURRENT.md` 报 CRLF 警告，属**他人**未提交文件的换行风格，非本次产物。）

---

## 9. 未验证风险

1. **只做了 `--headless` 启动**：真窗渲染与手感未验（贴图「可从包内 `load()`」≠「真窗战斗屏渲染正确」）。
2. **`ui/widgets/*.gd` 残留**（§7-①）未处理，待裁定。
3. **Debug Layer 2 未实施**：本轮只给出设计与 Layer 1 实测；包内仍有 5 个 debug 路径。
4. **包≠纯 HEAD**（§7-④）。
5. **一处一次性 export 噪声**：裁剪配置首跑日志出现 1 条
   `ERROR: The object does not have any 'meta' values with the key 'DialogueManagerPlugin'.`
   —— 来自 `addons/dialogue_manager` 的 export plugin。**随后 3 次导出（2 次裁剪配置 + 1 次批准配置）均 0 ERROR**，
   且该 exe 启动 0 ERROR ⇒ 判为**瞬态、不可复现**，**未定位根因**，登记。
6. **包装层 `test.ps1` / `check.ps1` 在本会话仍不可得真实判定**（Godot 子进程 stdout 不可达，见上一轮 VDA §5），
   故本轮回归全部走**直连 Godot 等价命令**。

---

## 10. 交付物

| 文件 | 性质 |
|---|---|
| `export_presets.cfg` | **修改**（2 行：两个 preset 的 `exclude_filter` 行尾追加批准模式）——**已随 `bccc3983` 提交，现已在 HEAD**（§0.1） |
| `tools/agent3_pck_audit.gd` | **修改**（修复假 PASS：字节级检索 + 4 项 canary 自检 + 去前缀 needle；§6.1） |
| `docs/q8g/Q8G_RELEASE_HYGIENE_PREFLIGHT.md` | 本文件（新增） |
| `build/static_dep_audit.py` | 静态依赖审计脚本（gitignored，可复跑；§1.3） |
| `build/verify-hygiene-bccc3983/{gu-zhenren.exe,verify.pck}` | **最终 HEAD 的 Release**（190,503,688 B / 81,359,100 B） |
| `build/verify-hygiene-bccc3983/pack_list{,_pck}.txt` | 完整包清单 691 条 ×2 |
| `build/verify-hygiene-96d79f2d/*` | 第一次导出（可复现性对照，§4.3） |
| `build/pckprobe/{project.godot,probe.gd}` | loader 级包内容探针（不入库） |
| `build/scratch-*.pck` / `build/scratch-debugprune/` | Debug 裁剪实验产物（不入库） |

**未修改**：`scripts/**`、`data/**`、`project.godot`、`tests/**`、
`docs/q8g/Q8G_DEBUG_COMPILE_PRUNE_PLAN.md`、`docs/q8g/AGENT3_UI_RELEASE_REPORT.md`（他人产物）。
**未推送**（`bccc3983` 位于 `origin/master` 之前 1 个提交）。

---

**记录时间**：2026-09-14（初稿）／2026-09-15（更正 git 状态、needle 形态、审计工具假 PASS；补最终 HEAD 复测）
**状态**：Release Hygiene 四项裁定 **已施工、已入 HEAD、已在最终 HEAD 上验证 PASS**；
Debug 编译期裁剪 **仅设计与 Layer 1 实测**（另案）；
最终 Windows Release Gate 仍 **CONDITIONAL**（§7 开放项未闭合 + 真窗未验 + 未推送）。
