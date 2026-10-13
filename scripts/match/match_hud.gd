class_name MatchHud
extends CanvasLayer
## In-match HUD. Every value shown (health, timer, rounds, combos) is read
## from the live CombatWorld / MatchFlow each frame.

var _bars: Array[HealthBar] = []
var _names: Array[Label] = []
var _tags: Array[Label] = []
var _pips: Array = [[], []]
var _combo_labels: Array[Label] = []
var _combo_sub: Array[Label] = []
var _combo_timer := [0.0, 0.0]
var _callouts: Array[Label] = []
var _timer_label: Label
var _announce: Label
var _announce_sub: Label
var _hint: Label
var _root: Control
var _rounds_to_win := 2


func build(names: Array, tags: Array, colors: Array, rounds_to_win: int) -> void:
	layer = 5
	_rounds_to_win = rounds_to_win
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	# Top gradient for legibility
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.custom_minimum_size = Vector2(0, 220)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	for i in 2:
		var bar := HealthBar.new()
		bar.mirrored = i == 1
		bar.fill_color = colors[i]
		bar.size = Vector2(740, 36)
		bar.position = Vector2(100, 56) if i == 0 else Vector2(1080, 56)
		if i == 1:
			bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			bar.offset_left = -840
			bar.offset_right = -100
			bar.offset_top = 56
			bar.offset_bottom = 92
		_root.add_child(bar)
		_bars.append(bar)
		var name_l := UiTheme.title_label(names[i], 34, colors[i])
		var tag_l := UiTheme.label(tags[i], 24, UiTheme.DIM, UiTheme.bold_font())
		if i == 0:
			name_l.position = Vector2(104, 100)
			tag_l.position = Vector2(104, 18)
		else:
			name_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			name_l.offset_left = -700
			name_l.offset_right = -104
			name_l.offset_top = 100
			tag_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag_l.offset_left = -400
			tag_l.offset_right = -104
			tag_l.offset_top = 18
		_root.add_child(name_l)
		_root.add_child(tag_l)
		_names.append(name_l)
		_tags.append(tag_l)
		# Round pips
		for r in rounds_to_win:
			var pip := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
			sb.border_color = Color(1, 1, 1, 0.6)
			sb.set_border_width_all(2)
			sb.skew = Vector2(0.3, 0)
			pip.add_theme_stylebox_override("panel", sb)
			pip.size = Vector2(30, 16)
			if i == 0:
				pip.position = Vector2(800 - r * 40, 104)
			else:
				pip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				pip.offset_left = -830 + r * 40
				pip.offset_right = pip.offset_left + 30
				pip.offset_top = 104
				pip.offset_bottom = 120
			_root.add_child(pip)
			_pips[i].append(sb)
		# Combo counter
		var combo := UiTheme.title_label("", 64, Color.WHITE)
		var sub := UiTheme.label("", 30, colors[i], UiTheme.bold_font())
		var call := UiTheme.title_label("", 34, UiTheme.AMBER)
		if i == 0:
			combo.position = Vector2(80, 300)
			sub.position = Vector2(84, 378)
			call.position = Vector2(84, 250)
		else:
			for c in [combo, sub, call]:
				c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				c.offset_left = -700
				c.offset_right = -80
			combo.offset_top = 300
			sub.offset_top = 378
			call.offset_top = 250
		_root.add_child(combo)
		_root.add_child(sub)
		_root.add_child(call)
		_combo_labels.append(combo)
		_combo_sub.append(sub)
		_callouts.append(call)
	# Timer
	var hex := Panel.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.04, 0.04, 0.08, 0.92)
	hsb.border_color = UiTheme.CYAN
	hsb.set_border_width_all(3)
	hsb.set_corner_radius_all(6)
	hsb.skew = Vector2(0.12, 0)
	hex.add_theme_stylebox_override("panel", hsb)
	hex.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hex.offset_left = -78
	hex.offset_right = 78
	hex.offset_top = 36
	hex.offset_bottom = 124
	_root.add_child(hex)
	_timer_label = UiTheme.title_label("99", 56)
	_timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hex.add_child(_timer_label)
	# Announcer
	_announce = UiTheme.title_label("", 120, Color.WHITE)
	_announce.set_anchors_preset(Control.PRESET_CENTER)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce.offset_left = -900
	_announce.offset_right = 900
	_announce.offset_top = -140
	_announce.offset_bottom = 40
	_announce.pivot_offset = Vector2(900, 90)
	_root.add_child(_announce)
	_announce_sub = UiTheme.label("", 40, UiTheme.AMBER, UiTheme.bold_font())
	_announce_sub.set_anchors_preset(Control.PRESET_CENTER)
	_announce_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_sub.offset_left = -900
	_announce_sub.offset_right = 900
	_announce_sub.offset_top = 50
	_announce_sub.offset_bottom = 110
	_root.add_child(_announce_sub)
	# Controls hint
	_hint = UiTheme.label("P1: A/D move  W jump  S crouch  ·  J/K/L light/medium/heavy  ·  I special (+direction)  ·  U throw  ·  hold back to block  ·  Esc pause", 22, Color(1, 1, 1, 0.55))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_left = -900
	_hint.offset_right = 900
	_hint.offset_top = -50
	_hint.offset_bottom = -16
	_root.add_child(_hint)
	_hint.visible = Settings.get_value("show_hints")


