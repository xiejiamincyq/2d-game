extends SceneTree
## Real six-map/director wiring, controlled trap clocks; not a human playthrough.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Field = preload("res://scripts/world/ReusableTrapField.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const FIELDS := ["TrapField","HeatField","TidalField","SporeField","EchoField","RiftField"]
const BINDERS := ["","bind_heat_field","bind_tidal_field","bind_spore_field","bind_echo_field","bind_rift_field"]
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignStepTrapIntegrationTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for chapter in range(1,7): await chapter_contract(chapter)
	if failures==0: print("TEST PASS: CampaignStepTrapIntegrationTest %d"%checks)
	quit(1 if failures else 0)
func chapter_contract(chapter: int) -> void:
	var host := Node2D.new(); root.add_child(host)
	var definition: Dictionary = Definitions.get_definition(chapter)
	var map: Node2D = definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	var field = map.get_node_or_null(FIELDS[chapter-1])
	check(field!=null and field.get_script()==Field,"chapter%d formal map must own shared stepped field, not periodic legacy hazard"%chapter)
	if field==null or field.get_script()!=Field:
		host.free(); await process_frame; return
	var player := Player.new(); host.add_child(player); player.set_physics_process(false)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var director: Node = definition.director.new(); host.add_child(director); director.set_process(false)
	if chapter>1: check(director.call(BINDERS[chapter-1],field),"real regional binder chapter%d"%chapter)
	check(director.start_run(521,player,enemies,shots,portals,growth,map.layout),"real director starts chapter%d"%chapter)
	check(not field.active and field.get_child_count()>0,"INTRO has visible but disarmed sites chapter%d"%chapter)
	for child in field.get_children():
		check(child.get_script()==Trap and child.health.current_health==80 and not child.is_in_group(&"enemies"),"real 80HP non-enemy pressure plate chapter%d"%chapter)
		child.set_physics_process(false)
	check(director.begin_encounter(),"actual encounter begins chapter%d"%chapter)
	var armed: Array = field.get_children().filter(func(child): return child.enabled)
	check(armed.size()==(10 if chapter==2 else 2),"regional armed count preserved chapter%d"%chapter)
	if not armed.is_empty():
		var plate = armed[0]
		player.global_position=plate.global_position; player.shield=0
		plate._physics_process(0.01)
		check(plate.stage==Trap.Stage.WARNING and player.health.current_health==100,"step warns before damage chapter%d"%chapter)
		plate._physics_process(0.49)
		check(player.health.current_health==100,"full warning window chapter%d"%chapter)
		plate._physics_process(0.02)
		check(player.health.current_health==80,"actual damage exactly20 chapter%d"%chapter)
		player.health._process(1.51); plate._physics_process(1.51)
		plate._physics_process(0.01); plate._physics_process(0.51)
		check(player.health.current_health==60,"same plate triggers again after cooldown chapter%d"%chapter)
		plate.take_damage(20)
		field.set_active(false); field.set_active(true)
		check(plate.health.current_health==60,"activation does not heal plate chapter%d"%chapter)
		plate.take_damage(60)
		check(not field.get_destructible_targets().has(plate) and not director.get_attack_targets().has(plate),"destroyed terrain never enters enemy/clear roster chapter%d"%chapter)
		await process_frame
		var remaining: int=field.get_child_count()
		field.set_active(false); field.set_active(true)
		check(field.get_child_count()==remaining,"destroyed plate not replenished chapter%d"%chapter)
	# A living trap must not hold an otherwise empty combat's clearance debt.
	director.spawn_queue.clear()
	for portal in director.active_portals.duplicate():
		if is_instance_valid(portal): portal.queue_free()
	director.active_portals.clear()
	director._process(0)
	check(director.state==director.State.COLLECT and not field.active,"clear moves to collection and cancels plates chapter%d"%chapter)
	check(field.get_children().all(func(child): return not child.enabled),"no hazard during collection chapter%d"%chapter)
	host.free(); await process_frame
