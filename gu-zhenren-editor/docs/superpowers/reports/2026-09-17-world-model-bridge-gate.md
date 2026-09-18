# 世界模型接入 Godot + 上游漂移收口（2026-09-17）

> 范围：`world-model/` 生成器幂等化 + 商店报价漂移补齐 + Godot 侧只读接入层与一致性门禁。
> 约束依据：`world-model/governance/CONSTRAINTS-V2.md`（R1 数据即规范 / R2 一条命令验收 / R4 改前快照）。
> 改前快照：`world-model/.snapshots/20260917T140017-before-godot-bridge-and-idempotency-fix`（`tools/snapshot.py take`）。

## 1. 变更文件

| 文件 | 动作 | 作用 |
| --- | --- | --- |
| `world-model/tools/build_world_model.py` | 改 | 4 处人工策展内容改为生成器常量/稳定排序，消除"重生成即回退策展"的不幂等；`shop_offers` 补带 `npc_only` |
| `world-model/tools/check_upstream_drift.py` | 改 | 补 3 类此前漏检的漂移：蛊 `effect_source`、报价逐条（id 集合/kind/tier/stone_cost/npc_only）、节点逐条（id 集合/stage/type） |
| `world-model/data/{balance,economy,gu,manifest,regions}.json` | 改（生成产物） | 重生成结果：补齐 `purchase_blood_droplet`、货郎 `stage`、5 只蛊的显式效果等上游事实 |
| `world-model/reports/validation-report.md` | 改（生成产物） | `validate_world_model.py` 运行时重写（时间戳 + 检查条数，0 失败） |
| `scripts/domain/world_model_bridge.gd` | 新增 | Godot 侧只读接入层：读 `res://world-model/data/*.json`，暴露蛊/敌人/配方边/报价/价值锚 |
| `tests/unit/test_world_model_bridge.gd` | 新增 | 一致性门禁：逐条比对 `data/` 与 `world-model/data/`，含 `SABOTAGE` 负控 |
| `docs/superpowers/reports/2026-09-17-world-model-bridge-gate.md` | 新增 | 本报告 |

未改动：`world-model/governance/CONSTRAINTS-V2.md`、`data/`（生产数据）、`export_presets.cfg`（理由见 §5）。

## 2. 生成器不幂等的实际范围（比预期大）

最初只报告了 `balance.economy.gu_value_anchor_exceptions` 一处。实测"把当前生成器重跑一遍"与已入库产物的差异后，实际有 **4 类人工策展内容会被重生成抹掉**，另有 3 类上游漂移未同步：

| # | 现象 | 处理 |
| --- | --- | --- |
| 1 | `balance.json` 的 `economy.gu_value_anchor_exceptions`（13 条）+ `_note_zh` 只有手工版有 | 移入生成器常量 `GU_VALUE_ANCHOR_EXCEPTION_IDS` / `_NOTE_ZH`（选"常量表"而非"读回产物"，因为读回产物会让构建依赖上一次的输出，删掉 `world-model/data/` 就无法从上游自举） |
| 2 | `gu.json` 的 10 只策展蛊 `adaptation_note` 被重生成降级为短文案 | 把策展文案写回 `CURATED_GU_DEFAULT` |
| 3 | `gu.json` 的 `gu_stats.by_source_class_note` 只有手工版有 | 移入生成器常量 `SOURCE_CLASS_NOTE_ZH`，按原位置插在 `by_source_class` 之后 |
| 4 | `gu.json` 实体顺序为按 id 排序，生成器按上游顺序输出（802 条下标整体位移） | `entities.sort(key=id)`，顺序只由 id 集合决定 |
| 5 | 上游新增报价 `purchase_blood_droplet`（38 vs 37） | 重生成同步 |
| 6 | 上游货郎节点 `stage` two→one、NPC 货架换货、L1/L2 层模板重排 | 重生成同步 |
| 7 | 上游给 5 只蛊补了显式 `v1_effect`（`effect_source` role_default→explicit，`moon_ray_gu` 伤害 2→4） | 重生成同步 |

同步后逐项核对：**`source_class` 无一变化**（536 original_game_content / 266 canon）、**`value` 无一变化**、**`adaptation_note` 无一变化**、13 条价值锚例外逐条保留。即"重生成"只带来上游事实同步，没有回退任何既有语义。

## 3. 验收实测

### 1) `python world-model/tools/accept.py --smoke 5` → 退出码 0

```
[PASS] 1 数据校验（schema/引用/数值/环）   0.3s  报告：world-model/reports/validation-report.md
[PASS] 2 测试套件（断言式，全量）          5.0s  用例：39｜通过：39｜失败：0
[PASS] 3 冒烟跑局（5 局）                 0.3s  5/5 局走到结算，异常终止 0
结论：全绿，可提交（退出码 0）
```

### 2) 生成器连跑两次 → 产物逐字节一致；随后 accept 仍 0

