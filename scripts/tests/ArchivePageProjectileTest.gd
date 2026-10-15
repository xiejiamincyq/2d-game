extends SceneTree
## Real physical bodies/walls and swept page flight, not Boss/chapter victory.
const SOURCE := "res://scripts/components/ArchivePageProjectile.gd"
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var sources: Array[StringName] = []
	var stealth_active := false
	func _ready() -> void: add_to_group(&"player")
	func is_stealthed() -> bool: return stealth_active
	func take_damage(amount: float,source: StringName = &"") -> void:
		hits.append(amount); sources.append(source)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchivePageProjectileTest "+label)
func _initialize() -> void: call_deferred("run")
func shape(body: CollisionObject2D,radius: float) -> void:
	var collider := CollisionShape2D.new(); var circle := CircleShape2D.new()
	circle.radius = radius; collider.shape = circle; body.add_child(collider)
func wall(host: Node2D,at: Vector2,size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at
	var collider := CollisionShape2D.new(); var rectangle := RectangleShape2D.new()
	rectangle.size = size; collider.shape = rectangle; body.add_child(collider); host.add_child(body)
	return body
func fire(shots: Node2D,owner_body: CharacterBody2D,bounds: Rect2 = Rect2(-600,-600,1200,1200)) -> Node2D:
	var shot = load(SOURCE).new()
	shot.position = Vector2(20,0); shot.world_bounds = bounds; shot.collision_layer = 0; shot.collision_mask = 1
	shots.add_child(shot); shot.ignore_source(owner_body)
	return shot
func gone(shot: Node) -> bool:
	var deadline := Time.get_ticks_msec()+2500
	while is_instance_valid(shot) and Time.get_ticks_msec()<deadline: await physics_frame
	return not is_instance_valid(shot)
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"independent swept page projectile absent")
	if failures: quit(1); return
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var emitter := CharacterBody2D.new(); shape(emitter,56); host.add_child(emitter)
		var target := Target.new(); target.position = Vector2(200,0); shape(target,16.9); host.add_child(target)
		await physics_frame; await physics_frame
		var shot = fire(shots,emitter)
		check(shot.radius==10 and shot.damage==24 and shot.velocity==Vector2(420,0) and is_equal_approx(shot.lifetime,1.35),"page stats/footprint")
		check(shot.sweep_query.exclude.has(emitter.get_rid()),"source still intersects birth circle")
		check(await gone(shot),"open page never resolves")
		check(target.hits==[24.0] and target.sources==[&"archive_page"],"page damage missing/repeated/misclassified")
		target.hits.clear(); target.sources.clear()
		var barrier := wall(host,Vector2(100,0),Vector2(2,250))
		await physics_frame; await physics_frame
		shot = fire(shots,emitter)
		check(await gone(shot) and target.hits.is_empty(),"continuous page crosses 2px wall")
		barrier.free(); await physics_frame; await physics_frame
		shot = fire(shots,emitter,Rect2(-100,-100,200,200))
		check(await gone(shot) and target.hits.is_empty(),"page hits beyond whole-body world boundary")
		barrier = wall(host,Vector2(20,0),Vector2(12,120))
		await physics_frame; await physics_frame
		shot = fire(shots,emitter)
		check(await gone(shot) and target.hits.is_empty(),"overlapped birth penetrates obstacle")
		barrier.free(); await physics_frame; await physics_frame
		shot = fire(shots,emitter)
		shot.set_physics_process(false); shot.lifetime = 0.1
		shot._physics_process(1.0)
		check(shot.is_queued_for_deletion() and target.hits.is_empty() and shot.position.x<=62.001,"hitch flies past expired lifetime")
		shot._try_hit(target)
		check(target.hits.is_empty(),"queued page still accepts collision callback")
		await process_frame
		target.stealth_active = true; shot = fire(shots,emitter)
		check(await gone(shot) and target.hits.is_empty(),"page damages stealth target")
		target.stealth_active = false
		shot = fire(shots,emitter); shot.set_physics_process(false)
		host.remove_child(emitter)
		check(shot.is_queued_for_deletion() and not shot.visible,"departed source leaves live page")
		emitter.free(); await process_frame
		host.free(); await process_frame
	Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: ArchivePageProjectileTest %d" % checks)
	quit(1 if failures else 0)
