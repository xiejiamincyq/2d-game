extends Node2D
## Original quiet off-map paper. Render only: no input, physics or navigation.
const PALETTES := [Color("243b30"),Color("303637"),Color("35494b"),Color("253b3a"),Color("302b3b"),Color("202b40")]
var bounds := Rect2()
var paper_color := Color()

static func install(map: Node2D, area: Rect2, chapter: int) -> void:
	var backdrop := map.get_node_or_null("MapBackdrop")
	if backdrop == null:
		backdrop = load("res://scripts/world/ChapterMapBackdrop.gd").new()
		backdrop.name = "MapBackdrop"
		map.add_child(backdrop)
	backdrop.configure(area,chapter)

func configure(area: Rect2, chapter: int) -> void:
	bounds=area
	paper_color=PALETTES[chapter-1]
	z_index=-101 # Original floor remains -100, therefore untouched and on top.
	process_mode=Node.PROCESS_MODE_DISABLED
	var canvas := get_node_or_null("OutsidePaper")
	if canvas == null:
		canvas=CanvasLayer.new()
		canvas.name="OutsidePaper"
		canvas.layer=-20
		add_child(canvas)
		var fill := ColorRect.new()
		fill.name="Fill"
		fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
		canvas.add_child(fill)
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.get_node("Fill").color=paper_color
	queue_redraw()

func _draw() -> void:
	# A low-contrast closed lip makes the non-walkable edge explicit. Floor on
	# top hides its inner half; no paths, holes or hazard symbols painted outside.
	draw_rect(bounds.grow(24),paper_color.lightened(0.10),false,10)
	draw_rect(bounds.grow(9),paper_color.darkened(0.18),false,12)
