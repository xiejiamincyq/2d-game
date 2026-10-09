extends "res://scripts/art/BenchmarkNativeMonsterSample.gd"

const Draft = preload("res://scenes/art/technical/RootlingDraft.gd")

func new_actor() -> Node2D:
	return Draft.new()

func output_path() -> String:
	return "res://build/diagnostics/campaign-goal/rootling-paper-density-v2.json"

func sample_name() -> String:
	return "RootlingDraft"
