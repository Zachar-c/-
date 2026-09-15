# P0-3 最终 Windows Release Gate — Owner 交回

> 对应：`docs/q8g/Q8G_OWNER_EXECUTION_CHECKLIST.md` **P0-3**
> 执行者：Owner 侧 Agent；验收者：Agent3
> 依赖：P0-1（`a35e3786` + `79b67210`，另一 Agent 提交）、P0-2（`6ea67c95`，本 Agent）

---

## 一、固定 HEAD 与产物

```text
HEAD            = cc8a70a2c0eddafdf01687bb86d361239c46ec9c   （cc8a70a2）
预设             = "Windows Desktop"
产物目录         = build/owner-p03-cc8a70a2/

gu-zhenren.exe  = 222,502,968 B
gu-zhenren.pck  = 113,183,276 B
```

> 注：`build/` 有 `.gdignore` 且被 `exclude_filter` 排除，产物不进包、不入库。

---

## 二、命令与退出码

```text
export APPDATA='C:\Users\90877\AppData\Roaming'      # 必需：APPDATA 为空时 Godot 会去项目内找导出模板
godot --headless --path . --export-release "Windows Desktop" build/owner-p03-cc8a70a2/gu-zhenren.exe
    → rc=0（21s）
godot --headless --path . --export-pack "Windows Desktop" build/owner-p03-cc8a70a2/gu-zhenren.pck
    → rc=0
./build/owner-p03-cc8a70a2/gu-zhenren.exe --headless --quit-after 3
    → EXIT=0，日志内 SCRIPT ERROR / Parse Error = 0
godot --headless --path . -s tools/agent3_pck_audit.gd -- --pck=C:/Users/.../build/owner-p03-cc8a70a2/gu-zhenren.pck
    → rc=0，AUDIT_PASS
```

> **坑（供复用）**：审计工具的 `--pck=` 必须传 **Windows 形态**路径
> （`C:/Users/...`）。传 Git Bash 的 `$(pwd)` 会得到 `/c/Users/...`，
> Godot 是原生进程，会报 `AUDIT_FAIL pck missing`。

---

## 三、PCK 审计全文

```text
PCK_BYTES=113183276
SCAN_BYTES=113183276

CANARY project.binary = 1
CANARY run_screen_router.gd = 5
CANARY gu_card_view.gd = 6
CANARY MaShanZheng-Regular.ttf = 4          ← 反空转 canary 全非零 ⇒ 扫描器有效

HIT tests/unit/ = 0
HIT tests/integration/ = 0
HIT tools/ = 0
HIT docs/ = 0
HIT .preview/ = 0
HIT .codex/ = 0
HIT .superpowers/ = 0
HIT memory/ = 0
HIT lore_engine/ = 0
HIT lore_sources/ = 0
HIT vendor/ = 0
HIT 分支：六卷精编版/ = 0
HIT 肉鸽设计-原始数据/ = 0
HIT acceptance_driver.gd = 0
HIT guitkx_build.gd = 0
HIT Godot/editor_settings = 0
HIT Godot/app_userdata/ = 0
HIT ui/_sample.guitkx = 0
HIT guitkx.diags.json = 0
HIT ui/widgets/gu_card.guitkx = 0

OBS_debug_panel=0
OBS_run_debug_facade=0
OBS_debug_actions=0
OBS_debug_snapshot=5
OBS_claude_pot=0

AUDIT_PASS
```

---

## 四、验收标准自评（对照清单）

