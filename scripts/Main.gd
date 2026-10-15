extends Node2D
## Campaign tent only. The six-chapter journey is the sole playable game mode.
const GameUIScript=preload("res://scripts/ui/GameUI.gd")
const AudioManagerScript=preload("res://scripts/systems/AudioManager.gd")
const CampaignProgressScript=preload("res://scripts/systems/CampaignProgress.gd")
const CampaignStoreScript=preload("res://scripts/systems/CampaignProgressStore.gd")
const CampaignSessionScript=preload("res://scripts/systems/CampaignSession.gd")
const ChapterRegistry=preload("res://scripts/campaign/ChapterSceneRegistry.gd")
const CAMPAIGN_READY_CHAPTERS: Array[int]=ChapterRegistry.READY_CHAPTERS
const AUDIO_SHUTDOWN_TIMEOUT_MS:=2000
var ui: Node
var audio: Node
var audio_enabled:=true
var initial_bgm_volume:=0.65
var initial_bgm_muted:=false
var closing:=false
var restarting:=false
var campaign_progress=CampaignProgressScript.new()
var campaign_store_path: String=CampaignStoreScript.DEFAULT_PATH
var campaign_storage_ok:=false
var journey_store_path:=""
var campaign_session: RefCounted

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit=false
	Engine.time_scale=1
	randomize()
	ui=GameUIScript.new()
	add_child(ui)
	audio=AudioManagerScript.new()
	audio.silent_mode=not audio_enabled or DisplayServer.get_name()=="headless"
	add_child(audio)
	audio.set_bgm_volume(initial_bgm_volume)
	audio.set_bgm_muted(initial_bgm_muted)
	ui.start_requested.connect(_start_primary_campaign)
	ui.chapter_requested.connect(_start_campaign_chapter)
	ui.quit_requested.connect(_request_close)
	ui.bgm_volume_changed.connect(audio.set_bgm_volume)
	ui.bgm_mute_changed.connect(audio.set_bgm_muted)
	ui.set_bgm_state(audio.bgm_volume_linear,audio.bgm_muted)
	_load_campaign_menu()
	ui.show_start_screen()

func _load_campaign_menu() -> void:
	var path := campaign_store_path
	if DisplayServer.get_name() == "headless" and path == CampaignStoreScript.DEFAULT_PATH:
		path = "user://five_minute_overdrive_campaign_test_v1.json"
	campaign_session = CampaignSessionScript.new(path, journey_store_path)
	campaign_storage_ok = campaign_session.load()
	var notice: String = "" if campaign_storage_ok else campaign_session.failure_message
	if campaign_storage_ok:
		campaign_progress = campaign_session.progress
	# Content readiness and permanent unlock are independent. Planned regions
	# cannot launch merely because an earlier Boss unlocked their progress gate.
	ui.start_screen.set_campaign(campaign_progress, CAMPAIGN_READY_CHAPTERS, notice)
	if campaign_storage_ok:
		ui.start_screen.set_journey(campaign_session.journey.get_entry(), campaign_session.journey.get_build(), campaign_session.has_pending_clear())

func _start_primary_campaign() -> void:
	# Recompute from live progress. UI copies, labels and disabled flags are not authority.
	if closing or restarting:
		return
	if not campaign_storage_ok or campaign_session == null:
		return
	var chapter: int = campaign_session.journey.get_entry().chapter
	_start_campaign_chapter(chapter)

func _can_start_campaign_chapter(chapter: int) -> bool:
	return not closing and not restarting and campaign_storage_ok and campaign_session != null and chapter in CAMPAIGN_READY_CHAPTERS and campaign_session.loop_for_chapter(chapter) > 0

func _start_campaign_chapter(chapter: int) -> void:
	if not _can_start_campaign_chapter(chapter):
		return
	var destination: Node = ChapterRegistry.instantiate_chapter(chapter)
	if destination == null:
		push_error("Chapter launch destination unavailable")
		return
	restarting = true
	get_tree().paused = true
	destination.campaign_store_path = campaign_store_path
	destination.journey_store_path = journey_store_path
	destination.run_loop = campaign_session.loop_for_chapter(chapter)
	destination.audio_enabled = audio_enabled
	destination.bgm_volume = audio.bgm_volume_linear
	destination.bgm_muted = audio.bgm_muted
	var drained: bool = await _drain_audio_for_scene_exit()
	if closing or not drained:
		destination.free()
		if not drained:
			_finish_close(1)
		return
	get_tree().paused = false
	get_parent().add_child(destination)
	if destination.get_parent() == get_tree().root:
		get_tree().current_scene = destination
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_close()

func _request_close() -> void:
	if closing:
		return
	closing = true
	get_tree().paused = true
	var drained: bool = await _drain_audio_for_scene_exit()
	_finish_close(0 if drained else 1)

func _drain_audio_for_scene_exit() -> bool:
	if not is_instance_valid(audio):
		return true
	audio.begin_shutdown()
	var deadline := Time.get_ticks_msec() + AUDIO_SHUTDOWN_TIMEOUT_MS
	while not audio.is_shutdown_complete():
		if Time.get_ticks_msec() >= deadline:
			push_error("Audio shutdown timed out before scene exit")
			return false
		await get_tree().process_frame
	return true

func _finish_close(exit_code: int) -> void:
	get_tree().quit(exit_code)
