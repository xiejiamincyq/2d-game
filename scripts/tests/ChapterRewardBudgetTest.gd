extends SceneTree
## Pure diagnostic budget regression; no scene launch, actor/growth/save writes.
## A REWARD -> REWARD transition may hide a new settlement transaction.
const Driver = preload("res://scripts/art/VerifyNurseryChapterFlow.gd")
const BUDGET_METHOD := &"reward_selection_count"

var checks := 0
var failures := 0
var driver_script: Script = Driver

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ChapterRewardBudgetTest " + label)

func _initialize() -> void:
	call_deferred("run")

func count_for(previous_transaction: int, transaction: int, selections: int) -> int:
	return int(driver_script.call(BUDGET_METHOD, previous_transaction, transaction, selections))

func run() -> void:
	# Keep RED semantic: the existing driver must parse before the API exists.
	check(driver_script.has_method(BUDGET_METHOD), "diagnostic transaction budget API missing")
	if failures > 0:
		quit(1)
		return

	# Third encounter settlement can close into boss_prep in the same REWARD state.
	check(count_for(41, 42, 3) == 0, "same REWARD state new transaction inherits exhausted budget")
	check(count_for(41, 42, 2) == 0, "new transaction inherits partially used budget")
	check(count_for(0, 42, 3) == 0, "non-REWARD to REWARD inherits old selections")

	# First free selection and two paid selections share one three-choice budget.
	var selections := count_for(0, 41, 0)
	check(selections == 0, "first settlement does not start empty")
	selections = count_for(41, 41, selections + 1)
	check(selections == 1, "free selection is omitted from transaction budget")
	selections = count_for(41, 41, selections + 1)
	check(selections == 2, "first paid selection loses prior free selection")
	selections = count_for(41, 41, selections + 1)
	check(selections == 3, "free plus two paid selections do not exhaust budget")
	check(count_for(41, 41, selections) == 3, "same transaction resets exhausted budget")

	check(count_for(41, 0, 0) == 3, "empty transaction does not fail closed")
	check(count_for(41, -1, 2) == 3, "negative transaction does not fail closed")
	check(count_for(0, 0, -4) == 3, "empty transaction with negative count reopens budget")
	check(count_for(41, 41, -1) == 0, "same transaction negative count is not clamped")
	check(count_for(41, 41, 4) == 3, "same transaction exceeds three selections")
	check(count_for(41, 42, 99) == 0, "new transaction must reset before old-count clamp")

	if failures == 0:
		print("TEST PASS: ChapterRewardBudgetTest %d" % checks)
	quit(1 if failures > 0 else 0)
