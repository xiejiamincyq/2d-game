extends SceneTree
## Actual chapter Actor and actual combat-owned drawing, never a mock effect.
const Boss = preload("res://scripts/actors/NurseryVineBoss.gd")
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void: hits.append(amount)
var failed := false
var output := ""
var viewport: SubViewport
func check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error("VINE EFFECT GPU FAIL: "+label)
func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	check(pixels.save_png(output+name+".png")==OK,"capture write "+name)
	return pixels
func green_count(pixels: Image) -> int:
	var count := 0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c := pixels.get_pixel(x,y)
			if c.a>0.9 and absf(c.r-0.569)<0.025 and absf(c.g-0.706)<0.025 and absf(c.b-0.490)<0.025: count+=1
	return count
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU/unused output required")
	if failed: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderVineGuardAttackEffects.gd","scripts/actors/NurseryVineBoss.gd","scripts/actors/OverseerBoss.gd","scripts/components/NativeVineGuardMotion.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/components/VineGuardAttackDirector.gd","scripts/components/VineSeedProjectile.gd","scripts/components/RiftShardProjectile.gd","scripts/components/Projectile.gd","scripts/components/NativeProjectileOriginSafety.gd","scenes/actors/native/vine_guard_paper_v2.tscn","assets/art/actors/native/vine_guard_motion_v2.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640,512)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shots := Node2D.new()
	viewport.add_child(shots)
	var target := Target.new()
	target.position = Vector2(380,280)
	viewport.add_child(target)
	var boss := Boss.new()
	boss.setup(5,shots,target)
	boss.position = Vector2(240,280)
	boss.world_bounds = Rect2(0,0,640,512)
	viewport.add_child(boss)
	boss.set_physics_process(false)
	boss._physics_process(1.41)
	var combat = boss.get_attack_director()
	combat.attack_gap = 99
	check(combat.start_action(&"lash"),"actual lash fails")
	boss._physics_process(0.15)
	check(boss.native_visual.player.current_animation=="lash_warning","actual lash warning not native")
	await capture("lash-warning")
	boss._physics_process(0.16)
	check(target.hits==[54.0] and boss.native_visual.player.current_animation=="lash_attack","actual lash hit/pose absent")
	await capture("lash-impact")
	boss.native_visual.visible = false
	var lash_pixels := green_count(await capture("lash-effect-only"))
	check(lash_pixels>10,"actual vine arc not rendered; body colors excluded")
	boss.native_visual.visible = true
	combat.cancel_action()
	combat.set_health_phase(2)
	boss._physics_process(0.65)
	combat.attack_gap = 99
	check(combat.start_action(&"roots"),"actual root placement fails")
	boss._physics_process(0.2)
	await capture("roots-warning")
	boss._physics_process(0.61)
	check(target.hits==[54.0,60.0] and boss.native_visual.player.current_animation=="roots_attack","actual root hit/pose absent")
	await capture("roots-impact")
	boss.native_visual.visible = false
	var root_pixels := green_count(await capture("roots-effect-only"))
	check(root_pixels>100,"actual root glyphs invisible; body colors excluded")
	boss.native_visual.visible = true
	combat.cancel_action()
	check(combat.start_action(&"seeds"),"actual seeds fail")
	boss._physics_process(0.15)
	await capture("seeds-warning")
	boss._physics_process(0.21)
	check(shots.get_child_count()==3 and boss.native_visual.player.current_animation=="seeds_attack","actual crown emission/pose absent")
	for shot in shots.get_children():
		shot.set_physics_process(false)
		shot._physics_process(0.20)
	await capture("seeds-impact")
	boss.native_visual.visible = false
	var seed_pixels := green_count(await capture("seeds-effect-only"))
	check(seed_pixels>50,"actual three original seeds invisible; body colors excluded")
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source changed during capture")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"lash_pixels":lash_pixels,"root_pixels":root_pixels,"seed_pixels":seed_pixels,"actual_hits":target.hits,"actual_seed_count":shots.get_child_count(),"sources":sources,"scope":"Actual first-chapter Actor clock fixture: native short warnings, one 54 lash hit and one 60 root hit, three actual seeds with swept flight, isolated combat-owned effect pixels. Not natural-input victory or six chapters."},"\t"))
	file.close()
	viewport.free()
	await process_frame
	print("VINE EFFECT GPU %s: lash %d / roots %d / seeds %d isolated pixels"%["FAIL" if failed else "PASS",lash_pixels,root_pixels,seed_pixels])
	quit(1 if failed else 0)
