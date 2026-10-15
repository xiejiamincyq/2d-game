extends SceneTree
## Real swept physics: widened page hits its new band, not a wider invisible area.
const Page = preload("res://scripts/components/ArchivePageProjectile.gd")
class Target extends CharacterBody2D:
	var hits := 0
	func _ready() -> void:
		add_to_group("player")
		var collider := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 16.9
		collider.shape = circle
		add_child(collider)
	func take_damage(_amount: float,_source: StringName = &"") -> void: hits += 1
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ArchivePageWidthTest "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for offset in [25.0,30.0]:
			var host := Node2D.new()
			root.add_child(host)
			var target := Target.new()
			target.position = Vector2(140,offset)
			host.add_child(target)
			await physics_frame
			await physics_frame
			var shot := Page.new()
			shot.world_bounds = Rect2(-600,-600,1200,1200)
			shot.collision_layer = 0
			shot.collision_mask = 1
			host.add_child(shot)
			check(shot.radius==10 and shot.sweep_shape.radius==10,"visual/physics width not doubled")
			check(shot.has_method("get_visual_hull"),"projectile visual has no shared radius geometry")
			if shot.has_method("get_visual_hull"):
				var hull: PackedVector2Array = shot.get_visual_hull()
				var widest := 0.0
				var highest := 0.0
				for point in hull:
					widest = maxf(widest,absf(point.x))
					highest = maxf(highest,absf(point.y))
					check(point.length()<=shot.radius+0.001,"art extends outside authoritative circle")
				check(is_equal_approx(widest,10) and highest>=8.5,"visible projectile footprint too thin")
			var deadline := Time.get_ticks_msec()+2500
			while is_instance_valid(shot) and Time.get_ticks_msec()<deadline: await physics_frame
			check(not is_instance_valid(shot),"projectile lifetime did not end")
			check(target.hits==(1 if offset==25 else 0),"%dHz width band %.0f has wrong real hit count"%[rate,offset])
			host.free()
			await process_frame
	Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: ArchivePageWidthTest %d"%checks)
	quit(1 if failures else 0)
