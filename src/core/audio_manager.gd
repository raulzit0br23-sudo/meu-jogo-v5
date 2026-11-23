extends Node
## Gerenciador de áudio: barramentos, pool de vozes 3D, cache de streams, reverberação por zona,
## trilha dinâmica em camadas (exploração / tensão / combate) e analisador para sincronia labial.

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 24

var _cache := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _ui_player: AudioStreamPlayer
var _music_layers := {}
var _ambience: AudioStreamPlayer
var _ambience2: AudioStreamPlayer
var intensity := 0.0          # 0 = calmo, 0.5 = tensão, 1 = combate
var _intensity_smooth := 0.0
var music_enabled := false
var _voice_analyzer: AudioEffectSpectrumAnalyzerInstance
var _reverb: AudioEffectReverb

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 6000.0
		p.attenuation_filter_db = -12.0
		add_child(p)
		_pool.append(p)
	_ui_player = AudioStreamPlayer.new(); _ui_player.bus = "SFX"; add_child(_ui_player)
	_ambience = AudioStreamPlayer.new(); _ambience.bus = "SFX"; _ambience.volume_db = -8.0; add_child(_ambience)
	_ambience2 = AudioStreamPlayer.new(); _ambience2.bus = "SFX"; _ambience2.volume_db = -12.0; add_child(_ambience2)
	for layer in ["explore", "tension", "combat"]:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = -80.0
		mp.stream = _load_loop("res://assets/audio/music/%s.wav" % layer)
		add_child(mp)
		_music_layers[layer] = mp

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.4; _reverb.damping = 0.6; _reverb.wet = 0.12; _reverb.dry = 1.0
	AudioServer.add_bus_effect(sfx, _reverb)
	var limiter := AudioEffectHardLimiter.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), limiter)
	var voice := AudioServer.get_bus_index("Voice")
	var an := AudioEffectSpectrumAnalyzer.new()
	an.buffer_length = 0.1
	AudioServer.add_bus_effect(voice, an)
	var vrev := AudioEffectReverb.new(); vrev.room_size = 0.3; vrev.wet = 0.08
	AudioServer.add_bus_effect(voice, vrev)
	_voice_analyzer = AudioServer.get_bus_effect_instance(voice, 0)

## Ajusta a reverberação de acordo com o ambiente (zona acústica).
func set_room(room_size: float, wet: float, damping := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_reverb, "room_size", room_size, 0.8)
	tw.parallel().tween_property(_reverb, "wet", wet, 0.8)
	_reverb.damping = damping

func get_stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := name if name.begins_with("res://") else SFX_DIR + name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	else:
		push_warning("Áudio ausente: " + path)
	_cache[name] = s
	return s

func _load_loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s

func play_3d(name: String, pos: Vector3, volume_db := 0.0, pitch_var := 0.08, max_dist := 70.0) -> AudioStreamPlayer3D:
	var s := get_stream(name)
	if s == null:
		return null
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stop()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
	return p

func play_ui(name: String, volume_db := -6.0) -> void:
	var s := get_stream(name)
	if s:
		_ui_player.stream = s
		_ui_player.volume_db = volume_db
		_ui_player.play()

func play_ambience(path: String, secondary := "", vol := -8.0) -> void:
	_ambience.stream = _load_loop(path)
	_ambience.volume_db = vol
	if _ambience.stream: _ambience.play()
	if secondary != "":
		_ambience2.stream = _load_loop(secondary)
		if _ambience2.stream: _ambience2.play()
	else:
		_ambience2.stop()

func stop_ambience() -> void:
	_ambience.stop(); _ambience2.stop()

func start_music() -> void:
	music_enabled = true
	for k in _music_layers:
		var mp: AudioStreamPlayer = _music_layers[k]
		if mp.stream:
			mp.play(0.0)

func stop_music() -> void:
	music_enabled = false
	for k in _music_layers:
		_music_layers[k].stop()

func play_music_track(path: String) -> AudioStreamPlayer:
	stop_music()
	var mp: AudioStreamPlayer = get_node_or_null("Theme")
	if mp == null:
		mp = AudioStreamPlayer.new(); mp.name = "Theme"; mp.bus = "Music"; add_child(mp)
	mp.stream = _load_loop(path)
	mp.volume_db = -4.0
	if mp.stream: mp.play()
	return mp

func stop_theme() -> void:
	var mp: AudioStreamPlayer = get_node_or_null("Theme")
	if mp: mp.stop()

func _process(delta: float) -> void:
	if not music_enabled:
		return
	_intensity_smooth = move_toward(_intensity_smooth, intensity, delta * (0.6 if intensity > _intensity_smooth else 0.15))
	var e := 1.0
	var t := clampf(_intensity_smooth * 2.0, 0.0, 1.0)
	var c := clampf(_intensity_smooth * 2.0 - 1.0, 0.0, 1.0)
	_set_layer("explore", e * (1.0 - c * 0.6))
	_set_layer("tension", t)
	_set_layer("combat", c)

func _set_layer(name: String, lin: float) -> void:
	var mp: AudioStreamPlayer = _music_layers.get(name)
	if mp:
		mp.volume_db = linear_to_db(maxf(lin, 0.0001)) - 6.0

## Energia da voz atual (0..1) para sincronia labial/gestual.
func voice_energy() -> float:
	if _voice_analyzer == null:
		return 0.0
	var m := _voice_analyzer.get_magnitude_for_frequency_range(150.0, 3500.0)
	return clampf((m.x + m.y) * 6.0, 0.0, 1.0)
