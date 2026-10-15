extends SceneTree
## Real map receivers and physical actor, controlled ordinary attack clocks.
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Scrapper=preload("res://scripts/components/ScrapperAttack.gd")
const Crab=preload("res://scripts/components/CrabPincerAttack.gd")
const Mote=preload("res://scripts/components/MotePulseAttack.gd")
const Shade=preload("res://scripts/components/ShadeAmbushAttack.gd")
const Echo=preload("res://scripts/components/EchoRingAttack.gd")
const Cut=preload("res://scripts/components/SpaceCutAttack.gd")
const Elite=preload("res://scripts/components/EliteHybridAttack.gd")
const Charge=preload("res://scripts/components/CinderChargeAttack.gd")
const Enemy=preload("res://scripts/actors/Enemy.gd")
const Trap=preload("res://scripts/world/ReusableStepTrap.gd")
const Lob=preload("res://scripts/components/LobbedProjectile.gd")
class Actor extends CharacterBody2D:
	var body_radius:=14.0
	var contact_damage:=12.0
	var is_attacking:=false
	var is_fragment:=false
	func _ready() -> void:
		var collision:=CollisionShape2D.new(); var shape:=CircleShape2D.new(); shape.radius=body_radius
		collision.shape=shape; add_child(collision)
	func _clamp_to_world_bounds() -> void: pass
class Target extends Node2D:
	var hits:=0
	func take_damage(_amount: float) -> bool: hits+=1; return false
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: EnemyTerrainAttackTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func run() -> void:
	for chapter in range(1,7): await map_case(chapter)
	await cancel_in_damage()
	await pressure_receivers()
	if failures==0: print("TEST PASS: EnemyTerrainAttackTest %d"%checks)
	quit(1 if failures else 0)
func map_case(chapter: int) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	var wall: Node2D=map.layout.get_child(0); var rect: Rect2=wall.get_damage_rect()
	var actor:=Actor.new(); actor.position=Vector2(rect.position.x-30,rect.get_center().y); host.add_child(actor)
	var target:=Target.new(); target.position=actor.position+Vector2(42,0); host.add_child(target)
	await tick(); await tick()
	for source in [Scrapper,Crab,Mote,Shade,Echo,Cut,Elite,Charge]:
		var attack=source.new(); var hp: float=wall.health.current_health
		actor.position=Vector2(rect.position.x-30,rect.get_center().y)
		target.position=actor.position+Vector2(42,0)
		if source==Charge: target.position=actor.position+Vector2(120,0)
		await tick(); await tick()
		if source==Charge:
			attack.cooldown=0; attack.tick(actor,target,0.001)
		else:
			if source in [Cut,Elite]: attack.cooldown=0; attack.consider(actor,target,0)
			else: attack.begin(actor,target,0)
			attack.resolve_hit(actor,target)
		check(wall.health.current_health==hp,"chapter%d %s warning harmless"%[chapter,source.resource_path.get_file()])
		if source==Charge: attack.tick(actor,target,0.46)
		else:
			attack.advance(attack.get_warning_duration()+minf(0.10,attack.get_active_duration()/2))
			attack.resolve_hit(actor,target); attack.resolve_hit(actor,target)
		check(is_equal_approx(wall.health.current_health,hp-12),"chapter%d %s actual attack hits wall once"%[chapter,source.resource_path.get_file()])
		attack.cancel()
		if source==Charge: attack.tick(actor,target,0.001)
		else: attack.resolve_hit(actor,target)
		check(is_equal_approx(wall.health.current_health,hp-12),"chapter%d %s cancellation never repeats terrain damage"%[chapter,source.resource_path.get_file()])
	var ordinary:=Enemy.new(); ordinary.setup(Enemy.EnemyKind.SCRAPPER,0,host,target)
	ordinary.position=Vector2(rect.position.x-30,rect.get_center().y); host.add_child(ordinary)
	ordinary.set_physics_process(false); actor.collision_layer=0
	target.position=ordinary.position+Vector2(25,0)
	await tick(); await tick()
	var hp: float=wall.health.current_health
	ordinary._update_melee_attack(0.01,target,25)
	check(wall.health.current_health==hp,"chapter%d ordinary melee warning harmless"%chapter)
	ordinary._update_melee_attack(ordinary.attack_windup,target,25)
	check(is_equal_approx(wall.health.current_health,hp-ordinary.contact_damage),"chapter%d ordinary close melee damages terrain once"%chapter)
	var lob:=Lob.new(); host.add_child(lob); lob.set_physics_process(false)
	lob.damage=9; lob.configure(actor.position,Vector2(rect.position.x-71,rect.get_center().y),target)
	hp=wall.health.current_health; lob._explode(); lob._explode()
	check(is_equal_approx(wall.health.current_health,hp-9),"chapter%d airborne lob blast grazes wall face exactly once"%chapter)
	check(not wall.is_in_group(&"enemies"),"chapter%d terrain remains outside clear/kill groups"%chapter)
	host.free(); await process_frame
