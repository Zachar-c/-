class_name ActionPoints
extends RefCounted


# 念头/行动点/一心多用统一（2026-08-31 裁定）：每回合行动次数由魂魄底蕴
# 分档决定：1/10/100/1000/10000+ → 2/3/4/5/6，超过 10000 不再增加。
# 旧卡牌引擎 BattleResolver（actions_max/left）与 V1 蛊行动制（念头/used_this_turn）
# 共用唯一一张分档表，避免两套经济漂移。V1 每个动作消耗 1 念头，
# 念头上限即本表返回值（取当前魂魄底蕴）。

const SOUL_ACTION_TIERS := [[10000, 6], [1000, 5], [100, 4], [10, 3]]


static func per_turn(soul: int) -> int:
	for tier in SOUL_ACTION_TIERS:
		if soul >= int(tier[0]):
			return int(tier[1])
	return 2