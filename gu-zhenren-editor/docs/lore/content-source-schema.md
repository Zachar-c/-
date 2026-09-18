# 内容来源字段规范

未来面向玩家的内容数据，无论是蛊虫、事件、势力、首领、遗藏或结局，都应带有下列来源元数据。它们属于开发审查字段，可在发布构建中保留或剥离，但制作阶段不得省略。

```json
{
  "id": "small_light_gu",
  "rank": 1,
  "energy_type": "primeval_essence",
  "activation_cost": 3,
  "feeding_interval": "phase_end",
  "feeding_requirements": [
    { "material_id": "light_grass", "amount": 2 }
  ],
  "effect": {
    "effect_id": "assist_moonblade",
    "parameters": { "damage_multiplier": 2 }
  },
  "roles": ["support"],
  "name": "小光蛊",
  "summary": "辅助月光蛊的凡蛊。",
  "lore_summary": "原著中可与月光蛊配合增强月刃。",
  "refinement_recipes": [],
  "advancement_recipes": [],
  "purchase_price_range": { "min": 0, "max": 0 },
  "value": 0,
  "source_class": "adaptation",
  "source_ids": ["CAN-SMALL-LIGHT-001", "CAN-SMALL-LIGHT-002", "ADP-SMALL-LIGHT-001"],
  "adaptation_note": "信息效果为游戏扩展，不是原著直接能力。",
  "canon_review_status": "approved"
}
```

## 字段

| 字段 | 类型 | 规则 |
| --- | --- | --- |
| `rank` | integer | 蛊虫转数，取值为 `1` 至 `9`。首发可用内容只能为 `1` 至 `3`。 |
| `energy_type` | string | 催发能量类型，使用 `primeval_essence` 或 `immortal_essence`。首发凡蛊只能使用 `primeval_essence`。 |
| `activation_cost` | number | 每次催发消耗的真元或仙元；不得用统一默认值抹平差异。 |
| `feeding_interval` | string | 喂养成本结算节奏。首发固定为 `phase_end`，第一、二阶段结束时自动汇总为元石总账。 |
| `feeding_requirements` | object array | 每次阶段养护所需材料和数量，用于推导总账、交易价与世界观说明；首发不要求玩家逐项收集或手动投喂。 |
| `effect` | object | 可测试、可复现的规则效果；使用 ASCII 的 `effect_id` 与参数，不能把规则藏在文案中。 |
| `roles` | string array | 主要用途，首发使用 `attack`、`defense`、`support`、`movement`、`healing` 及后续明确扩展项。 |
| `activation_conditions` | object array | 催发所需的可见规则条件，例如真元、冷却、状态、目标或局势；不得用于实现隐藏的战前可用蛊名单。 |
| `lifecycle` | string | 蛊虫在当前跑局中的规则形态，例如 `persistent`、`consumable` 或 `body_modification`；必须与获得和失去逻辑一致。 |
| `persistent_changes` | object array | 消耗蛊或改造蛊造成的当前跑局长期变化。每项须包含规则效果、持续范围、叠加边界与移除条件。 |
| `name` | string | 玩家可见中文名称。 |
| `summary` | string | 玩家可见中文简介，说明当前游戏效果。 |
| `lore_summary` | string | 可选的世界观或原著依据摘要；不可把改编内容写成原著直接事实。 |
| `refinement_recipes` | array | 合炼蛊方；首发未实现时使用空数组，不在规则层假装存在。 |
| `advancement_recipes` | array | 升炼蛊方；与合炼蛊方分开表达。 |
| `purchase_price_range` | object | 正常购买价格区间；具体成交价仍受节点、关系与局势影响。 |
| `value` | number | 基础价值，用于交易、交换与事件结算，不等同于实际买卖价格。 |
| `trade_tags` | string array | 交易偏好标签，用于一换一、多换一、势力指定收购与商队交换池；不能只以基础价值决定所有交换。 |
| `rarity` | string | 首发使用受控稀有度，用于限定直售、交换、传承与遭遇奖励来源；稀有蛊不应默认开放直购。 |
| `source_class` | string | 只能为 `canon`、`adaptation` 或 `original_game_content`。 |
| `source_ids` | string array | 指向 `CAN-` 和/或 `ADP-` 条目；原创内容至少指向其设计条目。 |
| `adaptation_note` | string | `adaptation` 必填，说明扩展或简化；其余类型可为空字符串。 |
| `canon_review_status` | string | 使用 `draft`、`needs_source`、`approved`、`rejected` 之一。仅 `approved` 可进入可玩内容池。 |

