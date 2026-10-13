extends SceneTree
## Actual Actor/ground on the Archive map; controlled samples, not a normal run.
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var output := ""
var viewport: SubViewport
var captures := {}
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("ARCHIVE SEAL GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func pixels() -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func capture(name: String) -> Image:
	var image := await pixels()
	check(image.save_png(output+name+".png")==OK,"save "+name)
	captures[name] = FileAccess.get_sha256(output+name+".png")
	return image
func make_viewport(size: Vector2i,transparent: bool = true) -> void:
	viewport = SubViewport.new(); viewport.size = size; viewport.world_2d = World2D.new()
	viewport.transparent_bg = transparent; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderArchiveBossSeal.gd","scripts/actors/ArchiveArchivistBoss.gd","scripts/actors/OverseerBoss.gd","scripts/actors/Player.gd","scripts/components/SporeArchivistAttackDirector.gd","scripts/components/ArchiveSealAttack.gd","scripts/components/NativeSporeArchivistMotion.gd","scripts/components/ArchivePageProjectile.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/world/ArchiveMap.gd","scripts/world/ArchiveArenaLayout.gd","scripts/world/ArchiveFloor.gd","scripts/world/ArchiveObstacle.gd","scripts/world/ArchivePropArt.gd","scenes/world/luminous_archive.tscn","scenes/actors/native/spore_archivist_paper_v2.tscn","assets/art/actors/native/spore_archivist_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"missing source "+path)
	make_viewport(Vector2i(320,320))
	var samples: Array[Dictionary] = []
	for left in [false,true]:
		var shots := Node2D.new(); viewport.add_child(shots)
		var target := Player.new(); target.position = Vector2(300,180); viewport.add_child(target)
		target.visible = false; target.set_physics_process(false)
		var boss := Boss.new(); boss.setup(4,shots,target); boss.position = Vector2(160,180)
		viewport.add_child(boss); boss.set_physics_process(false); boss.world_status.visible = false
		var body := boss.get_visual_node(); body.set_facing_left(left)
		for stage in ["warning","attack","recovery"]:
			var clip: String = "seal_"+stage
			check(body.sample_clip(clip,body.player.get_animation(clip).length*0.55),"sample "+clip)
			for flash in [0.0,0.35]:
				boss.boss_flash_material.set_shader_parameter("flash_amount",flash)
				var image := await pixels()
				var opaque := 0; var partial := 0; var edge := 0; var outside := 0
				var bounds: Rect2 = boss.get_visual_rect()
				for y in 320:
					for x in 320:
						var alpha := image.get_pixel(x,y).a
						opaque += 1 if alpha>=0.99 else 0
						partial += 1 if alpha>0.01 and alpha<0.99 else 0
						edge += 1 if alpha>0.01 and (x==0 or x==319 or y==0 or y==319) else 0
						outside += 1 if alpha>=0.99 and not bounds.grow(1).has_point(Vector2(x+0.5-160,y+0.5-180)) else 0
				check(opaque>3000 and partial==0 and edge==0 and outside==0,"Actor opacity/bounds "+clip)
				samples.append({"clip":clip,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge,"outside":outside})
		boss.free(); target.free(); shots.free()
	viewport.free(); await process_frame
	make_viewport(Vector2i(1280,720),false)
	var map = load("res://scenes/world/luminous_archive.tscn").instantiate(); map.map_seed = 521; viewport.add_child(map)
	var camera := Camera2D.new(); camera.position = Vector2(0,-672); viewport.add_child(camera); camera.make_current()
	var shots := Node2D.new(); shots.z_index = 50; viewport.add_child(shots)
	var target := Player.new(); target.position = Vector2(240,-672); target.world_bounds = map.layout.world_bounds
	viewport.add_child(target); target.set_physics_process(false)
	var boss := Boss.new(); boss.position = Vector2(0,-672); boss.world_bounds = map.layout.world_bounds
	boss.setup(4,shots,target); viewport.add_child(boss); boss.set_physics_process(false); boss.set_arena_navigation(map.layout)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(combat.start_action(&"seal"),"actual map warning cannot arm")
	combat.advance(0.12)
	var warning := await capture("runtime-warning")
	var center: Vector2 = viewport.get_canvas_transform()*boss.global_position
	var cream := 0; var black := 0
	for y in range(int(center.y)-145,int(center.y)-121):
		for x in range(int(center.x)-10,int(center.x)+10):
			var color := warning.get_pixel(x,y)
			cream += 1 if Vector3(color.r,color.g,color.b).distance_to(Vector3(0.953,0.929,0.863))<0.08 else 0
			black += 1 if maxf(color.r,maxf(color.g,color.b))<0.1 else 0
	check(boss.should_show_attack_marker() and cream>=12 and black>=20,"short outlined head absent")
	var points: Array = combat.seal_attack.centers.duplicate()
	combat.advance(0.12)
	var active := await capture("runtime-active")
	check(target.health.current_health==82 and not boss.should_show_attack_marker(),"actual positive damage/native stage absent")
	combat.advance(0.28)
	var recovery := await capture("runtime-recovery")
	var removed := 0
	for point in points:
		var at: Vector2 = viewport.get_canvas_transform()*point
		var local_removed := 0
		for y in range(int(at.y)-28,int(at.y)+29):
			for x in range(int(at.x)-28,int(at.x)+29):
				# Only ring/particle footprint; do not count unrelated player/Boss changes.
				var distance := Vector2(x+0.5,y+0.5).distance_to(at)
				if distance>=10 and distance<=27 and active.get_pixel(x,y)!=recovery.get_pixel(x,y): local_removed += 1
		check(local_removed>=100,"ground positive pixels/recovery removal absent")
		removed += local_removed
	check(combat.seal_attack.centers.is_empty() and combat.z_index==-1 and not combat.z_as_relative,"ground lifetime/z layer incorrect")
	combat.cancel_action(); await capture("runtime-cancelled")
	viewport.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift")
	var report := {"passed":failures==0,"checks":checks,"actor_samples":samples,"head_cream":cream,"head_black":black,"ground_removed_pixels":removed,"sources":sources,"captures":captures,"scope":"12 actual Actor seal-stage/left/right/flash body samples + actual Archive map warning/damage/ground removal. Controlled Boss clock, stationary actual Player. No ordinary run, Boss victory/unlock, brood, whole roster or performance proof."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ARCHIVE SEAL GPU %s: %d checks, 12 Actor poses, head %d/%d, ground removed %d pixels" % ["PASS" if failures==0 else "FAIL",checks,cream,black,removed])
	quit(0 if failures==0 else 1)
