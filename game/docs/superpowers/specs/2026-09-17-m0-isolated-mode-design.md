# M0 独立垂直切片设计

## 背景与目标

当前完整运行流已经包含多层地图、商店、炼蛊、流派和自动战利品结算，但它不能直接证明 M0 契约：现有 Reward 屏是“战利品已自动入账”的确认屏，没有三选一；完整路线也远超四场战斗。

本设计新增一个独立的 M0 运行入口，验证最小可玩闭环，不改变现有完整运行流的默认语义：

```text
普通战斗 → 普通战斗 → 精英/事件战斗 → Boss
       ↓          ↓          ↓
    三选一奖励 → 三选一奖励 → 三选一奖励
```

Boss 击败即成功；玩家死亡进入结算页，可返回大厅并立即开启下一局。

## 方案

### 运行入口与路线

在 `RunController` 增加 `start_m0_run(seed)`。它初始化正常 `RunState` 和内容目录，但只注入 M0 起始蛊虫，设置 `m0_mode = true`，并使用 `M0RunFlow` 生成四个线性节点：

1. `ridge_hound` 普通战斗；
2. `iron_hide_boar` 普通战斗；
3. `ridge_elite_scout` 精英战斗；
4. `miasma_vein_lord` Boss 战。

节点使用现有 `RunTravelFlow`、`RunBattleFlow` 和 `BattleCommandFacade`，不创建第二套战斗规则。M0 模式只改变路线、奖励和 Boss 成功出口。

### 大厅入口与存档

大厅保留完整运行的 `new_run` 入口，并新增可见的 `M0 · 四战试炼` 按钮；按钮通过现有 `RunCommandBuilder` 提交 `new_m0_run`，不是测试专用入口。M0 标记写入既有 `RunState.node_flags.m0_mode`，沿用 v4 路由与状态存档，重载时恢复 M0 模式与四节点路线；不新增永久成长或独立存档格式。

### 奖励语义

新增 `M0RewardResolver`，负责确定性地产生三个互不重复的奖励选项，并在选择时一次性写入事件日志：

- 蛊虫：向当前蛊囊添加一个可用于后续战斗的蛊实例；
- 恢复：恢复固定生命值但不超过上限；
- 资源：增加固定元石。

选项由运行种子和战斗序号派生，不能靠 UI 重抽。战斗原有的材料/元石基础结算保留；M0 三选一作为明确的战后构筑选择，选择前不得离开奖励屏。

### UI 接线

M0 Reward snapshot 暴露 `choice_rewards`。Reward 屏在 M0 模式显示三个可点击按钮；点击后发送 `m0_reward_take`，按钮锁定，随后“继续旅程”才可离开。完整运行流仍显示旧的自动入账确认卡。

### 成功与失败

- M0 Boss 胜利直接进入 Ending，结局记录 `m0_boss_defeated`；
- 普通战斗不能通过撤退完成 M0 路线；
- 死亡仍走现有死亡结算页；返回大厅后再次调用 `start_m0_run`，断言新状态为 active 且路线重新从第一场开始。

## 数据流

```text
start_m0_run
  → M0RunFlow.build_route
  → existing travel/battle facade
  → victory
  → M0RewardResolver.build_options
  → Reward snapshot choice_rewards
  → m0_reward_take
  → Resolver.apply → M0RewardResolver.apply_choice
  → leave_encounter
  → next battle
```

## 错误与门禁

- 选择未知奖励、重复选择或不在当前选项池中的奖励，一律拒绝且不改状态；
- M0 Reward 屏未选择前，`leave_encounter` 返回 `m0_reward_choice_required`；
- 选项应用成功后保留三张已禁用卡片用于回显，离开 Reward 时清空本次选项；应用失败时不改变选项，玩家仍停留在 Reward 屏；
- M0 模式不得调用普通战斗撤退作为成功路径；Boss 继续沿用既有不可撤退门禁。

## 验收证据

新增集成测试覆盖：

1. 单局恰好完成四场战斗，三场普通/精英战斗各经过三选一奖励，最终 Boss 胜利；
2. 每次奖励选择后蛊囊、生命或元石发生对应变化，且重复提交被拒绝；
3. 两个不同种子得到不同的奖励选择签名，并至少选择出不同 Build；
4. 失败后回到大厅，重新开始 M0 时状态为 active、战斗计数清零、路线回到第一节点；
5. M0 UI 路径全程无 `battle_retreat`，所有战斗胜利事件均为 `battle_finished/reason=battle_victory`。

## 非目标

本次不改完整运行流的自动战利品语义，不实现完整三选一奖励池、永久成长、复杂路线、完整炼蛊、喂养、剧情树或美术重做。M0 通过后再决定哪些机制进入 M1。
