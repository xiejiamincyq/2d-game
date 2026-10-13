extends SceneTree
## Bounded actual Vfx / Player / Enemy / Boss fixtures, not ordinary gameplay.
const Vfx = preload("res://scripts/effects/CombatVfx.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Enemy = preload("res://scripts/actors/Enemy.gd")
const Boss = preload("res://scripts/actors/OverseerBoss.gd")
const Evidence = preload("res://scripts/art/CampaignChainEvidence.gd")
var checks := 0
var failed := false
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("NATIVE IMPACT GPU FAIL: " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not Evidence.safe_id(args[0]): quit(1); return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(output), "fresh GPU output required")
	if failed: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := Evidence.build_source_bank()
	check(not sources.is_empty(), "canonical source bank absent")
	var view := SubViewport.new()
	view.size = Vector2i(128,128)
	view.world_2d = World2D.new()
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var vfx := Vfx.new()
	view.add_child(vfx)
	vfx.set_process(false)
	var samples: Array[Dictionary] = []
	var isolated := Image.create(512,384,false,Image.FORMAT_RGBA8)
	isolated.fill(Color("343d40"))
	for row in 3:
		var strength: float = [0.3,1.0,2.0][row]
		for column in 4:
			var time: float = [0.0,0.035,0.09,0.23][column]
			vfx.clear_all()
			vfx.request_effect(Vfx.SPARK,Vector2(64,64),Vector2.RIGHT,strength)
			vfx._process(time)
			await process_frame; await RenderingServer.frame_post_draw
			var pixels := view.get_texture().get_image()
			var visible := 0; var edge := 0; var outside := 0
			for y in 128:
				for x in 128:
					var alpha := pixels.get_pixel(x,y).a
					if alpha <= 0.01: continue
					visible += 1
					edge += 1 if x == 0 or y == 0 or x == 127 or y == 127 else 0
					outside += 1 if not Rect2(24,24,80,80).has_point(Vector2(x,y)) else 0
			check(edge == 0 and outside == 0, "native spark spills outside safe local region")
			check(visible > 4 if time < 0.1+0.06*strength else visible == 0, "native impact invisible or retained after expiry")
			samples.append({"intensity":strength,"elapsed":time,"visible_pixels":visible,"edge":edge,"outside_safe_region":outside})
			isolated.blend_rect(pixels,Rect2i(0,0,128,128),Vector2i(column*128,row*128))
	check(isolated.save_png(output+"isolated.png") == OK, "isolated sheet write")
	view.free()
	var stage := SubViewport.new()
	stage.size = Vector2i(960,400)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var background := ColorRect.new()
	background.size = Vector2(960,400)
	background.color = Color("435750")
	background.z_index = -100
	stage.add_child(background)
	var actors: Array[CharacterBody2D] = []
	var player := Player.new()
	player.position = Vector2(160,215)
	stage.add_child(player)
	player.set_physics_process(false)
	player.advance_entrance(player.get_entrance_duration()+0.01)
	actors.append(player)
	var target := Node2D.new()
	target.position = Vector2(1300,215)
	stage.add_child(target)
	var enemy := Enemy.new()
	enemy.setup(Enemy.EnemyKind.SCRAPPER,0,stage,target)
	enemy.position = Vector2(480,215)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	actors.append(enemy)
	var boss := Boss.new()
	boss.setup(0,stage,target)
	boss.position = Vector2(800,215)
	stage.add_child(boss)
	boss.set_physics_process(false)
	boss.get_attack_director().advance(1.41)
	boss._update_entrance_reveal()
	boss._update_boss_motion(0)
	actors.append(boss)
	for actor in actors:
		if actor != player:
			actor.get_visual_node().player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.get_visual_node().sample_clip("idle",0)
	check(enemy.basic_attack.begin(enemy,target,enemy.basic_attack.Move.CLAW), "actual head warning cannot start")
	enemy._queue_visual_redraw()
	check(enemy.should_show_attack_marker(), "actual head warning suppressed")
	# Transparent baseline supplies a true opaque actor mask: translucent contact
	# shadows/antialiased fringe may legitimately blend with ground decoration.
	stage.transparent_bg = true
	background.hide()
	await process_frame; await RenderingServer.frame_post_draw
	var actor_mask := stage.get_texture().get_image()
	stage.transparent_bg = false
	background.show()
	await process_frame; await RenderingServer.frame_post_draw
	var baseline := stage.get_texture().get_image()
	var effects := Vfx.new()
	stage.add_child(effects)
	effects.set_process(false)
	for actor in actors:
		for hit in 20: effects.request_effect(Vfx.SPARK,actor.position,Vector2.RIGHT,1)
		# Contact-edge sample remains visible without flooding the opaque body.
		effects.request_effect(Vfx.SPARK,actor.position+Vector2(34,-15),Vector2.RIGHT,1)
		if actor != player: effects.request_effect(Vfx.BLAST,actor.position,Vector2.UP,1)
	effects._process(0.035)
	# Deliberately overlap the genuine warning with friendly hit decoration.
	var marker_at := enemy.position+Vector2(0,enemy.get_attack_marker_top()-7)
	for hit in 20: effects.request_effect(Vfx.SPARK,marker_at,Vector2.RIGHT,2)
	await process_frame; await RenderingServer.frame_post_draw
	var combined := stage.get_texture().get_image()
	var bodies: Array[Dictionary] = []
	for actor in actors:
		var visual = actor.get_visual_node()
		var bounds: Rect2 = visual.global_transform * actor.get_visual_rect()
		var compare := bounds.intersection(Rect2(0,0,960,400))
		var unchanged := 0; var changed := 0
		for y in range(int(compare.position.y),int(compare.end.y)):
			for x in range(int(compare.position.x),int(compare.end.x)):
				if actor_mask.get_pixel(x,y).a < 0.99: continue
				if combined.get_pixel(x,y).is_equal_approx(baseline.get_pixel(x,y)): unchanged += 1
				else: changed += 1
		check(unchanged > 300 and changed == 0, "ground impact changes actual actor pixels")
		bodies.append({"actor":actor.get_script().resource_path,"unchanged_body_pixels":unchanged,"changed_body_pixels":changed,"root_alpha":actor.modulate.a})
	check(combined.get_data() != baseline.get_data(), "actual impact fixture has no rendered difference")
	var marker_pixels := 0; var marker_changed := 0
	for y in range(int(marker_at.y)-10,int(marker_at.y)+10):
		for x in range(int(marker_at.x)-5,int(marker_at.x)+5):
			if actor_mask.get_pixel(x,y).a < 0.99: continue
			marker_pixels += 1
			marker_changed += 0 if combined.get_pixel(x,y).is_equal_approx(baseline.get_pixel(x,y)) else 1
	check(marker_pixels > 60 and marker_changed == 0, "friendly impact erases actual head warning")
	check(effects.get_child_count() == 0 and effects.get_total_effect_count() <= 184, "per-effect nodes or cap regression")
	check(baseline.save_png(output+"actors-baseline.png") == OK and combined.save_png(output+"actors-impact.png") == OK, "actor comparison capture")
	stage.free()
	await process_frame
	check(Evidence.source_bank_matches(sources), "source changed during effect GPU capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"checks":checks,"samples":samples,"actors":bodies,"warning":{"opaque_pixels":marker_pixels,"changed_pixels":marker_changed},"source_bank":sources,"scope":"Actual bounded Vfx at twelve intensity/time fixtures and actual native Player/Scrapper/Overseer combined with hit/blast flooding on a flat control backdrop; opaque body-pixel comparison, genuine Scrapper head-warning overlap, expiry, safe-region and layer checks. Effects deliberately fade; this does not declare actor alpha from isolated effect pixels. Actor poses held with explicit manual sampling. No Main, user saves, ordinary input, dense game performance, all warnings or all effects proof."},"\t")); file.close()
	print("NATIVE IMPACT GPU %s: %d checks, 12 isolated samples, 3 actual bodies" % ["FAIL" if failed else "PASS",checks])
	quit(1 if failed else 0)
