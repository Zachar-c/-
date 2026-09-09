# 技术审计报告 —— 《蛊路求生》

- **审计日期**：2026-09-09
- **审计基线**：`12e3dc1`（master，与 origin 同步）
- **审计范围**：代码质量 / 架构合理性 / 安全性 / 性能 / 依赖管理 / 文档完整性 / 开发流程合规
- **方法**：静态扫描 + 历史取证 + 契约自动比对 + 既有测试基线（unit 1100/1099、integration 31/31）
- **局限**：未做运行时 profiling 与真窗键鼠验收；性能结论基于静态热路径分析，非实测帧率

---

## 0. 执行摘要

| 维度 | 评级 | 结论 |
|---|---|---|
| **安全性** | ✅ A | 零路径遍历、零外部进程/网络、存档原子写 + 校验和 + 版本迁移，全部达标 |
| **架构合理性** | ✅ B+ | 依赖方向零违规、单一数据加载口、单一命令分发点；存在 3 个 god file 未收敛 |
| **文档完整性** | ⚠️ B | 契约 158 个标识符仅 1 项漂移，**守得住**；但 CC BY 署名义务未履行、无 LICENSE |
| **代码质量** | ⚠️ B- | 100 文件 29k 行；4 个文件超 1700 行；2 个核心模块无专属单测 |
| **性能** | ✅ A- | 仅 1 处 `_process`、1 处 `_input`，无每帧解析；但开新局全量重解析内容表 |
| **依赖管理** | ⚠️ C+ | addons/vendor 许可证齐全，但**构建产物入版本库致 .git 460M** |
| **开发流程合规** | ⚠️ C | 并行会话纪律已建立；临时分支未清理、导出配置未隔离开发产物 |

**总体：B。** 安全与架构地基扎实，主要风险集中在**仓库卫生与发布合规**（P0 三条），而非代码逻辑本身。

### 必须立即处置的三条（P0）

1. **构建产物进版本库** —— `.git` 460M，历史含 80M 级 exe 分卷与 APK，每次构建不可逆膨胀
2. **导出配置未隔离开发产物** —— Release PCK 会塞进约 494M 的 build / 预览 / 截图，并**把旧 exe 嵌进新包**
3. **CC BY 3.0 署名义务未履行** —— 53 个 game-icons 图标要求游戏内署名，CREDITS.md 自认"待实现"；项目无 LICENSE

---

## 1. 检查清单

| # | 检查项 | 方法 | 结果 |
|---|---|---|---|
| 1.1 | 域层反向依赖表现层 | `grep presentation scripts/domain/*.gd` | ✅ 0 命中（仅注释） |
| 1.2 | 绕过 catalog 直读 JSON | `grep "res://data/" scripts/` | ⚠️ 2 处（表现层） |
| 1.3 | 非种子随机 | `grep randi/randf scripts/` | ⚠️ 1 处（音效变体） |
| 1.4 | 散落全局可变状态 | 脚本级 `var` 扫描 | ⚠️ app_settings 单例（设计内） |
| 2.1 | 路径遍历 | `FileAccess.*` 全量调用点 | ✅ 全部为常量路径 |
| 2.2 | 外部进程 / 网络 / 系统命令 | `OS.execute` / `HTTPRequest` / `shell_open` | ✅ 0 命中（仅测试读环境变量） |
| 2.3 | 存档原子写与校验 | `save_repository.gd` | ✅ tmp + rename_absolute + SAVE_VERSION 4 + XOR 校验和 + v3 迁移 |
| 3.1 | 每帧回调 | `_process` / `_physics_process` / `_input` | ✅ 1 + 0 + 1 |
| 3.2 | 热路径节点查找 | `get_node` in process | ✅ 24 处，均在 `_ready` 类初始化 |
| 3.3 | 内容表重复加载 | `ContentCatalog` 调用点 | ⚠️ 开新局二次全量加载 |
| 4.1 | 第三方许可证 | addons/vendor LICENSE 文件 | ✅ 5 个齐全 |
| 4.2 | 上游追踪 | CREDITS / audit 文档 | ✅ URL + MIT 已记录 |
| 4.3 | 大文件入版本库 | `git rev-list --objects` 排序 | ❌ 4 个 80M 级构建产物 |
| 5.1 | 契约漂移 | 提取契约标识符与源码比对（158 项） | ⚠️ 1 项真漂移 |
| 5.2 | 测试覆盖 | 大文件 ↔ 专属测试映射 | ⚠️ 2 个核心模块 0 专属单测 |
| 6.1 | 死代码 | 文件名/class_name 引用扫描 | ✅ 域层 0 死代码（2 候选为误报） |
| 6.2 | 分支与工作树卫生 | `git branch` / `git worktree` | ⚠️ 临时分支未清理 |
| 6.3 | 导出隔离 | `export_presets.cfg` exclude 列表 | ❌ 未排除 build/ 等 494M |

