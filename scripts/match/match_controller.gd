extends Node3D
## Runs a match: owns the CombatWorld / MatchFlow simulation (stepped at a
## fixed 60 Hz in _physics_process), reads player / CPU input, and drives
## visuals, audio, camera and HUD from simulation events.
##
## Debug keys: F1 toggles hit/hurt box display.

const STAGE_SCENE := preload("res://scenes/stages/neon_rooftop.tscn")
const HIT_TRAUMA := [0.12, 0.2, 0.38, 0.45]

var world: CombatWorld
var flow: MatchFlow
var views: Array[FighterView] = []
var camera: FightCamera
var hud: MatchHud
var vfx: Vfx
var pause_menu: PauseMenu
var results: ResultsScreen
var datas: Array[FighterData] = []
var controllers: Array = [null, null]   # PlayerInputReader or CpuController
var _projectile_views := {}
var _match_over_handled := false
var _debug_draw: MeshInstance3D
var _debug_mesh: ImmediateMesh
var _debug_visible := false
var _accent_colors: Array[Color] = []


func _ready() -> void:
	Engine.time_scale = 1.0
	add_child(STAGE_SCENE.instantiate())
	datas = [GameState.get_fighter(GameState.p1_fighter), GameState.get_fighter(GameState.p2_fighter)]
	if datas[0] == null or datas[1] == null:
		push_error("Match: fighter data missing, returning to main menu.")
		GameState.go_to(GameState.MAIN_MENU)
		return
	world = CombatWorld.new(datas[0], datas[1])
	flow = MatchFlow.new(world, GameState.rounds_to_win, GameState.round_seconds)
	var mirror := datas[0].id == datas[1].id
	for i in 2:
		var v := FighterView.new()
		v.name = "Fighter%d" % (i + 1)
		add_child(v)
		v.setup(datas[i], world.fighters[i], mirror and i == 1)
		views.append(v)
		_accent_colors.append(datas[i].alt_accent_color if mirror and i == 1 else datas[i].accent_color)
	vfx = Vfx.new()
	add_child(vfx)
	camera = FightCamera.new()
	add_child(camera)
	camera.targets = [views[0], views[1]]
	camera.shake_enabled = Settings.get_value("screen_shake")
	camera.current = true
	_setup_controllers()
	hud = MatchHud.new()
	add_child(hud)
	var tags := _tags()
	var ui_colors := [datas[0].ui_color, datas[1].alt_accent_color if mirror else datas[1].ui_color]
	hud.build([datas[0].display_name, datas[1].display_name], tags, ui_colors, flow.rounds_to_win)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.restart_requested.connect(_restart)
	_build_debug_draw()
	Settings.changed.connect(_on_settings_changed)
	_handle_events(flow.start_match())
	for v in views:
		v.snap()
	camera.snap_to_targets()
	camera.play_intro()
	AudioManager.play_music("battle")
	AudioManager.play_ambient("rain")


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _tags() -> Array:
	match GameState.mode:
		GameState.Mode.VS_PLAYER:
			return ["PLAYER 1", "PLAYER 2"]
		GameState.Mode.CPU_VS_CPU:
			return ["CPU  " + GameState.DIFFICULTY_NAMES[GameState.p1_difficulty], "CPU  " + GameState.DIFFICULTY_NAMES[GameState.difficulty]]
	return ["PLAYER 1", "CPU  " + GameState.DIFFICULTY_NAMES[GameState.difficulty]]


func _setup_controllers() -> void:
	var seed := GameState.ai_seed
	match GameState.mode:
		GameState.Mode.VS_PLAYER:
			controllers = [PlayerInputReader.new(0), PlayerInputReader.new(1)]
		GameState.Mode.CPU_VS_CPU:
			controllers = [CpuController.new(GameState.get_ai_profile(GameState.p1_difficulty), 0, seed),
				CpuController.new(GameState.get_ai_profile(GameState.difficulty), 1, seed + 1 if seed != 0 else 0)]
		_:
			controllers = [PlayerInputReader.new(0), CpuController.new(GameState.get_ai_profile(GameState.difficulty), 1, seed)]


