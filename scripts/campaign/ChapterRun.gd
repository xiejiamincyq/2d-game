extends Node2D
## Shared chapter coordinator. No wave snapshots or fake permanent clears.

const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Registry = preload("res://scripts/campaign/ChapterSceneRegistry.gd")
const Catalog = preload("res://scripts/systems/ChapterCatalog.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/ChapterEncounterDirector.gd")
const Interface = preload("res://scripts/ui/NurseryChapterUI.gd")
const Audio = preload("res://scripts/systems/AudioManager.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Session = preload("res://scripts/systems/CampaignSession.gd")
const LoopRules = preload("res://scripts/systems/CampaignLoopRules.gd")
const Feedback = preload("res://scripts/systems/CombatFeedback.gd")
const Vfx = preload("res://scripts/effects/CombatVfx.gd")
const Effects = preload("res://scripts/effects/CameraEffects.gd")
const Framing = preload("res://scripts/systems/BossCameraFraming.gd")
const Outline = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
const NativeDeathMotion = preload("res://scripts/components/NativeScrapperMotion.gd")
const Coin = preload("res://scripts/pickups/CoinPickup.gd")
const Heart = preload("res://scripts/pickups/HeartPickup.gd")
const Shield = preload("res://scripts/pickups/ShieldPickup.gd")
var campaign_store_path := Store.DEFAULT_PATH
var journey_store_path := ""
var run_loop := 0
var audio_enabled := true
var bgm_volume := 0.65
var bgm_muted := false
var run_seed: int = -9223372036854775807
var progress := Progress.new()
var session: RefCounted
var ui: GameUI
var audio: AudioManager
var map: Node2D
var player: CharacterBody2D
var growth: Node
var director: Node
var projectiles: Node2D
var pickups: Node2D
var feedback: CombatFeedback
var framing: Node
var clear_saved := false
var _clear_received := false
var _receipt_saved := false
var _pending_choice := ""
var _resuming_reward := false
var _pending_exit: Dictionary = {}
var manually_paused := false
var leaving := false
var kills := 0
var elapsed := 0.0
var overdrive_charge := 0.0
var overdrive_active := false
var combo := 0
var combo_remaining := 0.0
var definition: Dictionary

func _chapter_number() -> int: return 1
func _bind_region() -> bool: return true

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	Engine.time_scale = 1
	definition = Definitions.get_definition(_chapter_number())
	ui = Interface.new()
	ui.risk_name = definition.get("risk_name", "路线")
	add_child(ui)
	audio = Audio.new()
	audio.silent_mode = not audio_enabled or DisplayServer.get_name() == "headless"
	add_child(audio)
	audio.set_bgm_volume(bgm_volume)
	audio.set_bgm_muted(bgm_muted)
	ui.set_bgm_state(bgm_volume, bgm_muted)
	ui.bgm_volume_changed.connect(audio.set_bgm_volume)
	ui.bgm_mute_changed.connect(audio.set_bgm_muted)
	ui.proceed_requested.connect(_proceed)
	ui.route_requested.connect(_choose_route)
	ui.pause_requested.connect(_toggle_pause)
	ui.resume_requested.connect(_toggle_pause)
	ui.return_requested.connect(func() -> void: _leave(false))
	ui.replay_requested.connect(func() -> void: _leave(true))
	ui.retry_save_requested.connect(_retry_clear_save)
	ui.carry_choice_requested.connect(_claim_carry)
	ui.next_chapter_requested.connect(func() -> void:
		if clear_saved and _chapter_number() < 6:
			_leave(true, false, _chapter_number() + 1)
	)
	ui.settlement_offer_selected.connect(_claim_offer)
	ui.settlement_close_requested.connect(_finish_reward)
	if DisplayServer.get_name() == "headless" and campaign_store_path == Store.DEFAULT_PATH:
		campaign_store_path = "user://five_minute_overdrive_campaign_test_v1.json"
	session = Session.new(campaign_store_path, journey_store_path)
	if not session.load():
		ui.present("章节无法启动", session.failure_message, &"error")
		return
	progress = session.progress
	var allowed_loop: int = session.loop_for_chapter(_chapter_number())
	if definition.is_empty() or allowed_loop == 0 or (run_loop > 0 and run_loop != allowed_loop):
		ui.present("章节无法启动", "该章节尚未解锁或内容未完成。请先击败前一关首领，再返回帐篷选择。", &"error")
		return
	run_loop = allowed_loop
	if session.has_pending_clear():
		_clear_received = true
		_receipt_saved = true
		_resuming_reward = true
		ui.hud.hide()
		_present_carry()
		return
	if run_seed == -9223372036854775807:
		run_seed = randi()
	_build_world()

func _build_world() -> void:
	map = definition.map.instantiate()
	map.map_seed = run_seed
	map.process_mode = PROCESS_MODE_PAUSABLE
	add_child(map)
	var enemies := _layer("Enemies", true)
	projectiles = _layer("Projectiles")
	projectiles.z_index = Outline.OUTLINE_Z_INDEX + 1
	pickups = _layer("Pickups")
	var portals := _layer("Portals")
	player = Player.new()
	player.world_bounds = map.layout.world_bounds
	player.projectile_parent = projectiles
	map.add_child(player)
	map.layout.occlusion_target = player
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8
	camera.limit_left = int(map.layout.world_bounds.position.x)
	camera.limit_top = int(map.layout.world_bounds.position.y)
	camera.limit_right = int(map.layout.world_bounds.end.x)
	camera.limit_bottom = int(map.layout.world_bounds.end.y)
	player.add_child(camera)
	camera.make_current()
	var outline := Outline.new()
	player.add_child(outline)
	outline.setup(player, enemies, map.layout)
	var vfx := Vfx.new()
	map.add_child(vfx)
	var effects := Effects.new()
	player.add_child(effects)
	effects.setup(camera)
	framing = Framing.new()
	player.add_child(framing)
	framing.setup(camera, player, ui, map.layout.world_bounds)
	feedback = Feedback.new()
	add_child(feedback)
	feedback.setup(vfx, effects, audio, func() -> bool: return overdrive_active)
	player.fired.connect(func(projectile: Node) -> void:
		projectile.world_bounds = map.layout.world_bounds
		projectiles.add_child(projectile)
		if projectile.has_signal("exploded"):
			projectile.exploded.connect(func(position: Vector2, _radius: float) -> void:
				audio.play("explosion")
				vfx.request_effect(&"blast", position, Vector2.UP, 1.4)
			)
		audio.play_shot()
	)
	player.health_changed.connect(ui.set_health)
	player.shield_changed.connect(ui.set_shield)
	player.laser_active_changed.connect(audio.set_laser_active)
	player.entrance_finished.connect(func() -> void:
		if not leaving and director.state == Director.State.INTRO:
			ui.proceed_button.disabled = false
			get_tree().paused = true
	)
	growth = Growth.new()
	add_child(growth)
	growth.progression_state_changed.connect(ui.set_progression_state)
	growth.settlement_changed.connect(func(state: Dictionary) -> void:
		ui.set_encounter_reward(state, director.get_encounter().name)
	)
	growth.upgrade_applied.connect(func(label: String) -> void: ui.show_toast(label); audio.play("upgrade"))
	if not growth.setup_chapter_with_carry(player, _chapter_number(), session.journey.get_build()):
		_modal("章节无法启动", "章节成长上下文无法初始化。未开始战斗、未保存进度；请返回帐篷。", &"error")
		return
	director = definition.director.new()
	# Shared combat's deferred drop callback targets its chapter owner.
	director.process_mode = PROCESS_MODE_PAUSABLE
	add_child(director)
	director.encounter_prepared.connect(_on_prepared)
	director.encounter_status.connect(func(encounter: Dictionary, remaining: int) -> void:
		var label: String = definition.boss_name if director.state == Director.State.BOSS else encounter.name
		ui.wave_label.text = "%s · %s\n剩余 %d" % [_location_label(), label, remaining]
	)
	director.reward_ready.connect(_on_reward)
	director.route_ready.connect(func() -> void:
		_modal("岔路 / 选择风险", definition.route, &"route")
	)
	director.chapter_boss_ready.connect(func(label: String) -> void:
		_modal("首领区域", label + "\n" + definition.boss_hint, &"boss")
	)
	director.chapter_cleared.connect(save_clear)
	director.run_failed.connect(func(reason: String) -> void:
		_modal("探索失败", reason + "\n离开时保存金币；已继承能力与解锁保留。未继承的本局构筑重置。", &"failed")
		audio.play("defeat")
	)
	director.boss_spawned.connect(func(boss: Node, label: String, maximum: float) -> void:
		framing.track_boss(boss)
		ui.show_boss_health(boss, label, maximum)
		ui.wave_label.text = "%s · %s" % [_location_label(), definition.boss_name]
	)
	director.boss_health_changed.connect(ui.set_boss_health)
	director.boss_defeated.connect(func(_boss: Node) -> void: ui.hide_boss_health())
	director.boss_cue.connect(audio.play_boss_cue)
	director.damage_resolved.connect(feedback.on_damage_resolved)
	director.enemy_killed.connect(_on_kill)
	director.collection_window_changed.connect(ui.set_collection_window)
	if not director.configure_loop(run_loop) or not _bind_region() or not director.start_run(run_seed, player, enemies, projectiles, portals, growth, map.layout):
		_modal("章节无法启动", "区域资源或战斗流程无法初始化。未开始战斗、未保存进度；请返回帐篷。", &"error")
		return
	player.set_enemy_provider(director.get_attack_targets)
	ui.set_health(player.health.current_health, player.health.max_health)
	ui.set_shield(player.shield, player.max_shield)
	ui.proceed_button.disabled = true
	get_tree().paused = false
	player.begin_spawn_input_guard()
	player.begin_entrance()
	audio.play_bgm()

func _layer(label: String, sorted := false) -> Node2D:
	var layer := Node2D.new()
	layer.name = label
	layer.y_sort_enabled = sorted
	map.add_child(layer)
	return layer

func _modal(title: String, description: String, stage: StringName) -> void:
	if leaving:
		return
	if feedback != null:
		feedback.reset_all()
	if framing != null:
		framing.set_combat_state(false, true)
	get_tree().paused = true
	if director != null and director.state == Director.State.CLEARED:
		NativeDeathMotion.settle_cleared_death_tails(self)
	audio.set_laser_active(false)
	ui.present(title, description, stage)

func _on_prepared(encounter: Dictionary) -> void:
	ui.wave_label.text = "%s · %s\n尚未开始" % [_location_label(), encounter.name]
	var difficulty:="本轮敌方生命 ×%.2f；第2轮起逐轮混入异区敌人，分批增援。"%LoopRules.health_scale(run_loop)
	_modal("%s / %s" % [_location_label(), encounter.name], "%s · 地图种子 %d\n%s\n%s" % [definition.name, run_seed, difficulty, definition.intro], &"intro")

func _location_label() -> String:
	return "第%d轮 · 第%d关"%[run_loop,_chapter_number()]

func _proceed() -> void:
	if leaving or player == null or player.is_entrance_active() or manually_paused:
		return
	var started: bool = director.begin_encounter() if director.state == Director.State.INTRO else director.begin_boss()
	if started:
		_resume_combat()

func _resume_combat() -> void:
	ui.hide_flow()
	get_tree().paused = false
	player.begin_spawn_input_guard()
	# Player clears transient modifiers on pause; restore the frozen chapter state.
	player.set_overdrive_active(overdrive_active)
	framing.set_combat_state(true, false)

func _on_reward(state: Dictionary) -> void:
	_modal("遭遇胜利", "整备后继续探索。", &"reward")
	ui.flow_root.hide()
	ui.set_encounter_reward(state, director.get_encounter().name)
	ui.show_settlement()
	# show_screen refreshes generic labels; apply chapter wording afterwards.
	ui.set_encounter_reward(state, director.get_encounter().name)

func _claim_offer(offer: Dictionary) -> void:
	if leaving or manually_paused or director.state != Director.State.REWARD:
		return
	if growth.get_settlement_state().reward_claimed:
		director.purchase_reward(offer)
	else:
		director.claim_reward(offer)

func _finish_reward() -> void:
	if not leaving:
		director.finish_reward()

func _choose_route(route: StringName) -> void:
	if not leaving:
		director.choose_route(route)

func _toggle_pause() -> void:
	if leaving or director == null or director.state not in [Director.State.COMBAT, Director.State.COLLECT, Director.State.BOSS]:
		return
	manually_paused = not manually_paused
	if manually_paused:
		_modal("暂停探索", "空格或 Esc 继续。返回帐篷会保存金币与已继承能力，结束本局探索。", &"pause")
	else:
		_resume_combat()

func save_clear(chapter: int) -> bool:
	if leaving or clear_saved or chapter != _chapter_number() or director == null or director.state != Director.State.CLEARED or director.defeated_boss_instance <= 0:
		return false
	if _receipt_saved:
		return false
	_clear_received = true
	if not session.record_defeat(run_loop, chapter, growth.coins, growth.upgrade_counts):
		_modal("首领已击败 · 保存失败", session.failure_message + " 可重试保存通关；本次奖励尚未提交。", &"save_error")
		return false
	_receipt_saved = true
	_present_carry()
	return true

func _present_carry() -> void:
	if session.has_pending_clear():
		var choices: Array[Dictionary] = session.journey.get_pending_choices()
		if choices.is_empty():
			_claim_carry("")
			return
		_modal("选择通关继承", "本次通关奖励已登记，可关闭游戏后继续领取。", &"cleared")
		ui.present_chapter_clear(_chapter_number(), choices, session.journey.get_build().coins, false)
		if _resuming_reward:
			ui.flow_title.text = "继续领取%s通关奖励" % _location_label()
		return
	_show_saved_clear()

func _claim_carry(card_id: String) -> void:
	if leaving or not _clear_received or not _receipt_saved or clear_saved or not session.has_pending_clear():
		return
	_pending_choice = card_id
	if not session.claim_pending(card_id):
		_modal("通关奖励 · 保存失败", session.failure_message + " 已登记奖励保留，可重试或回帐篷后继续领取。", &"save_error")
		return
	_show_saved_clear()

func _show_saved_clear() -> void:
	progress = session.progress
	clear_saved = true
	_modal("%s通关 · 已保存" % _location_label(), "金币与继承能力已保存。", &"cleared")
	var choices: Array[Dictionary] = []
	ui.present_chapter_clear(_chapter_number(), choices, session.journey.get_build().coins, true)
	ui.flow_title.text = "%s通关 · 已保存" % _location_label()
	if not _pending_choice.is_empty():
		ui.flow_description.text = "金币 %d · 所选普通能力继承一级；重玩本关不会再次发放继承奖励。" % session.journey.get_build().coins
	if _chapter_number() == 6:
		ui.flow_description.text += "\n返回帐篷后继续，进入下一轮第1关；重玩仍为第%d轮第6关。" % run_loop
	audio.play("victory")

func _retry_clear_save() -> void:
	if not _pending_exit.is_empty():
		var request := _pending_exit.duplicate()
		_pending_exit.clear()
		_leave(request.replay, request.quit_app, request.destination_chapter)
		return
	if _receipt_saved:
		_claim_carry(_pending_choice)
	else:
		save_clear(_chapter_number())

func _on_kill(_enemy: Node, _source: StringName, _coins: int) -> void:
	kills += 1
	# A terminal modal pauses _process before its next stats refresh.
	ui.set_run_stats(kills, elapsed)
	combo += 1
	combo_remaining = 3.0
	if not overdrive_active:
		overdrive_charge = minf(100, overdrive_charge + 9)
		if overdrive_charge == 100:
			_set_overdrive(true)
	ui.set_combo(combo)
	ui.set_overdrive_charge(overdrive_charge, overdrive_active)

func spawn_coins(position: Vector2, value: int) -> void:
	if leaving:
		return
	var coin := Coin.new()
	coin.value = value
	coin.target_player = player
	coin.position = position
	pickups.add_child(coin)
	coin.collected.connect(func(amount: int) -> void: growth.add_coins(amount); audio.play("coin"))

func spawn_heart(position: Vector2, value: float = 20.0) -> void:
	if leaving:
		return
	var heart := Heart.new()
	heart.position = position
	heart.value = value
	pickups.add_child(heart)
	heart.collected.connect(func(amount: float) -> void: player.heal(amount); audio.play("heart"))

func spawn_shield(position: Vector2, value: float = 9.0) -> void:
	if leaving:
		return
	var shield := Shield.new()
	shield.position = position
	shield.value = value
	pickups.add_child(shield)
	shield.collected.connect(func(amount: float) -> void: player.add_shield(amount); audio.play("pickup"))

func _process(delta: float) -> void:
	if not leaving and director != null and not get_tree().paused and director.state in [Director.State.COMBAT, Director.State.COLLECT, Director.State.BOSS]:
		elapsed += delta
		ui.set_run_stats(kills, elapsed)
		overdrive_charge = maxf(0, overdrive_charge - (34 if overdrive_active else 7) * delta)
		if overdrive_active and overdrive_charge == 0:
			_set_overdrive(false)
		ui.set_overdrive_charge(overdrive_charge, overdrive_active)
		combo_remaining = maxf(0, combo_remaining - delta)
		if combo_remaining == 0 and combo > 0:
			combo = 0
			ui.clear_combo()

func _set_overdrive(active: bool) -> void:
	overdrive_active = active
	player.set_overdrive_active(active)
	ui.set_overdrive(active, overdrive_charge / 34.0)
	if active:
		audio.play("upgrade")

func _leave(replay: bool, quit_app := false, destination_chapter := 0) -> void:
	if leaving:
		return
	# An accepted death is not just a balance checkpoint. Retry its receipt before
	# abandoning the scene after a transient save failure; never lose the reward.
	if _clear_received and not _receipt_saved:
		save_clear(_chapter_number())
		if not _receipt_saved:
			if quit_app:
				get_tree().quit(1)
			return
	if not quit_app and replay and session != null and session.has_pending_clear():
		return
	if growth != null and session != null and not session.checkpoint_coins(growth.coins):
		_pending_exit = {"replay":replay,"quit_app":quit_app,"destination_chapter":destination_chapter}
		_modal("旅程保存失败", session.failure_message, &"save_error")
		ui.retry_save_button.text = "重试保存并离开"
		if quit_app:
			get_tree().quit(1)
		return
	_pending_exit.clear()
	leaving = true
	get_tree().paused = true
	if feedback != null:
		feedback.reset_all()
	audio.begin_shutdown()
	var deadline := Time.get_ticks_msec() + 2000
	while not audio.is_shutdown_complete():
		if Time.get_ticks_msec() >= deadline:
			push_error("Chapter audio shutdown timed out")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	if quit_app:
		get_tree().quit(0)
		return
	var selected_chapter: int = _chapter_number() if destination_chapter == 0 else destination_chapter
	var destination: Node = Registry.instantiate_chapter(selected_chapter) if replay else load("res://scenes/Main.tscn").instantiate()
	if destination == null:
		push_error("Chapter destination unavailable")
		get_tree().quit(1)
		return
	if replay:
		destination.run_loop = run_loop
		# A fresh run must not silently reuse the prior seed, even on RNG collision.
		destination.run_seed = randi()
		if destination.run_seed == run_seed: destination.run_seed = run_seed + 1 if run_seed < 9223372036854775807 else 0
	destination.campaign_store_path = campaign_store_path
	destination.journey_store_path = journey_store_path
	destination.audio_enabled = audio_enabled
	# Chapter replays keep audio preferences; Main reload also receives them.
	if replay:
		destination.bgm_volume = audio.bgm_volume_linear
		destination.bgm_muted = audio.bgm_muted
	else:
		destination.initial_bgm_volume = audio.bgm_volume_linear
		destination.initial_bgm_muted = audio.bgm_muted
	get_tree().paused = false
	get_parent().add_child(destination)
	if destination.get_parent() == get_tree().root:
		get_tree().current_scene = destination
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_leave(false, true)

func _exit_tree() -> void:
	if framing != null and is_instance_valid(framing):
		framing.reset_framing()
	if feedback != null and is_instance_valid(feedback):
		feedback.reset_all()
