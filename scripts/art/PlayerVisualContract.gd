extends RefCounted
class_name PlayerVisualContract

const CAMERA_PITCH_DEGREES := 45.0
const DIRECTION_COUNT := 24
const DIRECTION_STEP_DEGREES := 15.0
const ATLAS_COLUMNS := 6
const ATLAS_ROWS := 4
const FRAME_SIZE := Vector2i(64, 64)
const FRAME_PIVOT := Vector2(32.0, 32.0)
const LAYER_ORDER := ["weapon_behind", "body", "weapon_front"]

static func direction_index(angle_radians: float) -> int:
	var raw_index := roundi(rad_to_deg(angle_radians) / DIRECTION_STEP_DEGREES)
	return posmod(raw_index, DIRECTION_COUNT)

static func frame_rect(frame_index: int) -> Rect2i:
	var normalized := posmod(frame_index, DIRECTION_COUNT)
	var column := normalized % ATLAS_COLUMNS
	var row := floori(float(normalized) / float(ATLAS_COLUMNS))
	return Rect2i(Vector2i(column, row) * FRAME_SIZE, FRAME_SIZE)
