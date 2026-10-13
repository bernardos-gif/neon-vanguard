class_name OptionRow
extends Button
## A focusable "< VALUE >" selector. Left/right (keyboard, D-pad or stick)
## or clicking cycles through the options.

signal value_changed(index: int)

var caption := ""
var options: Array = []
var index := 0


func _init(p_caption := "", p_options: Array = [], p_index := 0) -> void:
	caption = p_caption
	options = p_options
	index = clampi(p_index, 0, maxi(options.size() - 1, 0))
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(640, 60)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	_refresh()
	focus_entered.connect(func(): AudioManager.play(&"ui_move", -10.0, 0.0))


func _pressed() -> void:
	cycle(1)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		cycle(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		cycle(1)
		accept_event()


func cycle(dir: int) -> void:
	if options.is_empty():
		return
	index = wrapi(index + dir, 0, options.size())
	_refresh()
	AudioManager.play(&"ui_move", -6.0, 0.0)
	value_changed.emit(index)


func set_index(i: int) -> void:
	index = clampi(i, 0, maxi(options.size() - 1, 0))
	_refresh()


func _refresh() -> void:
	var v: String = str(options[index]) if not options.is_empty() else ""
	text = "%s      <  %s  >" % [caption, v]