func cancel_in_damage() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var actor:=Actor.new(); actor.position=Vector2(-30,0); host.add_child(actor)
	var target:=Target.new(); target.position=Vector2(20,0); host.add_child(target)
	var a:=Trap.new(); var b:=Trap.new(); host.add_child(a); host.add_child(b)
	var attack:=Scrapper.new(); attack.begin(actor,target,0)
	a.health.health_changed.connect(func(_current,_maximum): attack.cancel())
	b.health.health_changed.connect(func(_current,_maximum): attack.cancel())
	await tick(); await tick()
	attack.advance(attack.get_warning_duration()+0.02); attack.resolve_hit(actor,target)
	check(is_equal_approx(a.health.current_health+b.health.current_health,148),"controller cancellation in first terrain callback stops remaining receivers")
	host.free(); await process_frame
func pressure_receivers() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var actor:=Actor.new(); actor.position=Vector2(-30,0); host.add_child(actor)
	var target:=Target.new(); target.position=Vector2(12,0); host.add_child(target)
	var plate:=Trap.new(); host.add_child(plate)
	await tick(); await tick()
	for source in [Scrapper,Crab,Mote,Shade,Echo,Cut,Elite,Charge]:
		var attack=source.new(); plate.health.current_health=80
		actor.position=Vector2(-30,0); target.position=Vector2(12,0)
		if source==Charge: target.position=Vector2(90,0)
		if source==Charge: attack.cooldown=0; attack.tick(actor,target,0.001)
		else:
			if source in [Cut,Elite]: attack.cooldown=0; attack.consider(actor,target,0)
			else: attack.begin(actor,target,0)
			attack.resolve_hit(actor,target)
		check(plate.health.current_health==80,"%s does not hurt Area in warning"%source.resource_path.get_file())
		if source==Charge: attack.tick(actor,target,0.46); attack.tick(actor,target,0.02)
		else:
			attack.advance(attack.get_warning_duration()+minf(0.1,attack.get_active_duration()/2))
			attack.resolve_hit(actor,target); attack.resolve_hit(actor,target)
		check(plate.health.current_health==68,"%s hits physical pressure Area exactly once"%source.resource_path.get_file())
	for source in [Scrapper,Shade]:
		var attack=source.new(); plate.health.current_health=80; actor.position=Vector2(-30,0); target.position=Vector2(90,0)
		attack.begin(actor,target,1); attack.advance(attack.get_warning_duration()+0.03)
		actor.move_and_collide(attack.get_velocity()*0.03)
		attack.resolve_hit(actor,target); attack.resolve_hit(actor,target)
		check(plate.health.current_health==68,"%s pounce damages only actual contact circle"%source.resource_path.get_file())
	actor.is_fragment=true; actor.position=Vector2(-45,0); target.position=Vector2(0,0); plate.health.current_health=80
	var fragment:=Mote.new(); fragment.begin(actor,target,0); fragment.advance(fragment.get_warning_duration()+0.03); fragment.resolve_hit(actor,target)
	check(plate.health.current_health==80,"fragment pulse keeps28px reach instead of copying full-size46px pulse")
	host.free(); await process_frame
