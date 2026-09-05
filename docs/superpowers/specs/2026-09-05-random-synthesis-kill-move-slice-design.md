# 随机合成杀招最小闭环设计

> 审阅：✅ 2026-09-06 用户审订通过（定稿）。注：802 目录重建后 slice 相关配方已删除，本文档保留为决策记录；现行杀招语义按 master plan「只留数据地基」执行。

## 目标

建立一个可玩的最小 V1 闭环：新局开始，玩家沿随机路线取得蛊虫，使用固定配方合成组合杀招，进入战斗，执行组合杀招，并通过统一流程结束本局。

“随机”表示每次尝试使用新随机种子。集成驱动在当前种子无法满足闭环时重滚，不注入资源、不直接修改 RunState。

## 范围

### 本次实现

1. 复用 `data/refinement_recipes.json` 的固定蛊虫配方；不把 `data/synthesis.json` 的旧战斗材料配方当作本 slice 配方。
2. 为本 slice 给至少一条固定配方增加显式 `kill_move_id` 输出映射，并在 `data/v1_battle.json` 给该杀招声明定义和成本。
3. 复用现有 `ActionPreviewService`、`Resolver`、`BattleCommandFacade` 和 `RunController.submit_command()`。
4. 为配方输入、蛊虫输出、杀招映射、杀招预览和战斗执行补充必要单元测试。
5. 增加一条随机种子重滚集成流程，验证真实路线、真实合成、真实战斗和真实终局。
6. 输出每次尝试的最小闭环证据：种子、取得的输入蛊、配方、输出蛊、生成杀招、战斗命令、终局视图或合法终局。

### 明确不做

1. 不新增独立合成服务。
2. 不恢复旧 deck / hand / discard 领域模型。
3. 不新增随机配方或乱炼规则。
4. 不注入蛊虫、材料、配方、战斗状态或胜利结果。
5. 不绕过 `RunController.submit_command()`。
6. 不改变现有培养门槛、资源校验、战斗规则或 `insufficient_qi_quality`。
7. 不扩展无关 UI、地图、经济和 Ending 功能。

## 现有模块职责

- `data/refinement_recipes.json`：固定蛊虫配方，明确声明 `input_gu_ids` 和 `output_gu_id`。
- `data/v1_battle.json`：战斗杀招定义，明确声明 `id`、`recipe`、资源成本和效果。
- `data/synthesis.json`：旧战斗内材料合成合同，仍由旧战斗路径使用；本 slice 不复用它作为蛊虫组合配方。
- `ActionPreviewService`：只读生成固定配方和战斗杀招卡，报告成本、输入、输出和阻断原因。
- `Resolver`：执行 `refine_gu`，消费输入，生成合成结果并更新 `RunState`。
- `BattleCommandFacade`：处理 `play_kill_move` 的战斗命令转发与结算。
- `RunController`：创建随机新局、提交路线和战斗命令、切换 Battle / Ending 视图。
- 集成测试驱动：只观察控制器，通过真实命令推进，不调用领域 resolver 直接执行流程。

## 数据合同裁定

本 slice 只使用一条可追踪链：

```text
固定配方 input_gu_ids
  -> Resolver.refine_gu
  -> output_gu_id 实例进入 RunState
  -> v1_battle.kill_moves[].recipe 引用 output_gu_id
  -> BattleCommandFacade.play_kill_move(kill_move_id)
```

`input_gu_ids` 和 `output_gu_id` 是合成的唯一输入输出字段。`kill_move_id` 是战斗命令的唯一输出标识，不从显示名称、标签或 `combat` 字段推断。为避免“配方成功但战斗没有杀招”，本 slice 选定的固定配方必须声明 `kill_move_id`，且该 ID 必须精确匹配 `v1_battle.kill_moves[].id`；对应杀招的 `recipe` 必须包含该配方的 `output_gu_id`。输入蛊和输出蛊 ID 必须存在于 `gu_by_id`，杀招引用的蛊定义也必须存在。

当前 `data/synthesis.json` 的 `material_cost -> temp_card_id` 只表达战斗内临时卡，不表达蛊虫输入、合成输出或 V1 `kill_moves`，因此不能作为本 slice 的数据来源。当前 `v1_battle.json` 尚无可供该链执行的杀招定义；实现前必须补一条最小、显式且可校验的固定配方到杀招映射，否则随机重滚只能掩盖数据缺口，无法完成闭环。

