# 发布 / 导出阻塞诊断（2026-09-14）

**执行者**：Agent 2（执行 worker）
**触发**：inbox §33「当前阻塞」条目中「`tools/check.ps1` 在 Android 导出检查阶段因本机缺少 Android build-tools directory 而退出」
**性质**：只读诊断 + 事实核对。**未修改任何文件**（本报告为新增），未执行导出/签名，未推送。

---

## 0. 结论摘要

| 项 | 结论 |
|---|---|
| §33 的归因 | 🔴 **不成立**：全仓两个 `check.ps1`（主树 47 行、`.claude/worktrees/...` 24 行）**都不含任何 Android 引用**，不可能进入"Android 导出检查阶段" |
| Android 阻塞本身 | ✅ **真实存在**，但属**导出 / 签名**路径，与 `check.ps1` **正交** |
| 实际缺什么 | **两件**（不止一件）：① Android SDK —— `%LOCALAPPDATA%\Android` **整个目录不存在**；② **Android 导出模板 —— 未安装**（`export_templates/4.7.2.stable/` 只有 Windows 模板） |
| 附加缺口 | `%LOCALAPPDATA%\Android\debug.keystore` 缺失；`sign_android.ps1:10` 把 build-tools 版本**硬编码为 `34.0.0`** |
| 既有构建产物 | 🔴 **陈旧**：`build/win/gu-zhenren.exe` = **09-06 03:00**、`build/android/gu-zhenren-signed.apk` = **09-09 22:10** ⇒ **不能作为当前 HEAD 的发布证据** |
| Windows PCK | ✅ **本机可验证**：Windows 导出模板齐全，且 preset 用 `binary_format/embed_pck=true` ⇒ "PCK" 内嵌在 exe 内 |
| 我的改动是否引入该报错 | ❌ **已排除**：我的 7 份运行日志（import / guitkx / unit×2 / integration×2 / drift）`android|build-tools` 命中**全为 0** |

**一句话**：Android 确实不可在本机导出，但**不是 `check.ps1` 阻塞**；`check.ps1` 的五个阶段全部与 Android 无关。
建议把状态条目改为「**导出 / 签名流水线**被本机 Android 环境缺失阻塞」，并把「完整 check」与「Android 导出」拆成两行。

---

## 1. 证据

### 1.1 全仓 `check.ps1` 与 Android 无关

```
find . -name check.ps1 -not -path "./.git/*"
  ./.claude/worktrees/battle-visual-implementation/tools/check.ps1   → 24 行，android 命中 0
  ./tools/check.ps1                                                  → 47 行，android 命中 0
```

`tools/check.ps1` 的实际阶段（全部与 Android 无关）：

```
① guitkx_build.ps1              （编译 16 个 .guitkx → .tscn）
② test.ps1 -Suite all           （unit + integration）
③ godot --headless --quit-after 3        （启动探针）
④ godot -s tools/check_contract_drift.gd （契约漂移门）
⑤ git diff --check                       （空白错误）
```

`git log -- tools/check.ps1` 最后一次改动为 `1a00ca56`，之后未动。

全仓**唯一**的 `--export-release` 调用点：

```
tools/export.ps1:13   $exportArgs = @('--headless','--path',$projectRoot,'--export-release',$Preset)
```

`grep -rn "check.ps1"` 与 `android` 同现的结果**只出现在 inbox 自身**（§33 的描述里），文档中并不存在"含 Android 的完整 check"定义。

### 1.2 Android 环境：两件都缺

```
%LOCALAPPDATA%\Android                                      → 不存在（整个目录）
%LOCALAPPDATA%\Android\Sdk\build-tools                      → 不存在
%LOCALAPPDATA%\Android\debug.keystore                       → 不存在
find /c/Users/90877 -maxdepth 3 -type d -name build-tools   → 无结果

%APPDATA%\Godot\export_templates\4.7.2.stable\
  windows_debug_x86_64.exe
  windows_debug_x86_64_console.exe
  windows_release_x86_64.exe          ← 存在
  windows_release_x86_64_console.exe  ← 存在
  （android 相关模板：0 个）
```

⇒ 即使补上 Android SDK，**Godot 仍会因缺 Android 导出模板而无法导出**。这是两个独立的缺失，需一并解决。

`tools/sign_android.ps1:9-10`：

