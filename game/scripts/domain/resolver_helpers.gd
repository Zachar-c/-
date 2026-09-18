class_name ResolverHelpers
extends RefCounted


# Spec-v4 phase-2 (T9.2, gate defense): pure plumbing helpers extracted from
# resolver.gd verbatim (zero behaviour change) to make room for the v2
# command dispatch table without touching the resolver line gate. Move-only
# per the ffe3aa6 economy_rules precedent - nothing here is a rule.


# Append semantics: feeds already on the result must survive alongside the
# new entry instead of being overwritten.
static func append_result_feed(result: Dictionary, feed: String) -> Dictionary:
	var inner: Dictionary = result.get("result", {})
	var feeds: Array = inner.get("feeds", [])
	feeds = feeds.duplicate()
	if not feeds.has(feed):
		feeds.append(feed)
	inner["feeds"] = feeds
	result["result"] = inner
	return result


static func add_fact(facts: Array[String], fact_id: String) -> void:
	if not facts.has(fact_id):
		facts.append(fact_id)
