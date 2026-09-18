extends GutTest


## 分布 / 独立性回归：`SeededRoll.index` 的产出必须是"随机"，而不是**等差阶梯**。
##
## 背景（2026-09-10 实测出的缺陷）：旧实现把 tick 线性混进种子、且只走一步 LCG，
## 仿射性使连续 tick 的取值恒差常数 —— bound=4 每 tick 恒 +3、bound=7 恒 +1、bound=100 恒 +87。
## 抽出来是刚性阶梯而非随机序列：`roll_chance(bound=35)` 的百分点每次恰好 −13，
## 命中序列是可见周期 `1100000 1100000 1110000…`，400 次的游程只出现 2/3/5。
##
## **为什么以前抓不到**：既有断言只查**确定性**（同种子同结果），从没查过**分布/独立性**；
## 而等差阶梯的**平均值仍然正确**（命中率 34.5% ≈ 期望 35%）。确定性 + 均值正确 = 全绿。
## 本文件补上缺失的这一维度，防止同类缺陷静默回归。


const SeededRollScript = preload("res://scripts/domain/seeded_roll.gd")

const SEED := 20260910
const SALT := "distribution.probe"


## 相邻两次抽取的"步长"不能几乎是常数 —— 这正是等差阶梯的特征。
## 判据：出现最多的那个步长占比必须 < 0.5。
## （旧实现下占比 ≈ 0.998；正常随机下 bound=4 约 0.25、bound=100 约 0.02。）
func test_consecutive_draws_are_not_an_arithmetic_staircase() -> void:
	var samples := 400
	for bound_value in [4, 7, 100]:
		var bound: int = int(bound_value)
		var delta_counts := {}
		for tick in samples:
			var current: int = int(SeededRollScript.index(bound, SEED, SALT, tick))
			var following: int = int(SeededRollScript.index(bound, SEED, SALT, tick + 1))
			var delta: int = posmod(following - current, bound)
			delta_counts[delta] = int(delta_counts.get(delta, 0)) + 1
		var most_common := 0
		for delta in delta_counts:
			most_common = maxi(most_common, int(delta_counts[delta]))
		var share := float(most_common) / float(samples)
		assert_lt(share, 0.5,
				"bound=%d：相邻抽取的步长几乎恒定（占比 %.3f，共 %d 种）——tick 又退化成等差阶梯了？"
				% [bound, share, delta_counts.size()])


## 2-gram 卡方：连续两次抽取之间必须不存在显著相关。
## 上界取 `df + 6σ`（σ = sqrt(2·df)）—— 极宽松，正常随机不可能越界；
## 而旧实现的卡方是 10^5 量级，会稳稳判红。
func test_consecutive_draws_are_independent_2gram() -> void:
	var samples := 1200
	for bound_value in [4, 7]:
		var bound: int = int(bound_value)
		var cells := {}
		for tick in samples:
			var first: int = int(SeededRollScript.index(bound, SEED, SALT, tick))
			var second: int = int(SeededRollScript.index(bound, SEED, SALT, tick + 1))
			var key: int = first * bound + second
			cells[key] = int(cells.get(key, 0)) + 1
		var cell_count: int = bound * bound
		var expected := float(samples) / float(cell_count)
		var chi := 0.0
		for key in cells:
			var delta := float(cells[key]) - expected
			chi += delta * delta / expected
		var degrees: int = cell_count - 1
		var limit := float(degrees) + 6.0 * sqrt(2.0 * float(degrees))
		assert_lt(chi, limit,
				"bound=%d：连续两次抽取存在相关性（卡方 %.1f，上界 %.1f）" % [bound, chi, limit])


## 不同 salt 之间必须去相关：同一 tick 上换一个 salt，取值不应是固定偏移。
## （旧实现里 salt 进入种子后也是仿射的，换 salt 只是换一个固定偏移。）
func test_different_salts_are_decorrelated() -> void:
	var samples := 300
	var offsets := {}
	for tick in samples:
		var alpha: int = int(SeededRollScript.index(100, SEED, "salt.alpha", tick))
		var beta: int = int(SeededRollScript.index(100, SEED, "salt.beta", tick))
		var offset: int = posmod(beta - alpha, 100)
		offsets[offset] = int(offsets.get(offset, 0)) + 1
	var most_common := 0
	for offset in offsets:
		most_common = maxi(most_common, int(offsets[offset]))
	assert_lt(float(most_common) / float(samples), 0.5,
			"同一 tick 下两条 salt 的差值几乎恒定（共 %d 种）——salt 未起到去相关作用" % offsets.size())
