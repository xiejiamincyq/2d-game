extends RefCounted
## New keyed poses for this player's actual anatomical views; no method tracks.
const LENGTHS := {"idle": 1.4, "walk": 0.6, "shoot": 0.16, "dash": 0.16, "hit": 0.22, "death": 0.55, "entrance": 0.72}

func make(rig: Skeleton2D, direction: String) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var sign_x := -1.0 if direction == "Left" else 1.0
	for clip in LENGTHS:
		var motion := Animation.new()
		motion.length = LENGTHS[clip]
		motion.loop_mode = Animation.LOOP_LINEAR if clip in ["idle", "walk"] else Animation.LOOP_NONE
		for bone: Bone2D in rig.find_children("*", "Bone2D", true, false):
			var path := "Skeleton2D/" + str(rig.get_path_to(bone))
			var positions: Array = []
			var rotations: Array = []
			for phase in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var at := bone.rest.origin
				var angle := bone.rest.get_rotation()
				var wave := sin(phase * TAU)
				var pulse := sin(phase * PI)
				if clip == "idle":
					if bone.name == &"Torso": at.y -= pulse * 0.7
					if bone.name == &"Head": angle += wave * 0.018
				elif clip == "walk":
					if bone.name == &"Torso": at.y -= absf(wave) * 1.2
					if str(bone.name).begins_with("Leg"):
						angle += wave * (0.24 if bone.name == &"LegL" else -0.24)
					if str(bone.name).begins_with("Foot"):
						at.y -= maxf(0, wave * (1 if bone.name == &"FootL" else -1)) * 2.4
					if bone.name == &"ArmL": angle -= wave * 0.16
				elif clip == "shoot":
					if bone.name == &"HandR": at -= Vector2.RIGHT.rotated(_angle(direction)) * pulse * 2.0
					if bone.name == &"ForearmR": angle += pulse * 0.08 * sign_x
					if bone.name == &"Head": angle -= pulse * 0.03 * sign_x
				elif clip == "dash":
					if bone.name == &"Torso": angle += pulse * 0.18 * sign_x; at.y += pulse * 2
					if bone.name == &"LegL": angle -= pulse * 0.55
					if bone.name == &"LegR": angle += pulse * 0.5
					if bone.name == &"ArmL": angle += pulse * 0.3 * sign_x
				elif clip == "hit":
					if bone.name == &"Torso": at.x -= pulse * 2 * sign_x; angle -= pulse * 0.13 * sign_x
					if bone.name == &"Head": angle += pulse * 0.12 * sign_x
				elif clip == "death":
					var ease := 1 - pow(1 - phase, 2)
					if bone.name == &"Torso": at.y += ease * 14; angle += ease * 0.85 * sign_x
					if bone.name == &"Head": angle -= ease * 0.3 * sign_x
					if str(bone.name).begins_with("Leg"): angle -= ease * 0.45 * sign_x
					if bone.name == &"ArmL": angle += ease * 0.7 * sign_x
				elif clip == "entrance":
					if bone.name == &"Torso": at.y += pulse * 3
					if str(bone.name).begins_with("Leg"): angle += pulse * (0.28 if bone.name == &"LegL" else -0.28)
				positions.append(at)
				rotations.append(angle)
			_track(motion, path + ":position", positions)
			_track(motion, path + ":rotation", rotations)
		library.add_animation(clip, motion)
	return library

func _angle(direction: String) -> float:
	return {"Front": PI / 2, "Back": -PI / 2, "Left": PI, "Right": 0.0}[direction]

func _track(motion: Animation, path: String, values: Array) -> void:
	var track := motion.add_track(Animation.TYPE_VALUE)
	motion.track_set_path(track, NodePath(path))
	for index in values.size():
		motion.track_insert_key(track, motion.length * index / (values.size() - 1), values[index])