```
python world-model/tools/build_world_model.py --generated-at 2026-09-17T00:00:00Z   # 连跑两次，两次 exit 0
balance.json     40e28aab3922ee5e30ebd0f2..  run1==run2: True
economy.json     6cba9e0a11667dd450a1b0e2..  run1==run2: True
events.json      ac8e26b1877fd5b5ac4cb1ef..  run1==run2: True
factions.json    ac7c481c6a8d56f4820d0b79..  run1==run2: True
gu.json          b00eda64ec505fb9614e5ebe..  run1==run2: True
loot.json        a6bb7c01b110f4f9c904718a..  run1==run2: True
manifest.json    59cd417d7e65303f900ea324..  run1==run2: True
paths.json       54155a80cb7b8471350bfa31..  run1==run2: True
realms.json      78517be20bb9cee27d23e7aa..  run1==run2: True
regions.json     9e862cf2c28de6e9ec8bcb3e..  run1==run2: True
VERDICT 产物逐字节一致 = True
--- accept after regeneration --- 结论：全绿，可提交（退出码 0）
```

**一条必须说明的边界**：`generated_at` 取墙钟。不加 `--generated-at` 连跑两次，唯一差异就是时间戳（10 个文件各 1 行；`manifest.json` 22 行，因为内嵌的每文件 sha256 也会随之变化——实测两次无参运行 40 行差异全部是时间戳及其派生哈希）。工具本来就提供 `--generated-at` 做可复现构建，仓库里现有产物的 `generated_at` 也正是 `2026-09-17T00:00:00Z`，所以逐字节判定用该固定值给出；我没有改动"不加参数就用当前时间"这一既有语义。

### 3) `python world-model/tools/check_upstream_drift.py` → 退出码 0

```
检查项：5204｜漂移项：0
结论：未检测到漂移。        （改前：检查项 4176｜漂移项 1）
```

加固的有效性有独立负控：把检测器的根指向改动前快照（`.snapshots/.../data/`）后运行，能一次报出**全部 7 项**旧漂移（改前只报得出 1 项）：

```
gu[bear_strength_gu].effect_source: 上游='explicit' 世界模型='role_default'
gu[blood_def_1_21_gu].effect_source: 上游='explicit' 世界模型='role_default'
gu[blood_mov_1_22_gu].effect_source: 上游='explicit' 世界模型='role_default'
gu[moon_ray_gu].effect_source: 上游='explicit' 世界模型='role_default'
商店报价数量: 上游=38 世界模型=37
报价缺失：['purchase_blood_droplet']
节点[wandering_peddler].stage: 上游='one' 世界模型='two'
→ 退出码 = 1
```

### 4) Godot 全量 unit 套件 → 0 失败

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --import          # exit 0
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit -glog=1

Scripts             215     （基线 214，+1 = 新门禁测试文件）
Tests              1556     （基线 1548，+8 = 新门禁用例）
Passing Tests      1556
Asserts           52290
Warnings              2
Orphans               2
SCRIPT ERROR 行数      0
```

数字口径说明：基线（214 / 1548 / 52264）来自用户实测，我没有在改动前的树上重测，因此 `Asserts` 的 +26 中只有 +20（本文件实测断言数）能归因于本次新增；其余 +6 未定位到具体来源（已确认没有任何既有用例读取 `world-model/`，也不会因新增 `.gd`/测试文件而改变断言数）。用例数 +8、通过 +8、失败 0 与本次改动自洽。

### 5) 新门禁单独运行（含负控两态）

```
... -gtest res://tests/unit/test_world_model_bridge.gd -gexit -glog=1

[SABOTAGE = false]  Tests 8 / Passing 8 / Asserts 20 / exit 0   "All tests passed!"
[SABOTAGE = true ]  Tests 8 / Passing 5 / Failing 3 / Asserts 16/20 / exit 1
    [Failed]:  SABOTAGE 负控开关被打开：门禁当前处于人为损坏状态
    [Failed]:  ARRAY(["gu bear_strength_gu.value: 生产=5.0 世界模型=-999"]) != ARRAY([]).
               蛊逐只 rank/value/school/role 应与生产一致
    [Failed]:  [37] expected to equal [38]:  商店报价条数：世界模型 vs 生产 data/shops.json
