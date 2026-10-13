extends SceneTree
## One coherent actual-scale body sheet, not a repeated per-family motion matrix.
const Roster = preload("res://scripts/tests/NativeCharacterRosterTest.gd")
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const PlayerSource = preload("res://scripts/actors/Player.gd")
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Catalog = preload("res://scripts/systems/ChapterCatalog.gd")
const BossSource = preload("res://scripts/actors/NurseryVineBoss.gd")
const LegacyBossSource = preload("res://scripts/actors/OverseerBoss.gd")
const FurnaceBossSource = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
const TideBossSource = preload("res://scripts/actors/SaltTideBoss.gd")
const ArchiveBossSource = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
var failed := false
func check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error("ROSTER GPU FAIL: "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier():
		push_error("ROSTER GPU FAIL: safe unused output identifier required")
		quit(1)
		return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and unused folder required")
	if failed:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shots := Node2D.new()
	viewport.add_child(shots)
	var target := Node2D.new()
	target.position = Vector2(500,500)
	viewport.add_child(target)
	var samples: Array[Dictionary] = []
	var sheets: Array[Image] = []
	var sources := {}
	for path in ["scripts/art/RenderNativeCharacterRoster.gd","scripts/tests/NativeCharacterRosterTest.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/actors/Enemy.gd","scripts/actors/Player.gd","scripts/actors/DroneVisual.gd","scripts/components/NativeActorView.gd","scripts/components/NativePlayerView.gd","scripts/actors/SaltTideBoss.gd","scripts/components/NativeTideShellMotion.gd","scripts/components/TideShellAttackDirector.gd","scripts/actors/ArchiveArchivistBoss.gd","scripts/components/SporeArchivistAttackDirector.gd","scripts/components/NativeSporeArchivistMotion.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	for pose in ["idle","walk"]:
		var sheet := Image.create(1536,1280,false,Image.FORMAT_RGBA8)
		sheet.fill(Color("304138"))
		var cell := 0
		for entry in Roster.NPCS:
			var actor = _production_actor(entry[0],shots,target)
			var view: Node2D
			var origin := "production Actor body"
			if actor:
				viewport.add_child(actor)
				actor.set_physics_process(false)
				view = actor.get_visual_node()
				view.reparent(viewport)
				actor.free()
			else:
				origin = "nonproduction body resource only; not chapter combat"
				view = load("res://scenes/actors/native/"+entry[0]+".tscn").instantiate()
				viewport.add_child(view)
			var scene := view.scene_file_path
			sources[scene.trim_prefix("res://")] = FileAccess.get_sha256(scene)
			var library: String = view.player.get_animation_library("").resource_path
			sources[library.trim_prefix("res://")] = FileAccess.get_sha256(library)
			var visual_scale := view.scale
			var midpoint: Vector2 = view.get_node("Facing/Skin").polygon[0]
			var bounds := Rect2(midpoint,Vector2.ZERO)
			for point in view.get_node("Facing/Skin").polygon: bounds = bounds.expand(point)
			view.position = Vector2(128,128)-view.transform.basis_xform(bounds.get_center())
			view.sample_clip(pose,0.23)
			await process_frame
			await RenderingServer.frame_post_draw
			_capture(viewport,sheet,cell,entry[0],pose,origin,visual_scale,samples)
			cell += 1
			view.free()
		for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
			var player = PlayerSource.new()
			viewport.add_child(player)
			player.set_physics_process(false)
			var view = player.get_visual_node()
			view.reparent(viewport)
			player.free()
			view.position = Vector2(128,128)
			view.set_aim(direction)
			view.sample_clip(pose,0.23)
			await process_frame
			await RenderingServer.frame_post_draw
			_capture(viewport,sheet,cell,"player/"+view.facing,pose,"actual Player body",view.scale,samples)
			cell += 1
			view.free()
		var owner = PlayerSource.new()
		viewport.add_child(owner)
		owner.set_physics_process(false)
		owner.drone_count = 1
		owner._sync_drone_visuals()
		var drone = owner.drone_visuals[0]
		drone.reparent(viewport)
		owner.free()
		drone.position = Vector2(128,128)
		drone.get_visual_node().sample_clip(pose,0.23)
		await process_frame
		await RenderingServer.frame_post_draw
		_capture(viewport,sheet,cell,"ranger_drone_paper_v1",pose,"actual Player-owned companion",Vector2.ONE,samples)
		check(sheet.save_png(output+pose+".png")==OK,"sheet save")
		drone.free()
		sheets.append(sheet)
	viewport.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var report := {"passed":not failed,"samples":samples,"sources":sources,"scope":"%d cells per pose: %d NPC body resources, explicitly distinguishing production bodies from nonproduction resources; 4 actual Player directions and actual companion. Includes actual Salt and Archive Boss v2. Source art scale, not AI/physics performance, full Boss animation or all-chapter readiness proof."%[Roster.NPCS.size()+5,Roster.NPCS.size()]}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	check(file!=null,"report open")
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	if not failed: print("ROSTER GPU PASS: %d actual-scale opaque bodies; planned Boss resources labelled separately"%samples.size())
	quit(1 if failed else 0)
func _production_actor(stem: String,shots: Node,target: Node2D) -> CharacterBody2D:
	var index := Roster.KINDS.find(stem)
	if index>=0:
		var actor = EnemySource.new()
		actor.setup(index,0,shots,target)
		return actor
	if stem=="vine_guard_paper_v2":
		var actor = BossSource.new()
		actor.setup(5,shots,target)
		return actor
	if stem=="furnace_foreman_paper_v2":
		var actor = FurnaceBossSource.new()
		actor.setup(2,shots,target)
		return actor
	if stem=="tide_shell_paper_v2":
		var actor = TideBossSource.new()
		actor.setup(3,shots,target)
		return actor
	if stem=="spore_archivist_paper_v2":
		var actor = ArchiveBossSource.new()
		actor.setup(4,shots,target)
		return actor
	if stem=="root_commander_paper_v1":
		var actor = LegacyBossSource.new()
		actor.setup(5,shots,target)
		return actor
	for chapter in range(1,7):
		for role in Catalog.get_chapter(chapter).enemy_roles:
			if Roster.ROLES[role]==stem: return Factory.create_actor(chapter,role,0,shots,target)
	return null
func _capture(viewport: SubViewport,sheet: Image,cell: int,stem: String,pose: String,origin: String,scale_value: Vector2,samples: Array[Dictionary]) -> void:
	var pixels := viewport.get_texture().get_image()
	var opaque := 0
	var partial := 0
	var edge := 0
	for y in 256:
		for x in 256:
			var alpha := pixels.get_pixel(x,y).a
			opaque += 1 if is_equal_approx(alpha,1) else 0
			partial += 1 if alpha>0 and alpha<1 else 0
			edge += 1 if alpha>0 and (x==0 or y==0 or x==255 or y==255) else 0
	check(opaque>150 and partial==0 and edge==0,"invisible/translucent/cropped "+stem+"/"+pose)
	sheet.blend_rect(pixels,Rect2i(0,0,256,256),Vector2i((cell%6)*256,(cell/6)*256))
	samples.append({"cell":cell,"body":stem,"pose":pose,"origin":origin,"scale":[scale_value.x,scale_value.y],"opaque":opaque,"partial":partial,"edge":edge})
