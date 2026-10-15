extends SceneTree
## Actual map/actors/drone/beam GPU; controlled passive ticks, not normal play.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Enemy = preload("res://scripts/actors/Enemy.gd")
const OUTPUT := "res://build/diagnostics/campaign-goal/laser-cover-gpu-v2"
var checks:=0
var failures:=0
var sources: Dictionary={}
var captures: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: VerifyLaserCover "+label)
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport,label: Label,state: String,description: String) -> void:
	label.text=description
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var pixels:=view.get_texture().get_image()
	var path:=OUTPUT.path_join(state+".png")
	check(pixels!=null and pixels.get_size()==Vector2i(1280,720) and pixels.save_png(path)==OK,"real GPU image "+state)
	captures.append({"state":state,"path":path,"sha256":FileAccess.get_sha256(path)})
func run() -> void:
	check(DisplayServer.get_name()!="headless","real renderer required")
	check(not DirAccess.dir_exists_absolute(OUTPUT),"preserve earlier GPU evidence")
	if failures: quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT)==OK,"new output folder")
	for path in ["scripts/components/DroneLaserResolver.gd","scripts/components/BeamHitGeometry.gd","scripts/components/TerrainDamageQuery.gd","scripts/actors/Player.gd","scripts/components/LaserBeam.gd","scripts/art/VerifyLaserCover.gd","scenes/world/ember_foundry.tscn","scripts/world/DestructibleObstacle.gd"]:
		sources[path]=FileAccess.get_sha256("res://"+path)
	var saved: Dictionary={}
	for base in ["user://five_minute_overdrive_campaign_v1.json","user://five_minute_overdrive_journey_v1.json"]:
		for suffix in ["",".bak",".tmp"]:
			saved[base+suffix]=FileAccess.get_sha256(base+suffix) if FileAccess.file_exists(base+suffix) else "MISSING"
	var view:=SubViewport.new(); view.size=Vector2i(1280,720); view.world_2d=World2D.new()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var map:=Map.instantiate(); map.map_seed=521; view.add_child(map)
	var wall: Node2D=map.layout.get_child(0); var rect: Rect2=wall.get_damage_rect()
	var player:=Player.new(); player.position=Vector2(rect.position.x-128,rect.get_center().y)
	player.projectile_parent=map; player.world_bounds=map.layout.world_bounds; map.add_child(player); player.set_physics_process(false)
	var actor:=Enemy.new(); actor.setup(Enemy.EnemyKind.SCRAPPER,0,map)
	actor.position=Vector2(rect.end.x+80,rect.get_center().y); map.add_child(actor); actor.set_physics_process(false)
	var hp: float=actor.health.current_health
	player.set_enemy_provider(func(): return [actor])
	player.drone_count=1; player.drone_laser_piercing=true
	player._sync_drone_visuals(); player._sync_drone_lasers(); player._update_drone_positions()
	player.drone_aim_directions[0]=Vector2.RIGHT
	var camera:=Camera2D.new(); camera.position=rect.get_center(); view.add_child(camera); camera.make_current()
	var canvas:=CanvasLayer.new(); view.add_child(canvas)
	var label:=Label.new(); label.position=Vector2(24,24); label.add_theme_font_size_override("font_size",22)
	label.add_theme_color_override("font_color",Color("f3eddc")); label.add_theme_color_override("font_outline_color",Color("123b3b"))
	label.add_theme_constant_override("outline_size",6); canvas.add_child(label)
	await physics_frame; await process_frame; await physics_frame; await process_frame
	var wall_hp: float=wall.health.current_health
	player._update_drone_lasers(0.1)
	var beam: Node2D=player.drone_lasers[0]
	check(beam.visible and (beam.global_position+beam.end_local).x<=rect.position.x+0.1,"actual persistent beam ends at first cover")
	check(is_equal_approx(wall.health.current_health,wall_hp-player.drone_damage*0.1) and actor.health.current_health==hp,"real DPS hits wall not actor behind")
	await capture(view,label,"blocked","穿透棱镜 · 建筑阻挡光束并承受持续伤害 · 敌人保持锁定但未受伤")
	for step in 240:
		if wall.is_queued_for_deletion(): break
		player._update_drone_lasers(0.1)
	check(wall.is_queued_for_deletion() and actor.health.current_health==hp,"sustained DPS destroys building before hitting rear")
	await physics_frame; await process_frame; await physics_frame; await process_frame
	player._update_drone_lasers(0.1)
	check(actor.health.current_health<hp,"cleared physical cover releases beam damage")
	await capture(view,label,"opened","建筑已被激光摧毁 · 原碰撞与导航占用解除 · 光束继续击中后方敌人")
	view.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	for path in saved: check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING")==saved[path],"default save changed")
	var report:=FileAccess.open(OUTPUT.path_join("report.json"),FileAccess.WRITE)
	check(report!=null,"report writer")
	if report!=null:
		report.store_string(JSON.stringify({"valid":failures==0,"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"sources":sources,"captures":captures,"limits":["Actual actors/map/beam, controlled passive time only.","No full chapter, save transaction or final EXE/performance acceptance."]},"\t")); report.close()
	if failures==0: print("TEST PASS: VerifyLaserCover %d"%checks)
	quit(1 if failures else 0)
