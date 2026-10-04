extends "res://scripts/art/VerifyNaturalRunRendered.gd"

const Arc = preload("res://scripts/components/ArcPulseVisual.gd")
const Laser = preload("res://scripts/components/LaserBeam.gd")
const Spike = preload("res://scripts/components/SpikeTrap.gd")
const Bullet = preload("res://scripts/components/Projectile.gd")
const Outline = preload("res://scripts/art/PlayerOcclusionOutline.gd")
var layer_observations := {}

func _capture() -> void:
	if started > 0 and terminal.is_empty() and not reloading and is_instance_valid(scene) and is_instance_valid(scene.projectiles):
		for item in scene.projectiles.get_children():
			var kind := ""
			if item is Arc:
				kind = "arc"
			elif item is Laser:
				kind = "laser"
			elif item is Spike:
				kind = "spike"
			elif item is Bullet:
				kind = "shared_projectile"
			if kind.is_empty():
				continue
			if not layer_observations.has(kind):
				layer_observations[kind] = {"draw_observations": 0, "violations": 0, "first_step": samples.size(), "first_wave": scene.wave_director.wave_index + 1}
			var info: Dictionary = layer_observations[kind]
			info.draw_observations += 1
			var correct: bool = item.z_as_relative and scene.projectiles.z_index > Outline.OUTLINE_Z_INDEX if kind == "shared_projectile" else not item.z_as_relative and item.z_index == -1
			if not correct:
				info.violations += 1
				valid = false
			info.last_step = samples.size()
	super._capture()

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
