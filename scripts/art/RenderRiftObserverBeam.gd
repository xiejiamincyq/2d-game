extends "RenderEchoMapPreview.gd"
## Actual Actor, articulated origin and real map; controlled clock GPU, not victory.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
const BossBar = preload("res://scripts/ui/BossHealthBar.gd")
const ACTIVE_COLOR := Color("ed8877")
var observations: Array[Dictionary] = []
func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderRiftObserverBeam "+label_text)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func pixel(image: Image,view: SubViewport,world: Vector2) -> Color:
	var screen := view.get_canvas_transform()*world
	check(Rect2(Vector2.ZERO,Vector2(view.size)).has_point(screen),"probe outside actual viewport")
	return image.get_pixel(clampi(roundi(screen.x),0,image.get_width()-1),clampi(roundi(screen.y),0,image.get_height()-1))
func close_color(actual: Color,expected: Color) -> bool:
	return Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(expected.r,expected.g,expected.b))<0.08 and actual.a>0.99
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and fresh evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderRiftObserverBeam.gd","scripts/art/RenderEchoMapPreview.gd","scripts/actors/RiftObserverBoss.gd","scripts/actors/OverseerBoss.gd","scripts/components/RiftObserverAttackDirector.gd","scripts/components/RiftObserverBeam.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/NativeActorView.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeRiftObserverMotion.gd","scripts/components/HealthComponent.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/EnemyHitFeedback.gd","scripts/effects/HostileEffectPalette.gd","scripts/systems/CombatView.gd","scenes/actors/native/rift_observer_paper_v2.tscn","assets/art/actors/native/rift_observer_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader","scripts/tests/RiftObserverOriginSafetyTest.gd","scripts/tests/RiftObserverBeamClockTest.gd","scripts/tests/RiftObserverBeamDodgeTest.gd","scripts/ui/BossHealthBar.gd","scenes/world/rift_observatory.tscn","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftFloor.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftPropArt.gd","scripts/world/RiftField.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source SHA "+path)
	if failures: quit(1); return
	RenderingServer.set_default_clear_color(Color("252b38")); release()
	for sign_value in [1,-1]:
		var view := viewport(Vector2i(1280,720))
		var map = RiftMap.instantiate(); map.map_seed = 521; view.add_child(map)
		var shots := Node2D.new(); map.add_child(shots)
		var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = map.layout.BOSS_CENTER+Vector2(sign_value*240,0)
		map.add_child(player); player.set_physics_process(false)
		var boss := Observer.new(); boss.world_bounds = map.layout.world_bounds; boss.position = map.layout.BOSS_CENTER; boss.arena_navigation = map.layout
		boss.setup(6,shots,player); map.add_child(boss); boss.set_physics_process(false)
		map.layout.occlusion_target = player
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		var camera := Camera2D.new(); camera.position = boss.position+Vector2(sign_value*120,0); view.add_child(camera)
		var ui := CanvasLayer.new(); view.add_child(ui)
		label(ui,"裂隙观测者 / 真实地图与Actor / 受控攻击时钟，非整场通关",Vector2(24,16))
		var bar := BossBar.new(); ui.add_child(bar); bar.show_boss("裂隙观测者 · 窄束机制检查",boss.health.max_health)
		check(combat.start_action(&"beam"),"actual attack cannot start")
		step(combat,0.15)
		boss.world_status.refresh()
		var root_transform := boss.global_transform
		var head_at := boss.to_global(Vector2(0,boss.get_attack_marker_top()-9))
		var side: Vector2 = combat.locked_direction.orthogonal()
		var warning := await capture(view,"warning-%s.png"%sign_value)
		check(boss.should_show_attack_marker() and not combat.beam.armed and player.health.current_health==100,"warning authority")
		check(close_color(pixel(warning,view,head_at),Color("f3eddc")),"actual outlined head warning absent")
		step(combat,0.15)
		var origin: Vector2 = combat.locked_origin; var direction: Vector2 = combat.locked_direction
		var spot := origin+direction*150
		var first := await capture(view,"active-release-%s.png"%sign_value)
		check(combat.beam.armed and origin.is_equal_approx(boss.get_action_origin(&"beam",8)) and player.health.current_health==100,"release socket or premature damage")
		check(close_color(pixel(first,view,spot),ACTIVE_COLOR) and close_color(pixel(first,view,spot+side*7),ACTIVE_COLOR),"same-radius active interior invisible")
		check(not close_color(pixel(first,view,spot+side*11),ACTIVE_COLOR),"beam visual extends beyond radius/outline")
		check(not boss.should_show_attack_marker() and not close_color(pixel(first,view,head_at),Color("f3eddc")),"head marker remains after release")
		step(combat,1.0/120)
		check(player.health.current_health==64 and combat.beam.attempted,"actual visible beam does not damage stationary normal Player once")
		step(combat,0.12-1.0/120)
		var last := await capture(view,"active-last-%s.png"%sign_value)
		check(combat.action_stage==combat.Stage.ACTIVE and combat.beam.armed and close_color(pixel(last,view,spot),ACTIVE_COLOR),"closing hit frame erased")
		check(player.health.current_health==64 and combat.locked_origin==origin and combat.locked_direction==direction and boss.global_transform==root_transform,"repeat/tracking/root rotation")
		combat.advance(1.0/120)
		var recovery := await capture(view,"recovery-%s.png"%sign_value)
		check(combat.action_stage==combat.Stage.RECOVERY and not combat.beam.armed and not close_color(pixel(recovery,view,spot),ACTIVE_COLOR),"recovery beam persists")
		step(combat,0.45); check(combat.start_action(&"beam"),"pause fixture start")
		step(combat,0.1); paused = true
		var pause_image := await capture(view,"paused-%s.png"%sign_value)
		check(not combat.is_attacking() and not boss.should_show_attack_marker() and not close_color(pixel(pause_image,view,spot),ACTIVE_COLOR),"pause retains beam/head")
		paused = false
		check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"GPU fixture modifies physical stats")
		check((view.get_canvas_transform()*(boss.global_transform*boss.get_visual_rect())).position.y>160,"Boss visual overlaps HUD safe region")
		observations.append({"facing_left":sign_value<0,"origin":[origin.x,origin.y],"tip":[combat.beam.tip.x,combat.beam.tip.y],"health":player.health.current_health,"root_unchanged":boss.global_transform==root_transform})
		view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"observations":observations,"scope":"Actual seed521 sixth map, Actor/Health/30 native bones/current sockets/Player and BossHealthBar at1280; left/right controlled sole-clock warning/active0/closing active/recovery/pause GPU checks with real damage. No natural full Boss battle, probes/refract, sixth readiness/unlock/save, OS input, human playtest, dense performance or whole goal completion."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderRiftObserverBeam %d; %d captures"%[checks,captures.size()])
	quit(1 if failures else 0)