---

## 2. P0 —— 严重（立即处置）

### P0-1 构建产物进入版本库，`.git` 已膨胀至 460M

**证据**

```
$ git ls-files build/
build/android/gu-zhenren-signed.apk     80,382,319 B
build/android/gu-zhenren.apk
build/win/gu-zhenren.exe.part1          83,886,080 B
build/win/gu-zhenren.exe.part2          81,931,064 B

$ du -sh .git  →  460M
```

`.gitignore` 主动放行了它们：

```
build/*
!build/win/
!build/android/
build/win/*
!build/win/*.part*        ← 放行分卷 exe
!build/android/*.apk      ← 放行 APK
```

**风险评估**

- **不可逆**：blob 一旦进历史，除非 `filter-branch`/`filter-repo` 重写历史——而本仓库 `.git` 已两次损坏，**重写历史风险极高，不建议**
- **持续恶化**：每次打包都新增约 160M 历史对象
- 克隆/拉取成本线性上升；gitee 免费仓库有容量上限，逼近后需强制清理
- 分卷 exe 无校验，从 git 取出的构建产物无法验证完整性

**改进建议**（按推荐度）

1. **停止跟踪**（推荐）：`git rm --cached build/`，把 `!build/win/*.part*` / `!build/android/*.apk` 两行删掉，产物改由 gitee Release 或本地目录分发。历史存量保留不动，成本可控。
2. 若必须入版本库：**启用 git-lfs**（本机已装 3.7.1，未启用）——`git lfs track "build/**"`。注意 gitee LFS 配额，且已入库 blob 不会自动转 LFS。
3. 无论如何，**先做一次 `git gc --aggressive`** 回收现有松弛对象。

**优先级**：P0，本周内。**这是唯一会随着每次构建持续变坏的问题。**

---

### P0-2 导出配置未隔离开发产物，Release PCK 会被塞进约 494M 垃圾

**证据**

`export_presets.cfg` 当前 exclude：

```
vendor/*, 分支：六卷精编版/*, 肉鸽设计-原始数据/*, docs/*, tests/*,
tools/*, addons/gut/*, addons/reactive_ui_toolkit_editor/*, *.md,
scripts/acceptance_driver.gd, scripts/guitkx_build.gd
```

**未被排除**且位于 `res://` 下：

| 项 | 体积 | 说明 |
|---|---|---|
| `build/` | **425M** | 含 `gu-zhenren.exe` 与两个 APK |
| `.preview/` | 50M | 预览产物 |
| `.superpowers/` | 14M | 工具产物 |
| `*.png`（根目录 12 张） | 5.3M | 开发截图 + `reference_slay_the_spire_battle.png` 参考图 |
| `.workbuddy/` `memory/` | 200K | 会话记忆（含审计记录） |

`build/` 与 `.preview/` 均无 `.gdignore`（全仓库仅 `.godot/.gdignore` 一处），Godot 会照常扫描并打包。

**风险评估**

- 包体从几十 M 膨胀到 500M 量级，分发与启动加载都受影响
- **把旧版 exe 嵌进新 PCK**：可能触发杀毒软件误报、版本混淆
- 开发截图与参考图（含杀戮尖塔参考素材）外泄，且参考图涉及他人美术
- 编辑器每次启动扫描 425M，导入卡顿（这已是现实成本，不只影响发布）

**改进建议**

