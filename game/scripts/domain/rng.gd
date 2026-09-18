class_name SeededRng
extends RefCounted


var _state: int


func _init(seed_value: int) -> void:
	_state = abs(seed_value) % 2147483647
	if _state == 0:
		_state = 1


func next_index(size: int) -> int:
	assert(size > 0)
	_state = (_state * 48271) % 2147483647
	return _state % size


## 推进 count 步、丢弃中间结果。
## 语义：把本实例当作一条**流**，"取第 N 次抽取" = discard(N) 之后 next_index(...)。
##
## ⚠️ 不要用"把 N 直接混进种子、只走一步"来模拟第 N 次抽取——那条路是仿射的，
## 连续 N 的中间状态恒差常数 `97 * 48271 mod M`，抽出来是等差阶梯而非随机序列。
## 详见 seeded_roll.gd 的 index() 注释（2026-09-10 实测，已在三处生产代码生效过）。
func discard(count: int) -> void:
	for _i in maxi(count, 0):
		_state = (_state * 48271) % 2147483647