## 内容类型要求

| 内容 | 最低要求 |
| --- | --- |
| 蛊虫 | 原著直接蛊虫使用 `canon` 或 `adaptation`；临时名、原创能力或合成效果使用 `original_game_content` 或 `adaptation`。必须声明转数、能量消耗、阶段养护、效果、用途、价值与来源；这些字段不可借固定蛊槽规避。 |
| 事件与遭遇 | 标注其社会环境或规则依据；完整剧情、NPC 和后果通常为原创。 |
| 势力、首领、遗藏 | 除直接获得明确授权的原著实体外，默认 `original_game_content`。 |
| 终局与数值 | 升仙概念可引用原著；阈值、计算和具体结局均为 `adaptation`。 |

## 角色数据的最低字段

蛊师和蛊仙使用独立的角色数据模型，至少应包含以下字段：

```json
{
  "rank": 1,
  "stage": "initial",
  "cultivator_class": "gu_master",
  "aperture_state": "light_membrane",
  "essence_tier": "bronze",
  "aptitude_class": "middle",
  "aptitude_capacity_ratio": 0.44,
  "max_rank_without_aptitude_upgrade": 2,
  "max_essence": 44,
  "essence_recovery": 4
}
```

`rank` 的范围是 `1` 至 `9`，`stage` 使用 `initial`、`middle`、`upper`、`peak`。`cultivator_class` 在一至五转为 `gu_master`，六至九转为 `gu_immortal`；九转另加 `honorific: "venerable"`，用于尊者称谓。`aperture_state` 与 `essence_tier` 分开：前者记录窍壁状态，后者记录青铜、赤铁、白银、黄金或紫晶真元品阶。`aptitude_class` 应区分 `none`、`ding`、`bing`、`yi`、`jia`、`ten_extreme`；其中具体比例需与原著区间及游戏数值规则分别说明。首发玩家增加 `max_rank_without_aptitude_upgrade: 2`，只有获得当前跑局的资质提升内容后才可提高该上限并开启三转突破。

## 炼制配方的最低字段

合炼、升炼、平炼与逆炼应使用统一的配方数据结构，并用 `refinement_type` 区分：

```json
{
  "id": "moonlight_gu_to_moon_glow_gu",
  "refinement_type": "advancement",
  "input_gu_ids": ["moonlight_gu", "small_light_gu"],
  "input_materials": [
    { "material_id": "moon_dew", "amount": 3 }
  ],
  "output_gu_ids": ["moon_glow_gu"],
  "rank_delta": 1,
  "requirements": ["rank_2_cultivator"],
  "risk_profile": "defined_by_recipe",
  "source_class": "adaptation",
  "source_ids": [],
  "canon_review_status": "needs_source"
}
```

`refinement_type` 只能为 `combination`、`advancement`、`lateral`、`reverse`，分别对应合炼、升炼、平炼、逆炼。`rank_delta` 对应为正数、正数、`0`、负数。示例中的蛊虫与配方仅用于字段说明，不代表已审查或已纳入首发内容池。

每张配方还必须有 `failure_outcome`。当其为 `destroy_inputs` 时，炼制失败会直接销毁所有输入蛊虫；首发不得把这类风险简化成只损失材料或无成本重试。

## 玩家杀招方案与残蛊方

