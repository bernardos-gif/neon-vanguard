class_name HealthBar
extends Control
## Angled health bar with a delayed "recent damage" trail. Drawn entirely in
## code. The displayed value always comes from the live simulation.

var ratio := 1.0                 # actual health
var trail := 1.0                 # delayed damage trail
var mirrored := false            # player 2 bar drains toward the centre
var fill_color := Color(0.2, 0.9, 1.0)
var _trail_delay := 0.0
var _pulse := 0.0


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	if r < ratio - 0.0001:
		_trail_delay = 0.55
	elif r > ratio:
		trail = r
	ratio = r


func _process(delta: float) -> void:
	if _trail_delay > 0.0:
		_trail_delay -= delta
	elif trail > ratio:
		trail = maxf(ratio, trail - delta * 0.6)
	_pulse += delta
	queue_redraw()


func _bar_poly(x0: float, x1: float, h: float, skew: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0 + skew, 0), Vector2(x1 + skew, 0), Vector2(x1, h), Vector2(x0, h)])


func _draw() -> void:
	var w := size.x
	var h := size.y
	var skew := 16.0 if not mirrored else -16.0
	# Frame and background
	draw_colored_polygon(_bar_poly(-6, w + 6, h + 6, skew).duplicate(), Color(0, 0, 0, 0.55))
	draw_colored_polygon(_bar_poly(0, w, h, skew), Color(0.08, 0.06, 0.12, 0.9))
	var tw := w * trail
	var fw := w * ratio
	var low := ratio < 0.3
	var col := fill_color
	if low:
		col = col.lerp(Color(1.0, 0.25, 0.2), 0.5 + 0.5 * sin(_pulse * 8.0))
	if mirrored:
		if tw > 0.0:
			draw_colored_polygon(_bar_poly(w - tw, w, h, skew), Color(1.0, 0.25, 0.3, 0.9))
		if fw > 0.0:
			draw_colored_polygon(_bar_poly(w - fw, w, h, skew), col)
			draw_colored_polygon(_bar_poly(w - fw, w, h * 0.35, skew), Color(1, 1, 1, 0.25))
	else:
		if tw > 0.0:
			draw_colored_polygon(_bar_poly(0, tw, h, skew), Color(1.0, 0.25, 0.3, 0.9))
		if fw > 0.0:
			draw_colored_polygon(_bar_poly(0, fw, h, skew), col)
			draw_colored_polygon(_bar_poly(0, fw, h * 0.35, skew), Color(1, 1, 1, 0.25))
	var outline := _bar_poly(0, w, h, skew)
	outline.append(outline[0])
	draw_polyline(outline, Color(1, 1, 1, 0.55), 2.0)