```powershell
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$apksigner = Join-Path $sdk "build-tools\34.0.0\apksigner.bat"
if (-not (Test-Path $apksigner)) { throw "apksigner not found: $apksigner" }
```

⇒ 版本号 `34.0.0` **硬编码**：日后装了别的 build-tools 版本，该脚本仍会 `throw`。

### 1.3 既有构建产物是陈旧的

```
build/win/gu-zhenren.exe                120,829,464 B   2026-09-06 03:00
build/android/gu-zhenren-signed.apk      80,382,319 B   2026-09-09 22:10
```

当前 HEAD 是 `2748ef82`（2026-09-14）。**两个产物都早于此后 6 个提交**（含 `b82950e1` 卡片重构、`73e3e5ee` 卡面 `load()` 修复、`2748ef82` 断言修复），因此**不能**用来主张"Release PCK 可用"。

`build/` 由 `.gitignore:7` 忽略，属本地产物，不随仓库分发。

### 1.4 我的改动已排除为诱因

| 日志 | `android` / `build-tools` 命中 |
|---|---|
| `a_import.txt`（`--import`） | **0** |
| `a_guitkx.txt` | **0** |
| `a_unit.txt` / `b_unit.txt` | **0** |
| `a_integration.txt` / `b_integration.txt` | **0** |
| `a_drift.txt` | **0** |

`tools/test.ps1` 新增的 `--import` 前置（提交 `2748ef82`）只重建导入缓存，**不触碰导出预设**，日志中亦无任何 Android 字样。

---

## 2. Windows PCK 是本机可验证的（唯一未验证项中可闭环的部分）

`export_presets.cfg`：

```
preset.0  name="Windows Desktop"  export_path="build/win/gu-zhenren.exe"
          export_filter="all_resources"  include_filter="data/*.json"
          binary_format/embed_pck=true          ← PCK 内嵌，不产出独立 .pck
preset.1  name="Android"          export_path="build/android/gu-zhenren.apk"
```

⇒ **Windows 的"最终 PCK"= exe 内嵌的 PCK**。本机模板齐全，因此这条可以真跑：

```bash
# 非破坏性：写到独立目录，不覆盖 09-06 的旧产物
"$GODOT" --headless --path . --export-release "Windows Desktop" build/verify-2748ef82/gu-zhenren.exe
# 引导验证：内嵌 PCK 读不出来会在启动即报错
"build/verify-2748ef82/gu-zhenren.exe" --headless --quit-after 3
```

这一步能同时验证 Agent 3 报告里自陈的风险（"exclude 扩展与 `load()` 贴图修复的包内行为未在最终 PCK 上实测"）。
**本次未执行**（§33 明确"先保留待处理"），等指令。

---

## 3. 建议的状态表述更正

```text
原（§33）  check.ps1：被本机 Android build-tools 缺失阻塞

建议改为
  check.ps1            ：五个阶段均不含 Android；本机可在正常 shell 运行（本轮未取得该结果）
  导出 / 签名流水线     ：被本机 Android 环境阻塞——
                         ① %LOCALAPPDATA%\Android 整个目录不存在（无 SDK / 无 build-tools / 无 debug.keystore）
                         ② Godot 未安装 Android 导出模板（export_templates/4.7.2.stable 仅 Windows）
  最终 PCK             ：未验证；既有 build/win/*.exe(09-06) 与 build/android/*.apk(09-09) 均为陈旧产物
  Windows PCK          ：本机可验证（模板齐全 + embed_pck=true），待指令
```

---

## 4. 未做 / 边界

- **未执行**任何导出、签名、安装 SDK/模板（§33 要求先保留待处理）。
- **未修改**任何文件；本报告为新增。
- **未触碰**其他 agent 的未提交改动（`docs/q8g/Q8G_HANDOFF_CURRENT.md`、`docs/q8g/Q8G_WORKER_REPORT_CURRENT.md` 等）。
- **未推送**（本地仍领先 `origin/master` **2** 个提交：`73e3e5ee` + `2748ef82`，与 §33 一致）。
- 需 Luna 裁定的一项：**是否要求 Android 侧可导出**（决定是装 SDK+模板+keystore，还是把 Android 降级为"不阻塞 PC 交付"的边界）。

---

**记录时间**：2026-09-14