1. exclude 追加：`build/*, .preview/*, .superpowers/*, .workbuddy/*, memory/*, *.png.import, battle_screenshot*.png, encounter_screenshot*.png, ending_screenshot*.png, map_screenshot*.png, reference_*.png`
2. 更稳的做法：给 `build/`、`.preview/`、`.superpowers/`、`.workbuddy/`、`.claude/` 各放一个空 `.gdignore`，**编辑器与导出双免**
3. 根目录开发截图移入 `docs/screenshots/`（已被 `docs/*` 排除），一劳永逸

**优先级**：P0，本周内。第 2 条是 5 个空文件的事，最高性价比。

**注意**：改完务必复跑 `test_export_presets_exclude_filter` —— 该测试刚刚因同类问题修正过（见 2026-09-09 提交 `4c3dccc`），断言方向已对齐现状。

---

### P0-3 CC BY 3.0 署名义务未履行 + 项目无 LICENSE

**证据**

`CREDITS.md` 自己写明：

> **署名要求**: CC BY 3.0 要求在游戏内「关于」界面署名，光放许可证文件不够。本文件为项目级署名记录，**游戏内署名界面待实现**。

涉及 `assets/wenzhen/icons/game-icons/` 下 **53 个 SVG 图标**（CC BY 3.0）。

另：仓库根目录**无任何 LICENSE / COPYING 文件**（`ls | grep -i license` 为空）。

**风险评估**

- **法律合规**：CC BY 是署名型许可，未在游戏内署名即构成许可违反；Demo 一旦对外分发即产生实际风险
- 项目自身无 LICENSE → 默认"保留所有权利"，与使用了 MIT/GPL 组件（GUT、dialogue_manager 等）的事实状态不一致；`addons/gut` 等 5 个 LICENSE 是**第三方**的，不能替代项目自身许可声明
- 后续若走发行/上架，这是阻塞项

**改进建议**

1. 在设置/标题屏增加"关于"入口，列出：game-icons.net（CC BY 3.0，含作者与链接）、GUT / dialogue_manager / ReactiveUI / GDQuest Open RPG（MIT）及各自 URL
2. 补根目录 `LICENSE`（项目自身许可，需你定：MIT / 专有 / 其他），并在 README 声明
3. 加一条守门断言：扫描 `assets/wenzhen/icons/game-icons/` 非空 ⇒ 关于屏必须含署名文本。把合规变成红灯，而不是靠人记

**优先级**：P0（合规），但实施依赖你定项目许可证 → **先定许可，再落地署名界面**。

---

## 3. P1 —— 高（本迭代内）

### P1-1 God file 未收敛：3 个生产核心文件共 6537 行

| 文件 | 行数 | 占比 |
|---|---|---|
| `scripts/domain/resolver.gd` | 2407 | 域层 18% |
| `scripts/presentation/run_snapshot_builder.gd` | 2372 | 表现层 18% |
| `scripts/presentation/run_controller.gd` | 1758 | 表现层 13% |
| （`scripts/acceptance_driver.gd` 2837 行 —— 测试工具，非生产路径，不计入） |

`resolver.gd` 是主计划已标记的 P1 god file；`run_snapshot_builder` 与 `run_controller` 未见对应拆分工单。

**风险**：改动局部行为时难以判断影响面；并行会话同时编辑大文件冲突概率高（本仓库已有 4 次并行事故）；新人无法定位职责边界。

**建议**

- `run_snapshot_builder` 按屏幕切分（battle / map / rest / shop / refine 各一个 builder），保留一个聚合入口，避免一次大爆炸重构
- `run_controller` 抽出「视图挂载」「命令分发」「存档生命周期」三条独立职责
- 拆分前**先补契约级测试**（见 P1-2），否则等于裸重构

**优先级**：P1。**顺序上必须排在 P1-2 之后。**

---

### P1-2 两个核心模块无专属单元测试

| 模块 | 行数 | 专属 unit 测试 | 间接引用测试数 |
|---|---|---|---|
| `run_snapshot_builder.gd` | 2372 | **0** | 23 |
| `run_controller.gd` | 1758 | **0** | 53 |
| `resolver.gd`（对照） | 2407 | 18 | — |
| `content_catalog.gd`（对照） | 1433 | 4 | — |

