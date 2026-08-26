extends "res://addons/gut/test.gd"


# B1 rulings: every new run rolls a fresh seed automatically (no UI entry,
# seed not displayed). Seed 101 stays reserved as the demo/regression route.
# These tests pin the contract between seeds and generated routes.


const RunControllerScript := preload("res://scripts/presentation/run_controller.gd")
const MapGeneratorScript := preload("res://scripts/domain/map_generator.gd")


func test_distinct_seeds_produce_distinct_routes() -> void:
	var first := MapGeneratorScript.build(101, true)
	var second := MapGeneratorScript.build(314159, false)
	var first_ids: Array[String] = []
	var second_ids: Array[String] = []
	for node in first:
		first_ids.append(str(node["id"]))
	for node in second:
		second_ids.append(str(node["id"]))
	assert_ne(first_ids, second_ids, "distinct seeds must craft distinct route node sets")


func test_same_seed_produces_identical_routes() -> void:
	var one := MapGeneratorScript.build(2026, false)
	var two := MapGeneratorScript.build(2026, false)
	assert_eq_deep(one, two)


func test_roll_seed_returns_positive_int() -> void:
	var rolled: int = RunControllerScript.roll_seed()
	assert_gt(rolled, 0, "auto-rolled seeds must be positive integers")


func test_roll_seed_advances_over_calls() -> void:
	var seen: Array[int] = []
	for i in range(8):
		seen.append(RunControllerScript.roll_seed())
	var distinct := {}
	for value in seen:
		distinct[value] = true
	assert_gt(distinct.size(), 1, "repeated rolls must not be trivially identical")