[SABOTAGE 恢复为 false]  Tests 8 / Passing 8 / Asserts 20 / exit 0
```

负控打开时**只有被人为污染的两条通路**（蛊表、报价表）加一条守卫用例失败，其余 5 条仍通过——说明门禁是在真比较内容，不是"读得到文件就算通过"。测试文件另设 `test_gate_is_not_left_sabotaged`，防止把 `SABOTAGE=true` 提交进仓库。

### 6) 导出是否包含 `world-model/data/*.json`

**结论：已包含，无需改 `export_presets.cfg`。** 实测（模板已装）：`--export-pack "Windows Desktop"` 后用导出器自身的打包日志核对文件表：

```
res://world-model/data/{balance,economy,events,factions,gu,loot,manifest,paths,realms,regions}.json
res://world-model/schema/world-model.schema.json
res://world-model/rulings/RUL-2026-09-17-003.json
res://world-model/saves/hall.json
```

原因：预设是 `export_filter="all_resources"`，Godot 4.7 下它把工程树里的数据文件一并打包（`.json` 并不需要 importer），而 `exclude_filter` 未列 `world-model/`。所以接入层在导出包里也能读到数据，`is_available()` 为 true；工程内仍保持"必须先问 `is_available()`"的写法，以便未来收窄导出时优雅降级。

>>> 顺带发现（未处理，交用户裁定）：`world-model/saves/hall.json`（Python 引擎的存档目录）与 `rulings/`、`schema/` 也一起进了 Release 包。这与 AGENTS.md「Release 构建不包含开发调试入口、语料、测试和受排除资源」的口径不一致。收窄只需在 `exclude_filter` 追加 `world-model/schema/*, world-model/rulings/*, world-model/saves/*, world-model/runs/*`（若要连数据一起排除则加 `world-model/*`，接入层会自动降级为 `is_available()==false`）。**我没有擅自改动导出行为**，因为它会改变 Release 包内容，超出本次任务边界。

## 4. 接入层的加载方式与 API

- 路径：`res://world-model/data/<doc>.json`（`WorldModelBridge.DATA_DIR`），10 份文档名为 `DOC_NAMES`。
- 读取：`FileAccess.file_exists` + `FileAccess.get_file_as_string` + `JSON.parse_string`；解析失败返回 `{}`，不抛错。
- 定位：`class_name WorldModelBridge`（`scripts/domain/world_model_bridge.gd`），`--import` 已注册为全局类（导入日志 `update_scripts_classes | WorldModelBridge`）。
- 只读访问器：`is_available()`、`missing_docs()`、`load_doc()`、`entities_of()`、`gu_entities()/gu_by_id()`、`enemy_entities()/enemy_by_id()`、`recipe_edges()/recipe_edge_by_id()`、`shop_offers()/shop_offer_by_id()`、`gu_value_by_rank()`、`gu_value_anchor_exceptions()`、`world_model_version()/generated_at()`。
- 边界：**不是运行时数据源**。生产代码没有任何路径调用它；游戏仍从 `data/` 读定义（`ContentCatalog`）。两表不一致由门禁报警，而不是由接入层在运行时替选数据。

## 5. 门禁覆盖范围

| 比对项 | 口径 |
| --- | --- |
| 蛊 | 条数 + 逐只 `rank`/`value`/`school`/`role` |
| 敌人 | 条数 + 逐条 `hp`/`rank`/`tier` |
| 配方边 | 带产物的配方 id 集合 |
| 商店报价 | 条数 + id 集合 + 逐条 `kind`/`tier`/`stone_cost`/`npc_only` |
| 价值锚 | `gu_value_by_rank` 全表 |
| 价值锚例外 | 与**生产蛊表**反向核对：偏离锚值未登记 = 失败；登记了却等于锚值 = 失败（与 `validate_world_model.py` 同规则、不同数据源） |

防退化：每个比对前先断言上游侧非空（`assert_gt(size, 0)`），避免"两边都读到空数组"把门禁变成恒真。

## 6. 偏差、未做与未验证

1. **不幂等的实际范围比任务描述更大**（4 类而非 1 类）。原因：生成器与已入库产物之间除该字段外还有 3 处人工策展未回写生成器。只修 `gu_value_anchor_exceptions` 会让"重生成"把另外 3 处一起抹掉，与"不要改动既有语义"直接冲突，因此一并纳入。
2. **产物重排缩进（1 空格）**：`balance.json`/`gu.json`/`manifest.json` 三份此前被外部编辑器按 2 空格重排，生成器统一写 1 空格（另外 7 份本来就是 1 空格）。这三份的 diff 含纯缩进变化，是本轮"让产物真正等于生成器输出"的机械结果；`balance.json` 的结构差异为 0（只差缩进），`gu.json` 的结构差异仅 8 处（见 §2 表 4/7 项）。
3. **`generated_at` 仍是墙钟**（见 §3-2）。未改为内容哈希，避免改变"生成时间"的语义。
4. **未做**：`export_presets.cfg` 收窄（§3-6，交裁定）；`world-model/data` 与 `data/` 的敌人 `theme`/`grade`、流派、材料逐字段门禁（Python 检测器已覆盖，Godot 门禁按任务要求聚焦蛊/敌人/配方边/报价/价值锚）。
5. **脚手架残留**：负控实测日志留在仓库根 `gate_sabotage.log`（未纳入 .gitignore）；按"不删除任何文件"的边界我没有清理，可随时删除。
6. **未验证**：真窗（非 headless）交互链路——本次改动没有触及任何运行时/UI 路径，故未按"仅用户主动要求才开真窗"的契约开窗。
