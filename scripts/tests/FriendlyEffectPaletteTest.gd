extends SceneTree

const ArcScript = preload("res://scripts/components/ArcPulseVisual.gd")
const LaserScript = preload("res://scripts/components/LaserBeam.gd")
const LockScript = preload("res://scripts/ui/DroneLockReticle.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const ProjectileScript = preload("res://scripts/components/Projectile.gd")
const TEAL := Color("35b8ac")
const MINT := Color("9bd7bd")
const CREAM := Color("f3eddc")

var assertions := 0

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: FriendlyEffectPaletteTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var arc := ArcScript.new()
	var arc_color: Color = arc.tint
	arc.free()
	if not _check(arc_color.is_equal_approx(TEAL), "friendly pulse still uses the legacy neon color instead of approved teal"):
		return
	var beam := LaserScript.new()
	var beam_color: Color = beam.tint
	var beam_lifetime: float = beam.lifetime
	var beam_width: float = beam.width
	beam.free()
	if not _check(beam_color.is_equal_approx(TEAL) and is_equal_approx(beam_lifetime, 0.09) and is_equal_approx(beam_width, 3.0), "beam changed lifetime/width or kept legacy neon"):
		return
	if not _check(LockScript.RETICLE_COLOR.is_equal_approx(TEAL) and LockScript.INNER_COLOR.is_equal_approx(CREAM) and is_equal_approx(LockScript.RADIUS, 13.0), "friendly drone target uses hostile warning colors or changed its radius"):
		return
	if not _check(PlayerScript.BASE_DRONE_LASER_COLOR.is_equal_approx(TEAL) and PlayerScript.THUNDER_MATRIX_LASER_COLOR.is_equal_approx(MINT), "player-owned beams do not use normal teal / matrix mint"):
		return
	var projectile := ProjectileScript.new()
	var projectile_color: Color = projectile.tint
	var projectile_radius: float = projectile.radius
	var projectile_lifetime: float = projectile.lifetime
	projectile.free()
	if not _check(projectile_color.is_equal_approx(Color.CYAN) and is_equal_approx(projectile_radius, 4.0) and is_equal_approx(projectile_lifetime, 6.0), "shared projectile default or physical contract changed"):
		return
	print("TEST PASS: FriendlyEffectPaletteTest %d" % assertions)
	quit(0)