integration 有 10 个流程测试（drive_to_ending / long_run_soak / spec_v4_acceptance 等）覆盖主链路，所以**不是无覆盖**，而是：

- 快照**契约**（哪些键必须存在、类型是什么）没有直接断言 → 契约漂移只能靠下游 UI 测试偶然发现
- 拆 god file 时没有安全网

**建议**：先给 `run_snapshot_builder` 补一份**快照契约测试**——按屏幕枚举必备键并断言类型与取值域。这同时也是 P1-1 拆分的前置条件。

**优先级**：P1，且**先于 P1-1 执行**。

---

### P1-3 开新局时内容表全量二次解析

**证据**

```gdscript
# run_controller.gd:154（启动，_initialize_view_flow）
catalog = ContentCatalog.load_all()
_content_errors = ContentCatalog.validate(catalog)

# run_controller.gd:180（start_new_run，每次开新局）
var loaded := ContentCatalog.load_and_validate_all()   # = load_all() + validate()
```

`load_all()` 会解析 `gu.json`（802 蛊）、`refinement_recipes.json`（386 方）、enemies、nodes、pacing、shops 等全表。开新局时这套又完整跑一遍，而启动已跑过一次。

**风险**：开新局有可感知卡顿（量级待实测）；反复开新局（调试/试玩）放大成本。不影响每帧性能。

**建议**

- 最简：启动时加载一次并缓存，`start_new_run` 复用；仅在 `_content_errors` 非空或收到显式 reload 信号时重解析
- 若担心热重载：保留 `load_and_validate_all()` 但加参数 `force_reload := false`

**优先级**：P1（低成本，改一行调用 + 一个缓存字段）。**建议先实测一次开新局耗时再动手**，避免为不存在的问题改代码。

---

## 4. P2 —— 中（排期处理）

### P2-1 表现层绕过 catalog 直读 JSON，且这两份数据**不在校验范围**

`scripts/presentation/display_text.gd`：

```gdscript
:256  JSON.parse_string(FileAccess.get_file_as_string("res://data/names.json"))
:295  FileAccess.open("res://data/gu_names.json", FileAccess.READ)
```

两点问题：

1. **架构违规**：AGENTS 明令"禁止绕过目录直读 JSON"
2. **校验盲区**：`content_catalog.gd` 的加载清单里**没有** `names.json` / `gu_names.json` → 这两个文件的结构错误不会被启动校验捕获，只在运行时炸

缓解因素：有 `static var _names` + `_names_loaded` 缓存，性能无问题。

**建议**：把两个文件纳入 `content_catalog.load_all()` 并加 schema 校验，`display_text` 改从 catalog 取。若因体积/用途不宜入 catalog，至少补一个启动期存在性与结构校验。

**优先级**：P2。

---

### P2-2 `map_generator` 存在绕过 catalog 的 fallback 双路径

```gdscript
# map_generator.gd:24/30 —— 优先 catalog
var data = catalog.get("nodes_data", {}) if not catalog.is_empty() else _load_json("res://data/nodes.json")
# map_generator.gd:41 —— pacing 同样有 override，但空时回落文件
var pacing = pacing_override if not pacing_override.is_empty() else _load_json("res://data/pacing.json")
```

生产路径（第 33 行入口）会传 `catalog.get("pacing", {})`，所以**正常情况下不读文件**。但任何直接调静态函数且不传 catalog 的调用方（工具脚本、新测试）都会静默走未经校验的文件路径——两份数据可能不一致且无人报警。

**建议**：让 fallback 在 `OS.is_debug_build()` 下 `push_warning`，或直接移除 fallback 强制传 catalog。

**优先级**：P2。

---

### P2-3 契约漂移 1 项（整体健康）

自动比对：契约文档 158 个 snake_case 标识符，代码中缺失 3 个，逐一核实后：