杀招不是设计数据中的预设组合，也不是独立获得后替代蛊虫的技能。每只蛊虫的数据只定义自身的效果、条件、真元消耗和可组合的状态变化；多蛊在同一局势中的配合由通用领域规则结算。

玩家可为自己常用的多蛊方案保存一条本地记录：名称、参与蛊虫、建议顺序、目标偏好和备注都由玩家编辑。该记录只为检索、复盘和快捷操作服务，不能在规则上赋予额外伤害、保证触发或绕过条件。

```json
{
  "name": "光剑召来",
  "participant_gu_ids": ["light_sword_gu", "light_source_gu", "light_wing_gu", "recall_gu"],
  "suggested_sequence": ["light_source_gu", "light_sword_gu", "light_wing_gu", "recall_gu"],
  "note": "先增威，再加速射出，回收时二次压迫。"
}
```

示例是玩家的个人方案，不是系统内置杀招、蛊方或已批准首发内容。若玩家或传承将某种多蛊方案进一步推演为单蛊，炼制配方仍按“炼制配方的最低字段”单独审查、单独定义风险与来源。

## 蛊虫交换数据的最低字段

商队和势力提供的蛊虫交换必须是数据化报价，而不是脚本临时发放：

```json
{
  "id": "caravan_trade_rare_support_001",
  "source_type": "caravan",
  "offer_gu_ids": ["rare_support_gu"],
  "requested_gu_tags": ["light", "support"],
  "requested_gu_count": 2,
  "requested_resources": { "primeval_stones": 12 },
  "relationship_requirement": { "faction_id": "local_trade_clan", "minimum": 1 },
  "availability": "limited",
  "source_class": "original_game_content",
  "source_ids": [],
  "canon_review_status": "needs_source"
}
```

一换一以 `requested_gu_count: 1` 表示，多换一使用大于 `1` 的值。报价可要求特定蛊虫、用途或交易标签，并可附带资源与势力条件。示例中的 ID 和内容仅用于字段说明，不代表首发已纳入的势力或蛊虫。

## 传承数据的最低字段

传承不是系统为玩家预设的唯一杀招。它记录前人验证过的局部经验、条件协同或炼制方向，并可在本局提供受限的提示或增益。

```json
{
  "id": "light_attack_mark_legacy",
  "focus_tags": ["light", "attack", "mark"],
  "guidance": "将光类攻伐蛊与标记效果连用，可借标记扩大后续攻势。",
  "rule_effect": {
    "effect_id": "marked_light_damage_bonus",
    "parameters": { "requires_tag_pair": true }
  },
  "scope": "current_run",
  "source_class": "original_game_content",
  "source_ids": [],
  "canon_review_status": "needs_source"
}
```

传承的 `rule_effect` 必须有明确触发条件、数值边界和当前跑局范围。它可以引导一种路线，但不得阻止玩家发现未被传承记载的其他有效组合。

## 现有原型审查结论

当前 `data/gu.json` 中，`small_light_gu` 有可追溯的原著基础，但仍需登记其扩展效果。`trail_eye_gu`、`blood_moss_gu`、`thorn_whip_gu`、`mist_step_gu`、`venom_thread_gu`、`stone_shell_gu`、`shadow_veil_gu` 与 `pulse_drum_gu` 当前没有来源字段，应在第二版内容生产开始前标记为 `needs_source`，并决定其为有依据的改编还是完全原创内容。

当前 `data/npcs.json` 的 NPC 同样为原型内容，未经来源审查不得写成原著人物或原著既定势力。

## 审查流程

1. 制作人填写 `source_class` 与初始 `source_ids`。
2. 设定审查补充原文行号或新增 `ADP-` 条目。
3. 设计审查确认玩法没有越过登记册中的边界。
4. 将 `canon_review_status` 标为 `approved` 后，内容才可进入正式内容池。
5. 改动来源、能力或叙事宣称时，重新审查。