func _read_input(i: int) -> InputState:
	var c = controllers[i]
	if c is CpuController:
		return c.get_input(world)
	if c is PlayerInputReader:
		return c.read()
	return InputState.new()


# --------------------------------------------------------------------------
# Fixed-step simulation (60 Hz, independent of rendering frame rate)
# --------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if world == null:
		return
	var i0 := _read_input(0)
	var i1 := _read_input(1)
	var events := flow.tick(i0, i1)
	views[0].sim_ticked(world.fighters[1].pos.x)
	views[1].sim_ticked(world.fighters[0].pos.x)
	for id in _projectile_views:
		_projectile_views[id].sim_ticked()
	_handle_events(events)


func _process(delta: float) -> void:
	if flow == null:
		return
	hud.update_state(flow, world, delta)
	if _debug_visible:
		_redraw_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		_debug_visible = not _debug_visible
		_debug_draw.visible = _debug_visible


# --------------------------------------------------------------------------
# Events -> presentation
# --------------------------------------------------------------------------

func _to3(p: Vector2, z := 0.25) -> Vector3:
	return Vector3(p.x, p.y, z)


func _handle_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"attack_start":
				AudioManager.play(e["sound"], -8.0)
			"hit":
				_on_hit(e)
			"block":
				AudioManager.play(&"block", -3.0)
				vfx.hit(_to3(e["pos"]), Color(0.6, 0.8, 1.0), e["strength"], true)
				views[e["defender"]].flash(Color(0.5, 0.7, 1.0), 0.35)
				camera.add_trauma(0.08)
			"counter":
				AudioManager.play(&"counter", -2.0, 0.0)
				vfx.clash(_to3(e["pos"]), Color(0.4, 1.0, 1.0))
				hud.callout(e["fighter"], "STILL WATER!", UiTheme.CYAN)
				camera.add_trauma(0.3)
			"throw_start":
				AudioManager.play(&"whiff_heavy", -4.0)
			"throw_tech":
				AudioManager.play(&"tech", -2.0)
				vfx.clash(_to3(e["pos"]), Color(1.0, 1.0, 1.0))
				hud.callout(0, "THROW BREAK", Color.WHITE)
				hud.callout(1, "THROW BREAK", Color.WHITE)
			"projectile_spawn":
				var p: ProjectileSim = null
				for q in world.projectiles:
					if q.id == e["id"]:
						p = q
				if p:
					var pv := ProjectileView.new()
					add_child(pv)
					pv.setup(p, _accent_colors[e["fighter"]])
					_projectile_views[e["id"]] = pv
				AudioManager.play(&"projectile", -4.0)
			"projectile_end":
				if _projectile_views.has(e["id"]):
					_projectile_views[e["id"]].queue_free()
					_projectile_views.erase(e["id"])
				if e["impact"]:
					vfx.clash(_to3(e["pos"]), Color(0.4, 0.9, 1.0))
			"jump":
				AudioManager.play(&"jump", -14.0)
			"land":
				AudioManager.play(&"land", -14.0)
			"knockdown":
				AudioManager.play(&"knockdown", -4.0)
				var f: FighterSim = world.fighters[e["fighter"]]
				vfx.dust(Vector3(f.pos.x, 0.1, 0.0), 18)
				camera.add_trauma(0.2)
			"round_start":
				_clear_projectiles()
				for v in views:
					v.snap()
				var title := "FINAL ROUND" if e["final"] else "ROUND %d" % e["round"]
				hud.announce(title, "", UiTheme.AMBER, 0.9)
				AudioManager.play(&"round", -2.0, 0.0)
				camera.clear_focus()
				if e["round"] > 1:
					camera.play_intro()
			"fight":
				hud.announce("FIGHT!", "", UiTheme.MAGENTA, 0.5)
				AudioManager.play(&"fight", 0.0, 0.0)
			"round_over":
				_on_round_over(e)
			"victory_pose":
				camera.focus_on(views[e["fighter"]])
				AudioManager.play(&"victory", -6.0, 0.0)
			"match_over":
				_on_match_over(e)


