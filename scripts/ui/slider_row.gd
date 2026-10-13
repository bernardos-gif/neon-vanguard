class_name SliderRow
extends HBoxContainer
## Caption + slider + percentage, used for volume settings.

signal value_changed(value: float)

var slider: HSlider
var _value_label: Label


func _init(caption: String, value: float) -> void:
	add_theme_constant_override("separation", 24)
	var l := UiTheme.label(caption, 30)
	l.custom_minimum_size = Vector2(260, 0)
	add_child(l)
	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	add_child(slider)
	_value_label = UiTheme.label("", 28, UiTheme.DIM)
	_value_label.custom_minimum_size = Vector2(80, 0)
	add_child(_value_label)
	_update_label(value)
	slider.value_changed.connect(func(v):
		_update_label(v)
		value_changed.emit(v))


func _update_label(v: float) -> void:
	_value_label.text = "%d%%" % int(round(v * 100.0))
