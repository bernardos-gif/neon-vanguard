class_name ResultsScreen
extends CanvasLayer
## Victory / defeat screen with match statistics and next actions.

signal rematch_requested

var _first: Button


func show_results(flow: MatchFlow, world: CombatWorld, datas: Array, mode: int, winner: int) -> void:
	layer = 15
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.03, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var headline := ""
	var color := Color.WHITE
	if winner < 0:
		headline = "DRAW GAME"
		color = UiTheme.AMBER
	elif mode == GameState.Mode.VS_CPU:
		headline = "VICTORY" if winner == 0 else "DEFEAT"
		color = UiTheme.CYAN if winner == 0 else Color(1.0, 0.3, 0.35)
	else:
		headline = "PLAYER %d WINS" % (winner + 1) if mode == GameState.Mode.VS_PLAYER else "CPU %d WINS" % (winner + 1)
		color = datas[winner].ui_color
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.position = Vector2(120, 140)
	root.add_child(v)
	var title := UiTheme.title_label(headline, 110, color)
	v.add_child(title)
	if winner >= 0:
		v.add_child(UiTheme.label("%s  -  %s" % [datas[winner].display_name, datas[winner].title], 40, UiTheme.TEXT, UiTheme.bold_font()))
	var secs := int(flow.fight_frames / 60)
	v.add_child(UiTheme.label("Match time %d:%02d   ·   Rounds %d-%d" % [secs / 60, secs % 60, flow.wins[0], flow.wins[1]], 30, UiTheme.DIM))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	grid.add_child(UiTheme.label("", 28))
	for i in 2:
		grid.add_child(UiTheme.label(datas[i].display_name, 30, datas[i].ui_color, UiTheme.bold_font()))
	var rows := [
		["Rounds won", flow.wins[0], flow.wins[1]],
		["Damage dealt", world.fighters[0].stat_damage_dealt, world.fighters[1].stat_damage_dealt],
		["Hits landed", world.fighters[0].stat_hits, world.fighters[1].stat_hits],
		["Best combo", world.fighters[0].stat_max_combo, world.fighters[1].stat_max_combo],
		["Attacks blocked", world.fighters[0].stat_blocks, world.fighters[1].stat_blocks],
	]
	for r in rows:
		grid.add_child(UiTheme.label(r[0], 28, UiTheme.DIM))
		grid.add_child(UiTheme.label(str(r[1]), 28))
		grid.add_child(UiTheme.label(str(r[2]), 28))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	v.add_child(spacer)
	_first = UiTheme.button("REMATCH", func(): rematch_requested.emit())
	v.add_child(_first)
	v.add_child(UiTheme.button("CHARACTER SELECT", func(): GameState.go_to(GameState.CHARACTER_SELECT)))
	v.add_child(UiTheme.button("MAIN MENU", func(): GameState.go_to(GameState.MAIN_MENU)))
	title.modulate.a = 0.0
	title.scale = Vector2(1.3, 1.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title, "modulate:a", 1.0, 0.35)
	tw.tween_property(title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_first.grab_focus()
