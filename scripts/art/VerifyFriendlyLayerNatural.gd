extends "res://scripts/art/VerifyNaturalRunRendered.gd"

const Arc = preload("res://scripts/components/ArcPulseVisual.gd")
const Laser = preload("res://scripts/components/LaserBeam.gd")
const Spike = preload("res://scripts/components/SpikeTrap.gd")
const Flame = preload("res://scripts/components/FlameTrail.gd")
const Vfx = preload("res://scripts/effects/CombatVfx.gd")
const Bullet = preload("res://scripts/components/Projectile.gd")
const Outline = preload("res://scripts/effects/PlayerOcclusionOutline.gd")
var layer_observations := {}

func _capture() -> void:
	if started > 0 and terminal.is_empty() and not reloading and is_instance_valid(scene) and is_instance_valid(scene.projectiles):
		var items: Array[Node] = scene.projectiles.get_children()
		if is_instance_valid(scene.combat_vfx) and scene.combat_vfx.get_total_effect_count() > 0:
			items.append(scene.combat_vfx)
		for item in items:
			var kind := ""
			if item is Arc:
				kind = "arc"
			elif item is Laser:
				kind = "laser"
			elif item is Spike:
				kind = "spike"
			elif item is Flame:
				kind = "flame"
			elif item is Vfx:
				kind = "combat_vfx"
			elif item is Bullet:
				kind = "shared_projectile"
			if kind.is_empty():
				continue
			if not layer_observations.has(kind):
				layer_observations[kind] = {"draw_observations": 0, "violations": 0, "first_step": samples.size(), "first_wave": scene.wave_director.wave_index + 1}
			var info: Dictionary = layer_observations[kind]
			info.draw_observations += 1
			var correct: bool = item.z_as_relative and _effective_z(item) > Outline.OUTLINE_Z_INDEX if kind == "shared_projectile" else not item.z_as_relative and _effective_z(item) == -1
			if not correct:
				info.violations += 1
				valid = false
			info.last_step = samples.size()
	super._capture()

func _effective_z(item: CanvasItem) -> int:
	var value := item.z_index
	while item.z_as_relative and item.get_parent() is CanvasItem:
		item = item.get_parent()
		value += item.z_index
	return value

func _source_hashes() -> Dictionary:
	var hashes := super._source_hashes()
	var path := "scripts/art/VerifyFriendlyLayerNatural.gd"
	hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func _finish() -> void:
	var file := FileAccess.open(capture_dir.trim_suffix("/") + "-layers.json", FileAccess.WRITE)
	if file == null:
		valid = false
	else:
		file.store_string(JSON.stringify({"process_id": OS.get_process_id(), "observations": layer_observations, "source_sha256": source_before, "scope": "Read-only actual Main-generated component observations before native frame readback; absence is missing coverage, counts are repeated live draw observations not unique instances or visibility proof."}, "\t"))
		file.close()
	await super._finish()
