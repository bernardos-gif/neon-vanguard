extends Node3D
## Character select: choose mode, fighters, CPU difficulty and round rules.
## The selected fighters are shown as live 3D models with their bio.

const STAGE_SCENE := preload("res://scenes/stages/neon_rooftop.tscn")
const ROUND_OPTIONS := [1, 2, 3]       # rounds to win -> best of 1 / 3 / 5
const TIME_OPTIONS := [60, 99]

var _views: Array = [null, null]
var _cards: Array = []
var _mode_row: OptionRow
var _p_rows: Array[OptionRow] = []
var _diff_row: OptionRow
var _p1diff_row: OptionRow
var _first: Control
var _starting := false
var _camera: Camera3D
var _t := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	add_child(STAGE_SCENE.instantiate())
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.far = 600.0
	add_child(_camera)
	_camera.current = true
	_camera.position = Vector3(1.6, 1.4, 5.6)
	_camera.look_at(Vector3(1.6, 1.0, 0), Vector3.UP)
	_build_ui()
	for i in 2:
		_spawn_view(i)
	_refresh_cards()
	AudioManager.play_music("menu")
	AudioManager.play_ambient("rain")


func _process(delta: float) -> void:
	_t += delta
	_camera.position = Vector3(1.6 + sin(_t * 0.25) * 0.25, 1.4, 5.6)
	_camera.look_at(Vector3(1.6, 1.0, 0), Vector3.UP)


func _fighter_index(id: StringName) -> int:
	return maxi(0, GameState.FIGHTER_ORDER.find(id))


func _fighter_names() -> Array:
	var out := []
	for id in GameState.FIGHTER_ORDER:
		out.append(GameState.get_fighter(id).display_name)
	return out


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.03, 0.55)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(820, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.position = Vector2(80, 70)
	ui.add_child(v)
	v.add_child(UiTheme.title_label("SELECT FIGHTERS", 56, UiTheme.CYAN))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	v.add_child(spacer)
	_mode_row = OptionRow.new("Mode", ["PLAYER vs CPU", "PLAYER 1 vs PLAYER 2", "CPU vs CPU (watch)"], GameState.mode)
	_mode_row.value_changed.connect(func(i):
		GameState.mode = i
		_refresh_cards())
	v.add_child(_mode_row)
	var names := _fighter_names()
	for i in 2:
		var cur: StringName = GameState.p1_fighter if i == 0 else GameState.p2_fighter
		var row := OptionRow.new("Player %d fighter" % (i + 1), names, _fighter_index(cur))
		var idx := i
		row.value_changed.connect(func(n): _set_fighter(idx, n))
		v.add_child(row)
		_p_rows.append(row)
	_diff_row = OptionRow.new("CPU difficulty", GameState.DIFFICULTY_NAMES, GameState.difficulty)
	_diff_row.value_changed.connect(func(i): GameState.difficulty = i)
	v.add_child(_diff_row)
	_p1diff_row = OptionRow.new("CPU 1 difficulty (watch mode)", GameState.DIFFICULTY_NAMES, GameState.p1_difficulty)
	_p1diff_row.value_changed.connect(func(i): GameState.p1_difficulty = i)
	v.add_child(_p1diff_row)
	var rounds := OptionRow.new("Match length", ["BEST OF 1", "BEST OF 3", "BEST OF 5"], maxi(0, ROUND_OPTIONS.find(GameState.rounds_to_win)))
	rounds.value_changed.connect(func(i): GameState.rounds_to_win = ROUND_OPTIONS[i])
	v.add_child(rounds)
	var time := OptionRow.new("Round time", ["60 SECONDS", "99 SECONDS"], maxi(0, TIME_OPTIONS.find(GameState.round_seconds)))
	time.value_changed.connect(func(i): GameState.round_seconds = TIME_OPTIONS[i])
	v.add_child(time)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 14)
	v.add_child(spacer2)
	var fight := UiTheme.button("FIGHT!", _start)
	fight.add_theme_font_size_override("font_size", 40)
	v.add_child(fight)
	v.add_child(UiTheme.button("BACK", func(): GameState.go_to(GameState.MAIN_MENU)))
	_first = _mode_row
	# Fighter info cards
	for i in 2:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(500, 0)
		card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if i == 1 else Control.PRESET_BOTTOM_LEFT)
		if i == 0:
			card.offset_left = 880
			card.offset_right = 1380
		else:
			card.offset_left = -560
			card.offset_right = -60
		card.offset_top = -330
		card.offset_bottom = -40
		ui.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var tag := UiTheme.label("", 24, UiTheme.DIM, UiTheme.bold_font())
		var name_l := UiTheme.title_label("", 48)
		var title := UiTheme.label("", 28, UiTheme.AMBER, UiTheme.bold_font())
		var bio := UiTheme.label("", 24, UiTheme.TEXT)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD
		bio.custom_minimum_size = Vector2(440, 0)
		var style := UiTheme.label("", 22, UiTheme.DIM)
		style.autowrap_mode = TextServer.AUTOWRAP_WORD
		style.custom_minimum_size = Vector2(440, 0)
		for c in [tag, name_l, title, bio, style]:
			cv.add_child(c)
		_cards.append({"tag": tag, "name": name_l, "title": title, "bio": bio, "style": style})
	_first.call_deferred("grab_focus")


func _set_fighter(player: int, n: int) -> void:
	var id: StringName = GameState.FIGHTER_ORDER[n]
	if player == 0:
		GameState.p1_fighter = id
	else:
		GameState.p2_fighter = id
	_spawn_view(player)
	_refresh_cards()


func _spawn_view(player: int) -> void:
	if _views[player]:
		_views[player].queue_free()
	var id: StringName = GameState.p1_fighter if player == 0 else GameState.p2_fighter
	var view := FighterView.new()
	add_child(view)
	var mirror := player == 1 and GameState.p1_fighter == GameState.p2_fighter
	view.setup(GameState.get_fighter(id), null, mirror)
	view.position = Vector3(0.6 if player == 0 else 2.7, 0, 0)
	view.rotation.y = 0.0 if player == 0 else PI
	_views[player] = view
	# Re-colour P1's view too if a mirror match appears or disappears.
	if player == 0 and _views[1]:
		_spawn_view(1)


func _refresh_cards() -> void:
	var tags := ["PLAYER 1", "CPU"]
	match GameState.mode:
		GameState.Mode.VS_PLAYER:
			tags = ["PLAYER 1", "PLAYER 2"]
		GameState.Mode.CPU_VS_CPU:
			tags = ["CPU 1", "CPU 2"]
	for i in 2:
		var d := GameState.get_fighter(GameState.p1_fighter if i == 0 else GameState.p2_fighter)
		var c: Dictionary = _cards[i]
		c["tag"].text = tags[i]
		c["name"].text = d.display_name
		c["name"].add_theme_color_override("font_color", d.ui_color)
		c["title"].text = d.title.to_upper()
		c["bio"].text = d.bio
		c["style"].text = d.style_summary
	_diff_row.disabled = GameState.mode == GameState.Mode.VS_PLAYER
	_p1diff_row.visible = GameState.mode == GameState.Mode.CPU_VS_CPU


func _start() -> void:
	if _starting:
		return
	_starting = true
	for v in _views:
		if v:
			v.showcase_pose = &"victory"
	AudioManager.play(&"fight", -4.0, 0.0)
	await get_tree().create_timer(0.7).timeout
	GameState.go_to(GameState.MATCH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameState.go_to(GameState.MAIN_MENU)
