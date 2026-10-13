class_name PoseLibrary
extends RefCounted
## Key poses for the procedural fighter rigs. Angles are in degrees, rotating
## around the depth axis (the fighter faces +X): positive values swing a limb
## forward/up, negative values swing it back. Knees use negative values to
## bend the shin backwards.
##
## Keys: body (whole-body tilt), spine, chest, neck, sh_n/el_n (near arm
## shoulder/elbow), sh_f/el_f (far arm), hip_n/knee_n, hip_f/knee_f,
## shift (forward offset of the hips in metres), lift (extra height).

const KEYS := ["body", "spine", "chest", "neck", "sh_n", "el_n", "sh_f", "el_f",
	"hip_n", "knee_n", "hip_f", "knee_f", "shift", "lift"]

const ZERO := {
	"body": 0.0, "spine": 0.0, "chest": 0.0, "neck": 0.0,
	"sh_n": 0.0, "el_n": 0.0, "sh_f": 0.0, "el_f": 0.0,
	"hip_n": 0.0, "knee_n": 0.0, "hip_f": 0.0, "knee_f": 0.0,
	"shift": 0.0, "lift": 0.0,
}

const STANCE := {
	&"kairo": {"spine": -4.0, "chest": -6.0, "neck": 8.0, "sh_n": 50.0, "el_n": 95.0, "sh_f": 35.0, "el_f": 115.0,
		"hip_n": 22.0, "knee_n": -18.0, "hip_f": -14.0, "knee_f": -16.0},
	&"vesper": {"spine": -10.0, "chest": -6.0, "neck": 12.0, "sh_n": 30.0, "el_n": 75.0, "sh_f": 50.0, "el_f": 110.0,
		"hip_n": 26.0, "knee_n": -32.0, "hip_f": -18.0, "knee_f": -28.0},
}

const CROUCH := {"spine": -18.0, "chest": -8.0, "neck": 18.0, "sh_n": 45.0, "el_n": 100.0, "sh_f": 35.0, "el_f": 115.0,
	"hip_n": 75.0, "knee_n": -125.0, "hip_f": 30.0, "knee_f": -125.0}

