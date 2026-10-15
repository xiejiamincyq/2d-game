extends SceneTree
## Real six maps. State checks complement, not replace, GPU review.
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const FIELDS=["TrapField","HeatField","TidalField","SporeField","EchoField","RiftField"]
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: TerrainFeedbackTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func run() -> void:
	for chapter in range(1,7): await map_case(chapter)
	await first_hit_reentry()
	if failures==0: print("TEST PASS: TerrainFeedbackTest %d"%checks)
	quit(1 if failures else 0)
func metadata(floor_view: Node2D,chapter: int) -> String:
	match chapter:
		4: return JSON.stringify([floor_view.chambers,floor_view.doorways])
		5: return JSON.stringify([floor_view.rings,floor_view.gates,floor_view.echo_sites])
		6: return JSON.stringify([floor_view.island_profiles,floor_view.bypass_routes])
	return ""
func map_case(chapter: int) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	var wall: Node2D=map.layout.get_child(0)
	var rect: Rect2=wall.get_damage_rect()
	var descriptors: Array=map.layout.get_obstacle_descriptors()
	var profiles:=metadata(map.floor_view,chapter)
	var field: Node2D=map.get_node(FIELDS[chapter-1])
	var plate: Node2D=field.get_child(0); plate.take_damage(7)
	var trap_ids:=field.get_children().map(func(child): return child.get_instance_id())
	var collider: CollisionShape2D=wall.get_node("CollisionShape2D")
	var shape_id:=collider.shape.get_instance_id(); var transform:=collider.global_transform
	check(wall.get_node_or_null("DamageFeedback")==null,"chapter%d pristine buildings do not allocate active feedback"%chapter)
	var notifications: Array[Rect2]=[]
	var has_event: bool=map.layout.has_signal("obstacle_destroyed")
	check(has_event,"chapter%d public destruction event exists"%chapter)
	if has_event: map.layout.connect("obstacle_destroyed",func(footprint: Rect2): notifications.append(footprint))
	wall.take_damage(9)
	var view:=wall.get_node_or_null("DamageFeedback")
	check(view!=null,"chapter%d actual health event creates feedback"%chapter)
	if view!=null:
		view.set_process(false)
		check(is_equal_approx(view.health_ratio,wall.health.current_health/wall.health.max_health),"chapter%d bar uses actual shared Health"%chapter)
		check(view.get_node("HealthBar").visible and view.bar_rect.size==Vector2(56,6),"chapter%d small readable bar, no full-wall HUD"%chapter)
		check(view.bar_rect.end.y<wall.occlusion_rect.position.y,"chapter%d bar above whole native prop silhouette"%chapter)
		check(view.find_children("*","CollisionObject2D",true,false).is_empty(),"chapter%d feedback has no gameplay collider"%chapter)
		wall.take_damage(wall.health.max_health*0.6)
		check(view.damage_level>=2 and view.flash_remaining>0,"chapter%d heavy damage adds persistent cracks and brief hit cue"%chapter)
		view._process(0.20)
		check(view.flash_remaining==0 and view.damage_level>=2,"chapter%d hit cue expires without erasing damage state"%chapter)
	check(wall.modulate==Color.WHITE and wall.self_modulate==Color.WHITE,"chapter%d hit feedback never makes physical body transparent"%chapter)
	check(collider.shape.get_instance_id()==shape_id and collider.global_transform==transform,"chapter%d feedback cannot change collider or transform"%chapter)
	wall.take_damage(wall.health.max_health)
	check(wall.is_queued_for_deletion() and not wall.visible,"chapter%d lethal hit immediately removes solid visual"%chapter)
	check(notifications.size()==1 and notifications[0]==descriptors[0].rect,"chapter%d exact original footprint event once"%chapter)
	await tick(); await tick()
	if chapter<=3:
		check(map.floor_view.descriptors.size()==descriptors.size()-1 and not map.floor_view.descriptors.any(func(d): return Rect2(d.rect)==Rect2(descriptors[0].rect)),"chapter%d floor drops destroyed footprint without regenerate"%chapter)
	else:
		check(metadata(map.floor_view,chapter)==profiles,"chapter%d valid room/ring/island paving stays unchanged"%chapter)
	check(field.get_children().map(func(child): return child.get_instance_id())==trap_ids and plate.health.current_health==73,"chapter%d floor sync neither replaces nor heals traps"%chapter)
	check(map.layout.get_obstacle_descriptors().size()==descriptors.size()-1 and map.map_seed==521,"chapter%d surviving building/layout identity preserved"%chapter)
	var debris:=map.get_node_or_null("TerrainDebris")
	check(debris!=null and debris.find_children("*","CollisionObject2D",true,false).is_empty(),"chapter%d destruction reuses decorative debris only"%chapter)
	host.free(); await process_frame
func first_hit_reentry() -> void:
	var definition: Dictionary=Definitions.get_definition(1)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; root.add_child(map)
	var wall: Node2D=map.layout.get_child(0)
	var did_reenter: Array[bool]=[false]
	wall.child_entered_tree.connect(func(child: Node):
		if child.name==&"DamageFeedback" and not did_reenter[0]:
			did_reenter[0]=true; wall.take_damage(3))
	var maximum: float=wall.health.max_health; wall.take_damage(9)
	var feedback: Node2D=wall.get_node("DamageFeedback")
	check(did_reenter[0] and is_equal_approx(wall.health.current_health,maximum-12),"real child-entry callback reenters first terrain hit")
	check(is_equal_approx(feedback.health_ratio,(maximum-12)/maximum),"first-hit view reflects latest Health, not outer stale signal values")
	var original:=feedback.get_instance_id()
	wall.health.heal(maximum)
	check(not feedback.visible and not feedback.is_processing(),"full repair hides feedback and stops idle processing")
	wall.take_damage(5)
	check(wall.get_node("DamageFeedback").get_instance_id()==original and feedback.visible,"later hit reuses original visual child")
	var before: float=feedback.flash_remaining
	paused=true; await create_timer(0.06,true,false,true).timeout
	check(feedback.flash_remaining==before,"pause freezes real feedback clock")
	paused=false; await create_timer(0.12).timeout
	check(feedback.flash_remaining==0 and feedback.visible,"unpause expires hit cue but keeps damaged bar")
	var next: Node2D=map.layout.get_child(1)
	var receipts: Array[Rect2]=[]
	map.layout.obstacle_destroyed.connect(func(rect: Rect2): receipts.append(rect))
	next.child_entered_tree.connect(func(child: Node):
		if child.name==&"DamageFeedback": next.take_damage(next.health.max_health))
	next.take_damage(1)
	check(next.destroyed and next.is_queued_for_deletion() and not next.visible,"lethal child-entry reentry retires body immediately")
	check(receipts.size()==1,"lethal first-feedback reentry publishes one nav/floor receipt")
	map.free(); await process_frame
