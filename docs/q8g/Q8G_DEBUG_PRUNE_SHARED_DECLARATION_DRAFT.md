# Debug 阶段 B：Shared 所有权声明草案（未施工）

> 状态：**草案** — 供 Owner 确认后按 `docs/contracts/2026-09-12-agent-ownership-contract.md` 执行  
> 对应方案：`docs/q8g/Q8G_DEBUG_COMPILE_PRUNE_PLAN.md`  
> 基线建议：`d15fa567` 或更新 origin/master

---

## 1. 声明文件

```text
scripts/presentation/run_controller.gd          （Shared）
scripts/presentation/run_debug_facade.gd        （可选拆出/保留实现体）
scripts/domain/debug_actions.gd                 （仅导出过滤，不改语义）
export_presets.cfg                              （exclude 扩展）
scripts/presentation/widgets/debug_panel_view.gd （实现体，Release 剔除）
scenes/ui/widgets/debug_panel.tscn               （Release 剔除）
```

新增非 Shared：

```text
scripts/presentation/debug_bridge.gd
```

---

## 2. 原因

- `run_controller.gd` 对 `RunDebugFacade` 为 **class_name 硬引用**（约 20 处调用）。
- 现行仅 `OS.is_debug_build()` 运行时门控；Release 包内仍含 facade / panel / `debug_actions` 字节码与场景。
- 用户已批准「Release 编译期裁剪 Debug」，并禁止「只加 exclude_filter 却保留正式硬引用」。

---

## 3. 影响面

| 面 | 预期 |
|----|------|
| 正式 UI / save / travel / battle / ending | 语义不变；仅 debug 方法族转发路径变化 |
| Debug 构建 | F12 面板与命令行为与现网一致 |
| Release 构建 | 不 load facade；PCK 不含四路径 |
| 测试 | 依赖 `RunController.debug_*` 公开 API 的用例应仍绿（包装层签名不变） |

**明确不改：** `data/**`、pity/E6/pacing/battle 规则、`save_repository` 校验语义、`project.godot`。

---

## 4. 指定测试

| 测试 | 命令 / 动作 | 通过线 |
|------|-------------|--------|
| 交互门 | `verify_interaction_loop.gd` | 15/15 三键 |
| Rest | `verify_rest_headless.gd` | OK |
| Unit | `tools/test.ps1 -Suite unit` | 不红于合入前 |
| Integration | `-Suite integration` | 不红于合入前 |
| Debug 真窗 | F12 挂载 | 面板可见、命令早退仍受门控 |
| Release PCK | `agent3_pck_audit.gd` | debug 四路径 0 |
| Release smoke | exe `--quit-after 3` | EXIT=0 |

---

## 5. 单独 commit 纪律

```text
refactor(debug): route RunController debug API through optional DebugBridge
chore(export): exclude debug facade/panel from release packs
```

不得与 UI 美术、数据表、契约文档大改混提。

---

## 6. Owner 确认栏

```text
[ ] 同意施工范围
[ ] 指定施工者
[ ] 目标 HEAD：____
```
