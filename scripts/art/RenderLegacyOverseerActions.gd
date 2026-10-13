extends SceneTree
## Actual Actor/controller clock fixtures, body-only GPU audit. No gameplay
## victory, ordinary input, UI, projectile lifetime or performance claim.
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Evidence = preload("res://scripts/art/CampaignChainEvidence.gd")
const ACTIONS := ["sweep", "slam", "aimed_fan", "twin_spiral", "broken_ring"]
var viewport: SubViewport
var host: Node2D
var failed := false
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("LEGACY ACTION GPU FAIL: " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not Evidence.safe_id(args[0]): quit(1); return
	var output := "res://build/diagnostics/campaign-goal/" + args[0] + "/"
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(output), "fresh GPU output required")
	if failed: quit(1); return
	var sources := Evidence.build_source_bank()
	check(not sources.is_empty(), "canonical fixed-root source bank absent")
	DirAccess.make_dir_recursive_absolute(output)
	host = Node2D.new()
	root.add_child(host)
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.world_2d = World2D.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var clips: Array[String] = ["idle", "walk", "hit", "entrance", "death"]
	for action in ACTIONS:
		for stage in ["warning", "attack", "recovery"]: clips.append(action + "_" + stage)
	clips.append("phase_transition")
	var sheet := Image.create(clips.size()*320,960,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("343d40"))
	var keyed: Array[Dictionary] = []
	for column in clips.size():
		var clip := clips[column]
		for left in [false,true]:
			for strength in [0.0,0.35]:
				for row in 3:
					var phase: float = [0.0,0.45,0.85][row]
					var fixture := _make_actor(left)
					var actor = fixture.actor
					var body: Node2D = actor.get_visual_node()
					var duration := _prepare(actor, clip)
					_advance(actor, body, clip, duration*phase)
					actor.boss_flash_material.set_shader_parameter("flash_amount", strength)
					await process_frame
					await RenderingServer.frame_post_draw
					check(body.player.current_animation == clip, "real controller clip mismatch " + clip)
					var pixels := viewport.get_texture().get_image()
					var sample := _inspect(pixels, body, clip)
					sample.merge({"clip":clip,"phase":phase,"left":left,"flash":strength,"combat_duration":duration})
					keyed.append(sample)
					if not left and strength == 0:
						sheet.blend_rect(pixels,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
					fixture.shots.free()
					fixture.target.free()
					if is_instance_valid(actor): actor.free()
					if is_instance_valid(body): body.free() # Detached death only.
	check(sheet.save_png(output+"poses.png") == OK, "pose sheet write")
	for action in ACTIONS + ["phase_transition"]:
		var column: int = clips.find(action if action == "phase_transition" else action+"_warning")
		check(sheet.get_region(Rect2i(column*320,0,320 if action == "phase_transition" else 960,960)).save_png(output+action+".png") == OK, "action sheet write")
	var continuous: Array[Dictionary] = []
	for clip in clips:
		if not clip.contains("_"): continue
		for left in [false,true]:
			var fixture := _make_actor(left)
			var actor = fixture.actor
			var body: Node2D = actor.get_visual_node()
			var duration := _prepare(actor, clip)
			var previous := PackedByteArray()
			var changes := 0
			var samples: Array[Dictionary] = []
			for frame in 30:
				_advance(actor, body, clip, duration*(0.5 if frame == 0 else 1.0)/30.0)
				await process_frame
				await RenderingServer.frame_post_draw
				check(body.player.current_animation == clip, "continuous real stage mismatch " + clip)
				var pixels := viewport.get_texture().get_image()
				samples.append(_inspect(pixels, body, clip))
				var bytes := pixels.get_data()
				if frame > 0 and bytes != previous: changes += 1
				previous = bytes
			check(changes >= 25, "continuous real action static " + clip)
			continuous.append({"clip":clip,"left":left,"samples":samples,"adjacent_changes":changes,"combat_duration":duration})
			fixture.shots.free()
			fixture.target.free()
			actor.free()
	check(Evidence.source_bank_matches(sources), "source changed during GPU capture")
	var report := {"passed":not failed,"checks":checks,"actor":"OverseerBoss","scene":"res://scenes/actors/native/root_overseer_paper_v1.tscn","clips":clips,"keyed":keyed,"continuous":continuous,"source_bank":sources,"scope":"Actual legacy Actor, native skin/shared shader, authoritative explicit controller-clock fixtures for 21 clips and 16 action stages, both facing directions; keyed flash0/.35. Ground warning, shots, target and world status intentionally excluded from BODY pixels. Continuous samples additionally check each frame alpha/edge/live-body bounds. Not normal input, Main/chapter UI, damage dodge, flying-projectile lifetime, performance, independent export or victory."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	viewport.free()
	host.free()
	await process_frame
	print("LEGACY ACTION GPU %s: %d checks, %d keyed poses, %d continuous frames" % ["FAIL" if failed else "PASS",checks,keyed.size(),continuous.size()*30])
	quit(1 if failed else 0)
func _make_actor(left: bool) -> Dictionary:
	var shots := Node2D.new()
	shots.process_mode = Node.PROCESS_MODE_DISABLED
	host.add_child(shots)
	var target := Node2D.new()
	target.position = Vector2(700,164)
	host.add_child(target)
	var actor := Boss.new()
	actor.setup(0,shots,target)
	actor.position = Vector2(160,164)
	viewport.add_child(actor)
	actor.set_physics_process(false)
	actor.get_tentacle_attack().hide()
	actor.get_tentacle_attack().ground_fill.hide()
	actor.get_attack_director().get_pattern().hide()
	actor.world_status.hide()
	actor.get_visual_node().set_facing_left(left)
	return {"actor":actor,"shots":shots,"target":target}
func _prepare(actor: CharacterBody2D, clip: String) -> float:
	var body = actor.get_visual_node()
	if clip == "entrance": return actor.get_attack_director().ENTRANCE_SECONDS
	actor.get_attack_director().advance(1.41)
	actor._update_entrance_reveal()
	if clip == "phase_transition":
		actor.take_damage(4000)
		return actor.get_attack_director().TRANSITION_SECONDS
	if clip == "death":
		actor.take_damage(1e9)
		body.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		# Lethal Actor is queued for deletion; keyed loop accesses only retained body.
		return body.player.get_animation("death").length
	if clip in ["idle","walk","hit"]:
		actor.velocity = Vector2(60,0) if clip == "walk" else Vector2.ZERO
		if clip == "hit": actor.take_damage(1)
		actor._update_boss_motion(0)
		return body.player.get_animation(clip).length
	var action := clip.get_slice("_",0)
	if clip.begins_with("aimed_fan"): action = "aimed_fan"
	elif clip.begins_with("twin_spiral"): action = "twin_spiral"
	elif clip.begins_with("broken_ring"): action = "broken_ring"
	var stage := clip.get_slice("_",clip.get_slice_count("_")-1)
	var melee = actor.get_tentacle_attack()
	if action in ["sweep","slam"]:
		if action == "sweep": check(melee.start_sweep(actor.target_player.position), "start sweep")
		else: check(melee.start_slam(melee.make_slam_targets(actor.target_player.position,2)), "start slam")
		melee.set_physics_process(false)
		var warning: float = melee.SWEEP_WARNING_SECONDS if action == "sweep" else melee.SLAM_WARNING_SECONDS
		if stage != "warning": melee.advance_attack(warning if action == "slam" else warning+(melee.SWEEP_ACTIVE_SECONDS+0.001 if stage == "recovery" else 0.0))
		if action == "slam" and stage == "recovery": actor._update_boss_motion(body.player.get_animation("slam_attack").length)
		else: actor._update_boss_motion(0)
		return warning if stage == "warning" else melee.SWEEP_ACTIVE_SECONDS if action == "sweep" and stage == "attack" else body.player.get_animation(clip).length
	var pattern = actor.get_attack_director().get_pattern()
	check(pattern.start_pattern(StringName(action)), "start pattern " + action)
	var plan: Array = pattern.get_active_plan()
	var first: float = plan[0].time
	var last: float = plan[-1].time
	if stage != "warning": pattern.advance(last+0.001 if stage == "recovery" else first)
	actor._update_boss_motion(0)
	return first if stage == "warning" else last-first if stage == "attack" else body.player.get_animation(clip).length
func _advance(actor: CharacterBody2D, body: Node2D, clip: String, delta: float) -> void:
	if clip == "death": body.sample_clip(clip,delta); return
	if clip == "entrance":
		actor.get_attack_director().advance(delta)
		actor._update_entrance_reveal()
	elif clip == "phase_transition": actor.get_attack_director().advance(delta)
	elif clip.ends_with("_warning") or (clip.ends_with("_attack") and not clip.begins_with("slam")):
		if clip.begins_with("sweep") or clip.begins_with("slam"): actor.get_tentacle_attack().advance_attack(delta)
		else: actor.get_attack_director().get_pattern().advance(delta)
	# Only completed bodies/hit/gait advance a visual time; authoritative action
	# states are read from the controllers and ignore visual delta for their pose.
	actor._update_boss_motion(delta)
func _inspect(pixels: Image, body: Node2D, clip: String) -> Dictionary:
	var bounds: Rect2 = body.transform*body.get_node("Facing").transform*body.body_rect
	var opaque := 0; var partial := 0; var edge := 0; var outside := 0
	for y in 320:
		for x in 320:
			var alpha := pixels.get_pixel(x,y).a
			opaque += 1 if alpha >= 0.99 else 0
			partial += 1 if alpha > 0.01 and alpha < 0.99 else 0
			edge += 1 if alpha > 0.01 and (x == 0 or y == 0 or x == 319 or y == 319) else 0
			outside += 1 if alpha >= 0.99 and not bounds.grow(1).has_point(Vector2(x+0.5-160,y+0.5-164)) else 0
	check(opaque > 5000 and partial == 0 and edge == 0, "body alpha/edge " + clip)
	check(clip == "death" or outside == 0, "live bounds " + clip + " " + str(outside))
	return {"opaque":opaque,"partial":partial,"edge":edge,"outside_bounds":outside}
