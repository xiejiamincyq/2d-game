extends RefCounted
## Six chapters share one atomic journey journal. Old unlock data is read-only.
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const LegacyStore = preload("res://scripts/systems/CampaignProgressStore.gd")
const Journey = preload("res://scripts/systems/CampaignJourney.gd")
const Journal = preload("res://scripts/systems/CampaignJourneyStore.gd")
var progress := Progress.new()
var journey := Journey.new()
var failure_message := ""
var campaign_path: String
var journey_path: String
var journal: RefCounted
var _ready := false

func _init(path := LegacyStore.DEFAULT_PATH, journal_path := "") -> void:
	campaign_path = path
	journey_path = journal_path if not journal_path.is_empty() else (Journal.DEFAULT_PATH if path == LegacyStore.DEFAULT_PATH else path + ".journey")

func load() -> bool:
	_ready = false
	failure_message = ""
	var legacy := Progress.new()
	var legacy_status: int = LegacyStore.new(campaign_path).load_progress(legacy)
	if legacy_status not in [LegacyStore.LoadResult.MISSING, LegacyStore.LoadResult.LOADED]:
		failure_message = "旧章节存档异常或版本不兼容：原文件与备份保留，未开始游戏。"
		return false
	var candidate := Journey.new()
	var candidate_journal := Journal.new(journey_path)
	var status: int = candidate_journal.load_journey(candidate)
	if status not in [Journal.LoadResult.MISSING, Journal.LoadResult.LOADED]:
		failure_message = "旅程存档异常或版本不兼容：原文件与备份保留，未开始游戏。"
		return false
	var old_stage: int = legacy.to_state().cleared_chapters.size()
	var state := candidate.to_state()
	if old_stage > int(state.cleared_stage):
		state.cleared_stage = old_stage
		if not candidate.restore_state(state):
			failure_message = "旧章节进度与待领取奖励冲突：原文件保留，请先处理存档。"
			return false
	journey = candidate
	journal = candidate_journal
	_ready = true
	_sync_progress()
	return true

func has_pending_clear() -> bool:
	return not journey.get_pending_clear().is_empty()

func loop_for_chapter(chapter: int) -> int:
	if not _ready or not progress.is_unlocked(chapter):
		return 0
	var entry := journey.get_entry()
	if has_pending_clear() and chapter != int(entry.chapter):
		return 0
	return int(entry.loop) - 1 if chapter > int(entry.chapter) and int(entry.loop) > 1 else int(entry.loop)

func checkpoint_coins(balance: int) -> bool:
	var candidate := _candidate()
	return candidate != null and candidate.checkpoint_coins(balance) and _save(candidate)

func record_defeat(loop: int, chapter: int, balance: int, earned: Dictionary) -> bool:
	var candidate := _candidate()
	if candidate == null:
		return false
	var pending: Dictionary = candidate.get_pending_clear()
	if not pending.is_empty():
		return pending == {"loop": loop, "chapter": chapter, "coins": balance, "earned_counts": earned}
	var stage := (loop - 1) * 6 + chapter
	if stage <= int(candidate.to_state().cleared_stage):
		return candidate.commit_clear(loop, chapter, balance, earned, "") and _save(candidate)
	return candidate.begin_pending_clear(loop, chapter, balance, earned) and _save(candidate)

func claim_pending(choice: String) -> bool:
	var candidate := _candidate()
	return candidate != null and candidate.finalize_pending_clear(choice) and _save(candidate)

func _candidate() -> RefCounted:
	if not _ready:
		return null
	var candidate := Journey.new()
	return candidate if candidate.restore_state(journey.to_state()) else null

func _save(candidate: RefCounted) -> bool:
	if not journal.save_journey(candidate):
		failure_message = "旅程保存失败：未覆盖异常/冲突文件，未发出虚假继承奖励。"
		return false
	journey = candidate
	failure_message = ""
	_sync_progress()
	return true

func _sync_progress() -> void:
	var cleared: Array[int] = []
	for chapter in range(1, mini(6, int(journey.to_state().cleared_stage)) + 1):
		cleared.append(chapter)
	progress.restore_state({"version": Progress.VERSION, "cleared_chapters": cleared})
