extends "RenderEchoMapPreview.gd"
## Actual map/native sockets/Health; controlled sole clock, not ordinary victory.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
const BossBar = preload("res://scripts/ui/BossHealthBar.gd")
const CORE := Color("ed8877")
var observations: Array[Dictionary] = []
func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderRiftObserverProbes "+label_text)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func pixel(image: Image,view: SubViewport,world: Vector2) -> Color:
	var screen := view.get_canvas_transform()*world
	check(Rect2(Vector2.ZERO,Vector2(view.size)).has_point(screen),"sample outside actual viewport")
	return image.get_pixel(clampi(roundi(screen.x),0,image.get_width()-1),clampi(roundi(screen.y),0,image.get_height()-1))
func close_color(actual: Color,expected: Color) -> bool:
	return Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(expected.r,expected.g,expected.b))<0.08 and actual.a>0.99
func birth(combat: Node,boss: Node,index: int) -> void:
	var attempts := 0
	while not combat.probe_released[index] and attempts<40:
		combat.advance(1.0/120); attempts += 1
	var probe: RefCounted = combat.probes[index]
	var socket: StringName = &"probes_left" if index==0 else &"probes_right"
	check(attempts<40 and probe.armed and probe.age==0 and probe.origin.is_equal_approx(boss.get_action_origin(socket,6)) and probe.position==probe.origin,"actual current sensor birth, before damage")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and fresh evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderRiftObserverProbes.gd","scripts/art/RenderEchoMapPreview.gd","scripts/tests/EchoMovementTest.gd","scripts/actors/RiftObserverBoss.gd","scripts/actors/OverseerBoss.gd","scripts/components/RiftObserverAttackDirector.gd","scripts/components/RiftObserverProbe.gd","scripts/components/RiftObserverBeam.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/NativeActorView.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeRiftObserverMotion.gd","scripts/components/HealthComponent.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/EnemyHitFeedback.gd","scripts/effects/HostileEffectPalette.gd","scripts/systems/CombatView.gd","scenes/actors/native/rift_observer_paper_v2.tscn","assets/art/actors/native/rift_observer_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader","scripts/tests/RiftObserverOriginSafetyTest.gd","scripts/tests/RiftObserverProbeTest.gd","scripts/tests/RiftObserverProbeBoundaryTest.gd","scripts/tests/RiftObserverProbeAttackTest.gd","scripts/tests/RiftObserverProbeDodgeTest.gd","scripts/ui/BossHealthBar.gd","scenes/world/rift_observatory.tscn","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftFloor.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftPropArt.gd","scripts/world/RiftField.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"source SHA "+path)
	var origin_source := "scripts/tests/RiftObserverProbeOriginBoundaryTest.gd"
	sources[origin_source] = FileAccess.get_sha256("res://"+origin_source); check(sources[origin_source].length()==64,"source SHA "+origin_source)
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
		label(ui,"裂隙观测者 / 双臂锁点钳击 / 受控时钟，非整场通关",Vector2(24,16))
		var bar := BossBar.new(); ui.add_child(bar); bar.show_boss("裂隙观测者 · 双探针机制检查",boss.health.max_health)
		check(combat.start_action(&"probes"),"actual pair cannot start")
		var landings: PackedVector2Array = combat.probe_landings.duplicate()
		step(combat,0.16); boss.world_status.refresh()
		var root_transform := boss.global_transform
		var head_at := boss.to_global(Vector2(0,boss.get_attack_marker_top()-9))
		var warning := await capture(view,"warning-%s.png"%sign_value)
		check(boss.should_show_attack_marker() and not combat.probes[0].armed and not combat.probes[1].armed and player.health.current_health==100,"warning damage authority")
		check(close_color(pixel(warning,view,head_at),Color("f3eddc")),"actual outlined head warning absent")
		# Move only in this controlled renderer to expose landing pixels, not a dodge proof.
		player.position += Vector2(0,100); step(combat,0.16)
		check(not combat.probes[0].armed and not combat.probes[1].armed and combat.action_stage==combat.Stage.ACTIVE,"early invisible births")
		birth(combat,boss,0); var left_origin: Vector2 = combat.probe_origins[0]
		step(combat,0.05); var left_at: Vector2 = combat.probes[0].position
		var left := await capture(view,"left-outbound-%s.png"%sign_value)
		check(close_color(pixel(left,view,left_at),CORE) and not close_color(pixel(left,view,left_at+Vector2(9,0)),CORE),"small left footprint absent or oversized")
		check(combat.probes[0].age>0 and combat.probes[0].age<0.12 and not boss.should_show_attack_marker() and player.health.current_health==100,"left flight semantics")
		birth(combat,boss,1); var right_origin: Vector2 = combat.probe_origins[1]
		step(combat,0.05); var right_at: Vector2 = combat.probes[1].position
		var right := await capture(view,"right-outbound-%s.png"%sign_value)
		check(close_color(pixel(right,view,right_at),CORE) and not close_color(pixel(right,view,right_at+Vector2(9,0)),CORE),"small right footprint absent or oversized")
		check(combat.probe_landings==landings and combat.probes[0].origin==left_origin and combat.probes[1].origin==right_origin,"released path follows Owner/target")
		step(combat,0.15)
		var last_at: Vector2 = combat.probes[1].position
		var last := await capture(view,"right-last-%s.png"%sign_value)
		check(combat.probes[1].armed and is_equal_approx(combat.probes[1].age,0.20) and last_at.is_equal_approx(landings[1]) and close_color(pixel(last,view,last_at),CORE),"last legal landing footprint erased before rendering")
		check(not combat.probes[0].armed and player.health.current_health==100,"expired left or tracked target")
		paused = true
		var cancelled := await capture(view,"cancelled-%s.png"%sign_value)
		check(not combat.is_attacking() and not combat.probes[0].armed and not combat.probes[1].armed and not boss.should_show_attack_marker() and not close_color(pixel(cancelled,view,last_at),CORE),"pause retains hit shape or visible head/probe")
		paused = false
		check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1 and boss.global_transform==root_transform and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"renderer changes physical statistics/root")
		check((view.get_canvas_transform()*(boss.global_transform*boss.get_visual_rect())).position.y>160,"Boss overlaps HUD safe area")
		# Additional actual Health witness; no extra image is mislabelled as natural play.
		player.position = map.layout.BOSS_CENTER+Vector2(sign_value*240,0); player.health.invulnerable_time = 0
		check(combat.start_action(&"probes"),"stationary Health witness starts")
		step(combat,0.32); step(combat,0.24)
		check(player.health.current_health==73 and combat.probe_attempt.attempted,"real normal Player once-only Health missing")
		player.health.invulnerable_time = 0; step(combat,0.32); check(player.health.current_health==73,"second probe repeats actual Health")
		observations.append({"facing_left":sign_value<0,"left_origin":[left_origin.x,left_origin.y],"right_origin":[right_origin.x,right_origin.y],"left_landing":[landings[0].x,landings[0].y],"right_landing":[landings[1].x,landings[1].y],"health":player.health.current_health,"root_unchanged":boss.global_transform==root_transform})
		view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"observations":observations,"scope":"Actual seed521 sixth map, 30-bone Actor/Health/current left-right sensors/normal-stat Player/BossHealthBar at1280. Controlled sole-clock head warning, both current births and visible outbound small footprints, last legal landing, actual pause removal and additional real stationary HP73/no-repeat witness. Controlled Player reposition only exposes pixels; not natural dodge, full Boss, refract, sixth readiness/save, OS/human playtest, dense performance or whole goal."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderRiftObserverProbes %d; %d captures"%[checks,captures.size()])
	quit(1 if failures else 0)
