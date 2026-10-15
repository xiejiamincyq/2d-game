extends SceneTree
## Actual Actor/shader/body and combat-owned effects. Clock fixture, not victory.
const Boss = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
const CLIPS := ["idle","walk","hit","entrance","jet_warning","jet_attack","jet_recovery","ram_warning","ram_attack","ram_recovery","vents_warning","vents_attack","vents_recovery","death"]
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
	if not ok: failures += 1; push_error("FURNACE GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	check(pixels.save_png(output+name+".png")==OK,"capture "+name)
	captures[name] = FileAccess.get_sha256(output+name+".png")
	return pixels
func opaque_count(pixels: Image) -> int:
	var count := 0
	for y in pixels.get_height():
		for x in pixels.get_width(): count += 1 if pixels.get_pixel(x,y).a>=0.99 else 0
	return count
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderFurnaceBossActions.gd","scripts/art/BakeFurnaceForemanActions.gd","scripts/actors/FoundryFurnaceBoss.gd","scripts/actors/OverseerBoss.gd","scripts/components/FurnaceForemanAttackDirector.gd","scripts/components/NativeFurnaceForemanMotion.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/components/NativeScrapperMotion.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/effects/HostileAttackDrawing.gd","scenes/actors/native/furnace_foreman_paper_v2.tscn","assets/art/actors/native/furnace_foreman_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader","scripts/systems/FoundryEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/EncounterCombatCore.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"missing source "+path)
	viewport = SubViewport.new(); viewport.size = Vector2i(320,320)
	viewport.transparent_bg = true; viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var samples: Array[Dictionary] = []
	var sheet := Image.create(960,960,false,Image.FORMAT_RGBA8); sheet.fill(Color("304138"))
	for left in [false,true]:
		var target := Target.new(); target.position = Vector2(300,180); viewport.add_child(target)
		var boss := Boss.new(); boss.setup(2,viewport,target); boss.position = Vector2(160,180)
		viewport.add_child(boss); boss.set_physics_process(false)
		var body := boss.get_visual_node(); body.set_facing_left(left)
		for clip in CLIPS:
			for phase in [0.0,0.45,0.85]:
				check(body.sample_clip(clip,body.player.get_animation(clip).length*phase),"sample "+clip)
				for flash in [0.0,0.35]:
					boss.boss_flash_material.set_shader_parameter("flash_amount",flash)
					await process_frame; await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					var opaque := 0; var partial := 0; var edge := 0; var outside := 0
					var bounds: Rect2 = boss.get_visual_rect()
					for y in 320:
						for x in 320:
							var alpha := pixels.get_pixel(x,y).a
							opaque += 1 if alpha>=0.99 else 0
							partial += 1 if alpha>0.01 and alpha<0.99 else 0
							edge += 1 if alpha>0.01 and (x==0 or x==319 or y==0 or y==319) else 0
							outside += 1 if alpha>=0.99 and not bounds.grow(1).has_point(Vector2(x+0.5-160,y+0.5-180)) else 0
					check(opaque>3000 and partial==0 and edge==0,"opaque/unclipped "+clip)
					check(clip=="death" or outside==0,"camera body bounds "+clip)
					samples.append({"clip":clip,"phase":phase,"left":left,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge,"outside":outside})
					if not left and flash==0 and phase==0.45 and "_" in clip:
						var column: int = ["jet","ram","vents"].find(clip.get_slice("_",0))
						var row: int = ["warning","attack","recovery"].find(clip.get_slice("_",1))
						sheet.blend_rect(pixels,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
		boss.free(); target.free()
	check(sheet.save_png(output+"action-poses.png")==OK,"pose sheet")
	captures["action-poses"] = FileAccess.get_sha256(output+"action-poses.png")
	# Real native adapter gait; velocity is a controlled pose fixture.
	var target := Target.new(); viewport.add_child(target)
	var boss := Boss.new(); boss.setup(2,viewport,target); boss.position = Vector2(160,180)
	viewport.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	boss.velocity = Vector2(60,0)
	var previous := PackedByteArray(); var changes := 0
	for frame in 60:
		boss._update_boss_motion(1/60.0); await process_frame; await RenderingServer.frame_post_draw
		var data := viewport.get_texture().get_image().get_data()
		changes += 1 if frame>0 and data!=previous else 0; previous = data
	check(changes>=50,"gait is static")
	boss.free(); target.free(); viewport.free(); await process_frame
	viewport = SubViewport.new(); viewport.size = Vector2i(640,512); viewport.world_2d = World2D.new()
	viewport.transparent_bg = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	target = Target.new(); target.position = Vector2(380,280); viewport.add_child(target)
	boss = Boss.new(); boss.setup(2,viewport,target); boss.position = Vector2(160,280)
	boss.world_bounds = Rect2(0,0,640,512); viewport.add_child(boss); boss.set_physics_process(false)
	combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	var effects := {}
	for kind in [&"jet",&"ram",&"vents"]:
		boss.position = Vector2(160,280); boss._update_visual_facing(target.position)
		combat.cancel_action(); check(combat.start_action(kind),"actual action "+str(kind))
		combat.advance(combat.DURATIONS[kind][0]*0.6); boss._update_boss_motion(0)
		await capture(str(kind)+"-warning")
		combat.advance(combat.DURATIONS[kind][0]); boss._update_boss_motion(0)
		if kind==&"ram": combat.advance(0.35); boss._update_boss_motion(0)
		check(boss.native_visual.player.current_animation==str(kind)+"_attack","actual attack pose "+str(kind))
		await capture(str(kind)+"-active")
		boss.native_visual.visible = false
		effects[kind] = opaque_count(await capture(str(kind)+"-effect-only"))
		check(effects[kind]>10,"invisible combat effect "+str(kind))
		boss.native_visual.visible = true
	check(target.hits==[48.0,54.0,42.0],"three actual unique hits disagree")
	boss.native_visual.visible = false; paused = true
	await process_frame; await process_frame
	check(not combat.is_attacking() and opaque_count(await capture("paused-cancel"))==0,"pause retains danger/head marker")
	paused = false
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift")
	var report := {"passed":failures==0,"checks":checks,"actor":"FoundryFurnaceBoss","samples":samples,"gait_frames":60,"adjacent_changes":changes,"effects_opaque_pixels":effects,"actual_hits":target.hits,"sources":sources,"captures":captures,"scope":"Actual editable native Boss body/shader matrix, adapter gait, and actual combat-owned three effects in accelerated clock fixture. Not normal-input gameplay victory, Foundry UI, saved unlock or six chapters."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	viewport.free(); await process_frame
	print("FURNACE GPU %s: %d checks/%d body poses/%d gait changes, effects %s"%["PASS" if failures==0 else "FAIL",checks,samples.size(),changes,str(effects)])
	quit(0 if failures==0 else 1)