func update_state(flow: MatchFlow, world: CombatWorld, delta: float) -> void:
	for i in 2:
		var f: FighterSim = world.fighters[i]
		_bars[i].set_ratio(float(f.health) / f.data.max_health)
		for r in _pips[i].size():
			var sb: StyleBoxFlat = _pips[i][r]
			sb.bg_color = UiTheme.AMBER if flow.wins[i] > r else Color(0.1, 0.1, 0.15, 0.9)
		# Combo shown on the attacker's side, from the defender's counters.
		var victim: FighterSim = world.fighters[1 - i]
		if victim.combo_hits >= 2:
			_combo_labels[i].text = "%d HITS" % victim.combo_hits
			_combo_sub[i].text = "%d DAMAGE" % victim.combo_damage
			_combo_labels[i].modulate.a = 1.0
			_combo_sub[i].modulate.a = 1.0
			_combo_timer[i] = 1.2
		else:
			_combo_timer[i] = maxf(_combo_timer[i] - delta, 0.0)
			var a := clampf(_combo_timer[i] / 0.4, 0.0, 1.0)
			_combo_labels[i].modulate.a = a
			_combo_sub[i].modulate.a = a
		_callouts[i].modulate.a = maxf(_callouts[i].modulate.a - delta * 1.2, 0.0)
	var secs := flow.seconds_left()
	_timer_label.text = "%02d" % secs
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if secs <= 10 and flow.phase == MatchFlow.Phase.FIGHT else Color.WHITE)
	_hint.visible = Settings.get_value("show_hints") and flow.phase != MatchFlow.Phase.MATCH_END


func callout(player: int, text: String, color := UiTheme.AMBER) -> void:
	var l := _callouts[player]
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.modulate.a = 1.6


func announce(text: String, sub := "", color := Color.WHITE, hold := 1.2) -> void:
	_announce.text = text
	_announce.add_theme_color_override("font_color", color)
	_announce.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.5))
	_announce_sub.text = sub
	_announce.scale = Vector2(1.6, 1.6)
	_announce.modulate.a = 0.0
	_announce_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_announce, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_announce, "modulate:a", 1.0, 0.15)
	tw.tween_property(_announce_sub, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(hold)
	tw.chain().set_parallel(true)
	tw.tween_property(_announce, "modulate:a", 0.0, 0.3)
	tw.tween_property(_announce_sub, "modulate:a", 0.0, 0.3)


func set_visible_hud(v: bool) -> void:
	_root.visible = v
