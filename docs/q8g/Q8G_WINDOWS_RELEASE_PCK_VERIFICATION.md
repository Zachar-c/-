# Windows Release PCK 实测（2026-09-14）

**执行者**：Agent 2（执行 worker）
**授权**：inbox §34「已批准下一步只做 Windows Release PCK 实测」
**HEAD**：`2748ef82`　**产物**：`build/verify-2748ef82/gu-zhenren.exe`（190,567,104 B / 181.7 MB）
**性质**：只读式验收（只写 `build/`，该目录由 `.gitignore:7` 忽略）。未改任何生产文件、未提交、未推送。

---

## 0. 结论摘要

| 检查项 | 结果 |
|---|---|
| 导出运行 | ✅ **rc=0**，38 s，无致命错误 |
| 新 exe 启动 | ✅ **rc=0，零错误输出** |
| 内嵌 PCK 内容 | ✅ 可枚举：**937 条**（733 资源 + 204 `.godot/imported` 载荷） |
| 卡牌贴图加载 | ✅ **从包内实际 `load()` 成功且尺寸真实**（见 §5） |
| `tests/tools/docs/.preview/.codex` 排除 | ✅ **违规 0**（逐项计数见 §6） |
| `*.md` 排除 | ✅ **0 条** |
| debug 资源边界 | 🔴 `debug_panel.tscn` + `debug_panel_view.gd` **进包**（未做编译期裁剪） |
| 新发现（发布卫生） | 🔴 `Godot/`（含 `editor_settings-4.7.tres`）进包；🔴 `ui/_sample.*` 开发脚手架 + `.guitkx` 源 + `.guitkx.diags.json` 进包 |
| 先前 3 条"疑似违规" | ❌ **全部是我的断言写错**，已自我更正（见 §8） |

**总判**：Windows Release PCK **可导出、可启动、包内容与 `export_presets.cfg` 的排除意图一致**；`CONDITIONAL` 的两个理由已消解——剩下的是 3 条**发布卫生**观察（不阻塞）。

---

## 1. 一个必须先说的环境坑（属我方工具缺陷，非仓库缺陷）

首次导出 **rc=1** 且无产物：

```
ERROR: Cannot export project with preset "Windows Desktop" due to configuration errors:
在预期路径处未找到导出模板：./Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe
```

根因：**我的 bash 环境里 `APPDATA` 是空字符串**（`LOCALAPPDATA` 正常）。Godot 是原生进程，取到空 `APPDATA` 后把数据目录算成**相对路径 `./Godot`**，于是去项目内找导出模板；而模板实际在 `%APPDATA%\Godot\export_templates\4.7.2.stable\`（203 MB，Windows 模板齐全）。

```
APPDATA=[]                       ← 空
LOCALAPPDATA=[C:\Users\90877\AppData\Local]
```

修法：调用前 `export APPDATA='C:\Users\90877\AppData\Roaming'` ⇒ **rc=0**。

> 副作用说明：此前多轮不带 `APPDATA` 的 Godot 调用，把 `editor_settings-4.7.tres`、`Godot/Godot/`、`app_userdata/` 写进了**仓库内** `./Godot/`（这也是 `.gitignore:45 /Godot/` 存在的原因）。属 gitignored 目录，未清理。

---

## 2. 导出与启动

```
导出  : godot --headless --path . --export-release "Windows Desktop" build/verify-2748ef82/gu-zhenren.exe
        rc=0 | real 0m37.7s | 产物 190,567,104 B | 无致命 ERROR
启动  : ./build/verify-2748ef82/gu-zhenren.exe --headless --quit-after 3
        rc=0 | 输出仅引擎 banner 一行 | 零 ERROR / 零 SCRIPT ERROR
