# Boss 定义探针（只读）

- 敌人总数 32，其中 tier==boss 共 **7**
- 全部敌人字段出现频次: {'id': 32, 'theme': 32, 'grade': 32, 'tier': 32, 'rank': 32, 'hp': 32, 'clues': 32, 'intent': 32, 'reactions': 32, 'phases': 5, '_phases_note': 1}

## 每个 boss 的完整定义

### `blood_vein_bishop`
  - clues = ["swollen_veins", "beating_drum"]
  - grade = cultivator
  - hp = 20
  - id = blood_vein_bishop
  - intent = {"id": "vein_whip", "label": "血络鞭挞", "damage": 4, "speed": 3, "cooldown": 1}
  - phases = [{"until_hp_ratio": 1.0, "intents": [{"id": "vein_whip", "label": "血络鞭挞", "damage": 4, "speed": 3, "cooldown": 1}], "reactions": [{"id": "blood_siphon", "clue": "swollen_veins", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "血络回吸"}]}, {"until_hp_ratio": ...(截断)
  - rank = 5
  - reactions = [{"id": "blood_siphon", "clue": "swollen_veins", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "血络回吸"}]
  - theme = cultivator
  - tier = boss

### `blue_fur_jiangshi`
  - clues = ["blue_fur", "corpse_army"]
  - grade = anomaly
  - hp = 20
  - id = blue_fur_jiangshi
  - intent = {"id": "corpse_tide", "label": "尸潮掩杀", "damage": 4, "speed": 2, "cooldown": 1}
  - phases = [{"until_hp_ratio": 1.0, "intents": [{"id": "corpse_tide", "label": "尸潮掩杀", "damage": 4, "speed": 2, "cooldown": 1}], "reactions": [{"id": "corpse_barrier", "clue": "corpse_army", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "尸群为障"}]}, {"until_hp_ratio ...(截断)
  - rank = 5
  - reactions = [{"id": "corpse_barrier", "clue": "corpse_army", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "尸群为障"}]
  - theme = anomaly
  - tier = boss

### `clan_patriarch`
  - clues = ["frosted_temples", "solemn_robe"]
  - grade = cultivator
  - hp = 19
  - id = clan_patriarch
  - intent = {"id": "clan_wrath", "label": "一族之威", "damage": 4, "speed": 2, "cooldown": 1}
  - phases = [{"until_hp_ratio": 1.0, "intents": [{"id": "clan_wrath", "label": "一族之威", "damage": 4, "speed": 2, "cooldown": 1}], "reactions": [{"id": "ancestral_tablet", "clue": "solemn_robe", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "祖宗牌位"}]}, {"until_hp_rati ...(截断)
  - rank = 5
  - reactions = [{"id": "ancestral_tablet", "clue": "solemn_robe", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "祖宗牌位"}]
  - theme = faction
  - tier = boss

### `crag_serpent_matriarch`
  - clues = ["coiled_shadows", "scraped_scale"]
  - grade = beast
  - hp = 15
  - id = crag_serpent_matriarch
  - intent = {"id": "crush_coil", "label": "绞缠碾压", "damage": 3, "speed": 1}
  - rank = 4
  - reactions = []
  - theme = beast
  - tier = boss

### `marrow_gu_adept`
  - clues = ["bone_charms", "burnt_incense"]
  - grade = cultivator
  - hp = 16
  - id = marrow_gu_adept
  - intent = {"id": "marrow_lance", "label": "蚀骨骨矛", "damage": 3, "speed": 2}
  - rank = 4
  - reactions = [{"id": "bone_thorn_shield", "clue": "bone_charms", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "骨棘反甲"}]
  - theme = cultivator
  - tier = boss

### `miasma_vein_lord`
  - _phases_note = cooldown:n on an intent means fired at turn T, next selectable from turn T+n+1; while every intent of the active phase rests the boss shows cooldown_wait and attacks nothing that turn. Phase thresholds (until_hp_ratio) descend strictly in data order.
  - clues = ["wilting_aura", "slow_gaits"]
  - grade = cultivator
  - hp = 14
  - id = miasma_vein_lord
  - intent = {"id": "miasma_burst", "label": "瘴气喷涌", "damage": 2, "speed": 1}
  - phases = [{"until_hp_ratio": 1.0, "intents": [{"id": "miasma_burst", "label": "瘴气喷涌", "damage": 2, "speed": 1, "cooldown": 2}], "reactions": [{"id": "corrosive_mist", "clue": "wilting_aura", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "蚀气反激"}]}, {"until_hp_rat ...(截断)
  - rank = 3
  - reactions = [{"id": "corrosive_mist", "clue": "wilting_aura", "window": "before_damage", "trigger": "direct_strike", "counter_status": "guarded", "label": "蚀气反激"}]
  - theme = anomaly
  - tier = boss

### `thunder_crown_sovereign`
  - clues = ["charged_fur", "crackling_air"]
  - grade = beast
  - hp = 18
  - id = thunder_crown_sovereign
  - intent = {"id": "crown_bolt", "label": "雷冠贯落", "damage": 4, "speed": 2, "cooldown": 1}
  - phases = [{"until_hp_ratio": 1.0, "intents": [{"id": "crown_bolt", "label": "雷冠贯落", "damage": 4, "speed": 2, "cooldown": 1}], "reactions": []}, {"until_hp_ratio": 0.5, "intents": [{"id": "crown_bolt", "label": "雷冠贯落", "damage": 4, "speed": 2, "cooldown": 1}, {"id": "paralyzing_howl", "label": "麻痹长嗥", "damage ...(截断)
  - rank = 5
  - reactions = []
  - theme = beast
  - tier = boss

## 关底台节点（nodes.json）

### `layer_boss_stand_1` (layer_boss=1)
  - choices = ["fight"]
  - enemy_kind = crag_serpent_matriarch
  - enemy_theme = beast
  - layer_boss = 1
  - next_ids = []
  - on_skip = none
  - stage = one
  - time_scale = days
  - type = combat
  - visible = False

### `layer_boss_stand_2` (layer_boss=2)
  - choices = ["fight"]
  - core_replacement_token = {"claim_core_token": true}
  - enemy_kind = marrow_gu_adept
  - enemy_theme = cultivator
  - layer_boss = 2
  - next_ids = []
  - on_skip = none
  - stage = two
  - time_scale = days
  - type = combat
  - visible = False

### `layer_boss_stand_3` (layer_boss=3)
  - choices = ["fight"]
  - enemy_kind = thunder_crown_sovereign
  - enemy_theme = beast
  - layer_boss = 3
  - next_ids = []
  - on_skip = none
  - stage = three
  - time_scale = days
  - type = combat
  - visible = False

### `layer_boss_stand_4` (layer_boss=4)
  - choices = ["fight"]
  - enemy_kind = blood_vein_bishop
  - enemy_theme = cultivator
  - layer_boss = 4
  - next_ids = []
  - on_skip = none
  - stage = four
  - time_scale = days
  - type = combat
  - visible = False

### `final_boss_stand` (layer_boss=5)
  - choices = ["fight", "retreat"]
  - enemy_kind = miasma_vein_lord
  - enemy_theme = anomaly
  - layer_boss = 5
  - next_ids = []
  - on_skip = gain_pursuit
  - stage = five
  - summary = 瘴脉尽头，蛊主把守升仙窗口。
  - time_scale = days
  - type = combat
  - visible = False
