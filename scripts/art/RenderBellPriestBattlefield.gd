extends SceneTree
## Actual map/Actor/socket projectiles/Health HUD. Controlled clock-state fixture.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Map = preload("res://scenes/world/echo_court.tscn")
const Bar = preload("res://scripts/ui/BossHealthBar.gd")
const THEME = preload("res://themes/MintFarmTheme.tres")
var checks := 0
var failures := 0
var output := ""
var captures := {}
var samples: Array[Dictionary] = []
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderBellPriestBattlefield "+label)
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport,name: String) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	check(pixels.save_png(output+name)==OK,"actual frame save "+name); captures[name] = FileAccess.get_sha256(output+name)
	return pixels
func advance_by(combat: Node,seconds: float) -> void:
	for _step in ceili(seconds*120):
		var delta := minf(seconds,1.0/120); seconds -= delta; combat.advance(delta)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh actual GPU required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderBellPriestBattlefield.gd","scripts/actors/EchoBellPriestBoss.gd","scripts/actors/OverseerBoss.gd","scripts/actors/Player.gd","scripts/components/BellPriestAttackDirector.gd","scripts/components/BellPriestStrike.gd","scripts/components/BellPriestPendantProjectile.gd","scripts/components/BellPriestCrownProjectile.gd","scripts/components/NativeBellPriestMotion.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeActorView.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/ArchivePageProjectile.gd","scripts/components/VineSeedProjectile.gd","scripts/components/RiftShardProjectile.gd","scripts/components/Projectile.gd","scripts/components/HealthComponent.gd","scripts/world/TerrainSweep.gd","scenes/actors/native/bell_priest_paper_v2.tscn","assets/art/actors/native/bell_priest_motion_v2.tres","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","assets/art/shaders/dasher_hit_flash.gdshader","scripts/ui/BossHealthBar.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/HostileEffectPalette.gd","themes/MintFarmTheme.tres","scenes/world/echo_court.tscn","scripts/world/EchoMap.gd","scripts/world/EchoArenaLayout.gd","scripts/world/EchoFloor.gd","scripts/world/EchoObstacle.gd","scripts/world/EchoPropArt.gd","scripts/world/EchoField.gd","scripts/world/EchoBeat.gd","scripts/world/ArenaLayout.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source "+path)
	for kind in [&"bell",&"pendant",&"crown"]:
		var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
		var map = Map.instantiate(); map.map_seed = 521; view.add_child(map)
		var shots := Node2D.new(); shots.z_as_relative = false; shots.z_index = 22; map.add_child(shots)
		var player := Player.new(); player.position = map.layout.BOSS_CENTER+Vector2(120,0); player.world_bounds = map.layout.world_bounds; map.add_child(player); map.layout.occlusion_target = player
		var boss := Boss.new(); boss.position = map.layout.BOSS_CENTER; boss.world_bounds = map.layout.world_bounds; boss.setup(5,shots,player); boss.set_arena_navigation(map.layout); map.add_child(boss); boss.set_physics_process(false)
		var camera := Camera2D.new(); camera.position = boss.position+Vector2(0,-22); view.add_child(camera)
		var layer := CanvasLayer.new(); view.add_child(layer)
		var panel := Control.new(); panel.theme = THEME; layer.add_child(panel)
		var bar := Bar.new(); panel.add_child(bar); bar.show_boss(boss.get_display_name(),boss.health.max_health)
		boss.health_changed.connect(bar.set_boss_health); boss.died.connect(func(_b,_coins,_source): bar.hide_boss())
		var caption := Label.new(); caption.theme = THEME; caption.position = Vector2(24,20); caption.add_theme_font_size_override("font_size",22); caption.text = "钟骨司祭 / 真实地图与骨骼挂点 · 受控状态采样（非整关通关）"; panel.add_child(caption)
		caption.add_theme_color_override("font_color",Color("d0c5b6"))
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		if kind==&"crown": boss.take_damage(boss.health.max_health*0.8); combat.advance(0.65); combat.advance(0.65)
		# Let the real damage flash expire, rather than freezing it in a phase fixture.
		boss.set_physics_process(true)
		for _step in 12: await physics_frame
		boss.set_physics_process(false); combat.attack_gap = 99
		check(boss.flash_timer==0,"setup freezes an old hit flash")
		await physics_frame; await physics_frame; await process_frame
		check(combat.start_action(kind),"actual action refused")
		advance_by(combat,0.10); boss.world_status.refresh()
		var warning := await capture(view,String(kind)+"-warning.png")
		var marker: Vector2 = boss.get_global_transform_with_canvas()*Vector2(0,boss.get_attack_marker_top()-9)
		var cream := warning.get_pixelv(Vector2i(marker))
		check(boss.should_show_attack_marker() and cream.r>0.8 and cream.g>0.75 and cream.b>0.55,"real short head symbol absent "+String(kind))
		check(bar.visible and bar.health_bar.value==boss.health.current_health and bar.name_label.text==boss.get_display_name(),"actual HUD not bound to Health")
		var phase: int = boss.get_phase(); check(bar.phase_label.text=="PHASE "+["I","II","III"][phase-1],"actual Health phase absent from HUD")
		advance_by(combat,combat.DURATIONS[kind][0]-0.10+0.00001); advance_by(combat,0.12); boss.world_status.refresh()
		# Show actual flight away from the sockets; don't count overlapping births
		# or a scene-tree child count as proof that two projectiles are readable.
		if kind!=&"bell":
			for _step in 8: await physics_frame
		var active := await capture(view,String(kind)+"-active.png")
		check(not boss.should_show_attack_marker() and combat.action_stage==combat.Stage.ACTIVE,"active retains warning or wrong clock")
		check(active.get_data()!=warning.get_data(),"actual action pixels static")
		check(kind==&"bell" or shots.get_child_count()==2,"finite pair absent from actual frame")
		samples.append({"kind":String(kind),"phase":phase,"health":boss.health.current_health,"body_radius":boss.body_radius,"player_radius":player.get_body_radius(),"marker":marker,"owned_visible_projectiles":shots.get_child_count()})
		combat.cancel_action(); await process_frame
		check(shots.get_child_count()==0 and not boss.should_show_attack_marker(),"cancel retains actual visual danger")
		await capture(view,String(kind)+"-cancelled.png")
		boss.take_damage(boss.health.current_health+1); await process_frame
		check(not bar.visible and shots.get_child_count()==0,"actual Boss death keeps HUD/danger")
		await capture(view,String(kind)+"-death.png")
		view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift")
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"samples":samples,"scope":"Actual EchoMap/Boss/clock/real sockets, short head cue and real Health-bound BossHealthBar; warning/active/cancel/death frames, crown actual phase3. Controlled timing/position/death fixture, not ordinary-input victory, formal fifth chapter or unlock6."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderBellPriestBattlefield %d"%checks)
	quit(1 if failures else 0)