| 标识符 | 核实结果 |
|---|---|
| `gu_rot_pact_accept` | ✅ 存在于 `data/dialogues/events.dialogue`，**误报** |
| `test_command_rejections_v2` | ⚠️ 契约提到的测试名，tests 下不存在（低影响） |
| `beastiality_endpoint_check` | ❌ **真漂移**：scripts 与 data 均无 |

**风险**：单点，影响有限，但说明契约没有自动守门——这次是靠人工比对发现的。

**建议**：把这次的比对脚本固化成 `tools/check_contract_drift.gd` 或加进 `tools/check.ps1`，让契约漂移变红灯。顺手确认 `beastiality_endpoint_check` 是废弃项（删契约）还是未实现项（排期）。

**优先级**：P2（守门脚本值得做，单项修复可随手）。

---

### P2-4 分支与工作树卫生

```
$ git branch
  master
  worktree-battle-visual-implementation
  测试，用完就丢        ← 中文名临时分支，自述"用完就丢"
```

- `.worktrees/` 残留（已被 gitignore）
- `.claude/` **未被 gitignore**（`git check-ignore` 未命中）——与 AGENTS 第 8 条"提交时排除 `.claude/`"的意图相悖，属漏网风险

**建议**：清理临时分支（确认无未提交成果后）；`.claude/` 加进 `.gitignore`。

**优先级**：P2。

---

## 5. P3 —— 低（观察/随手）

| # | 发现 | 说明与建议 |
|---|---|---|
| P3-1 | `audio_manager.gd:100` 用 `randi()` | 仅音效变体选择，**不影响玩法确定性**，但字面违反 AGENTS「随机调用统一经种子化模块」。建议改用独立的非玩法 RNG 并加注释说明豁免理由，或在 AGENTS 明确「表现层音效豁免」 |
| P3-2 | `app_settings.gd` 为 autoload 单例，含 `master_volume` / `resolution_index` / `pre_mute_volume` 可变字段 | 属设计内的设置存储，非 Run 状态泄漏。建议补注释明确"不得承载 Run 内状态" |
| P3-3 | `meta_progress.gd` 有 7 个可变集合字段 | 跨局成长数据，合规（AGENTS 允许图鉴类解锁）。建议确认无路径写回 Run 内 |

---

## 6. 通过项（无需动作，作为基线记录）

**安全性 —— 全项通过，这是本次审计最扎实的一块**

- ✅ **零路径遍历**：全部 `FileAccess` 调用点使用常量路径（`user://nanjiang_smoke_*`），无任何用户输入拼接
- ✅ **零外部攻击面**：`OS.execute` / `OS.shell_open` / `HTTPRequest` / `TCPServer` / `JavaScriptBridge` 全部 0 命中；`OS.get_environment` 仅出现在 `acceptance_driver.gd`（测试工具，且已被导出排除）
- ✅ **存档完整性达标**：`tmp` + `DirAccess.rename_absolute` 原子写、`SAVE_VERSION = 4`、`_checksum` XOR 校验、版本不符返回 `{"ok":false,"kind":...}` 而非静默接受、v3→v4 迁移且"迁移而非丢弃"

**架构合理性 —— 依赖方向零违规**

- ✅ 域层对表现层 **0 反向依赖**（grep 全量，仅注释提及）
- ✅ 唯一数据加载口 `content_catalog`（P2-1/P2-2 的两处例外已记录）
- ✅ 命令分发单点：`battle_command_facade.gd:150 match command_type`
- ✅ 域层 **0 死代码**（`inheritance_resolver` / `journal_builder` 经 class_name 复核为误报，实际有 2 / 5 处引用）
- ✅ `battle_resolver.gd` 已不存在，B1 工单有实质进展

**性能 —— 热路径干净**

- ✅ 全仓库仅 1 处 `_process`（`audio_director.gd:117`）、0 处 `_physics_process`、1 处 `_input`（`battle_screen_view.gd:537`）
- ✅ 24 处 `get_node` 均在初始化路径，无每帧查找
- ✅ 无每帧 JSON 解析；`display_text` 有 static 缓存

**依赖管理 —— 许可证齐备**

