extends "res://scripts/art/RenderNativeMonsterSample.gd"

const Draft = preload("res://scenes/art/technical/RootlingDraft.gd")

func new_actor() -> Node2D:
	return Draft.new()

func output_path() -> String:
	return "res://docs/art/previews/campaign/rootling-paper-draft-v3.png"

func motion_path() -> String:
	return "res://build/diagnostics/campaign-goal/rootling-paper-motion-v3"

func subtitle() -> String:
	return "ORIGINAL ROOTLING DRAFT - one native weighted mesh - 12 joints - not gameplay/final art"

func enlargement() -> float:
	return 2.0

func first_row_y() -> float:
	return 250.0

func clip_label_y() -> float:
	return -170.0

func sample_name() -> String:
	return "RootlingDraft"
