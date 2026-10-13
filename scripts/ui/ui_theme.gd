class_name UiTheme
extends RefCounted
## Shared visual style for all menus and the HUD.

const CYAN := Color(0.2, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.25, 0.8)
const AMBER := Color(1.0, 0.7, 0.25)
const INK := Color(0.03, 0.035, 0.07, 0.86)
const TEXT := Color(0.92, 0.95, 1.0)
const DIM := Color(0.6, 0.66, 0.78)

static var _theme: Theme
static var _title_font: Font
static var _bold_font: Font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/Orbitron-ExtraBold.ttf")
	return _title_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = load("res://assets/fonts/Rajdhani-Bold.ttf")
	return _bold_font


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	t.default_font_size = 30
	var normal := _box(Color(0.05, 0.06, 0.11, 0.78), Color(0.25, 0.3, 0.45, 0.6), 2)
	var hover := _box(Color(0.08, 0.12, 0.2, 0.9), CYAN, 2)
	var focus := _box(Color(0.1, 0.06, 0.16, 0.95), MAGENTA, 3)
	focus.shadow_color = Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.45)
	focus.shadow_size = 10
	var pressed := _box(Color(0.15, 0.05, 0.2, 1.0), MAGENTA, 3)
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("disabled", cls, normal)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_font("font", cls, bold_font())
		t.set_font_size("font_size", cls, 32)
	t.set_color("font_color", "Label", TEXT)
	var panel := _box(INK, Color(0.3, 0.35, 0.5, 0.5), 2)
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.14, 0.22)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grabber := _circle_tex(Color.WHITE, 22)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(MAGENTA, 26))
	var slider_focus := _box(Color(0, 0, 0, 0), MAGENTA, 2)
	t.set_stylebox("focus", "HSlider", slider_focus)
	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.border_width_left = width + 4
	s.skew = Vector2(0.18, 0)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func _circle_tex(color: Color, size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 30, color := TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


static func title_label(text: String, size: int, color := TEXT) -> Label:
	var l := label(text, size, color, title_font())
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 22)
	l.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.45))
	return l


static func button(text: String, callback: Callable, width := 420) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		AudioManager.play(&"ui_accept", -4.0, 0.0)
		callback.call())
	b.focus_entered.connect(func(): AudioManager.play(&"ui_move", -10.0, 0.0))
	return b