const SHARED := {
	&"crouch": CROUCH,
	&"block": {"chest": 6.0, "neck": -4.0, "sh_n": 75.0, "el_n": 128.0, "sh_f": 66.0, "el_f": 135.0,
		"hip_n": 18.0, "knee_n": -22.0, "hip_f": -16.0, "knee_f": -18.0, "shift": -0.03},
	&"crouch_block": {"spine": -14.0, "chest": 4.0, "neck": 14.0, "sh_n": 78.0, "el_n": 128.0, "sh_f": 68.0, "el_f": 135.0,
		"hip_n": 75.0, "knee_n": -125.0, "hip_f": 30.0, "knee_f": -125.0},
	&"hit_high": {"body": 8.0, "spine": 14.0, "chest": 16.0, "neck": 30.0, "sh_n": 15.0, "el_n": 70.0, "sh_f": -12.0, "el_f": 60.0,
		"hip_n": 10.0, "knee_n": -14.0, "hip_f": -22.0, "knee_f": -10.0, "shift": -0.05},
	&"hit_low": {"spine": -26.0, "chest": -14.0, "neck": -10.0, "sh_n": 30.0, "el_n": 80.0, "sh_f": 20.0, "el_f": 90.0,
		"hip_n": 30.0, "knee_n": -40.0, "hip_f": 0.0, "knee_f": -40.0},
	&"air_hit": {"body": 35.0, "spine": 15.0, "chest": 10.0, "neck": 25.0, "sh_n": 120.0, "el_n": 40.0, "sh_f": 90.0, "el_f": 50.0,
		"hip_n": 30.0, "knee_n": -50.0, "hip_f": 10.0, "knee_f": -30.0},
	&"lying": {"body": 90.0, "spine": 4.0, "chest": 4.0, "neck": -10.0, "sh_n": 140.0, "el_n": 20.0, "sh_f": 100.0, "el_f": 30.0,
		"hip_n": 12.0, "knee_n": -25.0, "hip_f": 0.0, "knee_f": -6.0, "lift": 0.04},
	&"jump": {"spine": -10.0, "neck": 6.0, "sh_n": 70.0, "el_n": 110.0, "sh_f": 50.0, "el_f": 120.0,
		"hip_n": 70.0, "knee_n": -100.0, "hip_f": 40.0, "knee_f": -110.0},
	&"prejump": {"spine": -12.0, "sh_n": 40.0, "el_n": 100.0, "sh_f": 25.0, "el_f": 110.0,
		"hip_n": 45.0, "knee_n": -80.0, "hip_f": 25.0, "knee_f": -80.0},
	&"dash_f": {"body": -12.0, "spine": -10.0, "neck": 12.0, "sh_n": 50.0, "el_n": 100.0, "sh_f": 30.0, "el_f": 120.0,
		"hip_n": 45.0, "knee_n": -45.0, "hip_f": -35.0, "knee_f": -30.0},
	&"dash_b": {"body": 8.0, "spine": 4.0, "sh_n": 60.0, "el_n": 110.0, "sh_f": 40.0, "el_f": 120.0,
		"hip_n": -12.0, "knee_n": -45.0, "hip_f": 28.0, "knee_f": -20.0},
	&"air_w": {"spine": -12.0, "neck": 8.0, "sh_n": 60.0, "el_n": 120.0, "sh_f": 40.0, "el_f": 120.0,
		"hip_n": 80.0, "knee_n": -120.0, "hip_f": 50.0, "knee_f": -120.0},
	&"jlight": {"spine": -18.0, "chest": -10.0, "sh_n": 55.0, "el_n": 0.0, "sh_f": 40.0, "el_f": 120.0,
		"hip_n": 60.0, "knee_n": -110.0, "hip_f": 30.0, "knee_f": -100.0},
	&"jmedium": {"spine": -10.0, "sh_n": 60.0, "el_n": 110.0, "sh_f": 40.0, "el_f": 120.0,
		"hip_n": 105.0, "knee_n": -135.0, "hip_f": 10.0, "knee_f": -60.0},
	&"jheavy": {"body": -10.0, "spine": 10.0, "sh_n": 90.0, "el_n": 60.0, "sh_f": 20.0, "el_f": 80.0,
		"hip_n": 72.0, "knee_n": -5.0, "hip_f": 10.0, "knee_f": -90.0},
	&"throw_w": {"spine": -10.0, "chest": -14.0, "sh_n": 85.0, "el_n": 15.0, "sh_f": 80.0, "el_f": 25.0,
		"hip_n": 30.0, "knee_n": -28.0, "hip_f": -20.0, "knee_f": -15.0, "shift": 0.08},
	&"throw_reach": {"spine": -14.0, "chest": -18.0, "sh_n": 90.0, "el_n": 8.0, "sh_f": 88.0, "el_f": 12.0,
		"hip_n": 34.0, "knee_n": -30.0, "hip_f": -24.0, "knee_f": -12.0, "shift": 0.12},
	&"throw_lift": {"body": 10.0, "chest": 18.0, "neck": 10.0, "sh_n": 160.0, "el_n": 30.0, "sh_f": 150.0, "el_f": 40.0,
		"hip_n": 20.0, "knee_n": -30.0, "hip_f": -25.0, "knee_f": -15.0},
	&"throw_toss": {"body": -15.0, "spine": -20.0, "chest": -15.0, "sh_n": 70.0, "el_n": 10.0, "sh_f": 60.0, "el_f": 20.0,
		"hip_n": 40.0, "knee_n": -40.0, "hip_f": -30.0, "knee_f": -10.0},
	&"thrown": {"body": 20.0, "spine": 20.0, "chest": 15.0, "neck": 30.0, "sh_n": 100.0, "el_n": 50.0, "sh_f": 80.0, "el_f": 40.0,
		"hip_n": 20.0, "knee_n": -40.0, "hip_f": 5.0, "knee_f": -30.0, "lift": 0.15},
	&"crjab_w": {"spine": -18.0, "chest": -6.0, "neck": 18.0, "sh_n": 40.0, "el_n": 110.0, "sh_f": 35.0, "el_f": 115.0,
		"hip_n": 75.0, "knee_n": -125.0, "hip_f": 30.0, "knee_f": -125.0},
	&"crjab": {"spine": -20.0, "chest": -14.0, "neck": 20.0, "sh_n": 86.0, "el_n": 5.0, "sh_f": 35.0, "el_f": 115.0,
		"hip_n": 75.0, "knee_n": -125.0, "hip_f": 30.0, "knee_f": -125.0, "shift": 0.05},
	&"lowkick_w": {"spine": -14.0, "neck": 14.0, "sh_n": 45.0, "el_n": 100.0, "sh_f": 35.0, "el_f": 115.0,
		"hip_n": 60.0, "knee_n": -110.0, "hip_f": 35.0, "knee_f": -110.0},
	&"lowkick": {"spine": -12.0, "neck": 12.0, "sh_n": 45.0, "el_n": 100.0, "sh_f": 30.0, "el_f": 115.0,
		"hip_n": 62.0, "knee_n": -10.0, "hip_f": 35.0, "knee_f": -110.0},
	&"crflick_w": {"spine": -16.0, "neck": 16.0, "sh_n": 40.0, "el_n": 90.0, "sh_f": 45.0, "el_f": 110.0,
		"hip_n": 55.0, "knee_n": -120.0, "hip_f": 35.0, "knee_f": -115.0},
	&"crflick": {"spine": -16.0, "neck": 16.0, "sh_n": 40.0, "el_n": 90.0, "sh_f": 45.0, "el_f": 110.0,
		"hip_n": 70.0, "knee_n": -12.0, "hip_f": 35.0, "knee_f": -115.0},
	&"sweep_w": {"body": 8.0, "spine": -20.0, "neck": 18.0, "sh_n": 50.0, "el_n": 90.0, "sh_f": 10.0, "el_f": 40.0,
		"hip_n": 70.0, "knee_n": -130.0, "hip_f": 40.0, "knee_f": -125.0},
	&"sweep": {"body": 15.0, "spine": -25.0, "neck": 20.0, "sh_n": 60.0, "el_n": 60.0, "sh_f": -10.0, "el_f": 30.0,
		"hip_n": 84.0, "knee_n": -4.0, "hip_f": 45.0, "knee_f": -125.0},
}

