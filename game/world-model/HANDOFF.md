# 交接清单（HANDOFF）

> 更新：2026-09-17（覆盖旧版；旧版数字为 64556 检查 / 38 用例 / 13 风险，均已过时）
> 当前生效约束：`world-model/governance/CONSTRAINTS-V2.md`（依据 `rulings/RUL-2026-09-17-003.json`）

---

## 一、一句话状态

世界模型（8 类实体、10 个机读数据文件、纯 Python 规则层与运行器）已交付，**已接线进 Godot 项目**（只读接入层 + 一致性门禁），上游漂移归零，Godot 全量 unit 套件 0 失败。

## 二、入口命令（按用途）

| 想干什么 | 命令 | 退出码含义 |
| --- | --- | --- |
| **一键验收（首选）** | `python world-model/tools/accept.py --smoke 10` | 0 = 校验+测试+冒烟全绿 |
| 只跑数据校验 | `python world-model/tools/validate_world_model.py` | 0 = 无失败项 |
| 只跑测试 | `python world-model/tests/run_tests.py` | 0 = 全通过 |
| 打一局 | `python world-model/runner/cli.py --seed 101 --auto` | 0 = 走到结算 |
| 同种子复现 | `python world-model/runner/cli.py --seed 101 --auto --replay` | 0 = 与历史台账逐字节一致 |
| 批量平衡模拟 | `python world-model/tools/simulate_balance.py --runs 200 --hp-mult 1.5 2.0` | 0 = 报告已写出 |
| **上游漂移检测** | `python world-model/tools/check_upstream_drift.py` | 0 = 无漂移；1 = 有漂移 |
| 重新派生数据 | `python world-model/tools/build_world_model.py --generated-at 2026-09-17T00:00:00Z` | 0 = 已写出 |
| 改前快照 | `python world-model/tools/snapshot.py take <label>` | 0 = 已快照 |
| 覆盖式恢复 | `python world-model/tools/snapshot.py restore <id> --yes` | 0 = 已恢复（保留新增文件） |
| 全量回滚 | `python world-model/tools/snapshot.py restore <id> --prune --yes` | 0 = 已恢复且删除新增文件 |

依赖：Python ≥3.9、零第三方包；不需要 Godot 即可跑世界模型本身。

## 三、Godot 侧接线（2026-09-17 新增）

| 件 | 位置 | 作用 |
| --- | --- | --- |
| 接入层 | `scripts/domain/world_model_bridge.gd`（`class_name WorldModelBridge`） | 只读加载 `res://world-model/data/*.json`，暴露蛊/敌人/配方边/商店报价/价值锚访问器 |
| 一致性门禁 | `tests/unit/test_world_model_bridge.gd` | 8 用例 / 20 断言；逐条比对两侧数据；带 `SABOTAGE` 负控开关 |

- **游戏运行时仍用 `data/`**；接入层只做读取与一致性校验，不参与玩法结算。
- 跑法：先 `--headless --path . --import`，再 `-s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=1`。
- 负控语义：把测试文件里的 `const SABOTAGE := false` 改成 `true`，门禁必须失败（实测 5/8、退出码 1）。**若打开负控仍然全绿，说明门禁失效。**
- 导出：`export_presets.cfg` 为 `all_resources`，`world-model/data/*.json` 本就在 Release 包内；但**schema/rulings/saves 等开发部件也会被打进去**（见 §六 未决项）。

## 四、已完成（按提交）

| 提交 | 内容 |
| --- | --- |
| `a5fe44a` | 世界模型底座 + 约束体系 v2（46 文件） |
| `86d527e` | 按外部审查收口：映射表逐行渲染 `source_ids`（带编号行 0→874/983）、10 条空来源蛊改判、canon 必须有来源的硬断言、`attune_gu` 生命周期对齐 |
| `7b709d1` | 上游漂移检测器（含发现上游新增商店报价）+ 快照 `--prune` 全量回滚实测 |
| `4c92a1d` | 接线进 Godot（接入层 + 门禁）、生成器幂等修复、漂移归零 |

