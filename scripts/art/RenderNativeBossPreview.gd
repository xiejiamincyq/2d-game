extends SceneTree
## Actual first-chapter actor/shader matrix + chapter UI fixture, not natural-input victory.
const Boss = preload("res://scripts/actors/NurseryVineBoss.gd")
const LegacyBoss = preload("res://scripts/actors/OverseerBoss.gd")
const Chapter = preload("res://scenes/campaign/nursery_chapter.tscn")
const Support = preload("res://scripts/tests/TestSupport.gd")
const CLIPS := ["idle","walk","hit","entrance","death"]
var failed := false
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("BOSS GPU FAIL: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [1,2,3] or not args[0].is_valid_identifier() or (args.size()>=2 and args[1] not in ["nursery","overseer"]) or (args.size()==3 and [args[1],args[2]]!=["nursery","actions"]):
		quit(1)
		return
	var actor_source: Script = LegacyBoss if args.size()==2 and args[1]=="overseer" else Boss
	var actor_id := "OverseerBoss" if actor_source==LegacyBoss else "NurseryVineBoss"
	var clips: Array = CLIPS.duplicate()
	var actions := args.size()==3
	if actions:
		clips.erase("death")
		clips.append_array(["lash_warning","lash_attack","lash_recovery","roots_warning","roots_attack","roots_recovery","seeds_warning","seeds_attack","seeds_recovery","death"])
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/new evidence directory required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["res://scripts/art/RenderNativeBossPreview.gd","res://scripts/actors/NurseryVineBoss.gd","res://scripts/actors/OverseerBoss.gd","res://scripts/components/NativeBossMotion.gd","res://scripts/components/NativeActorView.gd","res://scripts/components/NativeScrapperMotion.gd","res://scripts/systems/BossCameraFraming.gd","res://scripts/systems/NurseryEncounterDirector.gd","res://scripts/systems/WaveDirector.gd","res://scripts/campaign/NurseryChapter.gd","res://scenes/actors/native/vine_guard_paper_v1.tscn","res://assets/art/actors/native/vine_guard_motion_v1.tres","res://assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256(path)
		check(sources[path].length()==64,"missing source "+path)
	for path in ["res://scenes/actors/native/root_commander_paper_v1.tscn","res://assets/art/actors/native/root_commander_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256(path)
		check(sources[path].length()==64,"missing source "+path)
	for path in ["res://scripts/components/NativeVineGuardMotion.gd","res://scripts/components/VineGuardAttackDirector.gd","res://scripts/components/VineSeedProjectile.gd","res://scripts/components/RiftShardProjectile.gd","res://scripts/components/NativeProjectileOriginSafety.gd","res://scenes/actors/native/vine_guard_paper_v2.tscn","res://assets/art/actors/native/vine_guard_motion_v2.tres"]:
		sources[path] = FileAccess.get_sha256(path)
		check(sources[path].length()==64,"missing new action source "+path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Image.create(clips.size()*320,960,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("304138"))
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var boss: CharacterBody2D = actor_source.new()
		boss.setup(0,viewport)
		boss.position = Vector2(160,164)
		viewport.add_child(boss)
		boss.set_physics_process(false)
		var body: Node2D = boss.get_visual_node()
		body.set_facing_left(left)
		for column in clips.size():
			var clip: String = clips[column]
			for row in 3:
				var phase: float = [0.0,0.45,0.85][row]
				check(body.sample_clip(clip,body.player.get_animation(clip).length*phase),"actual requested pose refused "+clip)
				for flash in [0.0,0.35]:
					boss.boss_flash_material.set_shader_parameter("flash_amount",flash)
					await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var opaque := 0
					var partial := 0
					var edge := 0
					var outside := 0
					for y in 320:
						for x in 320:
							var alpha := pixels.get_pixel(x,y).a
							opaque += 1 if alpha>=0.99 else 0
							partial += 1 if alpha>0.01 and alpha<0.99 else 0
							edge += 1 if alpha>0.01 and (x==0 or y==0 or x==319 or y==319) else 0
							outside += 1 if alpha>=0.99 and not (body.transform*boss.get_visual_rect()).grow(1).has_point(Vector2(x+0.5-160,y+0.5-164)) else 0
					check(opaque>5000 and partial==0 and edge==0,"body translucent/clipped "+clip)
					check(clip=="death" or outside==0,"live pose exceeds mirrored camera bounds "+clip+" phase "+str(phase)+" count "+str(outside))
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge,"outside_bounds":outside})
					if not left and flash==0:
						sheet.blend_rect(pixels,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
		boss.free()
	check(sheet.save_png(output+"poses.png")==OK,"pose sheet write")
	var actual: CharacterBody2D = actor_source.new()
	actual.setup(0,viewport)
	actual.position = Vector2(160,164)
	viewport.add_child(actual)
	actual.set_physics_process(false)
	# Clock fixture, not natural-input combat: preserve actual entrance immunity.
	actual.get_attack_director().advance(1.4)
	actual._update_entrance_reveal()
	actual.velocity = Vector2(60,0)
	var previous := PackedByteArray()
	var changes := 0
	for frame in 60:
		actual._update_boss_motion(1/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and pixels!=previous else 0
		previous = pixels
	check(changes>=50,"actual native adapter walk static")
	viewport.free()
	await process_frame
	var chapter_view := SubViewport.new()
	chapter_view.size = Vector2i(1280,720)
	chapter_view.world_2d = World2D.new()
	chapter_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(chapter_view)
	var chapter = Chapter.instantiate()
	var store_path := "user://vine_gpu_fixture_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(store_path),"existing progress collision")
	chapter.campaign_store_path = store_path
	chapter.audio_enabled = false
	chapter.run_seed = 521
	chapter_view.add_child(chapter)
	for frame in 360:
		if not chapter.player.is_entrance_active():
			break
		await process_frame
	# Accelerated Boss-preview UI fixture only. Full encounters covered by NurseryChapterTest.
	chapter.director.spawn_queue.clear()
	chapter.director._prepare_boss()
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss!=null and boss.get("native_visual")!=null,"chapter UI bypassed native actor")
	for frame in 360:
		if boss.entrance_resolved:
			break
		await process_frame
	check(boss.entrance_resolved and boss.modulate.a==1 and boss.scale==Vector2.ONE,"actual natural entrance broken")
	# Entrance may finish while the Boss is still outside the camera's fit band.
	# Require the real actor to walk in; HUD/indicator alone is not visual evidence.
	var body_visible := false
	for frame in 600:
		await physics_frame # Bound by real 60Hz game time, not uncapped render FPS.
		await RenderingServer.frame_post_draw
		var screen_body: Rect2 = boss.get_visual_node().get_global_transform_with_canvas()*boss.get_visual_rect()
		body_visible = chapter.framing.both_fit and chapter.framing.safe_screen_rect.encloses(screen_body)
		if body_visible:
			break
	check(body_visible,"chapter snapshot would omit Boss body")
	await RenderingServer.frame_post_draw
	check(chapter_view.get_texture().get_image().save_png(output+"chapter-boss.png")==OK,"chapter snapshot write")
	check(chapter.ui.boss_health_bar.visible and chapter.ui.wave_label.text.contains("藤冠"),"actual Boss HUD absent")
	check(not FileAccess.file_exists(store_path),"preview wrote campaign progress")
	for path in sources:
		check(FileAccess.get_sha256(path)==sources[path],"source drift during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"actor":actor_id,"samples":samples,"gait_frames":60,"adjacent_changes":changes,"sources":sources,"scope":"Actual "+actor_id+" body/shader poses for all listed clips (death last), actual native adapter gait and real Nursery chapter UI Boss-preview with natural entrance. Encounters deliberately skipped in UI fixture; not natural-input victory, attack effect proof or six-Boss completion.","clips":clips},"\t"))
	file.close()
	Support.stop_audio(chapter.audio)
	paused = false
	chapter_view.free()
	await process_frame
	print("BOSS GPU %s: %d poses, 60 gait frames/%d changes" % ["FAIL" if failed else "PASS",samples.size(),changes])
	quit(1 if failed else 0)
