extends SceneTree

const Player = preload("res://scripts/actors/Player.gd")
const Arc = preload("res://scripts/components/ArcPulseVisual.gd")
const Laser = preload("res://scripts/components/LaserBeam.gd")
const Spike = preload("res://scripts/components/SpikeTrap.gd")
const Outline = preload("res://scripts/art/PlayerOcclusionOutline.gd")
const Floor = preload("res://scripts/world/FloorGrid.gd")
const SOURCES := ["scripts/art/VerifyFriendlyOcclusion.gd", "scripts/actors/Player.gd", "scripts/components/ArcPulseVisual.gd", "scripts/components/LaserBeam.gd", "scripts/components/SpikeTrap.gd", "scripts/effects/FriendlyEffectPalette.gd", "scripts/art/PlayerOcclusionOutline.gd", "scripts/world/FloorGrid.gd", "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png", "assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png"]

func _initialize() -> void:
	var run := OS.get_environment("FRIENDLY_LAYER_RUN_ID")
	var output := "res://build/diagnostics/friendly-ground-layer/" + run
	if DisplayServer.get_name() == "headless" or run.is_empty() or not run.is_valid_filename() or DirAccess.dir_exists_absolute(output):
		push_error("Native capture requires a fresh safe run ID")
		quit(1)
		return
	var hashes := {}
	for path in SOURCES:
		var frozen: String = output + "/source/" + path
		DirAccess.make_dir_recursive_absolute(frozen.get_base_dir())
		if DirAccess.copy_absolute("res://" + path, frozen) != OK:
			quit(1)
			return
		hashes[path] = FileAccess.get_sha256(frozen)
	var states: Array[Dictionary] = []
	for direction in range(4):
		for overdrive in [false, true]:
			var view := SubViewport.new()
			view.size = Vector2i(1280, 720)
			view.transparent_bg = true
			view.world_2d = World2D.new()
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(view)
			var floor := Floor.new()
			view.add_child(floor)
			var player := Player.new()
			player.process_mode = Node.PROCESS_MODE_DISABLED
			view.add_child(player)
			player.position = Vector2(640, 360)
			player.gun_angle = direction * PI * 0.5
			player.set_overdrive_active(overdrive)
			player.queue_redraw()
			var prefix := "direction-%d-%s" % [direction, "overdrive" if overdrive else "ordinary"]
			var control := await capture(view, output + "/" + prefix + "-control.png")
			floor.hide()
			var mask := await capture(view, output + "/" + prefix + "-mask.png")
			floor.show()
			var shots := Node2D.new()
			shots.z_index = Outline.OUTLINE_Z_INDEX + 1
			shots.process_mode = Node.PROCESS_MODE_DISABLED
			view.add_child(shots)
			var arc := Arc.new()
			arc.setup(220, 20, Callable(), 0.5)
			arc.age = 0.04
			shots.add_child(arc)
			arc.position = player.position
			var spike := Spike.new()
			spike.radius = 52
			shots.add_child(spike)
			spike.position = player.position + Vector2(-6, -20)
			var beam := Laser.new()
			beam.persistent = true
			shots.add_child(beam)
			beam.setup(player.position + Vector2(-110, -16), player.position + Vector2(110, -16), player.get_drone_laser_color(), 6 if overdrive else 4)
			var overlay := await capture(view, output + "/" + prefix + "-overlap.png")
			if control == null or mask == null or overlay == null:
				quit(1)
				return
			var opaque := 0
			var changed := 0
			var outside_changes := 0
			for y in range(296, 424):
				for x in range(576, 704):
					var a := control.get_pixel(x, y)
					var b := overlay.get_pixel(x, y)
					var difference := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
					if mask.get_pixel(x, y).a >= 0.999:
						opaque += 1
						if difference > 1.01 / 255.0:
							changed += 1
					elif difference > 1.01 / 255.0:
						outside_changes += 1
			var images := {}
			for suffix: String in ["control", "mask", "overlap"]:
				var name := prefix + "-" + suffix + ".png"
				images[suffix] = {"file": name, "sha256": FileAccess.get_sha256(output + "/" + name)}
			states.append({"direction": direction, "cardinal": player.chibi_cardinal_index(player.gun_angle), "overdrive": overdrive, "opaque_pixels": opaque, "changed_opaque_pixels": changed, "outside_changed_pixels": outside_changes, "z": [arc.z_index, beam.z_index, spike.z_index], "absolute_z": [not arc.z_as_relative, not beam.z_as_relative, not spike.z_as_relative], "images": images})
			view.free()
			await process_frame
	var valid := states.size() == 8
	for path: String in hashes:
		valid = valid and hashes[path] == FileAccess.get_sha256("res://" + path)
	for state in states:
		valid = valid and state.opaque_pixels > 100 and state.outside_changed_pixels > 100
	var file := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"valid": valid, "process_id": OS.get_process_id(), "display": DisplayServer.get_name(), "source_sha256": hashes, "states": states, "scope": "Fixed actual player/components over actual floor; foreground container22; eight ordinary/overdrive cardinal poses, native control/alpha-mask/overlap. Not natural Main gameplay, dash, CombatVfx, human acceptance or complete source closure."}, "\t"))
	file.close()
	print("FRIENDLY OCCLUSION ", run, " valid=", valid, " states=", states.size())
	quit(0 if valid else 1)

func capture(view: SubViewport, path: String) -> Image:
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var bitmap := view.get_texture().get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.get_size() != view.size:
		return null
	bitmap.convert(Image.FORMAT_RGBA8)
	return bitmap if bitmap.save_png(path) == OK else null
