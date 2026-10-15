extends SceneTree
## Actual Actor/shader and combat effects; controlled clock, not chapter victory.
const Boss = preload("res://scripts/actors/SaltTideBoss.gd")
const CLIPS := ["idle","walk","hit","entrance","ripple_warning","ripple_attack","ripple_recovery","pincer_warning","pincer_attack","pincer_recovery","salt_warning","salt_attack","salt_recovery","death"]
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
var checks := 0
var failures := 0
var output := ""
var viewport: SubViewport
var captures := {}
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TIDE ACTOR GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func pixels() -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func capture(name: String) -> Image:
	var image := await pixels()
	check(image.save_png(output+name+".png")==OK,"save "+name)
	captures[name] = FileAccess.get_sha256(output+name+".png")
	return image
func visible_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width(): count += 1 if image.get_pixel(x,y).a>0.01 else 0
	return count
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderTideBossActions.gd","scripts/actors/SaltTideBoss.gd","scripts/actors/OverseerBoss.gd","scripts/components/TideShellAttackDirector.gd","scripts/components/NativeTideShellMotion.gd","scripts/components/TideSaltProjectile.gd","scripts/components/TideShellWaveGeometry.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/VineSeedProjectile.gd","scripts/components/RiftShardProjectile.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/HostileEffectPalette.gd","scenes/actors/native/tide_shell_paper_v2.tscn","assets/art/actors/native/tide_shell_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader","scripts/systems/SaltEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/EncounterCombatCore.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"missing source "+path)
	viewport = SubViewport.new(); viewport.size = Vector2i(320,320)
	viewport.world_2d = World2D.new(); viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var samples: Array[Dictionary] = []
	var sheets := [Image.create(960,960,false,Image.FORMAT_RGBA8),Image.create(960,960,false,Image.FORMAT_RGBA8)]
	for sheet in sheets: sheet.fill(Color("263b3e"))
	for left in [false,true]:
		var target := Target.new(); target.position = Vector2(300,180); viewport.add_child(target)
		var boss := Boss.new(); boss.setup(3,viewport,target); boss.position = Vector2(160,180)
		viewport.add_child(boss); boss.set_physics_process(false); boss.world_status.visible = false
		var body := boss.get_visual_node(); body.set_facing_left(left)
		for clip in CLIPS:
			for phase in [0.0,0.45,0.85]:
				check(body.sample_clip(clip,body.player.get_animation(clip).length*phase),"sample "+clip)
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
					check(opaque>3000 and partial==0 and edge==0,"opaque/unclipped "+clip)
					check(clip=="death" or outside==0,"body bounds "+clip)
					check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"physical root altered")
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge,"outside":outside})
					if flash==0 and phase==0.45 and "_" in clip:
						var column: int = ["ripple","pincer","salt"].find(clip.get_slice("_",0))
						var row: int = ["warning","attack","recovery"].find(clip.get_slice("_",1))
						sheets[1 if left else 0].blend_rect(image,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
		boss.free(); target.free()
	for index in 2:
		var name: String = "action-poses-left" if index else "action-poses"
		check(sheets[index].save_png(output+name+".png")==OK,"save actor poses")
		captures[name] = FileAccess.get_sha256(output+name+".png")
	viewport.free(); await process_frame
	viewport = SubViewport.new(); viewport.size = Vector2i(800,640); viewport.world_2d = World2D.new()
	viewport.transparent_bg = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var shots := Node2D.new(); viewport.add_child(shots)
	var target := Target.new(); target.position = Vector2(620,340); viewport.add_child(target)
	var boss := Boss.new(); boss.setup(3,shots,target); boss.position = Vector2(400,340)
	boss.world_bounds = Rect2(0,0,800,640); viewport.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	boss.world_status.visible = false; boss.velocity = Vector2(60,0)
	var previous := PackedByteArray(); var changes := 0
	for frame in 60:
		boss._update_boss_motion(1/60.0)
		var data := (await pixels()).get_data()
		changes += 1 if frame>0 and data!=previous else 0; previous = data
	check(changes>=50,"actual adapter gait static"); boss.velocity = Vector2.ZERO
	var effects := {}
	for kind in [&"ripple",&"pincer",&"salt"]:
		combat.cancel_action(); boss.world_status.visible = true
		check(combat.start_action(kind),"actual action "+str(kind)); combat.advance(combat.DURATIONS[kind][0]*0.6)
		check(boss.should_show_attack_marker(),"short head warning absent")
		await capture(str(kind)+"-warning")
		combat.advance(combat.DURATIONS[kind][0]); combat.advance(0.10)
		if kind==&"salt":
			# Let actual projectile physics clear the jaw/body before freezing the
			# diagnostic snapshot; advancing the Boss clock doesn't move bullets.
			for _frame in int(ceil(0.45*Engine.physics_ticks_per_second)):
				await physics_frame
		for shot in combat.owned_projectiles: shot.set_physics_process(false)
		check(boss.get_visual_node().player.current_animation==str(kind)+"_attack" and not boss.should_show_attack_marker(),"actual stage pose mismatch")
		var active_image := await capture(str(kind)+"-active")
		if kind==&"salt":
			for shot in combat.owned_projectiles:
				check(shot.global_position.x>boss.global_position.x+boss.get_visual_rect().end.x+6,"salt snapshot still inside body")
				var at := Vector2i(shot.global_position)
				check(active_image.get_pixel(at.x,at.y).r>0.7 and active_image.get_pixel(at.x,at.y).a>0.99,"salt center obscured in actual Actor capture")
		boss.get_visual_node().visible = false; boss.world_status.visible = false
		effects[kind] = visible_pixels(await capture(str(kind)+"-effect-only"))
		check(effects[kind]>10,"actual effect invisible "+str(kind))
		if kind==&"salt": check(combat.owned_projectiles.size()==3,"not three real salt projectiles")
		boss.get_visual_node().visible = true
	# Real physics wall occludes the actual rim; no mock VFX or ray provider.
	combat.cancel_action(); check(combat.start_action(&"ripple"),"wall action")
	combat.advance(0.28); combat.advance(0.25)
	var wall := StaticBody2D.new(); wall.position = Vector2(500,340)
	var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(2,320)
	collider.shape = shape; wall.add_child(collider); viewport.add_child(wall)
	await physics_frame; await physics_frame
	combat.queue_redraw(); boss.get_visual_node().visible = false
	check(not combat._point_visible(Vector2(600,340)) and combat._point_visible(Vector2(200,340)),"actual wall ray differs from draw")
	var clipped := await capture("ripple-wall-effect")
	var radius: float = combat.ring_radius(combat.action_elapsed)
	check(clipped.get_pixel(int(400+radius),340).a==0,"rim drawn through wall")
	check(clipped.get_pixel(int(400-radius),340).a>0.01,"visible rim missing")
	paused = true; await process_frame; await process_frame
	check(not combat.is_attacking() and visible_pixels(await capture("paused-cancel"))==0,"pause retains danger")
	paused = false
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var report := {"passed":failures==0,"checks":checks,"actor":"SaltTideBoss","samples":samples,"gait_changes":changes,"effects_visible_pixels":effects,"sources":sources,"captures":captures,"scope":"Actual Actor shader/body matrix, adapter gait, short head warnings, combat-owned ring/claws/three actual frozen salt projectiles, actual wall ray/render clipping and pause cancellation. Accelerated clocks/controlled target, not normal gameplay, full chapter, permanent unlock, six chapters or performance."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	viewport.free(); await process_frame
	print("TIDE ACTOR GPU %s: %d checks/%d body poses/%d gait changes, effects %s"%["PASS" if failures==0 else "FAIL",checks,samples.size(),changes,str(effects)])
	quit(1 if failures else 0)