- ✅ `addons/`（beckett / dialogue_manager / gut / reactive_ui_toolkit ×2）与 `vendor/godot-open-rpg` 各带 LICENSE
- ✅ 上游追踪完整：`CREDITS.md:145` 记录 GDQuest URL，`docs/open-rpg-audit.md` 记录 upstream URL + MIT + LICENSE 路径

---

## 7. 改进路线图（按执行顺序）

| 序 | 项 | 级别 | 依赖 | 预估改动 |
|---|---|---|---|---|
| 1 | `build/` 等 5 处加空 `.gdignore` | P0 | 无 | 5 个空文件，立刻生效，解决编辑器扫描与导出膨胀 |
| 2 | `export_presets.cfg` 补 exclude 清单 | P0 | 1 | 2 行（两个 preset） |
| 3 | `git rm --cached build/` + 删两条 `!` 白名单 | P0 | 无 | 1 次提交；需确认产物分发替代方案 |
| 4 | 定项目 LICENSE + 补根目录文件 | P0 | **你拍板** | 1 文件 |
| 5 | 游戏内"关于"署名界面 | P0 | 4 | 新屏幕或设置子页 |
| 6 | 补 `run_snapshot_builder` 快照契约测试 | P1 | 无 | 新测试文件（**拆分 god file 的前置**） |
| 7 | 拆 `run_snapshot_builder` 按屏幕切分 | P1 | 6 | 大改动，建议独立 worktree |
| 8 | 实测开新局耗时，再决定是否加 catalog 缓存 | P1 | 无 | 1 行或不动 |
| 9 | `display_text` 两份 JSON 纳入 catalog 校验 | P2 | 无 | 小 |
| 10 | `map_generator` fallback 加 debug warning | P2 | 无 | 1 行 |
| 11 | 契约漂移守门脚本入 `check.ps1` | P2 | 无 | 小（复用本次比对逻辑） |
| 12 | 清理临时分支 + `.claude/` 入 gitignore | P2 | 无 | 2 命令 |
| 13 | `audio_manager.randi()` 豁免说明 | P3 | 无 | 注释 |

**并行安全提示**：第 3、7 项涉及历史与核心文件，**必须**在本地无并行视觉会话活动时进行，且第 3 项前先 `git ls-remote` 确认远端状态（本仓库 `.git` 已两次损坏，禁用 `git stash` / `reset --hard`）。

---

## 8. 复现命令

```bash
# 仓库体积与历史大对象
du -sh .git
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' \
  | awk '$1=="blob"{print $2, $3}' | sort -rn | head -10

# 导出污染面
du -sh build .preview .superpowers .workbuddy memory
du -ch *.png | tail -1
find . -maxdepth 2 -name ".gdignore" -not -path "./.git/*"

# 分层与依赖方向
grep -rn "presentation" scripts/domain/*.gd          # 期望 0 命中
grep -rn "res://data/" scripts/presentation/*.gd     # 期望 0 命中
grep -rn "OS.execute\|HTTPRequest\|OS.shell_open" scripts/  # 期望 0 命中

# 契约漂移比对（本次所用方法）
python -c "
import re,io,os
doc=io.open('docs/contracts/2026-09-02-domain-ui-contract.md',encoding='utf-8').read()
ids=set(re.findall(r'\`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)\`',doc))
src=''.join(io.open(os.path.join(r,f),encoding='utf-8',errors='ignore').read()
    for r,d,fs in os.walk('scripts') for f in fs if f.endswith('.gd'))
print([i for i in sorted(ids) if i not in src])
"

# 测试基线
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```

---

## 9. 审计结论

**地基是好的**——依赖方向零违规、安全面零攻击点、存档完整性实现规范、契约漂移率 158 分之 1，这些都说明工程纪律在实际生效，不是写在 AGENTS.md 里的摆设。

**真正拖后腿的是仓库与发布卫生**：460M 的 `.git`、494M 的导出污染、未履行的 CC BY 署名义务。这三条都不是代码问题，但都属于**随时间持续变坏**的类型——尤其 P0-1，每打一次包就恶化一次。

**建议先做第 1、2 项**（5 个空 `.gdignore` + 2 行 exclude），成本几乎为零，但立刻止住编辑器扫描 425M 与包体膨胀，是本次审计性价比最高的动作。
