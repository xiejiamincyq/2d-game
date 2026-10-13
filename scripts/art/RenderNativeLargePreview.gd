extends SceneTree
## Review actual large Enemy-created bodies; reusable for BRUISER/OVERSEER.
## Author tool only. Optional slam mode requires the reviewed BRUISER v2.
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const CLIPS := ["idle","walk","hit","entrance","death"]
class BodyOnly extends EnemySource:
	func _draw() -> void:
		pass # HUD excluded for alpha counting, real body/shader creation retained.
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void: hits.append(amount)
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("LARGE GPU FAIL: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [2,3] or args[0] not in ["3","6"] or not args[1].is_valid_identifier() or (args.size()==3 and [args[0],args[2]] not in [["3","slam"],["6","commander"]]):
		push_error("LARGE GPU FAIL: expected large EnemyKind and new output identifier")
		quit(1)
		return
	var kind_id := int(args[0])
	var clips: Array = CLIPS.duplicate()
	var slam := args.size()==3 and args[2]=="slam"
	var commander := args.size()==3 and args[2]=="commander"
	if slam:
		clips.erase("death")
		clips.append_array(["slam_warning","slam_attack","slam_recovery","death"])
	if commander:
		clips.erase("death")
		clips.append_array(["melee_warning","melee_attack","melee_recovery","burst_warning","burst_attack","command","death"])
	var output := "res://build/diagnostics/campaign-goal/"+args[1]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new output required")
	if failed:
		quit(1)
		return
	var probe := BodyOnly.new()
	probe.setup(kind_id,0,root)
	root.add_child(probe)
	probe.set_physics_process(false)
	check(probe.native_visual!=null,"large enemy still raster")
	if slam: check(probe.native_visual.player.has_animation("slam_attack"),"post-rig slam resource not current")
	if commander: check(probe.native_visual.player.has_animation("burst_attack"),"post-rig commander resource not current")
	if failed:
		probe.free()
		quit(1)
		return
	var scene: String = probe.native_visual.scene_file_path
	var library: String = probe.native_visual.player.get_animation_library("").resource_path
	probe.free()
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["res://scripts/art/RenderNativeLargePreview.gd","res://scripts/actors/Enemy.gd","res://scripts/components/NativeLargeMotion.gd","res://scripts/components/NativeStoneCarrierMotion.gd","res://scripts/components/NativeRootCommanderMotion.gd","res://scripts/components/NativeProjectileOriginSafety.gd","res://scripts/components/NativeScrapperMotion.gd","res://scripts/components/NativeActorView.gd",scene,library,"res://assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256(path)
		check(sources[path].length()==64,"missing runtime source hash "+path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Image.create(clips.size()*256,768,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("304138"))
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var enemy := BodyOnly.new()
		enemy.setup(kind_id,0,viewport)
		enemy.position = Vector2(128,136)
		viewport.add_child(enemy)
		enemy.set_physics_process(false)
		var body: Node2D = enemy.native_visual
		body.set_facing_left(left)
		for column in clips.size():
			var clip: String = clips[column]
			check(body.player.has_animation(clip),"missing non-attack clip "+clip)
			if failed:
				break
			for row in 3:
				var phase: float = [0.0,0.45,0.85][row]
				check(body.sample_clip(clip,body.player.get_animation(clip).length*phase),"requested pose refused after terminal death "+clip)
				for flash in [0.0,0.35]:
					enemy.static_flash_material.set_shader_parameter("flash_amount",flash)
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var opaque := 0
					var partial := 0
					var edge := 0
					var outside_body_bounds := 0
					for y in 256:
						for x in 256:
							var alpha := pixels.get_pixel(x,y).a
							opaque += 1 if alpha>=0.99 else 0
							partial += 1 if alpha>0.01 and alpha<0.99 else 0
							edge += 1 if alpha>0.01 and (x==0 or y==0 or x==255 or y==255) else 0
							if alpha>=0.99 and not enemy.get_visual_rect().grow(1).has_point(Vector2(x+0.5-128,y+0.5-136)):
								outside_body_bounds += 1
					check(opaque>1500 and partial==0 and edge==0,"large body translucent/clipped "+clip)
					check(clip=="death" or outside_body_bounds==0,"live pose exceeds occlusion bounds "+clip+" phase "+str(phase)+" pixels "+str(outside_body_bounds))
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge,"outside_body_bounds":outside_body_bounds})
					if not left and flash==0:
						pixels.resize(256,256,Image.INTERPOLATE_NEAREST)
						sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i(column*256,row*256))
		enemy.free()
	check(sheet.save_png(output+"poses.png")==OK,"full-body sheet write")
	var actual := EnemySource.new()
	actual.setup(kind_id,0,viewport)
	actual.position = Vector2(128,136)
	viewport.add_child(actual)
	actual.set_physics_process(false)
	actual.velocity = Vector2(60,0)
	var previous := PackedByteArray()
	var changes := 0
	var effect_pixels := 0
	for frame in 60:
		actual._update_static_motion(1/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and pixels!=previous else 0
		previous = pixels
	check(changes>=50,"actual adapter walk static")
	actual.take_damage(1) # Real hit path and real damaged-large health bar.
	await process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(output+"actual-hit-bar.png")==OK,"actual hit/bar write")
	if slam:
		actual._update_static_motion(0.3)
		var target := Target.new()
		target.position = actual.position+Vector2(20,0)
		viewport.add_child(target)
		actual.target_player = target
		actual._physics_process(0.1)
		check(actual.should_show_attack_marker() and actual.native_visual.player.current_animation=="slam_warning","actual warning absent")
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(output+"actual-warning.png")==OK,"actual warning capture")
		actual._physics_process(0.48) # 0.08s after the real hit; ring extends beyond fists.
		check(target.hits==[54.0] and actual.native_visual.player.current_animation=="slam_attack","actual damage/impact capture mismatch")
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		check(pixels.save_png(output+"actual-impact.png")==OK,"actual impact capture")
		# Isolate the real ground canvas, not a synthetic approximation. Body
		# shares the effect palette and would create a false-positive color count.
		actual.native_visual.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		pixels = viewport.get_texture().get_image()
		for y in 256:
			for x in 256:
				var c := pixels.get_pixel(x,y)
				if c.a>0.9 and absf(c.r-0.878)<0.04 and absf(c.g-0.690)<0.04 and absf(c.b-0.455)<0.04:
					effect_pixels+=1
		check(effect_pixels>5,"actual compact slam ring is not rendered")
		check(pixels.save_png(output+"actual-effect-only.png")==OK,"isolated actual effect capture")
	if commander:
		actual._update_static_motion(0.3)
		var target := Target.new()
		target.position = actual.position+Vector2(80,0)
		viewport.add_child(target)
		var shots := Node2D.new()
		viewport.add_child(shots)
		actual.projectile_parent = shots
		actual.target_player = target
		actual.shoot_cooldown = 0
		actual._physics_process(0.01)
		check(actual.should_show_attack_marker() and actual.native_visual.player.current_animation=="burst_warning","actual core warning absent")
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(output+"actual-burst-warning.png")==OK,"core warning capture")
		actual._physics_process(0.91)
		check(shots.get_child_count()==12 and actual.native_visual.player.current_animation=="burst_attack","actual core burst absent")
		for shot in shots.get_children():
			shot.set_physics_process(false)
			shot._physics_process(0.15)
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(output+"actual-burst.png")==OK,"core burst capture")
		shots.free()
		actual.projectile_parent = null
		actual._physics_process(0.31)
		target.position = actual.position+Vector2(20,0)
		actual._physics_process(0.1)
		check(actual.should_show_attack_marker() and actual.native_visual.player.current_animation=="melee_warning","actual staff warning absent")
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(output+"actual-warning.png")==OK,"staff warning capture")
		actual._physics_process(0.3)
		check(target.hits==[72.0] and actual.native_visual.player.current_animation=="melee_attack","actual staff damage/impact absent")
		await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(output+"actual-impact.png")==OK,"staff impact capture")
		actual.native_visual.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		for y in 256:
			for x in 256:
				var c := pixels.get_pixel(x,y)
				if c.a>0.9 and absf(c.r-0.569)<0.04 and absf(c.g-0.706)<0.04 and absf(c.b-0.490)<0.04:
					effect_pixels += 1
		check(effect_pixels>5,"actual staff radial impact not rendered")
		check(pixels.save_png(output+"actual-effect-only.png")==OK,"isolated staff impact capture")
	for path in sources:
		check(FileAccess.get_sha256(path)==sources[path],"source changed during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"samples":samples,"gait_frames":60,"adjacent_changes":changes,"actual_effect_pixels":effect_pixels,"sources":sources,"scope":"Actual Enemy body/shader poses (HUD excluded), all listed clips/mirrors/hit flash; actual gait and hit/bar. Optional post-checkpoint actions add actual warning/impact and one real hit; commander also emits 12 actual projectiles (transitional projectile art). Not natural Main input or all Boss attacks.","clips":clips},"\t"))
	file.close()
	viewport.free()
	await process_frame
	print("LARGE GPU %s: %d actual shader poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",samples.size(),changes])
	quit(1 if failed else 0)
