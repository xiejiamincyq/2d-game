extends "BellPriestCrownDodgeTest.gd"
## Same ordinary body/input gates, but actual low-Health wider third-phase fan.
func _initialize() -> void:
	requested_phase = 3; test_name = "BellPriestCrownPhase3DodgeTest"
	super._initialize()
