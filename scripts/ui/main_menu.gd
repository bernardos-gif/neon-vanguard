extends Node3D
## Title screen: the rooftop stage with both fighters idling in the rain,
## a slow cinematic camera, and the main menu.

const STAGE_SCENE := preload("res://scenes/stages/neon_rooftop.tscn")

var _camera: Camera3D
var _t := 0.0
var _menu: VBoxContainer
var _overlay: Control
var _ui: Control


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	add_child(STAGE_SCENE.instantiate())
	var k := FighterView.new()
	add_child(k)
	k.setup(GameState.get_fighter(&"kairo"))
	k.position = Vector3(0.4, 0, 0)
	var v := FighterView.new()
	add_child(v)
	v.setup(GameState.get_fighter(&"vesper"))
	v.position = Vector3(2.2, 0, 0)
	v.rotation.y = PI
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 600.0
	add_child(_camera)
	_camera.current = true
	_build_ui()
	AudioManager.play_music("menu")
	AudioManager.play_ambient("rain")
	GameState.difficulty = Settings.get_value("default_difficulty")


func _process(delta: float) -> void:
	_t += delta
	var a := sin(_t * 0.12) * 0.35
	# Fighters sit right of centre so the menu on the left never covers them.
	_camera.position = Vector3(sin(a) * 6.0 - 1.0, 1.45 + sin(_t * 0.2) * 0.1, cos(a) * 6.0)
	_camera.look_at(Vector3(-1.0, 1.15, 0), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UiTheme.get_theme()
	layer.add_child(_ui)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.03, 0.85))
	g.set_color(1, Color(0.0, 0.0, 0.03, 0.0))
	gt.gradient = g
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(1100, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	var title := UiTheme.title_label("NEON\nVANGUARD", 118, Color.WHITE)
	title.add_theme_constant_override("line_spacing", -18)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.2, 0.8, 0.55))
	title.position = Vector2(140, 90)
	_ui.add_child(title)
	var sub := UiTheme.label("U N D E R G R O U N D   C H A M P I O N S H I P", 30, UiTheme.CYAN, UiTheme.bold_font())
	sub.position = Vector2(146, 400)
	_ui.add_child(sub)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	_menu.position = Vector2(140, 480)
	_ui.add_child(_menu)
	_menu.add_child(UiTheme.button("PLAY", _on_play))
	_menu.add_child(UiTheme.button("CHARACTER SELECT", func(): GameState.go_to(GameState.CHARACTER_SELECT)))
	_menu.add_child(UiTheme.button("CONTROLS", _open.bind("controls")))
	_menu.add_child(UiTheme.button("SETTINGS", _open.bind("settings")))
	_menu.add_child(UiTheme.button("QUIT", func(): get_tree().quit()))
	var foot := UiTheme.label("v%s  ·  first playable prototype  ·  keyboard: W/S + J  ·  gamepad: D-pad + A" % ProjectSettings.get_setting("application/config/version"), 22, UiTheme.DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 146
	foot.offset_top = -60
	foot.offset_bottom = -24
	foot.offset_right = 1400
	_ui.add_child(foot)
	var credit := UiTheme.label("Made with Godot Engine (MIT License), © Godot Engine contributors  ·  Fonts: Orbitron, Rajdhani (SIL OFL 1.1)", 18, Color(1, 1, 1, 0.4))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.offset_left = -1100
	credit.offset_right = -40
	credit.offset_top = -96
	credit.offset_bottom = -68
	_ui.add_child(credit)
	_focus_first.call_deferred()


func _focus_first() -> void:
	if is_inside_tree() and _menu.get_child_count() > 0:
		_menu.get_child(0).grab_focus()


func _on_play() -> void:
	# Quick match: Player 1 vs CPU with the current selections.
	GameState.mode = GameState.Mode.VS_CPU
	GameState.go_to(GameState.MATCH)


func _open(which: String) -> void:
	_overlay = SettingsMenu.new() if which == "settings" else ControlsPanel.new()
	_ui.add_child(_overlay)
	_overlay.closed.connect(func():
		_overlay = null
		_menu.get_child(3 if which == "settings" else 2).grab_focus())