`ContentCatalog.validate()` 在加载阶段拒绝以下合同错误：固定配方缺少输入或输出、输入/输出蛊 ID 不存在、`kill_move_id` 不存在、杀招 `recipe` 未包含输出蛊，或杀招引用未知蛊。集成测试遇到路线条件不足才重滚；遇到 catalog 合同错误直接失败。

## 蛊虫获取合同裁定

获取不是“出现一个 Gu ID”就算成功。每个成功的买入、交换、掉落或合成输出都必须满足同一实例合同：

```text
catalog-known definition_id
  -> unique instance_id
  -> state == "refined"
  -> rank 在 1..5
  -> cave_aperture.stored_gu_instance_ids 包含 instance_id
  -> gu_instances、gu_ids、refined_gu_ids 同步
```

现有 `RunState.new_run()` 已提供 `small_light_gu` 作为确定起点。其余获取渠道包括掉落、商店购买、商队交换和事件/遭遇奖励；这些渠道必须全部经过共享实例账本，不能各自只写 legacy `gu_ids`。固定配方所需输入必须至少有一条真实公共渠道可达：起始蛊、已配置节点奖励、商店/商队 offer 或明确事件奖励。若某输入只有极低概率掉落而没有可观测预览，不能作为本 slice 的唯一输入。

获取前校验 `definition_id` 存在且可进入 V1；校验失败时不扣材料、元石或其他资源。获取成功后测试读取真实 `RunState` 实例和预览，不直接写入资源。路线无法取得输入属于尝试失败，可以重滚；未知 ID、实例账本不同步或输出无法进入 V1 属于数据合同失败，必须立即失败，不能重滚。

## 蛊虫效果合同裁定

本 slice 的 V1 效果使用声明驱动，不使用角色效果猜测。`v1_effect` 是 V1 唯一 canonical 字段；支持的 `kind` 只有当前 `_apply_effect()` 已实现的 `strike`、`shield`、`buff`、`heal`、`heal_and_strike`、`status`、`shift`。每个 slice 使用的蛊必须显式声明一种受支持效果，并通过 catalog 校验必需字段、字段类型、非负数值和状态名称。

当前 `data/gu.json` 大多数定义只有 legacy `combat_effects`，V1 会在缺少 `v1_effect` 时按 `role` 生成泛化效果。这会丢失声明中的精确伤害、标记、延迟、范围、伤势治疗和临时属性。该兼容行为不作为本 slice 的数据合同。只为 slice 实际使用的输入蛊、输出蛊和杀招配方蛊补显式 `v1_effect`；不把 214 只蛊一次性迁移。

未知 `v1_effect.kind` 或未实现的 legacy effect 不得静默成功。catalog 校验应拒绝 slice 依赖的未知效果；运行时也必须在效果无法解析时返回明确拒绝，不扣除已声明资源后假装执行。预览必须展示声明效果和目标类型，不能用“催发蛊虫效果。”掩盖无实现效果。

## 数据流

```text
新随机种子
  -> RunController.start_new_run()
  -> MapGenerator 生成路线
  -> 真实 travel / encounter 命令取得蛊虫
  -> ActionPreviewService 找到可执行固定配方
  -> RunController.submit_command(refine_gu)
  -> Resolver 消费输入并生成组合杀招
  -> 真实 travel 命令进入 Battle
  -> ActionPreviewService.preview_battle_actions()
  -> RunController.submit_command(play_kill_move)
  -> BattleCommandFacade / V1BattleResolver 结算
  -> 真实 Ending 视图或合法终局
```

组合杀招输入、输出和执行命令必须来自现有数据与预览合同。测试不得根据内部实现猜测结果后直接写状态。

## 随机重滚策略

集成测试为每次尝试生成新的随机种子，并设置固定最大尝试次数。每次尝试从全新 `RunController` 和全新 `start_new_run(seed)` 开始。

驱动策略：

