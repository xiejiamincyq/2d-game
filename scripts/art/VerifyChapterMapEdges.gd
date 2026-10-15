extends SceneTree
## Controlled actual six map scenes/camera render, NOT ordinary combat/save.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const MainScene = preload("res://scenes/Main.tscn")
const Snapshot = preload("res://scripts/tests/fixtures/LegacyRunSnapshotStore.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
const SIZES := [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]
var assertions := 0
var failures := 0
var output := ""
var rows: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyChapterMapEdges " + label)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless" or args.size()!=1 or RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]{0,79}$").search(args[0])==null:
		quit(1); return
	output="res://build/diagnostics/campaign-goal/"+args[0]+"/"
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output.trim_suffix("/")): quit(1); return
	call_deferred("run_checks")

func run_checks() -> void:
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		check(false,"evidence folder failed")
		quit(1); return
	# Actual production Main sets the runtime clear color. A bare map viewport
	# otherwise uses Godot's neutral gray and falsely passes the void check.
	var main := MainScene.instantiate()
	var owned := "user://chapter_map_edges_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(owned),"owned cover save must be absent")
	main.campaign_store_path=owned
	main.audio_enabled=false
	var owned_snapshot := output+"owned_wave_snapshot.json"
	main.child_entered_tree.connect(func(child: Node) -> void:
		if child is Snapshot: child.save_path=owned_snapshot)
	root.add_child(main)
	check(main.snapshot_store.save_path==owned_snapshot,"Main wave snapshot was not isolated before ready")
	for chapter in range(1,7):
		var view := SubViewport.new()
		view.world_2d=World2D.new()
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var map: Node2D = Definitions.get_definition(chapter).map.instantiate()
		map.map_seed=521
		view.add_child(map)
		var bounds: Rect2 = map.layout.world_bounds
		var solids := JSON.stringify(map.layout.get_obstacle_descriptors())
		var physics_nodes := map.find_children("*","CollisionObject2D",true,false).size()
		var camera := Camera2D.new()
		camera.zoom=Vector2(0.8,0.8)
		camera.position_smoothing_enabled=false
		view.add_child(camera)
		camera.make_current()
		for size in SIZES:
			view.size=size
			# Four edges and four corners, deliberately exposing the real outside.
			var centers := [Vector2(bounds.position.x,bounds.get_center().y),Vector2(bounds.end.x,bounds.get_center().y),Vector2(bounds.get_center().x,bounds.position.y),Vector2(bounds.get_center().x,bounds.end.y),bounds.position,bounds.end,Vector2(bounds.position.x,bounds.end.y),Vector2(bounds.end.x,bounds.position.y)]
			for index in centers.size():
				camera.position=centers[index]
				camera.force_update_scroll()
				await process_frame
				await RenderingServer.frame_post_draw
				var pixels := view.get_texture().get_image()
				var inverse := view.get_canvas_transform().affine_inverse()
				var outside := 0
				var void_pixels := 0
				for y in range(32,size.y,72):
					for x in range(32,size.x,88):
						var world: Vector2 = inverse*Vector2(x,y)
						if bounds.grow(48).has_point(world): continue
						outside+=1
						var color := pixels.get_pixel(x,y)
						if color.a<0.99 or maxf(color.r,maxf(color.g,color.b))<0.10: void_pixels+=1
				check(outside>10,"outside witness missing")
				check(void_pixels==0,"chapter %d %dx%d edge %d has %d/%d unpainted samples"%[chapter,size.x,size.y,index,void_pixels,outside])
				var filename := "chapter_%d_%dx%d_edge_%d.png"%[chapter,size.x,size.y,index]
				# Smallest useful representative set; metrics cover all 144 cases.
				if index==5:
					check(pixels.save_png(output+filename)==OK,"GPU PNG failed")
				rows.append({"chapter":chapter,"size":[size.x,size.y],"edge":index,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"camera":[camera.position.x,camera.position.y],"zoom":camera.zoom.x,"outside_samples":outside,"void_samples":void_pixels,"file":filename if index==5 else ""})
		check(map.layout.world_bounds==bounds and JSON.stringify(map.layout.get_obstacle_descriptors())==solids,"render changed map geometry")
		check(map.find_children("*","CollisionObject2D",true,false).size()==physics_nodes,"render changed physics nodes")
		view.free()
		await process_frame
	check(not FileAccess.file_exists(owned),"map render wrote permanent progress")
	check(not FileAccess.file_exists(owned_snapshot),"map render wrote isolated wave snapshot")
	var report := FileAccess.open(output+"report.json",FileAccess.WRITE)
	check(report!=null,"report open failed")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"assertions":assertions,"cases":rows,"scope":"Six real map scenes, three sizes and eight edge/corner cameras at zoom0.8; isolated empty campaign and wave snapshot. No Boss, actor motion, navigation change, combat, clear/save or human claim."},"\t"))
		report.flush()
		if report.get_error()!=OK:
			check(false,"report write failed; on-disk report is not acceptance evidence")
		report.close()
	Support.stop_audio(main.audio)
	main.free()
	await process_frame
	if failures==0: print("TEST PASS: VerifyChapterMapEdges %d"%assertions)
	quit(1 if failures else 0)
