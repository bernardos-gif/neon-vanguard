extends SceneTree
## Development entry point for the full test suite:
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_all_tests.gd
## --fixed-fps 60 makes every rendered frame exactly one 60 Hz combat frame,
## so the scene tests run as fast as possible yet stay deterministic.


func _initialize() -> void:
	var suite: Node = load("res://tests/test_suite.gd").new()
	suite.name = "TestSuite"
	root.add_child.call_deferred(suite)
