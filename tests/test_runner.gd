extends Node
## Scene entry point for the full test suite. Works in the editor and in an
## exported build:
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
##   ./NeonVanguard.x86_64 --headless --fixed-fps 60 res://tests/test_runner.tscn


func _ready() -> void:
	var suite: Node = load("res://tests/test_suite.gd").new()
	suite.name = "TestSuite"
	get_tree().root.add_child.call_deferred(suite)
