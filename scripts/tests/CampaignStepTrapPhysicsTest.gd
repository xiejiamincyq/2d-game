extends SceneTree
## Actual six-map pressure plates, normal Player inputs and physics projectiles.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Shot = preload("res://scripts/components/Projectile.gd")
const FIELD_NAMES := ["TrapField","HeatField","TidalField","SporeField","EchoField","RiftField"]
var checks:=0
var failures:=0
func _chapters() -> Array[int]: return [1,2,3,4,5,6]
func suite_name() -> String: return get_script().resource_path.get_file().get_basename()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: %s %s"%[suite_name(),label])
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func release() -> void:
	for action in ["move_up","move_down","move_left","move_right"]: Input.action_release(action)
func wait_for(predicate: Callable,seconds: float) -> bool:
	var first:=Engine.get_physics_frames()
	while float(Engine.get_physics_frames()-first)/Engine.physics_ticks_per_second<seconds:
		if predicate.call(): return true
		await tick()
	return predicate.call()
func fixture(chapter: int,seed_value: int=521) -> Dictionary:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=seed_value; host.add_child(map)
	var field: Node2D=map.get_node(FIELD_NAMES[chapter-1])
	var trap: Node2D=field.get_child(0)
	var player:=Player.new(); player.world_bounds=map.layout.world_bounds
	player.position=trap.global_position; host.add_child(player)
	field.bind_player(player)
	return {"host":host,"map":map,"field":field,"trap":trap,"player":player}
func durability(player: Node) -> float: return player.health.current_health+player.shield
func escape(chapter: int,hz: int) -> void:
	Engine.physics_ticks_per_second=hz; release()
	var f:=fixture(chapter,0 if hz==30 else 20261011 if hz==120 else 521)
	var before:=durability(f.player)
	# Match real INTRO: scene construction is disarmed. Settle the actual tree
	# before measuring a visible combat cue, rather than consuming its warning
	# in map-construction catch-up or mixing pause recovery into human reaction.
	await tick(); await tick()
	f.field.set_active(true,1)
	check(await wait_for(func(): return f.trap.stage==f.trap.Stage.WARNING,0.15),"natural step cue chapter%d %dHz"%[chapter,hz])
	var elapsed: float=f.trap.elapsed
	var cue_tick:=Engine.get_physics_frames()
	f.player.health_changed.connect(func(current: float,_maximum: float):
		if current<100: print("STEP HIT chapter=%d hz=%d since_cue=%.3f offset=%s elapsed=%.3f"%[chapter,hz,float(Engine.get_physics_frames()-cue_tick)/hz,f.player.position-f.trap.global_position,f.trap.elapsed])
	)
	var directions: Array[Vector2]=[Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]
	var actions: Array[String]=["move_right","move_left","move_up","move_down"]
	var selected:=-1
	for index in directions.size():
		var clear:=true
		for distance in [20.0,40.0,60.0,90.0]:
			if not f.map.layout.is_position_walkable(f.trap.global_position+directions[index]*distance,f.player.get_body_radius()): clear=false
		if clear: selected=index; break
	check(selected>=0,"ordinary escape direction exists chapter%d"%chapter)
	if selected>=0:
		while Engine.get_physics_frames()-cue_tick<ceili(hz*0.25): await tick()
		check(durability(f.player)==before,"at least0.25s human reaction without premature hit")
		var at: Vector2=f.player.position
		print("STEP INPUT chapter=%d hz=%d cue_elapsed=%.3f elapsed=%.3f since_cue=%.3f speed=%.1f guard=%s"%[chapter,hz,elapsed,f.trap.elapsed,float(Engine.get_physics_frames()-cue_tick)/hz,f.player.get_effective_move_speed(),f.player.spawn_input_guard_active])
		Input.action_press(actions[selected])
		for frame in ceili(hz*0.30): await tick()
		release()
		check(f.player.position.distance_to(at)>45 and f.player.position.distance_to(f.trap.global_position)>f.trap.trigger_radius+f.player.get_body_radius(),"real normal movement clears full pressure overlap")
		check(durability(f.player)==before,"delayed ordinary escape takes no damage chapter%d %dHz"%[chapter,hz])
		check(is_equal_approx(f.player.move_speed,235) and is_equal_approx(f.player.get_body_radius(),16.9) and not f.player.is_stealthed(),"no movement/collision/stealth bypass")
	f.host.free(); await process_frame
