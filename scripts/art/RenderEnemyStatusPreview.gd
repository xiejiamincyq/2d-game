extends SceneTree
## Controlled GPU occlusion fixture, NOT a natural combat/performance proof.
## Real actor bodies and controllers; only their simulation clock is frozen.
const Enemy = preload("res://scripts/actors/Enemy.gd")
const Crab = preload("res://scripts/actors/FlankingCrabEnemy.gd")
const Palette = preload("res://scripts/effects/HostileEffectPalette.gd")
const Furnace = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
class Target extends Node2D:
	var health: Node = null
	func take_damage(_amount: float) -> bool: return true
var checks := 0
var failures := 0
var output: String
var observations: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("ENEMY STATUS GPU FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func shot(view: SubViewport,name: String) -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(not pixels.is_empty() and pixels.save_png(output+name)==OK,"capture "+name)
	return pixels
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU fresh output")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderEnemyStatusPreview.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/HostileEffectPalette.gd","scripts/actors/Enemy.gd","scripts/actors/FlankingCrabEnemy.gd","scripts/actors/OverseerBoss.gd","scripts/actors/NurseryVineBoss.gd","scripts/actors/FoundryFurnaceBoss.gd","scripts/components/CrabPincerAttack.gd","scripts/components/FurnaceForemanAttackDirector.gd","scenes/actors/native/flanking_crab_paper_v1.tscn","scenes/actors/native/root_commander_paper_v2.tscn","scenes/actors/native/salt_needler_paper_v1.tscn","scenes/actors/native/furnace_foreman_paper_v2.tscn"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length()==64,"source "+path)
	var view := SubViewport.new(); view.size = Vector2i(640,480)
	view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var actors := Node2D.new(); actors.y_sort_enabled = true; view.add_child(actors)
	var target := Target.new(); target.position = Vector2(365,260); view.add_child(target)
	var crab := Crab.new(); crab.position = Vector2(320,260)
	crab.setup(0,0,view,target); actors.add_child(crab); crab.set_physics_process(false)
	var blocker := Enemy.new(); blocker.setup(Enemy.EnemyKind.OVERSEER,0,view,target)
	actors.add_child(blocker); blocker.set_physics_process(false)
	check(crab.basic_attack.get_warning_duration()==0.18,"production short pincer warning unchanged")
	for index in range(3):
		blocker.position = crab.position+(Vector2(0,32) if index==2 else Vector2(-8 if index==0 else 8,8))
		blocker.native_visual.set_facing_left(index==0); blocker.hide()
		crab.basic_attack.cancel(); crab._queue_visual_redraw()
		var plain: Image = await shot(view,"isolated-idle-%d.png"%index)
		check(crab.basic_attack.begin(crab,target,crab.basic_attack.Move.CLAW),"real controller warning")
		crab._queue_visual_redraw()
		var warning: Image = await shot(view,"isolated-warning-%d.png"%index)
		blocker.show(); crab._queue_visual_redraw()
		var crowded: Image = await shot(view,"crowded-warning-%d.png"%index)
		crab.basic_attack.cancel(); crab._queue_visual_redraw()
		var crowded_idle: Image = await shot(view,"crowded-idle-%d.png"%index)
		var mask := 0; var visible := 0; var body_overlap := 0
		var at := crab.position+Vector2(0,crab.get_attack_marker_top())
		for y in range(int(at.y)-15,int(at.y)+3):
			for x in range(int(at.x)-5,int(at.x)+6):
				if warning.get_pixel(x,y)!=plain.get_pixel(x,y):
					mask += 1
					if crowded.get_pixel(x,y)==warning.get_pixel(x,y) and crowded.get_pixel(x,y)!=crowded_idle.get_pixel(x,y): visible += 1
		for y in range(200,270):
			for x in range(290,350):
				if plain.get_pixel(x,y)!=crowded_idle.get_pixel(x,y): body_overlap += 1
		check(mask>50,"actual isolated head pixels")
		check(visible>=mask*0.95,"front body hides head marker: %d/%d angle%d"%[visible,mask,index])
		check(body_overlap>200,"real body occlusion retained")
		var bar: Rect2 = crab.get_health_bar_rect(); var bar_pixels := 0
		for y in range(int(crab.position.y+bar.position.y+1),int(crab.position.y+bar.end.y-1)):
			for x in range(int(crab.position.x+bar.position.x+1),int(crab.position.x+bar.end.x-1)):
				if crowded.get_pixel(x,y).is_equal_approx(Palette.CORAL): bar_pixels += 1
		check(bar_pixels>=80,"actual crowded crab bar")
		observations.append({"angle":index,"head_mask_pixels":mask,"visible_head_pixels":visible,"body_overlap_pixels":body_overlap,"crab_bar_pixels":bar_pixels})
	blocker.hide(); crab.hide()
	var needler := Enemy.new(); needler.position = Vector2(320,260)
	needler.setup(Enemy.EnemyKind.MARKSMAN,0,view,target); actors.add_child(needler); needler.set_physics_process(false)
	var pixels: Image = await shot(view,"needler-hostile-bar.png")
	var bar: Rect2 = needler.get_health_bar_rect(); var coral := 0
	for y in range(int(needler.position.y+bar.position.y+1),int(needler.position.y+bar.end.y-1)):
		for x in range(int(needler.position.x+bar.position.x+1),int(needler.position.x+bar.end.x-1)):
			if pixels.get_pixel(x,y).is_equal_approx(Palette.CORAL): coral += 1
	check(coral>=64,"actual needler hostile coral fill, got %d"%coral)
	needler.hide()
	var boss := Furnace.new(); boss.position = Vector2(320,330); boss.setup(0,view,target)
	actors.add_child(boss); boss.set_physics_process(false)
	boss.attack_director.advance(1.41); boss._update_entrance_reveal()
	check(boss.attack_director.start_action(&"jet"),"actual Boss short warning")
	boss._update_boss_motion(0)
	var boss_warning: Image = await shot(view,"boss-warning.png")
	var boss_cream := 0
	for y in range(190,199):
		for x in range(318,323):
			if boss_warning.get_pixel(x,y).is_equal_approx(Palette.CREAM): boss_cream += 1
	check(boss_cream>=14,"actual Boss head pixels")
	paused = true
	var boss_paused: Image = await shot(view,"boss-paused.png")
	var paused_cream := 0
	for y in range(190,199):
		for x in range(318,323):
			if boss_paused.get_pixel(x,y).is_equal_approx(Palette.CREAM): paused_cream += 1
	check(not boss.should_show_attack_marker() and paused_cream==0,"cancelled Boss hint clears while paused")
	paused = false
	var references: Array[Dictionary] = []
	for name in DirAccess.get_files_at(output):
		if name.ends_with(".png"): references.append({"path":output+name,"sha256":FileAccess.get_sha256(output+name)})
	view.queue_free(); await process_frame; await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source unchanged "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"angles":observations,"needler_coral_pixels":coral,"boss_warning_pixels":boss_cream,"paused_boss_warning_pixels":paused_cream,"sources":sources,"captures":references,"scope":"controlled real-actor GPU occlusion fixture; no natural fight or performance claim"},"\t")); file.close()
	if failures==0: print("TEST PASS: RenderEnemyStatusPreview %d"%checks)
	quit(0 if failures==0 else 1)
