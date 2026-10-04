extends SceneTree

const Arc = preload("res://scripts/components/ArcPulseVisual.gd")
const Laser = preload("res://scripts/components/LaserBeam.gd")
const Spike = preload("res://scripts/components/SpikeTrap.gd")
const Flame = preload("res://scripts/components/FlameTrail.gd")
const Vfx = preload("res://scripts/effects/CombatVfx.gd")
const Projectile = preload("res://scripts/components/Projectile.gd")
const Outline = preload("res://scripts/art/PlayerOcclusionOutline.gd")
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: FriendlyEffectLayerTest: " + message)

func effective_z(item: CanvasItem) -> int:
	var value := item.z_index
	var parent := item.get_parent() as CanvasItem
	var relative := item.z_as_relative
	while relative and parent != null:
		value += parent.z_index
		relative = parent.z_as_relative
		parent = parent.get_parent() as CanvasItem
	return value

func _initialize() -> void:
	for settings in [[0, 22, true], [7, 50, true], [7, 50, false]]:
		var ancestor := Node2D.new()
		ancestor.z_index = settings[0]
		root.add_child(ancestor)
		var shots := Node2D.new()
		shots.z_index = settings[1]
		shots.z_as_relative = settings[2]
		shots.process_mode = Node.PROCESS_MODE_DISABLED
		ancestor.add_child(shots)
		var arc := Arc.new()
		arc.setup(220, 20, Callable(), 0.5)
		shots.add_child(arc)
		var beam := Laser.new()
		beam.persistent = true
		shots.add_child(beam)
		beam.setup(Vector2(10, 20), Vector2(200, 40), Color.WHITE, 6)
		var spike := Spike.new()
		spike.radius = 52
		spike.damage = 24
		shots.add_child(spike)
		var flame := Flame.new()
		shots.add_child(flame)
		var vfx := Vfx.new()
		shots.add_child(vfx)
		vfx.request_effect(Vfx.SPARK, Vector2.ZERO)
		var bullet := Projectile.new()
		shots.add_child(bullet)
		await process_frame
		for effect in [arc, beam, spike, flame, vfx]:
			print("FRIENDLY EFFECT LAYER ", effect.get_script().resource_path, " effective_z=", effective_z(effect))
			check(effective_z(effect) == -1 and not effect.z_as_relative, "friendly effect must stay absolute ground -1 regardless of foreground ancestors")
		check(effective_z(bullet) == effective_z(shots) and effective_z(bullet) > Outline.OUTLINE_Z_INDEX, "shared live projectile must remain above player contour")
		check(arc.max_radius == 220 and arc.damage == 20 and arc.get_expansion_speed() == 170, "arc mechanics changed with rendering layer")
		check(beam.end_local == Vector2(190, 20) and beam.width == 6 and beam.persistent, "beam ray endpoint/width/lifetime mode changed")
		var collisions := spike.get_children().filter(func(child: Node) -> bool: return child is CollisionShape2D)
		check(collisions.size() == 1 and collisions[0].shape is CircleShape2D and collisions[0].shape.radius == 52 and spike.damage == 24, "spike damage or collision radius changed")
		var flame_shapes := flame.get_children().filter(func(child: Node) -> bool: return child is CollisionShape2D)
		check(flame_shapes.size() == 1 and flame_shapes[0].shape.radius == 22 and flame.STACK_INTERVAL == 0.20 and flame.lifetime == 4, "flame collision or burn timing changed")
		check(vfx.get_effect_count(Vfx.SPARK) == 1 and vfx._sparks[0].textured, "ground layering suppressed hit feedback records")
		ancestor.free()
		await process_frame
	print("TEST %s: FriendlyEffectLayerTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
