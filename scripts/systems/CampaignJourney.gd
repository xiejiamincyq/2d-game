extends RefCounted
## Constant-size endless checkpoint, separate from permanent chapter unlocks.

const Rules = preload("res://scripts/systems/CampaignCarryRules.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const VERSION := 1
const MAX_COINS := Rules.MAX_COINS
const MAX_STAGE := 6000000

var _coins := 0
var _cleared_stage := 0
var _inherited_counts: Dictionary = {}
var _pending_clear: Dictionary = {}
var _catalog: Array[Dictionary] = []

func _init() -> void:
	var growth := Growth.new()
	_catalog = growth.upgrade_pool.duplicate(true)
	growth.free()

func get_entry() -> Dictionary:
	return {"loop": _cleared_stage / 6 + 1, "chapter": _cleared_stage % 6 + 1}

func get_build() -> Dictionary:
	return {"coins": _coins, "inherited_counts": _inherited_counts.duplicate(true)}

func checkpoint_coins(amount: int) -> bool:
	if amount < 0 or amount > MAX_COINS:
		return false
	if not _pending_clear.is_empty() and amount != _coins:
		return false
	_coins = amount
	return true

func eligible_ids(earned_counts: Dictionary) -> Array[String]:
	return Rules.eligible_ids(earned_counts, _inherited_counts, _catalog)

func get_pending_clear() -> Dictionary:
	return _pending_clear.duplicate(true)

func get_pending_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if _pending_clear.is_empty():
		return choices
	var ids := eligible_ids(_pending_clear.earned_counts)
	for card in _catalog:
		if String(card.id) in ids:
			var choice := card.duplicate(true)
			choice.label = String(card.label) + " · 继承一级"
			choices.append(choice)
	return choices

func begin_pending_clear(loop: int, chapter: int, balance: int, earned_counts: Dictionary) -> bool:
	var receipt := {"loop": loop, "chapter": chapter, "coins": balance, "earned_counts": earned_counts.duplicate(true)}
	if not _pending_clear.is_empty() or not _validate_pending(receipt, _cleared_stage, balance, _inherited_counts):
		return false
	_pending_clear = receipt
	_coins = balance
	return true

func finalize_pending_clear(choice: String) -> bool:
	if _pending_clear.is_empty():
		return false
	return commit_clear(_pending_clear.loop, _pending_clear.chapter, _coins, _pending_clear.earned_counts, choice)

func commit_clear(loop: int, chapter: int, balance: int, earned_counts: Dictionary, choice: String) -> bool:
	if loop < 1 or loop > MAX_STAGE / 6 or chapter < 1 or chapter > 6 or balance < 0 or balance > MAX_COINS:
		return false
	var stage := (loop - 1) * 6 + chapter
	if stage > _cleared_stage + 1 or not Rules.validate_counts(earned_counts, _catalog, false):
		return false
	if not _pending_clear.is_empty() and (loop != _pending_clear.loop or chapter != _pending_clear.chapter or balance != _coins or earned_counts != _pending_clear.earned_counts):
		return false
	# A replay may checkpoint its actual balance, never grant another ability.
	if stage <= _cleared_stage:
		return checkpoint_coins(balance) if choice.is_empty() else false
	var options := eligible_ids(earned_counts)
	if (choice.is_empty() and not options.is_empty()) or (not choice.is_empty() and choice not in options):
		return false
	var candidate := _inherited_counts.duplicate(true)
	if not choice.is_empty():
		candidate[choice] = int(candidate.get(choice, 0)) + 1
	if not Rules.validate_counts(candidate, _catalog):
		return false
	_inherited_counts = candidate
	_coins = balance
	_cleared_stage = stage
	_pending_clear.clear()
	return true

func to_state() -> Dictionary:
	return {"version": VERSION, "cleared_stage": _cleared_stage, "coins": _coins, "inherited_counts": _inherited_counts.duplicate(true), "pending_clear": _pending_clear.duplicate(true)}

func restore_state(state: Dictionary) -> bool:
	if state.size() not in [4, 5] or (state.size() == 5 and not state.has("pending_clear")):
		return false
	for key in ["version", "cleared_stage", "coins", "inherited_counts"]:
		if not state.has(key):
			return false
	if not Rules.is_integer(state.version, VERSION, VERSION) or not Rules.is_integer(state.cleared_stage, 0, MAX_STAGE) or not Rules.is_integer(state.coins, 0, MAX_COINS):
		return false
	if not state.inherited_counts is Dictionary or not Rules.validate_counts(state.inherited_counts, _catalog):
		return false
	var rewarded_ranks := 0
	for rank in state.inherited_counts.values():
		rewarded_ranks += int(rank)
	if rewarded_ranks > int(state.cleared_stage):
		return false
	var pending: Variant = state.get("pending_clear", {})
	if not _validate_pending(pending, int(state.cleared_stage), int(state.coins), state.inherited_counts):
		return false
	_cleared_stage = int(state.cleared_stage)
	_coins = int(state.coins)
	var canonical: Dictionary = {}
	for id in state.inherited_counts:
		canonical[id] = int(state.inherited_counts[id])
	_inherited_counts = canonical
	_pending_clear = pending.duplicate(true)
	if not _pending_clear.is_empty():
		for key in ["loop", "chapter", "coins"]:
			_pending_clear[key] = int(_pending_clear[key])
		for id in _pending_clear.earned_counts:
			_pending_clear.earned_counts[id] = int(_pending_clear.earned_counts[id])
	return true

func _validate_pending(pending: Variant, stage: int, balance: int, inherited: Dictionary) -> bool:
	if not pending is Dictionary:
		return false
	if pending.is_empty():
		return true
	if pending.size() != 4:
		return false
	for key in ["loop", "chapter", "coins", "earned_counts"]:
		if not pending.has(key):
			return false
	if not Rules.is_integer(pending.loop, 1, MAX_STAGE / 6) or not Rules.is_integer(pending.chapter, 1, 6) or not Rules.is_integer(pending.coins, 0, MAX_COINS):
		return false
	if int(pending.loop) != stage / 6 + 1 or int(pending.chapter) != stage % 6 + 1 or int(pending.coins) != balance:
		return false
	if not pending.earned_counts is Dictionary or not Rules.validate_counts(pending.earned_counts, _catalog, false):
		return false
	for id in inherited:
		if int(pending.earned_counts.get(id, 0)) < int(inherited[id]):
			return false
	return true
