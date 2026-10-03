extends RefCounted

# One reference for Boss AI, ranged enemies and the spawn director. Presentation
# camera motion must not feed back into these mechanics during Boss framing.
const REFERENCE_KEY := &"combat_navigation_reference"

class Reference extends RefCounted:
	var visible_rect: Rect2

static func attach(camera: Camera2D, reference: Reference) -> void:
	camera.set_meta(REFERENCE_KEY, reference)

static func detach(camera: Camera2D) -> void:
	if camera.has_meta(REFERENCE_KEY):
		camera.remove_meta(REFERENCE_KEY)

static func visible_rect(viewport: Viewport, fallback_center: Vector2) -> Rect2:
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(1280, 720)
	var camera := viewport.get_camera_2d() if viewport != null else null
	if camera == null:
		return Rect2(fallback_center - size * 0.5, size)
	if camera.has_meta(REFERENCE_KEY):
		var reference: Reference = camera.get_meta(REFERENCE_KEY)
		return reference.visible_rect
	var zoom := camera.zoom.abs()
	size /= Vector2(maxf(zoom.x, 0.001), maxf(zoom.y, 0.001))
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
