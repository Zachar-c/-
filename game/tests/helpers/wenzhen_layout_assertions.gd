extends RefCounted
class_name WenzhenLayoutAssertions


static func rect(node: Control) -> Rect2:
	return node.get_global_rect()


static func assert_inside(test: GutTest, child: Control, parent: Control, margin := 0.0) -> void:
	var inner := parent.get_global_rect().grow(-margin)
	test.assert_true(inner.encloses(child.get_global_rect()), "%s must stay inside %s" % [child.name, parent.name])


static func assert_no_overlap(test: GutTest, a: Control, b: Control, allowance := 0.0) -> void:
	var intersection := a.get_global_rect().intersection(b.get_global_rect())
	test.assert_lte(intersection.get_area(), allowance, "%s overlaps %s" % [a.name, b.name])
