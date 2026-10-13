class_name FightCamera
extends Camera3D
## Side-on fighting camera. Keeps both fighters framed, zooms with their
## separation, follows jumps gently and applies short, controlled shake on
## impacts. A short cinematic sweep plays at the start of a match.

const STAGE_LIMIT := 4.0

var targets: Array[Node3D] = []
var shake_enabled := true
var _trauma := 0.0
var _center := Vector3(0, 1.3, 0)
var _dist := 7.5
var _intro_t := 1.0
var _focus_target: Node3D
var _focus_t := 0.0
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	fov = 38.0
	near = 0.05
	far = 600.0
	_noise.frequency = 2.0


func play_intro() -> void:
	_intro_t = 0.0


func focus_on(target: Node3D) -> void:
	_focus_target = target
	_focus_t = 0.0


func clear_focus() -> void:
	_focus_target = null


func add_trauma(amount: float) -> void:
	if shake_enabled:
		_trauma = clampf(_trauma + amount, 0.0, 1.0)


func snap_to_targets() -> void:
	_process(10.0)


func _process(delta: float) -> void:
	_time += delta
	if targets.size() < 2:
		return
	var a := targets[0].global_position
	var b := targets[1].global_position
	var mid := (a + b) * 0.5
	var sep := absf(a.x - b.x)
	var want_dist := clampf(4.4 + sep * 0.78, 6.2, 10.6)
	var want_center := Vector3(clampf(mid.x, -STAGE_LIMIT, STAGE_LIMIT), 1.25 + maxf(a.y, b.y) * 0.35, 0.0)
	if _focus_target:
		_focus_t = minf(_focus_t + delta * 0.6, 1.0)
		var f := _focus_target.global_position
		var e := smoothstep(0.0, 1.0, _focus_t)
		want_center = want_center.lerp(Vector3(f.x, 1.1, 0), e)
		want_dist = lerpf(want_dist, 4.2, e)
	var k := 1.0 - exp(-6.0 * delta)
	_center = _center.lerp(want_center, k)
	_dist = lerpf(_dist, want_dist, 1.0 - exp(-3.5 * delta))
	var pos := _center + Vector3(0, 0.35, _dist)
	var look := _center + Vector3(0, -0.15, 0)
	if _intro_t < 1.0:
		_intro_t = minf(_intro_t + delta * 0.45, 1.0)
		var e2 := smoothstep(0.0, 1.0, _intro_t)
		var orbit := lerpf(-0.75, 0.0, e2)
		var start := _center + Vector3(sin(orbit) * 4.5, -0.6, cos(orbit) * 4.5)
		pos = start.lerp(pos, e2)
	global_position = pos
	look_at(look, Vector3.UP)
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var shake := _trauma * _trauma
	h_offset = _noise.get_noise_2d(_time * 40.0, 0.0) * shake * 0.18
	v_offset = _noise.get_noise_2d(0.0, _time * 40.0) * shake * 0.14