1. 在 Map 选择当前可达且未处理路线节点。
2. 在 Shop、Caravan、Encounter、Refine 等屏幕读取现有预览或节点合同，提交可执行真实命令。
3. 优先保留或取得固定配方所需输入蛊。
4. 在 Refine 屏寻找可执行固定配方，提交 `refine_gu`。
5. 合成成功后，继续使用真实路线进入战斗。
6. 在 Battle 读取杀招预览，提交 `play_kill_move`。
7. 观察 `controller.current_view_name() == "Ending"`，或记录控制器报告的合法死亡/终局。
8. 当前种子缺少输入、配方锁定、杀招不可执行、命令被拒或无法抵达战斗时，记录原因并开始下一次新种子。
9. 达到最大尝试次数仍未完成时，测试失败并输出所有尝试摘要。

重滚只改变测试尝试种子。它不能改变当前局状态，也不能把失败尝试标记为成功。

## 错误与边界

- 缺少输入蛊：预览返回不可执行和明确缺失项；驱动结束当前尝试。
- 配方锁定：保持现有图鉴门禁；驱动记录锁定原因。
- 合成资源不足：保持现有资源拒绝；不借贷、不补资源。
- 合成失败：遵守现有配方失败规则；当前尝试不得声称生成杀招。
- 杀招资源不足或不满足战斗条件：预览保持不可执行；驱动记录原因。
- `play_kill_move` 被拒：记录实际拒绝原因并结束当前尝试。
- 战斗死亡：属于合法终局，但只有已经完成合成和执行杀招的尝试才能满足完整闭环断言。
- Ending 证据必须来自 `current_view_name()`，不能从 terminal 状态或结果字符串推断。

## 单元测试

在现有相关测试文件中补充最小合同覆盖，不新建只有少量用例的测试套件：

1. 固定配方预览暴露 `input_gu_ids`、`output_gu_id`、可选材料成本、`kill_move_id` 和可执行状态。
2. 输入缺失、配方锁定和资源不足返回不可执行及明确原因。
3. 每个 slice 获取渠道返回 catalog-known、唯一且已存入洞天的蛊实例；未知输出不会扣除资源。
4. `refine_gu` 成功消费指定输入，并在状态中生成声明的 `output_gu_id`。
5. slice 使用的每只蛊都暴露显式、受支持的 `v1_effect`；预览显示效果和目标，不依赖 role 猜测。
6. 未知效果 kind 或缺少必需效果字段在 catalog 校验或命令预检阶段明确失败，不静默成功。
7. 合成结果能按显式 `kill_move_id` 在战斗预览中找到；不存在映射时 catalog 校验失败，不进入随机驱动。
8. 合成失败遵循既有失败规则，不留下伪造输出。
9. 战斗预览暴露组合杀招及其成本、目标和执行条件。
10. `play_kill_move` 经 `BattleCommandFacade` 被接受，并产生对应战斗效果或合法拒绝。
11. 未经合成时，组合杀招不可执行或不存在。

测试只锁定数据合同和命令合同，不复制完整路线流程。

## 集成验收

新增或收紧一条集成测试，验证：

1. 至少一次尝试使用新随机种子。
2. 真实路线取得固定配方输入蛊。
3. 真实 `refine_gu` 成功。
4. 状态真实包含生成的组合杀招。
5. 真实进入 Battle。
6. 真实提交一次 `play_kill_move`。
7. 组合杀招命令被接受，或产生明确合法终局结果。
8. 最终观察到 Ending 或合法终局。
9. 完整闭环成功时，证据字段完整；失败尝试保留明确分类。
10. 不直接调用 `Resolver.apply()`、`BattleCommandFacade.start()` 或内部状态写入来推进流程。

验收重点是闭环真实可玩，不要求单个预先指定种子必然成功。最大重滚次数必须固定，避免无限循环和不可重复测试。

## 实现约束

只修改支撑该 slice 的最少文件。优先复用现有预览、命令封装和测试辅助函数。若现有接口无法表达组合杀招，先扩展最小现有接口，再避免新建抽象层。

实现完成后运行：

```text
powershell.exe -File tools/test.ps1 -Test <相关单元测试>
powershell.exe -File tools/test.ps1 -Test <随机闭环集成测试>
powershell.exe -File tools/test.ps1 -Suite unit
powershell.exe -File tools/test.ps1 -Suite integration
powershell.exe -File tools/check.ps1
```

测试失败必须区分：路线无法满足、预览合同错误、合成执行错误、战斗命令错误和终局观察错误。
