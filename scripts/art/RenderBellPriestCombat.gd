extends SceneTree
## Actual Actor/unique combat clock alpha matrix. Controlled samples, not victory.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var output := ""
var samples: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderBellPriestCombat "+label)
func _initialize() -> void: call_deferred("run")
func image_from(view: SubViewport) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func advance_by(combat: Node,shots: Node2D,seconds: float) -> void:
	for _step in ceili(seconds*120):
		combat.advance(minf(seconds,1.0/120)); seconds -= minf(seconds,1.0/120)
		for shot in shots.get_children(): shot.set_physics_process(false)
func advance_to(combat: Node,shots: Node2D,stage: int,elapsed: float) -> void:
	# Crown intentionally clamps a step at each note. Read its real clock;
	# requested wall seconds are not proof of the resulting animation time.
	for _step in 300:
		if combat.action_stage!=stage or combat.action_elapsed>=elapsed-0.000001: return
		advance_by(combat,shots,minf(1.0/120,elapsed-combat.action_elapsed))
	check(false,"bounded actual clock sample did not finish")
func inspect_body(pixels: Image,boss: CharacterBody2D) -> Dictionary:
	var opaque := 0; var partial := 0; var edge := 0; var outside := 0
	var bounds: Rect2 = boss.get_visual_rect().grow(1)
	var to_body := boss.get_global_transform_with_canvas().affine_inverse()
	for y in pixels.get_height():
		for x in pixels.get_width():
			var alpha := pixels.get_pixel(x,y).a
			opaque += 1 if alpha>=0.99 else 0; partial += 1 if alpha>0.01 and alpha<0.99 else 0
			edge += 1 if alpha>0.01 and (x==0 or y==0 or x==pixels.get_width()-1 or y==pixels.get_height()-1) else 0
			outside += 1 if alpha>=0.99 and not bounds.has_point(to_body*Vector2(x+0.5,y+0.5)) else 0
	return {"opaque":opaque,"partial":partial,"edge":edge,"outside":outside}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh real GPU required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}; var captures := {}
	for path in ["scripts/art/RenderBellPriestCombat.gd","scripts/actors/EchoBellPriestBoss.gd","scripts/actors/OverseerBoss.gd","scripts/actors/Player.gd","scripts/components/BellPriestAttackDirector.gd","scripts/components/BellPriestStrike.gd","scripts/components/BellPriestPendantProjectile.gd","scripts/components/BellPriestCrownProjectile.gd","scripts/components/NativeBellPriestMotion.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/ArchivePageProjectile.gd","scripts/components/VineSeedProjectile.gd","scripts/components/RiftShardProjectile.gd","scripts/components/Projectile.gd","scripts/world/TerrainSweep.gd","scenes/actors/native/bell_priest_paper_v2.tscn","assets/art/actors/native/bell_priest_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"actual source "+path)
	var viewport := SubViewport.new(); viewport.size = Vector2i(320,320); viewport.transparent_bg = true
	viewport.world_2d = World2D.new(); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	for kind in [&"bell",&"pendant",&"crown"]:
		var sheet := Image.create(960,640,false,Image.FORMAT_RGBA8); sheet.fill(Color("393542"))
		for left in [false,true]:
			var shots := Node2D.new(); viewport.add_child(shots); shots.hide()
			var player := Player.new(); player.position = Vector2(40 if left else 280,180); viewport.add_child(player); player.set_physics_process(false); player.hide()
			var boss := Boss.new(); boss.position = Vector2(160,180); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(5,shots,player); viewport.add_child(boss); boss.set_physics_process(false)
			var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			combat.hide(); boss.world_status.hide(); check(combat.start_action(kind),"actual cast refused")
			for stage in [1,2,3]:
				var length: float = combat.DURATIONS[kind][stage-1]
				advance_to(combat,shots,stage,length*0.45)
				for flash in [0.0,0.35]:
					boss.boss_flash_material.set_shader_parameter("flash_amount",flash)
					var pixels := await image_from(viewport); var metric := inspect_body(pixels,boss)
					check(metric.opaque>3000 and metric.partial==0 and metric.edge==0 and metric.outside==0,"actual opaque/framed body %s/%s: %s"%[kind,stage,metric])
					check(boss.scale==Vector2.ONE and boss.body_radius==56 and boss.get_visual_node().skeleton.get_bone_count()==26 and combat.action_stage==stage,"root/anatomy/clock contract")
					metric.merge({"kind":String(kind),"stage":stage,"left":left,"flash":flash}); samples.append(metric)
					if flash==0: sheet.blend_rect(pixels,Rect2i(0,0,320,320),Vector2i((stage-1)*320,320 if left else 0))
				advance_to(combat,shots,stage,length)
			# Sample the actual clock continuously, not an independently posed rig.
			check(combat.action_stage==combat.Stage.IDLE,"key sample did not finish recovery")
			# Frozen alpha-only projectiles cannot expire; clear this fixture's
			# previous cast before another one, retaining the real runtime quotas.
			combat.cancel_action()
			boss.boss_flash_material.set_shader_parameter("flash_amount",0.0)
			check(combat.start_action(kind),"continuous actual cast refused")
			advance_to(combat,shots,combat.Stage.WARNING,combat.DURATIONS[kind][0])
			var origin: Vector2 = combat.locked_origin; var heading: Vector2 = combat.locked_direction
			var previous_pixels := PackedByteArray(); var changed_pairs := 0
			var socket: StringName = &"pendant_left" if kind==&"pendant" else kind
			var marker: Marker2D = boss.get_visual_node().skeleton.get_node(boss.SOCKETS[socket])
			var marker_start := marker.global_position; var marker_span := 0.0
			for frame in 30:
				var elapsed: float = combat.DURATIONS[kind][1]*(frame+1)/32.0
				advance_to(combat,shots,combat.Stage.ACTIVE,elapsed)
				var pixels := await image_from(viewport); var metric := inspect_body(pixels,boss)
				check(metric.opaque>3000 and metric.partial==0 and metric.edge==0 and metric.outside==0,"continuous actual body %s/%s/%d: %s"%[kind,left,frame,metric])
				check(combat.action_stage==combat.Stage.ACTIVE and is_equal_approx(combat.action_elapsed,elapsed) and combat.locked_origin==origin and combat.locked_direction==heading and boss.scale==Vector2.ONE,"continuous clock/frozen geometry/root")
				var current_pixels := pixels.get_data()
				if frame>0 and current_pixels!=previous_pixels: changed_pairs += 1
				previous_pixels = current_pixels; marker_span = maxf(marker_span,marker_start.distance_to(marker.global_position))
				metric.merge({"kind":String(kind),"left":left,"frame":frame,"elapsed":combat.action_elapsed,"continuous":true}); samples.append(metric)
			check(changed_pairs>=15 and marker_span>5,"actual consecutive motion/socket missing: %s/%s %d/%f"%[kind,left,changed_pairs,marker_span])
			samples.append({"kind":String(kind),"left":left,"changed_pairs":changed_pairs,"marker_span":marker_span,"sequence_summary":true})
			combat.cancel_action()
			# A smaller presentation changes the camera, never the physical actor.
			var camera := Camera2D.new(); camera.position = Vector2(160,180); camera.zoom = Vector2(0.75,0.75); viewport.add_child(camera)
			viewport.size = Vector2i(240,240)
			check(combat.start_action(kind),"small-window actual cast refused")
			advance_to(combat,shots,combat.Stage.WARNING,combat.DURATIONS[kind][0])
			advance_to(combat,shots,combat.Stage.ACTIVE,combat.DURATIONS[kind][1]*0.45)
			var small := await image_from(viewport); var small_metric := inspect_body(small,boss)
			check(small_metric.opaque>1600 and small_metric.partial==0 and small_metric.edge==0 and small_metric.outside==0 and boss.body_radius==56 and boss.scale==Vector2.ONE,"small-window actual body/physics: "+str(small_metric))
			small_metric.merge({"kind":String(kind),"left":left,"presentation_scale":0.75}); samples.append(small_metric)
			var small_name := String(kind)+("-left" if left else "-right")+"-small.png"
			check(small.save_png(output+small_name)==OK,"small actual capture"); captures[small_name] = FileAccess.get_sha256(output+small_name)
			camera.free(); viewport.size = Vector2i(320,320); viewport.canvas_transform = Transform2D.IDENTITY
			boss.free(); player.free(); shots.free(); await process_frame
		var name := String(kind)+"-actor.png"; check(sheet.save_png(output+name)==OK,"save actual Actor sheet"); captures[name] = FileAccess.get_sha256(output+name)
	viewport.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"samples":samples,"scope":"Actual 26-bone Boss/clock: 36 key/flash poses, 180 continuous ACTIVE samples and six 0.75-camera samples. Player, ground hints and projectiles hidden ONLY for isolated alpha measurement. Controlled clock, not normal play, HUD, chapter victory or readiness."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderBellPriestCombat %d"%checks)
	quit(1 if failures else 0)