const KAIRO := {
	&"jab_w": {"sh_n": 55.0, "el_n": 110.0, "chest": -2.0},
	&"jab": {"sh_n": 90.0, "el_n": 4.0, "chest": -14.0, "spine": -6.0, "sh_f": 30.0, "el_f": 125.0, "shift": 0.04},
	&"straight_w": {"sh_f": 15.0, "el_f": 130.0, "chest": 6.0, "hip_f": -20.0},
	&"straight": {"sh_f": 92.0, "el_f": 2.0, "chest": -22.0, "spine": -10.0, "sh_n": 30.0, "el_n": 110.0,
		"hip_f": -30.0, "knee_f": -5.0, "hip_n": 30.0, "knee_n": -25.0, "shift": 0.1},
	&"hikick_w": {"hip_n": 75.0, "knee_n": -110.0, "body": 6.0, "sh_n": 60.0, "el_n": 100.0},
	&"hikick": {"hip_n": 108.0, "knee_n": -6.0, "body": 18.0, "spine": 6.0, "sh_n": 20.0, "el_n": 90.0,
		"sh_f": 50.0, "el_f": 60.0, "hip_f": 0.0, "knee_f": -5.0},
	&"pulse_w": {"sh_n": -25.0, "el_n": 95.0, "sh_f": -30.0, "el_f": 95.0, "chest": 8.0, "hip_n": 30.0, "knee_n": -30.0},
	&"pulse": {"sh_n": 90.0, "el_n": 0.0, "sh_f": 86.0, "el_f": 4.0, "chest": -10.0, "hip_n": 35.0, "knee_n": -30.0, "shift": 0.08},
	&"comet_w": {"body": 6.0, "sh_n": 30.0, "el_n": 120.0, "sh_f": 20.0, "el_f": 120.0,
		"hip_n": 50.0, "knee_n": -80.0, "hip_f": 0.0, "knee_f": -60.0},
	&"comet": {"body": -20.0, "chest": -10.0, "sh_n": 70.0, "el_n": 100.0, "sh_f": 40.0, "el_f": 120.0,
		"hip_n": 100.0, "knee_n": -120.0, "hip_f": -25.0, "knee_f": -20.0},
	&"counter_w": {"sh_n": 100.0, "el_n": 60.0, "sh_f": 30.0, "el_f": 95.0, "chest": 6.0},
	&"counter": {"sh_n": 115.0, "el_n": 55.0, "sh_f": 30.0, "el_f": 95.0, "chest": 8.0, "neck": -5.0,
		"hip_n": 30.0, "knee_n": -35.0, "hip_f": -20.0, "knee_f": -30.0},
	&"riposte_w": {"sh_n": 40.0, "el_n": 120.0, "sh_f": 35.0, "el_f": 120.0, "chest": 10.0},
	&"riposte": {"body": -18.0, "sh_n": 95.0, "el_n": 0.0, "sh_f": 92.0, "el_f": 6.0,
		"hip_n": 40.0, "knee_n": -30.0, "hip_f": -40.0, "knee_f": -10.0, "shift": 0.15},
	&"victory": {"sh_n": 175.0, "el_n": 10.0, "sh_f": 30.0, "el_f": 120.0, "neck": 12.0, "chest": 4.0,
		"hip_n": 6.0, "knee_n": -4.0, "hip_f": -6.0, "knee_f": -4.0},
}