func _on_hit(e: Dictionary) -> void:
	var strength: int = e["strength"]
	AudioManager.play(e["sound"], -1.0 if strength >= 2 else -3.0)
	var att: int = e["attacker"]
	var color := _accent_colors[att]
	vfx.hit(_to3(e["pos"]), color, strength)
	views[e["defender"]].flash(Color(1, 1, 1), 0.6)
	camera.add_trauma(HIT_TRAUMA[strength] + (0.1 if e["counter"] else 0.0))
	if e.get("throw", false):
		hud.callout(att, "THROW", Color.WHITE)
	elif e["counter"]:
		hud.callout(att, "COUNTER", UiTheme.AMBER)
	elif e["punish"]:
		hud.callout(att, "PUNISH", UiTheme.MAGENTA)


func _on_round_over(e: Dictionary) -> void:
	var w: int = e["winner"]
	match e["reason"]:
		"ko":
			hud.announce("K.O.", "PERFECT" if e["perfect"] else "", Color(1.0, 0.3, 0.3), 1.4)
			AudioManager.play(&"ko", 0.0, 0.0)
			camera.add_trauma(0.7)
			_slow_motion(0.3, 0.9)
		"double_ko":
			hud.announce("DOUBLE K.O.", "DRAW", Color(1.0, 0.3, 0.3), 1.4)
			AudioManager.play(&"ko", 0.0, 0.0)
			_slow_motion(0.3, 0.9)
		"timeout":
			var sub := "DRAW" if w < 0 else "%s WINS THE ROUND" % datas[w].display_name
			hud.announce("TIME", sub, UiTheme.AMBER, 1.4)
			AudioManager.play(&"round", 0.0, 0.0)


func _slow_motion(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _on_match_over(e: Dictionary) -> void:
	if _match_over_handled:
		return
	_match_over_handled = true
	pause_menu.enabled = false
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	results = ResultsScreen.new()
	add_child(results)
	results.show_results(flow, world, datas, GameState.mode, e["winner"])
	results.rematch_requested.connect(_restart)
	hud.set_visible_hud(false)


func _restart() -> void:
	GameState.go_to(GameState.MATCH)


func _clear_projectiles() -> void:
	for id in _projectile_views:
		_projectile_views[id].queue_free()
	_projectile_views.clear()


func _on_settings_changed() -> void:
	camera.shake_enabled = Settings.get_value("screen_shake")


# --------------------------------------------------------------------------
# Debug collision display (F1)
# --------------------------------------------------------------------------

func _build_debug_draw() -> void:
	_debug_mesh = ImmediateMesh.new()
	_debug_draw = MeshInstance3D.new()
	_debug_draw.mesh = _debug_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_debug_draw.material_override = m
	_debug_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_draw.visible = false
	add_child(_debug_draw)


func _rect_lines(r: Rect2, c: Color) -> void:
	var z := 0.6
	var pts := [Vector3(r.position.x, r.position.y, z), Vector3(r.end.x, r.position.y, z),
		Vector3(r.end.x, r.end.y, z), Vector3(r.position.x, r.end.y, z)]
	for i in 4:
		_debug_mesh.surface_set_color(c)
		_debug_mesh.surface_add_vertex(pts[i])
		_debug_mesh.surface_set_color(c)
		_debug_mesh.surface_add_vertex(pts[(i + 1) % 4])


func _redraw_debug() -> void:
	_debug_mesh.clear_surfaces()
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for f in world.fighters:
		_rect_lines(f.hurtbox(), Color(0.2, 1.0, 0.3) if not f.is_invulnerable() else Color(0.4, 0.4, 1.0))
		_rect_lines(Rect2(f.pos.x - f.half_width(), f.pos.y, f.half_width() * 2.0, 0.08), Color(1, 1, 0))
		if f.is_attacking() and f.attack.kind == AttackData.Kind.STRIKE and f.attack.is_active_frame(f.state_frame):
			_rect_lines(f.hitbox_for(f.attack), Color(1, 0.15, 0.15))
	for p in world.projectiles:
		_rect_lines(p.rect(), Color(1, 0.15, 0.15))
	_debug_mesh.surface_end()
