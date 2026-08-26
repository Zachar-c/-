class_name SeededRoll
extends RefCounted


const RngScript = preload("res://scripts/domain/rng.gd")


# P2a C: single home for the shared deterministic roll formula previously
# hand-copied in BattleResolver._seeded_index and LootResolver._pick_from.
# Callers keep their own tick semantics (event-log length for loot/contact
# rolls) and own their salt strings; neither salts nor call order may change.


static func salt_hash(salt: String) -> int:
	var digest := 0
	for character in salt:
		digest = digest * 31 + character.unicode_at(0)
	return digest


static func mixed_seed(seed: int, salt: String, tick: int) -> int:
	return int(seed) * 1000003 + int(tick) * 97 + salt_hash(salt)


static func index(bound: int, seed: int, salt: String, tick: int) -> int:
	if bound <= 1:
		return 0
	var rng: Variant = RngScript.new(mixed_seed(seed, salt, tick))
	return rng.next_index(bound)
