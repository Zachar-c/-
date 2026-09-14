# Debug 编译期裁剪方案（Agent3 / 2026-09-14）

> 状态：**方案待实现**（Shared 文件改动，未施工）
> 授权：用户发布裁定「批准 Release 编译期裁剪 Debug」
> 约束：不得在 `exclude_filter` 里剔除脚本却让正式代码继续硬引用；不得改 `project.godot` 除非走 Shared ownership 5 步协议

---

## 1. 现状（为何 `exclude_filter` 不够）

| 组件 | 引用方式 | Release 现状 |
|------|----------|--------------|
| `scripts/presentation/run_controller.gd` | **硬引用** `RunDebugFacade`（全局 `class_name`，约 20 处调用） | facade 脚本必须进包，否则编译/解析失败 |
| `scripts/presentation/run_debug_facade.gd` | `preload(debug_actions.gd)` + `load(DEBUG_PANEL_PATH)` | 整文件进包；面板仅 `load()` |
| `scenes/ui/widgets/debug_panel.tscn` | 仅 `load()`（`is_debug_build` 门控挂载） | 进包 |
| `scripts/presentation/widgets/debug_panel_view.gd` | 面板场景脚本 | 进包 |
| `scripts/domain/debug_actions.gd` | 被 facade `preload` | 进包 |
| 运行时门控 | `OS.is_debug_build()` → `_debug_enabled_for_test` | Release **不挂载**面板，方法 early-return |

**结论：** 仅把 `debug_panel.tscn` / `debug_panel_view.gd` 写进 `exclude_filter` 而不改 `run_controller`，**不满足**「Release 包中不含 Debug 脚本、场景和调试命令」的完整语义；facade + `debug_actions` 仍会进包。本方案给出可落地的编译期裁剪路径。

---

## 2. 目标

```text
Release 导出包：
  - 无 debug_panel.tscn
  - 无 debug_panel_view.gd
  - 无 run_debug_facade.gd
  - 无 domain/debug_actions.gd
  - 无 F12 调试命令实现体
  - run_controller / 保存 / 战斗 / 启动 不因缺失 Debug 而报错

Debug（编辑器 / --debug 或 is_debug_build）：
  - 行为与当前一致（面板 + 命令门控）
```

---

## 3. 推荐方案：运行时惰性桥 + 导出过滤（分两步）

### 阶段 A（低风险，可独立交付）— 面板场景物理裁剪

1. 保持 `run_controller` 对 facade 的 **唯一** 入口不变。
2. 将 `_mount_debug_panel` 对场景的 `load()` 保持惰性（已满足）。
3. 在 `export_presets.cfg` **Windows Desktop** 的 `exclude_filter` 增加：

```text
scenes/ui/widgets/debug_panel.tscn,
scripts/presentation/widgets/debug_panel_view.gd
```

4. 验收：
   - Release PCK 阴性：不含上述两路径；
   - `is_debug_build=false` 时无 mount；
   - Debug 构建（编辑器跑）面板仍可用（exclude 不影响编辑器运行 `res://` 直读）。

**局限：** facade 与 `debug_actions` 仍进包（方法体存在但不可达）。

### 阶段 B（完整编译期裁剪，需 Shared 协议）— 拆除硬引用

#### B1. 引入可选桥

新文件（非 Shared）：`scripts/presentation/debug_bridge.gd`

```gdscript
class_name DebugBridge
extends RefCounted
## Release：本类可被导出过滤剔除；Debug 构建通过 load() 挂接真 facade。
## 正式代码只依赖本桥的静态空实现，不直接 import RunDebugFacade。

const FACADE_PATH := "res://scripts/presentation/run_debug_facade.gd"
static var _facade = null
static var _resolved := false

static func _ensure() -> void:
    if _resolved:
        return
    _resolved = true
    if not OS.is_debug_build() and not OS.has_feature("debug"):
        _facade = null
        return
    if ResourceLoader.exists(FACADE_PATH):
        _facade = load(FACADE_PATH)

static func enabled(controller) -> bool:
    _ensure()
    if _facade == null:
        return controller._debug_enabled_for_test if " _debug_enabled_for_test" in controller else false
    return _facade._debug_enabled(controller)

# 其余 API：_facade==null 时返回 debug_disabled / no-op
```

#### B2. 改 `run_controller.gd`（Shared，5 步协议）

| 步 | 内容 |
|----|------|
| 声明文件 | `run_controller.gd` |
| 原因 | 消除对 `RunDebugFacade` 的编译期硬引用，使 Release 可剔除 facade |
| 影响面 | 仅 debug 方法族包装层；正式 travel/battle/save 不得改动语义 |
| 指定测试 | unit 中 debug 门控相关 + `verify_interaction_loop` + Debug 构建手测 F12 |
| 单独 commit | `refactor(debug): route RunController debug API through optional DebugBridge` |

改法要点：

- 删除全部 `RunDebugFacade.xxx(self)` 直接调用；
- 改为 `DebugBridge.xxx(self)`；
- `DebugBridge` 在 Release 下不 `load` facade；导出过滤剔除：

```text
scripts/presentation/run_debug_facade.gd,
scripts/presentation/widgets/debug_panel_view.gd,
scenes/ui/widgets/debug_panel.tscn,
scripts/domain/debug_actions.gd
```

#### B3. 自定义 feature（可选强化）

- Export preset `custom_features="release_demo"`（或保持默认）；
- `DebugBridge._ensure` 优先 `OS.has_feature("debug")`，与 `is_debug_build` 双条件；
- 避免仅靠字符串路径硬编码时误在 Release `load`。

#### B4. 验收清单（阶段 B）

```text
[ ] Release PCK 不含：run_debug_facade / debug_panel_view / debug_panel.tscn / debug_actions
[ ] Release exe --quit-after 3：rc=0，无 SCRIPT ERROR
[ ] Release 下 F12 无反应（无节点、无命令）
[ ] 编辑器 Debug：面板仍挂载，debug 命令仍受 is_debug_build 门控
[ ] 正式路径：save_run / load_run / travel / battle / ending 单测与交互门全绿
[ ] 不修改 data/** 与 domain 规则语义
```

---

## 4. 明确不做

| 项 | 原因 |
|----|------|
| 只改 `exclude_filter` 剔除 facade 而不动 controller | 运行时/编译期硬引用断裂 |
| 把 Debug 能力做成跨局成长或正式命令 | 违反「调试不得改大厅存档/解锁」红线 |
| 在未走 Shared 协议时改 `project.godot` | Ownership 禁止 |

---

## 5. 与本批 export 卫生的关系

本批 `export_presets.cfg` **只**批准：

```text
Godot/*, Godot/**
lore_engine/*, lore_sources/*
ui/*.guitkx, ui/**/*.guitkx
ui/*.guitkx.diags.json, ui/**/*.guitkx.diags.json
ui/_sample.*
```

**不包含** debug 面板/facade 排除——留待阶段 A/B 单独 commit。

---

## 6. 工作量估计

| 阶段 | 触碰文件 | 风险 |
|------|----------|------|
| A | `export_presets.cfg` + PCK 阴性复测 | 低 |
| B | `debug_bridge.gd`（新）+ `run_controller.gd`（Shared）+ presets | 中（需回归） |

建议顺序：先交付本批卫生 export + 重导出证据 → 再开 Shared 协议做阶段 B。