| # | 标准 | 自评 | 证据 |
|---|---|---|---|
| 1 | 阴性：tests/tools/docs/memory/lore_engine/lore_sources/vendor/Godot/语料/acceptance_driver/guitkx_build = 0 | **PASS** | 上表 20 条 HIT 全 0，含 `分支：六卷精编版/`、`肉鸽设计-原始数据/`、`Godot/editor_settings`、`Godot/app_userdata/` |
| 2 | debug 四路径 = 0（依赖 P0-1） | **PASS** | `OBS_debug_panel=0`、`OBS_run_debug_facade=0`、`OBS_debug_actions=0`；`debug_panel_view` 是 `debug_panel` 的超串，前者为 0 ⇒ 后者必为 0 |
| 3 | `.claude/worktrees` = 0（依赖 P0-2） | **PASS** | `OBS_claude_pot=0`（P0-2 之前为 1） |
| 4 | exe smoke EXIT=0 | **PASS** | `--headless --quit-after 3` → EXIT=0，0 条 SCRIPT ERROR |
| 5 | 报告写明 HEAD 与产物路径 | **PASS** | 见 §一 |

**总判：PASS。**

---

## 五、观察（不阻塞，供 Agent3 记录）

### 5.1 `OBS_debug_snapshot=5` 仍在包内

```text
scripts/presentation/snapshots/debug_snapshot.gd 的字节串在 PCK 内命中 5 次。
原因：它被 Shared 的 run_snapshot_builder.gd 引用（`debug()` 分支），
      不在 P0-1 批准剔除的「四路径」清单内（清单为 run_debug_facade /
      debug_panel_view / debug_panel.tscn / domain/debug_actions）。
若要一并裁剪，需要走 Shared 协议改 run_snapshot_builder.gd —— 超出 P0-1 授权范围，
本轮未做。AGENTS.md「Release 构建必须编译裁剪」的完整达成度由 Owner/Agent3 裁定。
```

### 5.2 导出日志 13 条 WARNING，全部同一既有问题

```text
13 条全部形如：
  res://addons/dialogue_manager/**/*.tscn:N - ext_resource, invalid UID: uid://… - using text path instead
即 Dialogue Manager 插件场景的 UID 失效后回退文本路径。
这与 AGENTS.md「验证遗留」中已登记的「Dialogue Manager invalid UID」是同一项，
属既有问题、与 P0-1/P0-2 无关，不影响导出结果（rc=0）与启动（EXIT=0）。
```

### 5.3 孤儿目录未清理（P0-2 已使其无害）

```text
.claude/worktrees/battle-visual-implementation/（66MB / 1747 文件）仍在磁盘上。
P0-2 已通过关闭 Dialogue Manager 的自动 POT 维护使其不再影响 project.godot；
是否物理删除该孤儿目录需用户明确指令（删除他人工作目录）。
```

---

## 六、并发与可归因性

```text
本项执行期间工作树干净（HEAD = cc8a70a2，无未提交改动；仅 .codex/、4 个敌人 png、
3 份 Agent3/Owner 文档为未跟踪）。
导出与审计均在固定 HEAD 上进行，产物可复现：
  git rev-parse HEAD → cc8a70a2c0eddafdf01687bb86d361239c46ec9c
```

---

## 七、Owner 交回（清单格式）

```text
提交清单：
  （本项无生产改动，只产出 build/ 证据与本文档）
  <sha>  docs(q8g): record P0-3 final windows release gate evidence

命令与退出码：
  export-release "Windows Desktop"  → 0   build/owner-p03-cc8a70a2/gu-zhenren.exe (222,502,968 B)
  export-pack    "Windows Desktop"  → 0   build/owner-p03-cc8a70a2/gu-zhenren.pck (113,183,276 B)
  exe --headless --quit-after 3     → 0   0 条 SCRIPT ERROR
  agent3_pck_audit.gd --pck=…       → 0   AUDIT_PASS（20 条阴性 0；debug 四路径 0；claude_pot 0）

未完成项：
  - P1-1 .gutconfig engine 回归：待 Luna 裁定
  - P1-2 ObjectDB/RID 泄漏：未接单
  - P1-3 W10 真窗 flake：未接单
  - P2-1 / P2-2 美术：未接单
  - §5.1 debug_snapshot 残留裁剪：需 Shared 授权

需要 Agent3 验收的项编号：P0-3（连带 P0-1、P0-2 的合并效果）
```
