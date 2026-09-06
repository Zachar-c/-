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


static func index(bound: int, seed: int, salt: String, tick: int) -> int:
	if bound <= 1:
		return 0
	var rng: Variant = RngScript.new(mixed_seed(seed, salt, tick))
	return rng.next_index(bound)
