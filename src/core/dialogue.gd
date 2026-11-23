extends Node
## Sistema de diálogos: sequências de falas com dublagem PT/EN, legendas e fallback.
## Cada fala: {id, who, pt, en, [wait]}. Áudio: res://assets/audio/voice/<lang>/<id>.wav

signal line_started(speaker: String, text: String, duration: float)
signal line_finished(id: String)
signal sequence_finished(seq_name: String)

const SPEAKER_NAMES := {
	"bohdan": "Bohdan", "irina": "Irina", "kovac": "Cap. Kovač", "vigilante": "Vigilante",
	"pa": "Alto-falante", "regente": "O Regente", "lindqvist": "Dr. Lindqvist", "passenger": "Passageira",
	"matvei": "Matvei", "worker": "Operária", "foreman": "Capataz", "soldier": "Soldado", "conscript": "Recruta",
}

var _speakers := {}        # id -> Node3D (fonte posicional)
var _queue: Array = []
var _seq_name := ""
var _current: Dictionary = {}
var _player2d: AudioStreamPlayer
var _timer := 0.0
var _busy := false
var missing_voice: Array[String] = []

func _ready() -> void:
	_player2d = AudioStreamPlayer.new()
	_player2d.bus = "Voice"
	add_child(_player2d)

func register_speaker(id: String, node: Node3D) -> void:
	_speakers[id] = node

func clear_speakers() -> void:
	_speakers.clear()
	stop()

func is_busy() -> bool:
	return _busy

func play_sequence(seq_name: String, lines: Array) -> void:
	_seq_name = seq_name
	_queue = lines.duplicate()
	_busy = true
	_next()

func stop() -> void:
	_queue.clear()
	_busy = false
	_player2d.stop()
	for id in _speakers:
		var n = _speakers[id]
		if is_instance_valid(n) and n.has_method("stop_voice"):
			n.stop_voice()

func _next() -> void:
	if _queue.is_empty():
		_busy = false
		sequence_finished.emit(_seq_name)
		return
	_current = _queue.pop_front()
	var lang: String = Settings.get_v("access", "voice_lang", "pt")
	var sub_lang: String = Settings.get_v("access", "language", "pt")
	var text: String = _current.get(sub_lang, _current.get("pt", ""))
	var path := "res://assets/audio/voice/%s/%s.wav" % [lang, _current["id"]]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	var dur := 0.0
	if stream:
		dur = stream.get_length()
		var who: String = _current.get("who", "")
		var src = _speakers.get(who)
		if is_instance_valid(src) and src.has_method("speak"):
			src.speak(stream)
		else:
			_player2d.stream = stream
			_player2d.play()
	else:
		# Fallback documentado: legenda temporizada (~14 caracteres/s).
		dur = clampf(text.length() / 14.0, 1.5, 9.0)
		if not missing_voice.has(path):
			missing_voice.append(path)
	_timer = dur + float(_current.get("wait", 0.35))
	var who_name: String = SPEAKER_NAMES.get(_current.get("who", ""), _current.get("who", ""))
	line_started.emit(who_name, text, dur)

func _process(delta: float) -> void:
	if not _busy or get_tree().paused:
		return
	_timer -= delta
	if _timer <= 0.0:
		line_finished.emit(_current.get("id", ""))
		_next()