func standing_and_shooting(chapter: int) -> void:
	Engine.physics_ticks_per_second=60; release()
	var f:=fixture(chapter)
	var before:=durability(f.player)
	await tick(); await tick()
	f.field.set_active(true,1)
	check(await wait_for(func(): return f.trap.stage==f.trap.Stage.WARNING,0.15),"standing warning appears before pause")
	var frozen: float=f.trap.elapsed
	paused=true
	await create_timer(0.08,true,false,true).timeout
	check(is_equal_approx(f.trap.elapsed,frozen) and durability(f.player)==before,"real paused warning neither advances nor hurts")
	paused=false
	check(await wait_for(func(): return durability(f.player)<before,0.8),"standing player really receives first hit chapter%d"%chapter)
	check(is_equal_approx(before-durability(f.player),20),"first hit remains20 with real shield receiver")
	var first_hit:=durability(f.player)
	check(await wait_for(func(): return durability(f.player)<first_hit,2.3),"same actual plate naturally cycles again chapter%d"%chapter)
	check(is_equal_approx(first_hit-durability(f.player),20),"second cycle remains20 without burst")
	f.field.set_active(false)
	f.player.position=f.trap.global_position+Vector2(0,120)
	for faction in [&"enemies",&"player"]:
		var hp: float=f.trap.health.current_health
		var shot:=Shot.new(); shot.target_group=faction; shot.damage=9
		var direction:=1 if faction==&"enemies" else -1
		shot.position=f.trap.global_position+Vector2(-60*direction,0); shot.velocity=Vector2(360*direction,0)
		f.host.add_child(shot)
		check(await wait_for(func(): return f.trap.health.current_health<hp,0.5),"real %s projectile damages non-enemy plate chapter%d"%[faction,chapter])
		check(f.trap.health.current_health==hp-9,"projectile applies exactly9 once")
		check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),"zero-pierce actual shot consumed on plate")
	check(not f.trap.is_in_group(&"enemies") and f.trap.health.current_health==62,"both faction damage without enemy reward membership")
	var retired_id: int=f.trap.get_instance_id()
	var lethal:=Shot.new(); lethal.target_group=&"enemies"; lethal.damage=62
	lethal.position=f.trap.global_position-Vector2(60,0); lethal.velocity=Vector2(360,0); f.host.add_child(lethal)
	check(await wait_for(func(): return not is_instance_valid(f.trap) or f.trap.is_queued_for_deletion(),0.5),"real lethal projectile destroys plate")
	await tick()
	f.field.set_active(true,4)
	check(f.field.get_child_count()==9 and f.field.get_destructible_targets().all(func(child): return child.get_instance_id()!=retired_id),"destroyed actual collider not restored by combat update")
	check(not is_instance_valid(lethal) or lethal.is_queued_for_deletion(),"lethal zero-pierce projectile consumed once")
	f.host.free(); await process_frame
func run() -> void:
	var original:=Engine.physics_ticks_per_second
	var chapters: Array[int]=_chapters()
	var rates: Array[int]=[30,60,120]
	var escape_only:=false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--chapter="): chapters.assign([int(argument.trim_prefix("--chapter="))])
		if argument.begins_with("--hz="): rates.assign([int(argument.trim_prefix("--hz="))])
		if argument=="--escape-only": escape_only=true
	for chapter in chapters:
		for hz in rates: await escape(chapter,hz)
		if not escape_only: await standing_and_shooting(chapter)
	Engine.physics_ticks_per_second=original; release()
	if failures==0: print("TEST PASS: %s %d"%[suite_name(),checks])
	quit(1 if failures else 0)
