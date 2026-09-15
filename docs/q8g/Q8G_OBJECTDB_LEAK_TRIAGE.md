# P1-2 ObjectDB/RID 泄漏定位与修复（2026-09-15）

> 执行：Agent3 / Owner 接单  
> 基线：`1b55f30f`（P0 收口后）  
> 性质：**仅改 unit 测试所有权包装**；未改 `scripts/domain/**`、`data/**`、RunState、save

---

## 1. 基线（修复前）

| 场景 | ObjectDB | resources | RID |
|------|----------|-----------|-----|
| 全量 unit | **18** leaked | **6** still in use | 0 |
| 历史（2026-09-06） | 20601 | — | — |

VDA 已记录：导入缓存修复后残留 18+6；逐文件归因未做。

---

## 2. 定位方法

8 分片二分 → 单文件复现：

| 文件 | 单独跑 | ODB | RES |
|------|--------|-----|-----|
| `test_opening_fairness.gd` | 通过 | **Y** | **Y** |
| `test_sword_school_gu.gd` | 通过 | **Y** | **Y** |

其余分片无泄漏线。

**Verbose 泄漏类型（opening_fairness）：**

```text
Leaked instance: Node:... (path empty)
Leaked instance: RefCounted ×4
Leaked instance: GDScript ×N
Resource still in use:
  run_state.gd / dialogue_gateway.gd / template_dialogue_gateway.gd
  dialogue_manager_adapter.gd / meta_progress.gd / run_controller.gd
```

---

## 3. 根因

多处测试：

```gdscript
var controller = RunControllerScript.new()
controller.start_new_run(...)
# 无 autofree / free / add_child
```

`RunController` 是 `Node`：`new()` 后不 `free` 即泄漏；`start_new_run` 再持有 catalog/Timer/RUIHost 等，退出时表现为 ObjectDB + script resource 泄漏。

**对照**：`test_wenzhen_hall_screen` 等已用 `autofree(RunControllerScript.new())`，同套件无泄漏。

全仓 `tests/unit` 扫描：12 个文件存在裸 `RunControllerScript.new()`（部分已手动 `free` 的未改）。

---

## 4. 修复

统一改为：

```gdscript
var controller: RunController = autofree(RunControllerScript.new())
```

（必须显式类型：`autofree` 返回 Variant，`:=` 与后续 `state := controller.state` 会 Parse Error。）

**文件（12）：**  
`test_opening_fairness` · `test_sword_school_gu` · `test_slay_gu_final_chapter` · `test_moonlight_full_route` · `test_v1_five_layer_clear` · `test_encounter_session` · `test_combat_node_fight` · `test_battle_opening_warning` · `test_kill_move_content` · `test_hall_school_select` · `test_moonlight_school_start` · `test_audio_director`

另修 `test_moonlight_school_start`：`save_res :=` → `=`；`test_slay_gu_final_chapter`：`state :=` → `=`。

---

## 5. 验证

| 项 | 结果 |
|----|------|
| 单文件 `test_opening_fairness` | 4/4，无 leak 线 |
| 单文件 `test_sword_school_gu` | 26/26，无 leak 线 |
| **全量 unit** | **1467/1467 PASS**，退出码 0 |
| **ObjectDB / resources** | **无 `were leaked` / `still in use` 输出** |

交互门未回归（P0 已绿，本批未触 presentation）。

---

## 6. 结论

| 项 | 状态 |
|----|------|
| 根因 | GUT 语境下测试裸 `new()` Node 未释放，非生产运行路径 |
| 修复 | unit `autofree` + 类型注解 |
| 基线 | 18 ODB + 6 RES → **0 泄漏输出** |
| 生产代码 | 未改 |

**P1-2 可关闭**（测试侧）。若真窗/GUT 外仍见泄漏，另开调查。
