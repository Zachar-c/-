class_name ResourceVocabulary
extends RefCounted


const ORDER: Array[String] = ["yuanstone", "essence", "lifespan", "soul", "material"]
const ALIASES := {
	"stone": "yuanstone",
	"stones": "yuanstone",
	"yuanstone": "yuanstone",
	"true_essence": "essence",
	"essence": "essence",
	"shouyuan": "lifespan",
	"lifespan": "lifespan",
	"hunpo": "soul",
	"soul": "soul",
	"material": "material",
	"injury": "injury",
	"intel": "intel",
	"relic": "relic",
}
const LABELS := {
	"yuanstone": "元石",
	"essence": "真元",
	"lifespan": "寿元",
	"soul": "魂魄",
	"material": "材料",
	"injury": "伤势",
	"intel": "情报",
	"relic": "遗物",
}
const SUFFIXES := {}


static func normalize(kind: String) -> String:
	return str(ALIASES.get(str(kind), ""))


static func label(kind: String) -> String:
	var canonical := normalize(kind)
	return str(LABELS.get(canonical, "未知资源"))


static func suffix(kind: String) -> String:
	var canonical := normalize(kind)
	return str(SUFFIXES.get(canonical, ""))


static func display_order() -> Array[String]:
	return ORDER.duplicate()


static func is_canonical(kind: String) -> bool:
	return ORDER.has(str(kind))