const VESPER := {
	&"snap_w": {"sh_n": 40.0, "el_n": 100.0},
	&"snap": {"sh_n": 88.0, "el_n": 3.0, "chest": -10.0, "shift": 0.03},
	&"hook_w": {"hip_n": 85.0, "knee_n": -120.0, "body": 5.0},
	&"hook": {"hip_n": 92.0, "knee_n": -25.0, "body": 14.0, "sh_n": 30.0, "el_n": 90.0, "sh_f": 60.0, "el_f": 70.0},
	&"spin_w": {"body": 10.0, "chest": 20.0, "hip_f": 40.0, "knee_f": -90.0, "sh_n": 70.0, "el_n": 60.0},
	&"spin": {"body": 25.0, "hip_f": 112.0, "knee_f": -5.0, "hip_n": -5.0, "knee_n": -10.0,
		"sh_n": 100.0, "el_n": 30.0, "sh_f": 20.0, "el_f": 60.0},
	&"flurry_a": {"sh_n": 90.0, "el_n": 5.0, "sh_f": 40.0, "el_f": 110.0, "chest": -12.0, "shift": 0.05},
	&"flurry_b": {"sh_f": 90.0, "el_f": 5.0, "sh_n": 40.0, "el_n": 110.0, "chest": -18.0, "shift": 0.07},
	&"ghost_w": {"body": -10.0, "spine": -10.0, "hip_n": 50.0, "knee_n": -90.0, "hip_f": 10.0, "knee_f": -80.0},
	&"ghost": {"body": 30.0, "spine": 0.0, "neck": -10.0, "sh_n": 30.0, "el_n": 80.0, "sh_f": -40.0, "el_f": 30.0,
		"hip_n": 75.0, "knee_n": -5.0, "hip_f": 40.0, "knee_f": -130.0},
	&"flip_w": {"spine": -12.0, "sh_n": 40.0, "el_n": 100.0, "sh_f": 25.0, "el_f": 110.0,
		"hip_n": 45.0, "knee_n": -80.0, "hip_f": 25.0, "knee_f": -80.0},
	&"flip": {"spine": -10.0, "sh_n": 70.0, "el_n": 110.0, "sh_f": 50.0, "el_f": 120.0,
		"hip_n": 85.0, "knee_n": -120.0, "hip_f": 70.0, "knee_f": -125.0},
	&"victory": {"sh_n": 120.0, "el_n": 60.0, "sh_f": 25.0, "el_f": 100.0, "chest": 8.0, "neck": 8.0,
		"hip_n": 15.0, "knee_n": -10.0, "hip_f": -15.0, "knee_f": 0.0},
}


static func stance(style: StringName) -> Dictionary:
	return _complete(STANCE.get(style, STANCE[&"kairo"]))


## Returns a full pose for `name`. Style-specific poses are merged on top of
## the style's stance, shared poses on top of the neutral zero pose.
static func get_pose(style: StringName, name: StringName) -> Dictionary:
	var own: Dictionary = (KAIRO if style == &"kairo" else VESPER)
	if own.has(name):
		var p := stance(style)
		p.merge(own[name], true)
		return p
	if SHARED.has(name):
		return _complete(SHARED[name])
	return stance(style)


static func _complete(partial: Dictionary) -> Dictionary:
	var p := ZERO.duplicate()
	p.merge(partial, true)
	return p


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in KEYS:
		out[k] = lerpf(a.get(k, 0.0), b.get(k, 0.0), t)
	return out
