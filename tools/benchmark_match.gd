extends SceneTree
## Measures CPU time of a CPU-vs-CPU match scene (game logic, simulation, AI,
## animation, effects). Rendering is NOT included when run headless.
##   godot --headless --path . --fixed-fps 60 --script res://tools/benchmark_match.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.mode = 2
	gs.p1_difficulty = 2
	gs.difficulty = 2
	gs.ai_seed = 99
	change_scene_to_file(gs.MATCH)
	for i in 5:
		await process_frame
	var times: Array[float] = []
	for i in 3600:
		var t0 := Time.get_ticks_usec()
		await physics_frame
		await process_frame
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	print("frames: %d  mean: %.3f ms  median: %.3f ms  p99: %.3f ms  max: %.3f ms" % [times.size(), total / times.size(), times[times.size() / 2], times[int(times.size() * 0.99)], times[-1]])
	quit()
