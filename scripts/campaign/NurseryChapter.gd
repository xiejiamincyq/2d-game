extends Node2D
## Actual first-chapter coordinator. No wave snapshots or fake permanent clears.

const MapScene = preload("res://scenes/world/mist_nursery.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/NurseryEncounterDirector.gd")
const Interface = preload("res://scripts/ui/NurseryChapterUI.gd")
const Audio = preload("res://scripts/systems/AudioManager.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Feedback = preload("res://scripts/systems/CombatFeedback.gd")
const Vfx = preload("res://scripts/effects/CombatVfx.gd")
const Effects = preload("res://scripts/effects/CameraEffects.gd")
const Framing = preload("res://scripts/systems/BossCameraFraming.gd")
const Outline = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
const Coin = preload("res://scripts/pickups/CoinPickup.gd")
const Heart = preload("res://scripts/pickups/HeartPickup.gd")
const Shield = preload("res://scripts/pickups/ShieldPickup.gd")
var campaign_store_path := Store.DEFAULT_PATH
var audio_enabled := true
var bgm_volume := 0.65
var bgm_muted := false
var run_seed: int = -9223372036854775807
var progress := Progress.new()
var store: CampaignProgressStore
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
var manually_paused := false
var leaving := false
var kills := 0
var elapsed := 0.0
var overdrive_charge := 0.0
var overdrive_active := false
var combo := 0
var combo_remaining := 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	Engine.time_scale = 1
	ui = Interface.new()
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
	ui.retry_save_requested.connect(func() -> void: save_clear(1))
	ui.settlement_offer_selected.connect(_claim_offer)
	ui.settlement_close_requested.connect(_finish_reward)
	if DisplayServer.get_name() == "headless" and campaign_store_path == Store.DEFAULT_PATH:
		campaign_store_path = "user://five_minute_overdrive_campaign_test_v1.json"
	store = Store.new(campaign_store_path)
	var status := store.load_progress(progress)
	if status not in [Store.LoadResult.MISSING, Store.LoadResult.LOADED]:
		ui.present("章节无法启动", "存档异常或版本不兼容：原文件保留，请返回帐篷处理；未开始战斗。", &"error")
		return
	if run_seed == -9223372036854775807:
		run_seed = randi()
	_build_world()

func _build_world() -> void:
	map = MapScene.instantiate()
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
	growth.setup(player)
	director = Director.new()
	# WaveDirector's canonical deferred drop callback targets its parent owner.
	director.process_mode = PROCESS_MODE_PAUSABLE
	add_child(director)
	director.encounter_prepared.connect(_on_prepared)
	director.encounter_status.connect(func(encounter: Dictionary, remaining: int) -> void:
		var label: String = "过渡首领" if director.state == Director.State.BOSS else encounter.name
		ui.wave_label.text = "第1关 · %s\n剩余 %d" % [label, remaining]
	)
	director.reward_ready.connect(_on_reward)
	director.route_ready.connect(func() -> void:
		_modal("岔路 / 选择风险", "两段必经遭遇已完成。补给后直接迎战首领，或深入根巢换取额外构筑与金币。", &"route")
	)
	director.chapter_boss_ready.connect(func(label: String) -> void:
		_modal("首领区域", label + "\n此演员仅用于关卡工程试玩；不是新骨骼藤冠守卫成品。", &"boss")
	)
	director.chapter_cleared.connect(save_clear)
	director.run_failed.connect(func(reason: String) -> void:
		_modal("探索失败", reason + "\n永久已解锁进度保留；本局构筑不保留。", &"failed")
		audio.play("defeat")
	)
	director.boss_spawned.connect(func(boss: Node, _label: String, maximum: float) -> void:
		framing.track_boss(boss)
		ui.show_boss_health(boss, "过渡首领 · 深渊监工", maximum)
		ui.wave_label.text = "第1关 · 过渡首领"
	)
	director.boss_health_changed.connect(ui.set_boss_health)
	director.boss_defeated.connect(func(_boss: Node) -> void: ui.hide_boss_health())
	director.boss_cue.connect(audio.play_boss_cue)
	director.damage_resolved.connect(feedback.on_damage_resolved)
	director.enemy_killed.connect(_on_kill)
	director.collection_window_changed.connect(ui.set_collection_window)
	director.start_run(run_seed, player, enemies, projectiles, portals, growth, map.layout)
	player.set_enemy_provider(director.get_active_enemies)
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
	audio.set_laser_active(false)
	ui.present(title, description, stage)

func _on_prepared(encounter: Dictionary) -> void:
	_modal("第1关 / " + encounter.name, "雾苔苗圃 · 随机地图种子 %d\n两段必经遭遇 → 风险选择 → 首领。玩家及部分演员仍为过渡资源。" % run_seed, &"intro")

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
		_modal("暂停探索", "空格或 Esc 继续。返回帐篷将结束本局；永久解锁保留。", &"pause")
	else:
		_resume_combat()

func save_clear(chapter: int) -> bool:
	if leaving or clear_saved or chapter != 1 or director == null or director.state != Director.State.CLEARED or director.defeated_boss_instance <= 0:
		return false
	var candidate := Progress.new()
	candidate.restore_state(progress.to_state())
	if not candidate.has_cleared(1):
		candidate.record_boss_defeat(1)
	if not store.save_progress(candidate):
		_modal("首领已击败 · 保存失败", "未显示虚假解锁，未覆盖异常存档。可重试保存；返回前请注意本次通关尚未永久记录。", &"save_error")
		return false
	progress = candidate
	clear_saved = true
	_modal("第1关通关 · 已保存", "第2关已永久解锁（内容仍制作中）。可重玩本关获得不同地图与局内构筑。过渡首领不计为新Boss资源完成。", &"cleared")
	audio.play("victory")
	return true

func _on_kill(_enemy: Node, _source: StringName, _coins: int) -> void:
	kills += 1
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

func _leave(replay: bool, quit_app := false) -> void:
	if leaving:
		return
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
	var destination: Node = load("res://scenes/campaign/nursery_chapter.tscn" if replay else "res://scenes/Main.tscn").instantiate()
	destination.campaign_store_path = campaign_store_path
	destination.audio_enabled = audio_enabled
	# Chapter replays keep audio preferences; Main reload also receives them.
	if replay:
		destination.bgm_volume = audio.bgm_volume_linear
		destination.bgm_muted = audio.bgm_muted
	else:
		destination.initial_bgm_volume = audio.bgm_volume_linear
		destination.initial_bgm_muted = audio.bgm_muted
	get_tree().paused = false
	get_tree().root.add_child(destination)
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
