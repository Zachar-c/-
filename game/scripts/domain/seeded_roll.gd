class_name SeededRoll
extends RefCounted


const RngScript = preload("res://scripts/domain/rng.gd")


# P2a C: single home for the shared deterministic roll formula previously
# hand-copied in the legacy battle resolver (_seeded_index) and LootResolver
# (_pick_from).
# Callers keep their own tick semantics (event-log length for loot/contact
# rolls) and own their salt strings; neither salts nor call order may change.
# Quality batch ②: the last hand-rolled copies (Resolver._refinement_roll,
# _free_mix_seed, roll_chance and the legacy _battle_rng_seed) converged
# here; the battle shuffle seed keeps its numeric-salt form (mixed_seed_int)
# so deck draw order stays byte-identical after convergence.
#
# 2026-09-10 修正（等差阶梯缺陷）：index() 不再把 tick 混进种子，而是
# "在 (seed, salt) 派生的流上推进 tick 步"。tick=0 的结果与旧实现逐字节一致，
# 故 map_generator._node_rng（tick 恒为 0）与地图生成完全不受影响。


static func salt_hash(salt: String) -> int:
	var digest := 0
	for character in salt:
		digest = digest * 31 + character.unicode_at(0)
	return digest


static func mixed_seed(seed: int, salt: String, tick: int) -> int:
	return int(seed) * 1000003 + int(tick) * 97 + salt_hash(salt)


# Numeric-salt form: battle seeds use an integer salt scaled by 193 instead of
# a string hash. Kept as a documented second form; do not fold it into the
# string form or every battle draw order changes for identical seeds/tick.
static func mixed_seed_int(seed: int, salt: int, tick: int) -> int:
	return int(seed) * 1000003 + int(tick) * 97 + int(salt) * 193


## 第 tick 次抽取：以 (seed, salt) 派生一条流，推进 tick 步后取一个 [0, bound) 的值。
##
## ⚠️⚠️ 不要把 tick 线性混进种子再只走一步（旧实现 `mixed_seed(seed, salt, tick)` + 一次 LCG）。
## 那条路是**仿射**的：`state = (input * 48271) mod M`，连续 tick 的输入只差 97，
## 于是中间状态恒差常数 `97 * 48271 mod M = 4,682,287`，
## 而 `index(bound, ...)` 每 tick 恒移 `4,682,287 mod bound`：
##
##     bound = 4   → 每 tick 恒 +3
##     bound = 7   → 每 tick 恒 +1
##     bound = 100 → 每 tick 恒 +87（等价 −13）
##
## 结果不是随机序列，而是**等差阶梯**。2026-09-10 实测（`roll_chance` 路径，bound=35）：
## 百分点 `[15, 2, 89, 76, 63, 50, 37, 24, 11, 98, ...]` 每次恰好 −13；
## 命中序列是刚性循环 `1100000 1100000 1110000…`；400 次的游程只出现 2/3/5。
## 而**命中率 34.5% ≈ 期望 35%** —— 平均值正确，所以只查确定性的测试一直是绿的。
##
## 现在 tick 表示"第几次抽取"，相邻抽取之间是正常的 LCG 递推（已用 2-gram 卡方验证无相关）。
## tick 语义（掉落/概率判定用 `state.event_log.size()`）保持不变，只是含义从"种子偏移"
## 变成"流位置"。
##
## 兼容性：`tick = 0` 与旧实现**逐字节一致**（旧式在 tick=0 时恰为本式），
## 因此 map_generator 的 `_node_rng`（tick 恒 0）产出不变、既有地图种子不受影响。
static func index(bound: int, seed: int, salt: String, tick: int) -> int:
	if bound <= 1:
		return 0
	var rng: Variant = RngScript.new(mixed_seed(seed, salt, 0))
	rng.discard(tick)
	return rng.next_index(bound)
