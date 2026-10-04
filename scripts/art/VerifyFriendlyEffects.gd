extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const ArcScript = preload("res://scripts/components/ArcPulseVisual.gd")
const LaserScript = preload("res://scripts/components/LaserBeam.gd")
const SpikeScript = preload("res://scripts/components/SpikeTrap.gd")
const FlameScript = preload("res://scripts/components/FlameTrail.gd")
const LockScript = preload("res://scripts/ui/DroneLockReticle.gd")
const VfxScript = preload("res://scripts/effects/CombatVfx.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const HazardScript = preload("res://scripts/components/TentacleAttack.gd")
const SOURCES := ["scripts/art/VerifyFriendlyEffects.gd", "scripts/tests/FriendlyEffectPaletteTest.gd", "scripts/actors/Player.gd", "scripts/components/ArcPulseVisual.gd", "scripts/components/LaserBeam.gd", "scripts/components/SpikeTrap.gd", "scripts/components/FlameTrail.gd", "scripts/components/Projectile.gd", "scripts/ui/DroneLockReticle.gd", "scripts/effects/CombatVfx.gd", "scripts/components/TentacleAttack.gd", "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png", "assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png", "assets/art/effects/combat_hit_chibi_b_v1.png"]

class Target extends Node2D:
	var damage := 0.0
	var hits := 0
	func take_damage(amount: float, _source: StringName, _direction: Vector2) -> void:
		damage += amount
		hits += 1

func _initialize() -> void:
	var run_id := OS.get_environment("FRIENDLY_EFFECTS_RUN_ID")
	var output := "res://build/diagnostics/friendly-effects/" + run_id
	if DisplayServer.get_name() == "headless" or run_id.is_empty() or not run_id.is_valid_filename() or DirAccess.dir_exists_absolute(output):
		push_error("Friendly capture needs native rendering and a fresh safe run ID")
		quit(1)
		return
	var hashes := {}
	var sources: Array[String] = []
	sources.assign(SOURCES)
	if FileAccess.file_exists("res://scripts/effects/FriendlyEffectPalette.gd"):
		sources.append("scripts/effects/FriendlyEffectPalette.gd")
	for path in sources:
		var frozen: String = output + "/source/" + path
		DirAccess.make_dir_recursive_absolute(frozen.get_base_dir())
		if DirAccess.copy_absolute("res://" + path, frozen) != OK:
			quit(1)
			return
		hashes[path] = FileAccess.get_sha256(frozen)
	await process_frame
	var mechanics := _measure_mechanics()
	var images: Array[Dictionary] = []
	for direction in range(4):
		for overdrive in [false, true]:
			var view := SubViewport.new()
			view.size = Vector2i(1280, 720)
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			view.world_2d = World2D.new()
			root.add_child(view)
			var background := ColorRect.new()
			background.size = Vector2(view.size)
			background.color = Color("9bd7bd").darkened(0.30)
			background.z_index = -100
			view.add_child(background)
			var player := PlayerScript.new()
			view.add_child(player)
			player.process_mode = Node.PROCESS_MODE_DISABLED
			player.position = Vector2(610, 350)
			player.gun_angle = direction * PI * 0.5
			player.velocity = Vector2(120, 0)
			player.arc_pulse_level = 2
			player.dash_active = true
			player.set_overdrive_active(overdrive)
			player.fired.connect(func(shot: Node2D) -> void:
				view.add_child(shot)
				shot.position = Vector2(710, 370)
				shot.process_mode = Node.PROCESS_MODE_DISABLED)
			player._spawn_bullet(Vector2.RIGHT)
			var arc := ArcScript.new()
			arc.setup(220.0)
			arc.age = 0.20
			_add_frozen(view, arc, player.position)
			var beam := LaserScript.new()
			view.add_child(beam)
			beam.setup(Vector2(660, 320), Vector2(820, 265), player.get_drone_laser_color(), 4.0)
			beam.process_mode = Node.PROCESS_MODE_DISABLED
			_add_frozen(view, LockScript.new(), Vector2(820, 265))
			_add_frozen(view, SpikeScript.new(), Vector2(410, 475))
			_add_frozen(view, FlameScript.new(), Vector2(490, 475))
			var hazard := HazardScript.new()
			view.add_child(hazard)
			hazard.position = Vector2(880, 350)
			hazard.attack_kind = hazard.AttackKind.SWEEP
			hazard.attack_stage = hazard.AttackStage.WARNING
			hazard.sweep_angle = PI
			hazard.process_mode = Node.PROCESS_MODE_DISABLED
			hazard._queue_visual_redraw()
			var vfx := VfxScript.new()
			view.add_child(vfx)
			for kind: StringName in [VfxScript.AFTERIMAGE, VfxScript.RING, VfxScript.BLAST, VfxScript.DEBRIS]:
				vfx.request_effect(kind, Vector2(470, 220), Vector2.RIGHT)
			vfx._process(0.04)
			vfx.process_mode = Node.PROCESS_MODE_DISABLED
			player.queue_redraw()
			for _frame in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var bitmap := view.get_texture().get_image()
			var path := output + "/direction-%d-%s.png" % [direction, "overdrive" if overdrive else "ordinary"]
			if bitmap == null or bitmap.is_empty() or bitmap.get_size() != view.size or bitmap.save_png(path) != OK:
				quit(1)
				return
			images.append({"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "direction": direction, "overdrive": overdrive, "viewport": [1280, 720]})
			view.free()
			await process_frame
	var valid := images.size() == 8 and mechanics.size() == 360
	for path: String in hashes:
		valid = valid and hashes[path] == FileAccess.get_sha256("res://" + path)
	var file := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"valid": valid, "images": images, "source_sha256": hashes, "mechanics": mechanics, "scope": "1280x720 four cardinal frozen component states; 360 manual component steps; no Main/natural input/stores/performance/human acceptance"}))
	file.close()
	await process_frame
	print("FRIENDLY CAPTURE: %s valid=%s images=%d steps=%d" % [run_id, valid, images.size(), mechanics.size()])
	quit(0 if valid else 1)

