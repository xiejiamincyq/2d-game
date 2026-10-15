extends SceneTree
## Public field foundation only. Not map runtime migration, art or playtest proof.
const PATH := "res://scripts/world/ReusableTrapField.gd"
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const NurseryLayout = preload("res://scripts/world/NurseryArenaLayout.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ReusableTrapFieldTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(PATH),"shared ReusableTrapField production resource is missing")
	if failures: quit(1); return
	var source = load(PATH)
	check(source is Script and source.can_instantiate(),"production field script compiles and can instantiate")
	if failures: quit(1); return
	var probe = source.new()
	check(probe is Node2D,"field is a Node2D")
	for method in [&"configure",&"get_sites",&"bind_player",&"set_active",&"get_destructible_targets",&"clear"]:
		check(probe.has_method(method),"missing public method "+str(method))
	probe.free()
	if failures: quit(1); return
	for chapter in range(1,7): await map_contract(source,chapter)
	await insufficient_capacity(source)
	await ownership_and_rebinding(source)
	await paused_warning(source)
	for reason in [&"player_death",&"player_exit",&"layout_exit",&"field_exit"]:
		await cancellation(source,reason)
	for reason in [&"clear",&"layout_exit"]:
		await configure_reentry(source,reason)
	await nested_configure_reentry(source)
	if failures==0: print("TEST PASS: ReusableTrapFieldTest %d"%checks)
	quit(1 if failures else 0)

func fixture(source: Script,chapter: int=1,transformed: bool=false) -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var map = Definitions.get_definition(chapter).map.instantiate()
	map.map_seed = 521
	if transformed:
		map.position = Vector2(93,-51); map.rotation = 0.23
	host.add_child(map)
	var layout = map.get_node("Layout")
	var player := Player.new()
	player.position = layout.to_global(Vector2.ZERO)
	host.add_child(player); player.set_physics_process(false)
	var field = source.new()
	if transformed:
		field.position = Vector2(-117,69); field.rotation = -0.47
	host.add_child(field)
	return {"host":host,"map":map,"layout":layout,"player":player,"field":field}

func children(field: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in field.get_children():
		if child.get_script()==Trap and not child.is_queued_for_deletion(): result.append(child)
	return result

func group_ids() -> Array[int]:
	var result: Array[int] = []
	for member in get_nodes_in_group(&"destructible_terrain"): result.append(member.get_instance_id())
	result.sort()
	return result

func clear_fixture(f: Dictionary,baseline: Array[int],label: String) -> void:
	f.host.free()
	await process_frame
	check(group_ids()==baseline,label+" leaves no destructible group orphan")

func validate_sites(f: Dictionary,expected: int,label: String) -> void:
	var sites: Array = f.field.get_sites()
	var traps: Array[Node] = children(f.field)
	check(sites.size()==expected and traps.size()==expected,label+" exact actual trap count")
	var constants: Dictionary = f.layout.get_script().get_script_constant_map()
	check(constants.has("SPAWN_BUFFER") and constants.has("BOSS_BUFFER"),label+" real protected pockets exist")
	var protected_spawn: Rect2 = constants.get("SPAWN_BUFFER",Rect2()).grow(66)
	var protected_boss: Rect2 = constants.get("BOSS_BUFFER",Rect2()).grow(66)
	for index in sites.size():
		var at: Vector2 = sites[index]
		check(f.layout.is_position_walkable(at,66),label+" 66px terrain clearance "+str(index))
		check(not protected_spawn.has_point(at) and not protected_boss.has_point(at),label+" protected pockets "+str(index))
		check(f.layout.is_reachable(Vector2.ZERO,at,f.player.get_body_radius()),label+" reachable by actual Player radius "+str(index))
		var matched := false
		for trap in traps:
			if trap.global_position.distance_to(f.layout.to_global(at))<0.01: matched=true
		check(matched,label+" layout-local site anchors actual transformed child "+str(index))
		for previous in range(index):
			check(at.distance_to(sites[previous])>=169.99,label+" 170px pair spacing "+str(previous)+"/"+str(index))
	for trap in traps:
		check(trap.health.current_health==80 and trap.health.max_health==80,label+" own 80HP child")
		check(trap.DAMAGE==20 and is_equal_approx(trap.WARNING_SECONDS,0.5) and is_equal_approx(trap.COOLDOWN_SECONDS,1.5),label+" common bounded attack contract")
		check(not trap.enabled and not trap.is_in_group(&"enemies") and trap.is_in_group(&"destructible_terrain"),label+" configure stays inactive/non-enemy")

func map_contract(source: Script,chapter: int) -> void:
	var baseline := group_ids()
	var f := fixture(source,chapter,true)
	var label := "chapter%d"%chapter
	var descriptors: Array = f.layout.get_obstacle_descriptors()
	var fifth: Array = []
	if chapter==5: fifth=[f.layout.get_ring_profiles(),f.layout.get_gateways(),f.layout.get_echo_sites()]
	check(f.field.configure(f.layout,521,f.player),label+" default configure succeeds")
	validate_sites(f,10,label+" default")
	var original: Array = f.field.get_sites()
	var copy: Array = f.field.get_sites()
	copy.clear()
	check(f.field.get_sites()==original,label+" get_sites returns detached array")
	check(f.field.configure(f.layout,521,f.player),label+" repeated configure succeeds")
	check(f.field.get_sites()==original,label+" same seed exactly deterministic")
	check(f.field.configure(f.layout,522,f.player),label+" changed seed configure succeeds")
	check(f.field.get_sites()!=original,label+" changed seed changes sites")
	check(f.field.configure(f.layout,521,f.player),label+" restore seed configure succeeds")
	check(f.field.get_sites()==original,label+" restore seed repeats original sites")
	check(f.field.configure(f.layout,521,f.player,999),label+" oversized request caps at16 and fits real map")
	validate_sites(f,16,label+" capped")
	check(f.layout.get_obstacle_descriptors()==descriptors,label+" field never edits building descriptors")
	if chapter==5:
		check(fifth==[f.layout.get_ring_profiles(),f.layout.get_gateways(),f.layout.get_echo_sites()],"fifth chapter ring/gateway/echo layout unchanged")
	f.field.clear()
	check(f.field.get_sites().is_empty() and f.field.get_destructible_targets().is_empty() and children(f.field).is_empty(),label+" clear detaches all trap children immediately")
	await clear_fixture(f,baseline,label)

func insufficient_capacity(source: Script) -> void:
	var baseline := group_ids()
	var f := fixture(source)
	check(f.field.configure(f.layout,521,f.player),"capacity control starts with complete valid field")
	f.field.set_active(true)
	# Real layout subclass and queries, deliberately tiny bounds wholly inside its
	# spawn reservation. No generated geometry is changed to fabricate capacity.
	var small := NurseryLayout.new()
	small.world_bounds = Rect2(-80,-80,160,160)
	f.host.add_child(small)
	check(not f.field.configure(small,521,f.player,10),"insufficient real protected space returns false")
	check(children(f.field).is_empty() and f.field.get_sites().is_empty() and f.field.get_destructible_targets().is_empty(),"failed configure closes old field without partial new children")
	f.field.set_active(true)
	check(children(f.field).is_empty(),"failed configure cannot auto-refill on activation")
	await clear_fixture(f,baseline,"insufficient capacity")

func ownership_and_rebinding(source: Script) -> void:
	var baseline := group_ids()
	var f := fixture(source)
	check(f.field.configure(f.layout,521),"unbound configure can place inactive field")
	f.field.set_active(true)
	for trap in children(f.field): check(not trap.enabled,"unbound field cannot arm")
	f.field.bind_player(f.player)
	for trap in children(f.field): check(not trap.enabled,"binding alone cannot arm")
	f.field.set_active(true,2)
	var enabled := 0
	for trap in children(f.field):
		trap.set_physics_process(false)
		if trap.enabled: enabled+=1
	check(enabled==2,"active count limits armed children")
	f.field.set_active(true)
	var traps: Array[Node] = children(f.field)
	if traps.is_empty():
		check(false,"ownership fixture has no actual trap"); await clear_fixture(f,baseline,"ownership"); return
	var first = traps[0]
	f.player.global_position = first.global_position
	first._physics_process(0.01)
	check(first.stage==Trap.Stage.WARNING and f.player.health.current_health==100,"bound real Player begins warning not immediate damage")
	var replacement := Player.new()
	replacement.position = f.layout.to_global(Vector2.ZERO)
	f.host.add_child(replacement); replacement.set_physics_process(false)
	f.field.bind_player(replacement)
	check(first.stage==Trap.Stage.READY and is_zero_approx(first.elapsed),"rebind clears old warning clock")
	f.field.set_active(true)
	check(first.target_player==replacement and first.enabled,"rebound field targets new actual Player")
	# Explicitly controlled child clock, not an input-driven playthrough. The field
	# must really bind the vulnerable Player receiver, not merely store its name.
	replacement.global_position=first.global_position
	first._physics_process(0.01)
	first._physics_process(0.49)
	check(replacement.health.current_health==100,"field-owned child preserves full half-second warning")
	first._physics_process(0.02)
	check(replacement.health.current_health==80 and first.stage==Trap.Stage.COOLDOWN,"field-owned real trap delivers one actual 20HP hit")
	f.field.set_active(false); f.field.set_active(true)
	check(replacement.health.current_health==80,"field activation never heals previously damaged Player")
	f.player.health.damage(100,true)
	check(first.enabled and replacement.health.current_health==80,"old Player death cannot cancel rebound field or heal/strike replacement")
	var outsider := Trap.new(); f.host.add_child(outsider)
	var targets: Array = f.field.get_destructible_targets()
	check(targets.size()==10 and not targets.has(outsider),"destructible getter contains only ten owned actual live children")
	for target in targets: check(target.get_parent()==f.field,"target ownership not global terrain group")
	var retired_id: int = first.get_instance_id()
	for hit in 9: first.take_damage(9)
	check(not f.field.get_destructible_targets().has(first),"queued destroyed trap immediately excluded")
	await process_frame
	f.field.set_active(false); f.field.set_active(true)
	check(children(f.field).size()==9 and f.field.get_destructible_targets().size()==9,"inactive-active does not resurrect or replenish destroyed trap")
	for trap in children(f.field): check(trap.get_instance_id()!=retired_id,"retired actual child identity stays absent")
	await clear_fixture(f,baseline,"ownership/rebind")

func paused_warning(source: Script) -> void:
	var baseline := group_ids()
	var f := fixture(source)
	check(f.field.configure(f.layout,521,f.player),"pause fixture configure")
	f.field.set_active(true,1)
	var selected: Node
	for trap in children(f.field):
		if trap.enabled: selected=trap; break
	if not is_instance_valid(selected):
		check(false,"pause fixture has an armed child"); await clear_fixture(f,baseline,"pause"); return
	f.player.global_position = selected.global_position
	await physics_frame; await process_frame
	check(selected.stage==Trap.Stage.WARNING,"normal engine tick starts actual trap warning")
	var elapsed: float = selected.elapsed
	paused=true
	await create_timer(0.12,true,false,true).timeout
	check(is_equal_approx(selected.elapsed,elapsed) and f.player.health.current_health==100,"paused engine does not advance child warning or damage")
	paused=false
	f.field.set_active(false)
	check(selected.stage==Trap.Stage.READY and is_zero_approx(selected.elapsed),"deactivation clears paused pending warning")
	await clear_fixture(f,baseline,"pause")

func cancellation(source: Script,reason: StringName) -> void:
	var baseline := group_ids()
	var f := fixture(source)
	check(f.field.configure(f.layout,521,f.player),str(reason)+" fixture configure")
	f.field.set_active(true,1)
	var traps: Array[Node] = children(f.field)
	var selected: Node
	for trap in traps:
		trap.set_physics_process(false)
		if trap.enabled: selected=trap
	if not is_instance_valid(selected):
		check(false,str(reason)+" fixture has an armed child"); await clear_fixture(f,baseline,str(reason)); return
	f.player.global_position=selected.global_position
	selected._physics_process(0.01)
	check(selected.stage==Trap.Stage.WARNING,str(reason)+" begins with a genuine pending warning")
	var detached: Node
	match reason:
		&"player_death": f.player.health.damage(100,true)
		&"player_exit": detached=f.player; f.host.remove_child(detached)
		&"layout_exit": detached=f.layout; f.map.remove_child(detached)
		&"field_exit": detached=f.field; f.host.remove_child(detached)
	var expected_health := 0 if reason==&"player_death" else 100
	for trap in traps:
		if is_instance_valid(trap): check(not trap.enabled,str(reason)+" synchronously cancels each owned trap")
	f.field.set_active(true)
	for trap in traps:
		if not is_instance_valid(trap): continue
		check(not trap.enabled,str(reason)+" cannot reactivate invalid context")
		if trap.is_inside_tree(): trap._physics_process(0.6)
	check(f.player.health.current_health==expected_health,str(reason)+" no late hit or death heal")
	if is_instance_valid(detached): detached.free()
	await clear_fixture(f,baseline,str(reason))

func configure_reentry(source: Script,reason: StringName) -> void:
	var baseline := group_ids()
	var f := fixture(source)
	var observed := {"callbacks":0}
	# Real synchronous Node child-entry signal, not an injected private callback.
	# Only the first child is intercepted; cleanup must invalidate outer configure.
	f.field.child_entered_tree.connect(func(_child: Node) -> void:
		observed.callbacks += 1
		if reason==&"clear": f.field.clear()
		else: f.map.remove_child(f.layout)
	,CONNECT_ONE_SHOT)
	var configured: bool = f.field.configure(f.layout,521,f.player)
	var label := "configure synchronous "+str(reason)
	check(observed.callbacks==1,label+" actual one-shot child-entry observer ran")
	check(not configured,label+" cancellation cannot report successful configure")
	check(children(f.field).is_empty() and f.field.get_destructible_targets().is_empty(),label+" leaves no actual owned trap")
	check(f.field.get_sites().is_empty(),label+" leaves no published sites")
	check(f.field.get("target")==null and f.field.get("linked_health")==null,label+" does not rebind Player after cancellation")
	f.field.set_active(true)
	check(not f.field.get("active") and children(f.field).is_empty(),label+" cannot arm a canceled configure")
	check(f.player.health.current_health==100,label+" does not damage real Player")
	# The canceled layout is a real detached subtree and must be explicitly freed.
	if reason==&"layout_exit" and is_instance_valid(f.layout) and not f.layout.is_inside_tree(): f.layout.free()
	await clear_fixture(f,baseline,label)

func nested_configure_reentry(source: Script) -> void:
	var baseline := group_ids()
	var f := fixture(source)
	var observed := {"entered":false,"inner_result":null}
	f.field.child_entered_tree.connect(func(_child: Node) -> void:
		# Even if a signal backend defers ONE_SHOT disconnection, only request one
		# nested operation; do not let the reproduction fixture recurse forever.
		if observed.entered: return
		observed.entered=true
		observed.inner_result=f.field.configure(f.layout,522,f.player)
	,CONNECT_ONE_SHOT)
	var outer_result: bool = f.field.configure(f.layout,521,f.player)
	check(observed.entered,"nested configure actual child-entry observer ran")
	check(observed.inner_result is bool and observed.inner_result==false,"nested configure is explicitly rejected")
	check(not outer_result,"nested configure invalidates outer configure")
	check(children(f.field).is_empty() and f.field.get_destructible_targets().is_empty(),"nested configure leaves no partial/second-generation trap children")
	check(f.field.get_sites().is_empty(),"nested configure publishes no partial/second-generation sites")
	check(f.field.get("target")==null and f.field.get("linked_health")==null,"nested configure leaves Player unbound")
	f.field.set_active(true)
	check(not f.field.get("active") and children(f.field).is_empty(),"nested configure leaves whole field closed")
	check(f.player.health.current_health==100,"nested configure does not harm actual Player")
	await clear_fixture(f,baseline,"nested configure")
