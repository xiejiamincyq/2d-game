extends "res://scripts/art/RenderNativeMonsterSample.gd"

const Actor = preload("res://scenes/actors/native/rootling_paper_v3.tscn")

func new_actor() -> Node2D:
	return Actor.instantiate()

func output_path() -> String:
	return "res://docs/art/previews/campaign/rootling-native-resource-v1.png"

func motion_path() -> String:
	return "res://build/diagnostics/campaign-goal/rootling-native-resource-motion-v1"

func subtitle() -> String:
	return "EDITABLE ORIGINAL RESOURCE - Skeleton2D / Polygon2D / external AnimationLibrary - not Main"

func enlargement() -> float:
	return 2.0

func first_row_y() -> float:
	return 250.0

func clip_label_y() -> float:
	return -170.0

func sample_name() -> String:
	return "RootlingNativeResource"

func pose_at(actor: Node2D, clip: String, seconds: float) -> void:
	# Laboratory sampling only: reset real joint poses, never revive an actor
	# through its production API. Playback/death/cancellation tests are separate.
	actor.player.stop()
	actor.player.clear_queue()
	for index in actor.skeleton.get_bone_count():
		actor.skeleton.get_bone(index).apply_rest()
	actor.get_node("Warning").visible = false
	actor.player.play(clip)
	actor.player.seek(seconds, true)
