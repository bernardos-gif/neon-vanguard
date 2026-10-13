extends Node
## Player settings: audio volumes, display, graphics quality and gameplay
## options. Saved to user://settings.cfg and applied immediately.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "ULTRA"]
const FPS_LIMITS := [0, 60, 120, 144]

var values := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.85,
	"ambient_volume": 0.6,
	"fullscreen": false,
	"vsync": true,
	"fps_limit_index": 0,
	"quality": 2,
	"screen_shake": true,
	"show_hints": true,
	"default_difficulty": 1,
}


func _ready() -> void:
	load_settings()
	apply()


func get_value(key: String) -> Variant:
	return values.get(key)


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	apply()
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in values.keys():
		if cfg.has_section_key("settings", key):
			var v: Variant = cfg.get_value("settings", key)
			if typeof(v) == typeof(values[key]) or (typeof(values[key]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[key] = v


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values.keys():
		cfg.set_value("settings", key, values[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [PATH, err])


func apply() -> void:
	_set_bus("Master", values["master_volume"])
	_set_bus("Music", values["music_volume"])
	_set_bus("SFX", values["sfx_volume"])
	_set_bus("Ambient", values["ambient_volume"])
	if DisplayServer.get_name() != "headless":
		var want_full: bool = values["fullscreen"]
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_full and not is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not want_full and is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[clampi(values["fps_limit_index"], 0, FPS_LIMITS.size() - 1)]
	_apply_viewport_quality()
	changed.emit()


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func quality() -> int:
	return clampi(values["quality"], 0, 3)


func _apply_viewport_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match quality():
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 0.8
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 1.0
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		3:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.directional_shadow_atlas_set_size(4096, false)
