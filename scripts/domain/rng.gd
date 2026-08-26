class_name SeededRng
extends RefCounted


var _state: int


func _init(seed: int) -> void:
	_state = abs(seed) % 2147483647
	if _state == 0:
		_state = 1


func next_index(size: int) -> int:
	assert(size > 0)
	_state = (_state * 48271) % 2147483647
	return _state % size
