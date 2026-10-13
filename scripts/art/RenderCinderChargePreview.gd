extends SceneTree
## GPU resource poses + actual Enemy physics in deterministic test lanes.
## Not natural Main play, chapter 2 readiness, or human playtest acceptance.
const Actor = preload("res://scenes/actors/native/cinder_runner_paper_v2.tscn")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OUT := "res://build/diagnostics/campaign-goal/cinder-charge-v1/"
const CLIPS := ["charge_warning","charge","charge_recovery"]
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void:
		hits.append(amount)
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("CINDER CHARGE GPU FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(OUT),"GPU and unused output required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources := {}
	for path in ["scripts/art/RenderCinderChargePreview.gd","scripts/actors/Enemy.gd","scripts/components/CinderChargeAttack.gd","scripts/components/NativeCinderRunnerMotion.gd","scripts/components/NativeActorView.gd","scenes/art/technical/CinderChargeDraft.gd","scenes/actors/native/cinder_runner_paper_v2.tscn","assets/art/actors/native/cinder_runner_motion_v2.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"empty source hash")
	var tiny := SubViewport.new()
	tiny.size = Vector2i(128,128)
	tiny.transparent_bg = true
	tiny.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(tiny)
	var sheet := SubViewport.new()
	sheet.size = Vector2i(1200,600)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var background := ColorRect.new()
	background.size = sheet.size
	background.color = Color("304138")
	sheet.add_child(background)
	var samples: Array[Dictionary] = []
	for column in 6:
		var clip: String = CLIPS[column%3]
		var title := Label.new()
		title.text = clip + (" LEFT" if column>=3 else " RIGHT")
		title.position = Vector2(column*200+8,10)
		title.add_theme_font_size_override("font_size",16)
		sheet.add_child(title)
		var actor = Actor.instantiate()
		tiny.add_child(actor)
		actor.position = Vector2(64,76)
		actor.set_facing_left(column>=3)
		for row in 3:
			var phase: float = [0.0,0.4,0.85][row]
			actor.sample_clip(clip,actor.player.get_animation(clip).length*phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var bitmap := tiny.get_texture().get_image()
			var opaque := 0
			var partial := 0
			var edge := 0
			for y in 128:
				for x in 128:
					var a := bitmap.get_pixel(x,y).a
					opaque += 1 if a>=0.99 else 0
					partial += 1 if a>0.01 and a<0.99 else 0
					edge += 1 if a>0.01 and (x==0 or y==0 or x==127 or y==127) else 0
			check(opaque>700 and partial==0 and edge==0,"translucent / clipped native pose "+clip)
			samples.append({"clip":clip,"left":column>=3,"phase":phase,"opaque":opaque,"partial":partial,"edge":edge})
			var preview = Actor.instantiate()
			sheet.add_child(preview)
			preview.position = Vector2(column*200+110,135+row*165)
			preview.scale = Vector2.ONE*2
			preview.set_facing_left(column>=3)
			preview.sample_clip(clip,actor.player.get_animation(clip).length*phase)
		actor.free()
	await process_frame
	await RenderingServer.frame_post_draw
	check(sheet.get_texture().get_image().save_png(OUT+"poses.png")==OK,"pose write")
	sheet.free()
	tiny.free()
	var arena := Node2D.new()
	root.add_child(arena)
	var backdrop := ColorRect.new()
	backdrop.color = Color("304138")
	backdrop.size = Vector2(1280,720)
	arena.add_child(backdrop)
	var enemies: Array[CharacterBody2D] = []
	var targets: Array[Target] = []
	for lane in 3:
		var title := Label.new()
		title.position = Vector2(120,100+lane*180)
		title.text = ["LOCKED CHARGE / SINGLE HIT","SIDE DODGE / NO HOMING","PHYSICAL WALL / STOP + RECOVER"][lane]
		arena.add_child(title)
		var target := Target.new()
		target.position = Vector2(420,155+lane*180)
		arena.add_child(target)
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(-13,-13),Vector2(13,-13),Vector2(13,13),Vector2(-13,13)])
		marker.color = Color("edbd63")
		target.add_child(marker)
		targets.append(target)
		var enemy := EnemyScript.new()
		enemy.setup(EnemyScript.EnemyKind.DASHER,0,arena,target)
		enemy.position = Vector2(270,155+lane*180)
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.charge_attack.cooldown = 0
		enemies.append(enemy)
		if lane == 2:
			var wall := StaticBody2D.new()
			wall.position = Vector2(340,515)
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(12,130)
			shape.shape = rectangle
			wall.add_child(shape)
			var art := Polygon2D.new()
			art.polygon = PackedVector2Array([Vector2(-6,-65),Vector2(6,-65),Vector2(6,65),Vector2(-6,65)])
			art.color = Color("a69880")
			wall.add_child(art)
			arena.add_child(wall)
	await physics_frame
	for enemy in enemies:
		enemy.set_physics_process(true)
	var frames: Array[Dictionary] = []
	var observed := {}
	for frame in 54:
		await physics_frame
		if frame == 7:
			targets[1].position.y -= 80
		var states: Array[Dictionary] = []
		for lane in 3:
			var enemy := enemies[lane]
			var clip: String = enemy.native_visual.player.current_animation
			observed[clip] = true
			states.append({"lane":lane,"x":enemy.position.x,"y":enemy.position.y,"stage":enemy.charge_attack.stage,"clip":clip,"hits":targets[lane].hits.size()})
		frames.append({"frame":frame,"states":states})
		if frame in [4,17,32]:
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OUT+"runtime-%02d.png"%frame)==OK,"runtime image write")
	check(observed.has("charge_warning") and observed.has("charge") and observed.has("charge_recovery"),"real actor never presents all charge phases")
	check(targets[0].hits == [18.0],"real actor charge not one hit")
	check(targets[1].hits.is_empty(),"real actor homed into dodge")
	check(targets[2].hits.is_empty() and enemies[2].charge_attack.blocked,"wall charge passed / no recovery")
	for path in sources:
		check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during capture")
	var file := FileAccess.open(OUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"scope":"18 GPU resource poses and 54-frame actual Enemy physics lanes; not Main natural input or chapter readiness","samples":samples,"frames":frames,"sources":sources},"\t"))
	file.close()
	arena.free()
	await process_frame
	print("CINDER CHARGE GPU %s: 18 poses + actual 54-frame collision/dodge/single-hit lanes" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