```

启动零错误同时说明：**内嵌 PCK 可读、主场景 + autoload + `GuStyle`（字体 preload）在 release 包内均可初始化**。

---

## 3. 内嵌 PCK 内容

用 Godot 自身 `ProjectSettings.load_resource_pack()` 读取（不自行解析二进制格式；Godot 4.7 已是 `pack_version=4`）。

```
独立 pck（--export-pack，同预设）: build/verify-2748ef82/verify.pck  81,422,512 B
内嵌 exe                          : build/verify-2748ef82/gu-zhenren.exe
两者 FILE_COUNT 一致 = 937        ← 交叉验证：内嵌 PCK == 导出包
```

后缀分布：

```
258 .remap      资源（.tscn/.tres/.gd 重映射）
224 .gdc        编译后的 GDScript 字节码
168 .import     导入元数据（**必需**，见 §8）
168 （.godot/imported/*.ctex 载荷）
 56 .json
 16 .guitkx     🔴 RUITK 标记源
  5 .po
  3 .gdshader
  1 .png        assets/icon/app_icon_256.png（唯一裸图）
  1 .binary     project.binary（即 project.godot 的导出形式）
```

包内根级条目：`res://project.binary`、`res://gu_theme.tres.remap`。

---

## 4. 断言结果

| 断言组 | 结果 |
|---|---|
| `SHOULD_ABSENT`（前缀 + 精确） | ✅ **违规 0** |
| `SHOULD_ABSENT`（`*.md`） | ✅ **0 条** |
| 从包内 `load()` 10 项资源 | ✅ **失败 0** |
| 阴性对照（5 项必须加载不到） | ✅ **违规 0** |
| `SHOULD_PRESENT` | ⚠️ 报 6 项 missing —— **全部是我断言的写法错误**，见 §8 |

---

## 5. 卡牌贴图加载（从包内，非磁盘）

```
res://assets/wenzhen/gu/gu_force.png      CompressedTexture2D  1254x1254
res://assets/wenzhen/gu/gu_sword.png      CompressedTexture2D  1254x1254
res://assets/wenzhen/gu/gu_light.png      CompressedTexture2D  1024x1024
res://assets/wenzhen/gu/gu_blood.png      CompressedTexture2D  1024x1024
res://assets/wenzhen/fonts/MaShanZheng-Regular.ttf      FontFile
res://assets/wenzhen/fonts/LXGWZhiSongCL-Regular.ttf    FontFile
res://scenes/main.tscn                    PackedScene
res://scenes/ui/screens/battle_screen.tscn PackedScene
res://data/gu.json / res://data/nodes.json JSON
```

⇒ **卡牌贴图在 release 包内可加载，且尺寸真实（非占位）**；载体是 `res://.godot/imported/gu_force.png-<md5>.ctex`（168 个载荷与 168 个 `.import` **精确 1:1**）。

> ⚠️ 加载 `battle_screen.tscn` 时刷出 `Parse Error: Identifier "AudioManager" not declared`（`battle_screen_view.gd` / `gu_enemy_actor_view.gd` / `gu_top_bar_view.gd` / `wenzhen_master_theme.gd`）。**这是探针工程的产物**：`AudioManager` 是 autoload，我的空探针工程没有注册 autoload。**导出的 exe 启动零错误已反证这不是包内缺陷**。

---

## 6. 排除核对（逐项）

```
res://tests/                 0        res://.preview/        0
res://tools/                 0        res://.codex/          0
res://docs/                  0        res://memory/          0
res://addons/gut/            0        res://vendor/          0
*.md                         0
res://scripts/acceptance_driver.gd  不存在（load 返回 NULL ✔）
res://scripts/guitkx_build.gd       不存在（load 返回 NULL ✔）
res://.gutconfig.json               不存在
```

与 `export_presets.cfg` 的 `exclude_filter` 意图**完全一致**。

---

## 7. debug 资源边界

`debug_panel` **在包内**：

```
res://scenes/ui/widgets/debug_panel.tscn.remap
res://scripts/presentation/widgets/debug_panel_view.gd.remap
res://scripts/presentation/widgets/debug_panel_view.gdc
```

`export_filter="all_resources"` + `exclude_filter` 未列 `debug_panel*` ⇒ 必然进包。**未做编译期裁剪**（无 feature tag / 无 `exclude_filter` 条目）。这与 AGENTS.md「禁止把调试控制台仅靠 UI 隐藏；Release 构建必须编译裁剪」存在张力 —— **需裁定**（§12）。

---

## 8. 自我更正：先前 3 条"疑似违规"全部是我的断言写错

| 我先前的判定 | 实际 | 更正 |
|---|---|---|
| 168 项 `*.import` 泄漏 | `.import` 在 Godot 4 导出中**必需**，记录 `dest_files` 指向 `.godot/imported/*.ctex` | ❌ 误判，撤销 |
| `gu_force.png` / 字体 等 6 项"缺失" | 资源以 `.import` + `.ctex` 形式随包，**`load()` 全部成功** | ❌ 断言后缀写错 |
| `res://project.godot` 缺失 | 导出后成为 `res://project.binary` | ❌ 断言名写错 |

**教训**：包内容断言**不能用源码路径名**去比对，必须用 `load()` 或 `.remap`/`.godot/imported` 感知的匹配。

---

## 9. 回答发布边界开放项

| 开放项 | 结论 |
|---|---|
| `lore_engine/` 是否进包 | 🔴 **进包**（4 条：`config/default.json`、`schemas/extraction-v1.json`、`tests/fixtures/model/{valid,invalid}_extraction.json`）—— **含 Python 测试夹具** |
| `lore_sources/` 是否进包 | 🔴 **进包**（1 条：`manifest.json`） |
| `debug_panel.tscn` 是否需编译期裁剪 | **建议需要**，当前进包（§7） |
| 根目录零散截图排除 | ✅ **当前无对象**：仓库根目录已无任何 `*.png`/`*.jpg` |
| W10 首跑 flake | 未验证（不在本次范围） |
| ObjectDB/RID 泄漏 | 未闭合（见 VDA 报告 §4.2；release 启动未复现泄漏输出） |

---

## 10. 新发现：发布卫生（2 项）

### 10.1 `Godot/` 目录进包 🔴

```
res://Godot/editor_settings-4.7.tres.remap          ← 磁盘无 .remap，且带导出器生成的 .remap 后缀 ⇒ 确证为包内容
res://Godot/app_userdata/蛊真人/dialogue_manager_user_config.json
res://Godot/app_userdata/蛊真人/nanjiang_smoke_meta.json
```

根因：`exclude_filter` **没有 `/Godot/` 条目**，而 `export_filter="all_resources"` 会把 `.tres` / `.json` 一并打包。
⇒ **本机编辑器的 `editor_settings` 与 `user://` 下的 json 会随 release 包分发**。Git 层面已忽略该目录，但**导出过滤器没有**。

（第 4 条 `res://Godot/app_userdata/pckprobe/logs/godot.log` 经查是**探针工程自身**的 `build/pckprobe/Godot/...`，非包内容。）

### 10.2 `ui/_sample.*` 与 `.guitkx` 源 / 诊断文件进包 🔴

```
res://ui/_sample.gd.remap / .gdc / .guitkx / .guitkx.diags.json     ← 开发脚手架示例
res://ui/widgets/*.guitkx          （16 个 RUITK 标记源）
res://ui/widgets/*.guitkx.diags.json
```

`ui/*.guitkx` 是 RUITK 的**标记源**，构建期由 `scripts/guitkx_build.gd` 编译成 `.tscn`（该脚本已排除）；`.diags.json` 是编译诊断。二者是否需要**运行时**存在尚未确认 —— 若不需要，属可裁剪的包体与源码泄漏面。**需裁定**（§12）。

---

## 11. 未验证 / 边界

1. **`.guitkx` 是否为运行期必需**未确认（决定 10.2 是"可裁剪"还是"必须保留"）。
2. **真窗（非 headless）渲染与手感**未验证：本次只做 `--headless` 启动；卡牌贴图是"可从包内加载"，**不是**"在真窗战斗屏渲染正确"。真窗验收由用户主动要求时才做。
3. **W10 首跑 flake**、**ObjectDB/RID 泄漏**仍未闭合（不在本次范围）。
4. 探针加载项目脚本时会因缺 autoload 报 `AudioManager not declared` —— 已确认是探针产物，但**无法用该探针验证战斗屏渲染路径**，需真窗或专用驱动。
5. `build/pckprobe/`（探针工程）与 `build/verify-2748ef82/`（产物）均为 `build/` 下的本地文件，`build/` 已 gitignore；未纳入版本控制。

---

## 12. 需裁定（4 项）

| # | 议题 |
|---|---|
| ① | `exclude_filter` 是否加 `/Godot/`（与其它本地数据目录同级）？现会把 `editor_settings` 与 `app_userdata/*.json` 打进 release 包 |
| ② | `debug_panel.tscn` / `debug_panel_view.gd` 是否编译期裁剪？AGENTS.md 有「Release 必须编译裁剪」的条目 |
| ③ | `lore_engine/` + `lore_sources/` 是否排除？（含 Python 测试夹具；本阶段目标是 PC 单机 Demo） |
| ④ | `ui/*.guitkx` + `*.guitkx.diags.json` + `ui/_sample.*` 是否排除？（需先确认 `.guitkx` 是否运行期必需） |

---

## 13. 交付物

| 文件 | 性质 |
|---|---|
| `docs/q8g/Q8G_WINDOWS_RELEASE_PCK_VERIFICATION.md` | 本报告（新增） |
| `build/verify-2748ef82/gu-zhenren.exe` | release 产物（gitignored） |
| `build/verify-2748ef82/verify.pck` | 同预设独立包（交叉验证用，gitignored） |
| `build/verify-2748ef82/pack_list.txt` | 包内容全清单 937 条（gitignored） |
| `build/pckprobe/{project.godot,probe.gd}` | 一次性内容探针（gitignored） |

**未修改任何生产文件**；未提交；未推送（本地仍领先 `origin/master` 2 个提交）。

---

**记录时间**：2026-09-14