func _add_frozen(view: Node, effect: Node2D, position: Vector2) -> void:
	view.add_child(effect)
	effect.position = position
	effect.process_mode = Node.PROCESS_MODE_DISABLED
	effect.queue_redraw()

func _measure_mechanics() -> Array[Dictionary]:
	var fixture := Node2D.new()
	root.add_child(fixture)
	fixture.process_mode = Node.PROCESS_MODE_DISABLED
	var targets: Array[Node] = []
	for distance in [70, 140, 300]:
		var target := Target.new()
		fixture.add_child(target)
		target.position = Vector2(distance, 0)
		targets.append(target)
	var arc := ArcScript.new()
	fixture.add_child(arc)
	arc.setup(620, 20, func() -> Array[Node]: return targets, 0.5)
	var trap := SpikeScript.new()
	fixture.add_child(trap)
	var vfx := VfxScript.new()
	fixture.add_child(vfx)
	var records: Array[Dictionary] = []
	for step in range(360):
		if step % 30 == 0:
			for kind: StringName in [VfxScript.SPARK, VfxScript.RING, VfxScript.BLAST, VfxScript.DEBRIS, VfxScript.AFTERIMAGE]:
				vfx.request_effect(kind, Vector2(step % 120, 0), Vector2.RIGHT)
		if not arc.is_queued_for_deletion():
			arc._process(1.0 / 60)
		if not trap.is_queued_for_deletion():
			trap._process(1.0 / 60)
		vfx._process(1.0 / 60)
		var hits: Array = []
		for target in targets:
			hits.append([target.hits, target.damage])
		records.append({"step": step, "arc_radius": arc.get_current_radius(), "arc_age": arc.age, "arc_lifetime": arc.lifetime, "arc_hits": hits, "trap_lifetime": trap.lifetime, "trap_tick": trap.tick_timer, "trap_radius": trap.radius, "vfx_sparks": vfx._sparks.duplicate(true), "vfx_debris": vfx._debris.duplicate(true), "vfx_rings": vfx._rings.duplicate(true), "vfx_afterimages": vfx._afterimages.duplicate(true)})
	fixture.free()
	return records
