extends SceneTree
## Fast logic-only test entry point (no scenes):
##   godot --headless --path . --script res://tests/logic_runner.gd

func _initialize() -> void:
	var t := CombatTests.new()
	t.run_all()
	print("\nLogic tests: %d passed, %d failed" % [t.passed, t.failed])
	for f in t.failures:
		print("  - ", f)
	quit(0 if t.failed == 0 else 1)
