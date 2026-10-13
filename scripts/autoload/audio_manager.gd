extends Node
## Audio buses, sound-effect playback and music. All sounds are synthesised
## by SfxSynth; music is generated on a background thread so start-up stays
## responsive.

const BUSES := ["Music", "SFX", "Ambient"]
const VOICES := 12

var sfx: Dictionary = {}
var music_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _wanted_music := ""
var _thread: Thread
var _music_lock := Mutex.new()
var _pending_music: Dictionary = {}


func _enter_tree() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	add_child(_ambient_player)
	sfx = SfxSynth.build_library()
	sfx["rain"] = SfxSynth.to_wav(SfxSynth.rain_loop(4.0), true)
	_thread = Thread.new()
	_thread.start(_generate_music)


func _generate_music() -> void:
	var menu := SfxSynth.music_loop(0)
	_music_lock.lock()
	_pending_music["menu"] = menu
	_music_lock.unlock()
	var battle := SfxSynth.music_loop(1)
	_music_lock.lock()
	_pending_music["battle"] = battle
	_music_lock.unlock()


func _process(_delta: float) -> void:
	if _pending_music.is_empty():
		return
	_music_lock.lock()
	for key in _pending_music.keys():
		music_streams[key] = SfxSynth.to_wav(_pending_music[key], true)
	_pending_music.clear()
	_music_lock.unlock()
	if _wanted_music != "" and music_streams.has(_wanted_music) and _music_player.stream != music_streams[_wanted_music]:
		_start_music(_wanted_music)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	for p in _players:
		p.stop()
		p.stream = null
	_music_player.stop()
	_music_player.stream = null
	_ambient_player.stop()
	_ambient_player.stream = null


func play(name: StringName, volume_db := 0.0, pitch_variation := 0.06) -> void:
	var stream: AudioStream = sfx.get(String(name))
	if stream == null:
		return
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


func play_music(name: String) -> void:
	_wanted_music = name
	if music_streams.has(name):
		_start_music(name)


func _start_music(name: String) -> void:
	if _music_player.stream == music_streams[name] and _music_player.playing:
		return
	_music_player.stream = music_streams[name]
	_music_player.volume_db = -4.0
	_music_player.play()


func stop_music() -> void:
	_wanted_music = ""
	_music_player.stop()


func play_ambient(name: String) -> void:
	var stream: AudioStream = sfx.get(name)
	if stream == null:
		return
	if _ambient_player.stream != stream or not _ambient_player.playing:
		_ambient_player.stream = stream
		_ambient_player.volume_db = -6.0
		_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()
