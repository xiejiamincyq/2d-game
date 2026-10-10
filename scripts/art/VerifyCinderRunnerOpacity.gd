extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const OUT := "res://build/diagnostics/campaign-goal/cinder-opacity-v1/"
class BodyOnly extends EnemySource:
	func _draw() -> void:
		pass # Retain actual body creation/shader; exclude actor's HUD only.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(OUT):
		push_error("CINDER OPACITY FAIL: requires GPU and fresh output")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources := {}
	for path in ["scripts/art/VerifyCinderRunnerOpacity.gd","scripts/actors/Enemy.gd","scripts/components/NativeCinderRunnerMotion.gd","scripts/components/NativeActorView.gd","scenes/actors/native/cinder_runner_paper_v1.tscn","assets/art/actors/native/cinder_runner_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
		if sources[path].length() != 64:
			push_error("CINDER OPACITY FAIL: missing source hash: " + path)
			quit(1)
			return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192,192)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var samples: Array[Dictionary] = []
	var passed := true
	for left in [false,true]:
		var enemy := BodyOnly.new()
		enemy.setup(EnemySource.EnemyKind.DASHER,0,viewport)
		enemy.position = Vector2(96,112)
		viewport.add_child(enemy)
		enemy.set_physics_process(false)
		var body: Node2D = enemy.native_visual
		body.set_facing_left(left)
		for clip in ["idle","walk","warning","attack","hit","death"]:
			for phase in [0.0,0.5,1.0]:
				body.sample_clip(clip,body.player.get_animation(clip).length * phase)
				for flash in [0.0,0.35]:
					enemy.static_flash_material.set_shader_parameter("flash_amount",flash)
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var opaque := 0
					var partial := 0
					var edge := 0
					for y in 192:
						for x in 192:
							var alpha := pixels.get_pixel(x,y).a
							opaque += 1 if alpha > 0.99 else 0
							partial += 1 if alpha > 0.01 and alpha < 0.99 else 0
							edge += 1 if alpha > 0.01 and (x == 0 or y == 0 or x == 191 or y == 191) else 0
					var ok := opaque > 700 and partial == 0 and edge == 0
					passed = passed and ok
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge_pixels":edge,"passed":ok})
		enemy.free()
	for path in sources:
		passed = passed and FileAccess.get_sha256("res://" + path) == sources[path]
	var file := FileAccess.open(OUT + "report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"samples":samples,"sources":sources,"scope":"Actual Enemy-created native body and hit shader retained; only actor HUD drawing excluded. Six clips x three phases x two flips x two flash states; not continuous all-pose alpha or human acceptance."},"\t"))
	file.close()
	viewport.free()
	await process_frame
	if not passed:
		push_error("CINDER OPACITY FAIL: actual body translucent/clipped or source changed")
	print("CINDER OPACITY %s: %d actual GPU samples" % ["PASS" if passed else "FAIL",samples.size()])
	quit(0 if passed else 1)
