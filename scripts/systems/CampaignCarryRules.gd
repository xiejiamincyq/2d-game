extends RefCounted
## Pure shared rules. No Player mutation, storage, or ultimate carry-over.
const MAX_COINS := 9000000000

static func base_stats(chapter: int) -> Dictionary:
	return {"health": 90 + chapter * 10, "shield": 20} if chapter >= 1 and chapter <= 6 else {}

static func is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

static func validate_counts(counts: Dictionary, catalog: Array[Dictionary], inherited := true) -> bool:
	for id in counts:
		if not id is String:
			return false
		var card := _card(id, catalog)
		if card.is_empty() or (inherited and card.kind == "evolution"):
			return false
		if not is_integer(counts[id], 1, int(card.max_rank)):
			return false
		if inherited and not _has_prerequisites(card, counts):
			return false
	return true

static func eligible_ids(earned: Dictionary, carried: Dictionary, catalog: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	if not validate_counts(earned, catalog, false) or not validate_counts(carried, catalog):
		return result
	for card in catalog:
		var id := String(card.id)
		var previous := int(carried.get(id, 0))
		if card.kind != "evolution" and int(earned.get(id, 0)) > previous and previous < int(card.max_rank) and _has_prerequisites(card, carried):
			result.append(id)
	return result

static func _card(id: String, catalog: Array[Dictionary]) -> Dictionary:
	for card in catalog:
		if card.id == id:
			return card
	return {}

static func _has_prerequisites(card: Dictionary, counts: Dictionary) -> bool:
	var required: Variant = card.get("requires", "")
	if required is Array:
		for id in required:
			if int(counts.get(id, 0)) < 1:
				return false
		return true
	return String(required).is_empty() or int(counts.get(String(required), 0)) > 0
