extends "RenderEchoMapPreview.gd"
## Actual map/Actor/Health/GPU; sole-clock controlled samples, not a full battle.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
const BossBar = preload("res://scripts/ui/BossHealthBar.gd")
const CORE := Color("ed8877")
var observations: Array[Dictionary] = []
func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderRiftObserverRefract "+label_text)
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
func has_core(image: Image,view: SubViewport,world: Vector2) -> bool:
	for x in range(-3,4):
		for y in range(-3,4):
			if close_color(pixel(image,view,world+Vector2(x,y)),CORE): return true
	return false
func color_count(image: Image,view: SubViewport,world: Vector2,color: Color) -> int:
	var count := 0
	for x in range(-5,6):
		for y in range(-5,6):
			var actual := pixel(image,view,world+Vector2(x,y))
			if Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(color.r,color.g,color.b))<0.02 and actual.a>0.99: count += 1
	return count
func birth(combat: Node,boss: Node,batch: int) -> void:
	var attempts := 0
	while not combat.refract.released[batch] and attempts<50:
		combat.advance(1.0/120); attempts += 1
	for offset in range(3):
		var fragment: RefCounted = combat.refract.fragments[batch*3+offset]
		check(attempts<50 and fragment.armed and fragment.age==0 and fragment.position==fragment.origin and fragment.origin.is_equal_approx(boss.get_action_origin(&"refract",4,true)),"true current Beacon birth before any damage")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"GPU and fresh evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderRiftObserverRefract.gd","scripts/art/RenderEchoMapPreview.gd","scripts/tests/EchoMovementTest.gd","scripts/actors/RiftObserverBoss.gd","scripts/actors/OverseerBoss.gd","scripts/components/RiftObserverAttackDirector.gd","scripts/components/RiftObserverCircleFlight.gd","scripts/components/RiftObserverFragment.gd","scripts/components/RiftObserverRefractVolley.gd","scripts/components/RiftObserverProbe.gd","scripts/components/RiftObserverBeam.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/NativeActorView.gd","scripts/components/NativeBossMotion.gd","scripts/components/NativeRiftObserverMotion.gd","scripts/components/HealthComponent.gd","scripts/effects/EnemyWorldStatus.gd","scripts/effects/HostileAttackDrawing.gd","scripts/effects/EnemyHitFeedback.gd","scripts/effects/HostileEffectPalette.gd","scripts/systems/CombatView.gd","scenes/actors/native/rift_observer_paper_v2.tscn","assets/art/actors/native/rift_observer_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader","scripts/tests/RiftObserverCircleFlightTest.gd","scripts/tests/RiftObserverFragmentTest.gd","scripts/tests/RiftObserverRefractAttackTest.gd","scripts/tests/RiftObserverRefractDodgeTest.gd","scripts/tests/RiftObserverBeamClockTest.gd","scripts/tests/RiftObserverProbeAttackTest.gd","scripts/ui/BossHealthBar.gd","scenes/world/rift_observatory.tscn","scripts/world/RiftMap.gd","scripts/world/RiftArenaLayout.gd","scripts/world/RiftFloor.gd","scripts/world/RiftObstacle.gd","scripts/world/RiftPropArt.gd","scripts/world/RiftField.gd","scripts/world/ArenaLayout.gd","scripts/world/TerrainSweep.gd","scripts/actors/Player.gd","scripts/components/NativePlayerView.gd","scripts/components/NativePlayerMotion.gd","scenes/actors/native/player_paper_v1.tscn","assets/art/actors/native/player_front_motion_v1.tres","assets/art/actors/native/player_back_motion_v1.tres","assets/art/actors/native/player_left_motion_v1.tres","assets/art/actors/native/player_right_motion_v1.tres","themes/MintFarmTheme.tres"]:
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
		boss.setup(6,shots,player); map.add_child(boss); boss.set_physics_process(false); map.layout.occlusion_target = player
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
		var camera := Camera2D.new(); camera.position = boss.position+Vector2(sign_value*120,0); view.add_child(camera)
		var ui := CanvasLayer.new(); view.add_child(ui)
		label(ui,"裂隙观测者 / 三批错位碎片 / 受控时钟，非整场通关",Vector2(24,16))
		var bar := BossBar.new(); ui.add_child(bar); bar.show_boss("裂隙观测者 · 分节折射检查",boss.health.max_health)
		check(combat.start_action(&"refract"),"actual refract cannot start")
		step(combat,0.15); boss.world_status.refresh(); var root_transform := boss.global_transform
		var head_at := boss.to_global(Vector2(0,boss.get_attack_marker_top()-9))
		var warning := await capture(view,"warning-%s.png"%sign_value)
		check(boss.should_show_attack_marker() and not combat.refract.fragments[0].armed and player.health.current_health==100 and close_color(pixel(warning,view,head_at),Color("f3eddc")),"actual small outlined head warning missing/premature damage")
		# Only exposes exact fragment pixels here; ordinary dodge is a separate fixture.
		player.position += Vector2(0,100); step(combat,0.15)
		var last_positions := PackedVector2Array()
		for batch in range(3):
			birth(combat,boss,batch); step(combat,0.045 if batch<2 else 0.09)
			var image := await capture(view,"batch%s-%s.png"%[batch+1,sign_value])
			for offset in range(3):
				var fragment: RefCounted = combat.refract.fragments[batch*3+offset]
				check(fragment.armed and has_core(image,view,fragment.position) and not close_color(pixel(image,view,fragment.position+fragment.origin.direction_to(fragment.landing).orthogonal()*9),CORE),"small opaque fragment absent, occluded or oversized")
				var paper := color_count(image,view,fragment.position,Color("d0c5b6"))
				var ink := color_count(image,view,fragment.position,Color("292435"))
				print("REFRACT PIXELS: facing%s batch%s fragment%s paper%s ink%s"%[sign_value,batch,offset,paper,ink])
				check(paper>=3 and ink>=2,"1x paper triangle collapses to a thin colored streak")
				check(fragment.origin==combat.refract.origins[batch] and fragment.query.shape.radius==4,"visual is not current true circle geometry")
				if batch==2:
					check(is_equal_approx(fragment.age,0.09) and fragment.position.is_equal_approx(fragment.landing),"last legal no-hold footprint erased")
					last_positions.append(fragment.position)
			check(player.health.current_health==100 and not boss.should_show_attack_marker(),"fan follows repositioned Player or retains head mark")
		paused = true
		var cancelled := await capture(view,"cancelled-%s.png"%sign_value)
		check(not combat.is_attacking() and not boss.should_show_attack_marker(),"pause keeps attack/head warning")
		for index in range(9): check(not combat.refract.fragments[index].armed,"pause keeps a real fragment")
		for at in last_positions: check(not has_core(cancelled,view,at),"pause retains old fragment pixels")
		paused = false
		check(boss.global_transform==root_transform and boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"root opacity or physical statistics changed")
		check((view.get_canvas_transform()*(boss.global_transform*boss.get_visual_rect())).position.y>160,"Boss overlaps HUD safe area")
		player.position = map.layout.BOSS_CENTER+Vector2(sign_value*240,0); player.health.invulnerable_time = 0
		check(combat.start_action(&"refract"),"stationary real Health witness starts")
		step(combat,0.30); step(combat,0.46); check(player.health.current_health==100,"first two central gaps are not real")
		step(combat,0.14); check(player.health.current_health==76 and combat.refract.attempt.attempted,"last central fragment misses actual Health")
		player.health.invulnerable_time = 0; step(combat,0.02); check(player.health.current_health==76,"recovery repeats Health")
		observations.append({"facing_left":sign_value<0,"health":player.health.current_health,"root_unchanged":boss.global_transform==root_transform,"batch_births":combat.refract.births.duplicate(),"true_origins":Array(combat.refract.origins),"gpu":"%s / %s"%[RenderingServer.get_video_adapter_name(),RenderingServer.get_video_adapter_api_version()]})
		view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"sources":sources,"captures":captures,"observations":observations,"scope":"Actual seed521 sixth map/30-bone Actor/current Beacon/Health/ordinary-stat Player/BossHealthBar at1280, real GPU. Controlled sole-clock head warning, each three-fragment finite batch, true last legal no-hold frame, actual pause erasure, stationary central gaps and one24 hit. Player reposition only exposes pixels. Not ordinary dodge/full Boss/readiness/save6/OS/human/dense performance/whole goal."},"\t")); file.close()
	if not failures: print("TEST PASS: RenderRiftObserverRefract %d; %d captures"%[checks,captures.size()])
	quit(1 if failures else 0)
