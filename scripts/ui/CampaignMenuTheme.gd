extends RefCounted

const INK := Color("142520")
const PAPER := Color("f3eddc")

static func box(fill: Color, border: Color, width := 3, padding := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(padding)
	style.set_corner_radius_all(3)
	return style

static func create() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC"])
	result.default_font = font
	result.default_font_size = 18
	result.set_stylebox("panel", "PanelContainer", box(PAPER, INK))
	result.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = {"normal": Color("d4d8b9"), "hover": Color("e7d19c"), "pressed": Color("bcc39e"), "disabled": Color("dedacb")}[state]
		result.set_stylebox(state, "Button", box(fill, INK, 2, 9))
		result.set_color("font_color" if state == "normal" else "font_%s_color" % state, "Button", INK)
	var focus := box(Color.TRANSPARENT, Color("8b492b"), 3, 0)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	result.set_stylebox("focus", "Button", focus)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_color", "CheckButton", INK)
	return result
