extends Node
## Full automated test suite: combat logic tests + headless scene tests.
## Lives directly under the root window so it survives scene changes.
## Entry points: tests/test_runner.tscn (works in editor and exported builds)
## and tests/run_all_tests.gd (--script). See TESTING.md.

# Autoloads are looked up at runtime (they are not compile-time globals
# for a --script entry point).
var _gs: Node
var _settings: Node
var _failures: Array[String] = []
var _passed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failures.append(msg)
		push_error("SCENE TEST FAILURE: " + msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _run() -> void:
	_gs = get_tree().root.get_node("GameState")
	_settings = get_tree().root.get_node("Settings")
	print("== Combat logic tests ==")
	var t := CombatTests.new()
	t.run_all()
	print("Logic tests: %d passed, %d failed" % [t.passed, t.failed])
	for f in t.failures:
		_failures.append("[logic] " + f)

	print("\n== Scene tests ==")
	await _test_autoloads()
	await _test_main_menu()
	await _test_character_select()
	await _test_settings_overlay()
	await _test_cpu_match_completes()
	await _test_player_input_and_pause()
	await _test_versus_mode_routing()
	await _test_return_to_menu()

	print("\nScene checks passed: %d" % _passed)
	if _failures.is_empty():
		print("ALL TESTS PASSED (%d logic tests, %d scene checks)" % [t.passed, _passed])
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  - ", f)
	Engine.time_scale = 1.0
	get_tree().paused = false
	# Silence audio and let the mixer release its voices before quitting.
	var am := _autoload("AudioManager")
	am.stop_music()
	am.stop_ambient()
	for p in am._players:
		p.stop()
	get_tree().unload_current_scene()
	await _frames(10)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _autoload(name: String) -> Node:
	return get_tree().root.get_node_or_null(name)


func _test_autoloads() -> void:
	for n in ["InputConfig", "AudioManager", "Settings", "GameState"]:
		_check(_autoload(n) != null, "autoload %s missing" % n)
	for a in ["p1_light", "p1_left", "p2_heavy", "pause"]:
		_check(InputMap.has_action(a), "input action %s missing" % a)
	_check(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "audio buses missing")
	var am := _autoload("AudioManager")
	_check(am.sfx.size() >= 20, "sound library incomplete (%d sounds)" % am.sfx.size())
	# Wait for the music thread to finish generating loops.
	for i in 600:
		if am.music_streams.size() >= 2:
			break
		await get_tree().process_frame
	_check(am.music_streams.size() >= 2, "music loops were not generated")
	print("  autoloads, input map, audio: ok")


func _change(path: String) -> Node:
	var err := get_tree().change_scene_to_file(path)
	_check(err == OK, "could not change scene to " + path)
	await _frames(3)
	return get_tree().current_scene


func _test_main_menu() -> void:
	var scene := await _change("res://scenes/ui/main_menu.tscn")
	_check(scene != null and scene.name == "MainMenu", "main menu did not load")
	await _frames(60)
	var buttons := _find_buttons(scene)
	var texts := buttons.map(func(b): return b.text)
	for expected in ["PLAY", "CHARACTER SELECT", "CONTROLS", "SETTINGS", "QUIT"]:
		_check(expected in texts, "main menu button %s missing" % expected)
	_check(scene.get_viewport().gui_get_focus_owner() != null, "main menu has no keyboard/gamepad focus")
	print("  main menu: ok (%s)" % ", ".join(texts))


func _test_character_select() -> void:
	var scene := await _change("res://scenes/ui/character_select.tscn")
	_check(scene != null and scene.name == "CharacterSelect", "character select did not load")
	await _frames(30)
	var rows: Array = []
	for b in _find_buttons(scene):
		if b.has_method("cycle"):
			rows.append(b)
	_check(rows.size() >= 6, "character select option rows missing")
	# Cycle player 1's fighter and back; check GameState follows.
	var p1row = rows[1]
	var before: StringName = _gs.p1_fighter
	p1row.cycle(1)
	await _frames(5)
	_check(_gs.p1_fighter != before, "changing P1 fighter did not update GameState")
	p1row.cycle(1)
	await _frames(5)
	_check(_gs.p1_fighter == before, "fighter selection did not cycle back")
	print("  character select: ok")


func _test_settings_overlay() -> void:
	var scene := await _change("res://scenes/ui/main_menu.tscn")
	var settings: Control = load("res://scripts/ui/settings_menu.gd").new()
	scene.add_child(settings)
	await _frames(5)
	var old_q: int = _settings.quality()
	_settings.set_value("quality", 0)
	await _frames(3)
	_check(scene.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "LOW quality did not disable MSAA")
	_settings.set_value("quality", 3)
	await _frames(3)
	_check(scene.get_viewport().msaa_3d == Viewport.MSAA_4X, "ULTRA quality did not enable 4x MSAA")
	_settings.set_value("quality", old_q)
	var old_vol: float = _settings.get_value("music_volume")
	_settings.set_value("music_volume", 0.25)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	_check(absf(db - linear_to_db(0.25)) < 0.01, "music volume not applied to bus")
	_settings.set_value("music_volume", old_vol)
	settings.close()
	await _frames(3)
	print("  settings: ok")


func _match_scene() -> Node:
	return get_tree().current_scene


func _test_cpu_match_completes() -> void:
	_gs.mode = 2
	_gs.p1_fighter = &"kairo"
	_gs.p2_fighter = &"vesper"
	_gs.p1_difficulty = 2
	_gs.difficulty = 2
	_gs.rounds_to_win = 2
	_gs.round_seconds = 99
	_gs.ai_seed = 4242
	var scene := await _change(_gs.MATCH)
	_check(scene != null and scene.name == "Match", "match scene did not load")
	var flow: MatchFlow = scene.flow
	_check(flow != null and flow.round_number == 1, "match did not start round 1")
	var limit := 99 * 60 * 5 + 3000
	var frames := 0
	var saw_fight := false
	while scene.results == null and frames < limit:
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
		if flow.phase == MatchFlow.Phase.FIGHT:
			saw_fight = true
		# Views must follow the simulation.
		if frames % 120 == 0:
			for i in 2:
				var v: FighterView = scene.views[i]
				var f: FighterSim = scene.world.fighters[i]
				if absf(v.position.x - f.pos.x) > 0.6:
					_check(false, "fighter view drifted from simulation (%f vs %f)" % [v.position.x, f.pos.x])
	_check(saw_fight, "match never reached the FIGHT phase")
	_check(flow.phase == MatchFlow.Phase.MATCH_END, "CPU vs CPU match did not finish in %d frames" % frames)
	_check(scene.results != null, "results screen was not shown")
	_check(Engine.time_scale == 1.0, "time scale not restored after KO slow motion")
	print("  full CPU vs CPU match in match scene: ok (%d frames, winner P%d, rounds %s)" % [frames, flow.match_winner + 1, str(flow.round_results)])
	# Rematch twice to make sure repeated scene reloads are stable.
	for r in 2:
		scene.results.rematch_requested.emit()
		await _frames(4)
		scene = get_tree().current_scene
		_check(scene != null and scene.name == "Match" and scene.flow.round_number == 1 and scene.flow.wins == [0, 0], "rematch %d did not start a fresh match" % (r + 1))
		await _frames(150)
		_check(scene.flow.phase == MatchFlow.Phase.FIGHT, "rematch %d did not reach FIGHT" % (r + 1))
		scene.flow.match_winner = 0
		scene._on_match_over({"winner": 0})
		await _frames(70)
		_check(scene.results != null, "rematch %d results did not appear" % (r + 1))
	print("  rematch x2: ok")


func _test_player_input_and_pause() -> void:
	_gs.mode = 0
	_gs.ai_seed = 77
	var scene := await _change(_gs.MATCH)
	await _frames(MatchFlow.INTRO_FRAMES + 5)
	_check(scene.flow.phase == MatchFlow.Phase.FIGHT, "VS CPU match did not reach FIGHT")
	var p1: FighterSim = scene.world.fighters[0]
	var attacks_before := p1.stat_attacks
	Input.action_press("p1_light")
	await _frames(2)
	Input.action_release("p1_light")
	await _frames(20)
	_check(p1.stat_attacks == attacks_before + 1, "keyboard action p1_light did not start exactly one attack (%d)" % (p1.stat_attacks - attacks_before))
	var walked := false
	Input.action_press("p1_left")
	for i in 20:
		await _frames(1)
		if p1.state == FighterSim.State.WALK and p1.vel.x < 0.0:
			walked = true
	Input.action_release("p1_left")
	_check(walked, "p1_left did not make the fighter walk")
	# Pause freezes the simulation.
	scene.pause_menu.pause()
	var f0: int = scene.world.frame
	await _frames(30)
	_check(scene.world.frame == f0, "simulation advanced while paused")
	scene.pause_menu.resume()
	await _frames(5)
	_check(scene.world.frame > f0, "simulation did not resume after unpause")
	print("  keyboard input pipeline + pause/resume: ok")


func _test_versus_mode_routing() -> void:
	_gs.mode = 1
	var scene := await _change(_gs.MATCH)
	await _frames(MatchFlow.INTRO_FRAMES + 5)
	var p1: FighterSim = scene.world.fighters[0]
	var p2: FighterSim = scene.world.fighters[1]
	var a1 := p1.stat_attacks
	var a2 := p2.stat_attacks
	Input.action_press("p2_heavy")
	await _frames(2)
	Input.action_release("p2_heavy")
	await _frames(40)
	_check(p2.stat_attacks == a2 + 1, "P2 heavy did not make P2 attack")
	_check(p1.stat_attacks == a1, "P2's input also controlled P1 (input routing bug)")
	Input.action_press("p1_medium")
	await _frames(2)
	Input.action_release("p1_medium")
	await _frames(40)
	_check(p1.stat_attacks == a1 + 1, "P1 medium did not make P1 attack")
	_check(p2.stat_attacks == a2 + 1, "P1's input also controlled P2 (input routing bug)")
	print("  local versus input routing: ok")


func _test_return_to_menu() -> void:
	_gs.go_to(_gs.MAIN_MENU)
	await _frames(5)
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu", "returning to the main menu failed")
	_check(not get_tree().paused and Engine.time_scale == 1.0, "game left paused or slowed after returning to menu")
	print("  return to main menu: ok")


func _find_buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_find_buttons(c))
	return out