## 五、当前实测基线（改坏之前先对照这里）

```
python world-model/tools/accept.py --smoke 5   → 退出码 0
  数据校验：检查总数 64608 / 失败 0
  测试套件：用例 39 / 通过 39 / 失败 0
  冒烟跑局：5/5 走到结算，异常终止 0

python world-model/tools/check_upstream_drift.py → 检查项 5204 / 漂移项 0（退出码 0）

Godot headless 全量 unit → Scripts 215 / Tests 1556 / Passing 1556 / 失败 0（退出码 0）
```

固定种子指纹（跨机器核对用）：

```
seed 101: content_sha256 = 584e141d68f085e7d1e49019f86d44c67ba3930b662d12dc1ed29b913a8c689d
          结局 通关｜节点 48｜战斗 14 场 / 81 回合｜终局 2 转｜蛊虫 21 只
```

> 指纹不一致 = `world-model/data/` 被改过。先跑 `check_upstream_drift.py` 判断是上游变了还是本地被改。

## 六、已知未决 / 需人工决定

1. **`export_presets.cfg` 未收窄**：Release 包会包含 `world-model/schema`、`rulings`、`saves`（Python 引擎存档目录）。收窄只需在 `exclude_filter` 追加几行，但会改变发布产物，未擅自执行。
2. **`gate_sabotage.log`**（仓库根）：门禁负控的实测日志，未删除。
3. **`generated/_shortlist_spec.txt`**：未跟踪文件，来源不明，非本工作流产物。
4. **世界模型与 Godot 数据尚未统一**为单一真源：目前是「Godot `data/` 为运行时真源 + world-model 派生视图 + 门禁保证一致」。若要变成单一真源，需要另立裁定。
5. **6–9 转内容为 0**：`gu.json` 只有 1–5 转（含 1 只测试实体）。若首发范围上移，`cultivation_factor` 与 `stage_base_battle` 只到 5 转——**这是放开范围前必须先补的表**。两侧现在都不再给出错值：战斗侧 `essence_max_battle` 抛 `NumericOverflow`（原有行为），局外侧 `essence_max` 自 2026-09-18（`q8h-001`）起同样抛 `NumericOverflow`——此前是静默回落到 1 转默认值（`rules.py` 的 `.get(..., 1)`），即"看着合理的错数"，现已加回归锁。放开范围前只需补表，不会再出现静默降级。

## 七、快速验收（复制粘贴，Windows PowerShell）

```powershell
cd <repo root>

# 1) 世界模型自检
python world-model/tools/accept.py --smoke 10
python world-model/tools/check_upstream_drift.py

# 2) Godot 侧门禁 + 全量
$g = "C:\Users\Zachary\DevEnv\tools\Godot_v4.7.2-stable_win64_console.exe"
& $g --headless --path . --import
& $g --headless --path . -s addons/gut/gut_cmdln.gd -gtest res://tests/unit/test_world_model_bridge.gd -gexit -glog=1
& $g --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=1
```

## 八、回滚

| 场景 | 做法 |
| --- | --- |
| 回滚某次数据改动 | `snapshot.py restore <id> --yes`（覆盖式）或 `--prune`（连新增文件一起清） |
| 回滚整个世界模型 | `git rm -r world-model`（Godot 侧仍需一并回滚 `scripts/domain/world_model_bridge.gd`、`tests/unit/test_world_model_bridge.gd`、门禁测试） |
| 回滚接线 | `git revert 4c92a1d`；游戏行为不受影响（接入层只读） |
| 回滚约束体系 | `CONSTRAINTS-V2.md` 与 `rulings/RUL-2026-09-17-003.json` 各自可删，旧 AGENTS.md/契约文档仍在原位 |
