extends Node
## Estado global: fluxo de capítulos, checkpoints, salvamento (manual/auto/rápido),
## eventos de ruído para a IA, intensidade de combate e pausa.

signal checkpoint_reached(id: String)
signal objective_changed(text_key: String)
signal noise_emitted(pos: Vector3, radius: float, source: Node)
signal player_died
signal game_saved(slot: String)
signal chapter_started(n: int)

const SAVE_DIR := "user://saves/"
const VERSION := 1

const CHAPTERS := [
	{"n": 1, "act": "I", "script": "res://src/levels/chapter_01.gd", "ready": true},
	{"n": 2, "act": "I", "script": "res://src/levels/chapter_02.gd", "ready": true},
	{"n": 3, "act": "I", "script": "res://src/levels/chapter_03.gd", "ready": true},
	{"n": 4, "act": "I", "script": "res://src/levels/chapter_04.gd", "ready": true},
	{"n": 5, "act": "II", "script": "res://src/levels/chapter_05.gd", "ready": true},
	{"n": 6, "act": "II", "script": "res://src/levels/chapter_06.gd", "ready": true},
	{"n": 7, "act": "II", "script": "", "ready": false},
	{"n": 8, "act": "II", "script": "", "ready": false},
	{"n": 9, "act": "II", "script": "", "ready": false},
	{"n": 10, "act": "II", "script": "", "ready": false},
	{"n": 11, "act": "II", "script": "", "ready": false},
	{"n": 12, "act": "II", "script": "", "ready": false},
	{"n": 13, "act": "II", "script": "", "ready": false},
	{"n": 14, "act": "II", "script": "", "ready": false},
	{"n": 15, "act": "II", "script": "", "ready": false},
	{"n": 16, "act": "II", "script": "", "ready": false},
	{"n": 17, "act": "II", "script": "", "ready": false},
	{"n": 18, "act": "II", "script": "", "ready": false},
	{"n": 19, "act": "III", "script": "", "ready": false},
	{"n": 20, "act": "III", "script": "", "ready": false},
	{"n": 21, "act": "III", "script": "", "ready": false},
	{"n": 22, "act": "III", "script": "", "ready": false},
	{"n": 23, "act": "III", "script": "", "ready": false},
	{"n": 24, "act": "III", "script": "", "ready": false},
	{"n": 25, "act": "III", "script": "", "ready": false},
	{"n": 26, "act": "III", "script": "", "ready": false},
	{"n": 27, "act": "III", "script": "", "ready": false},
	{"n": 28, "act": "III", "script": "", "ready": false},
	{"n": 29, "act": "III", "script": "", "ready": false},
	{"n": 30, "act": "III", "script": "", "ready": false},
]

var player: Node = null
var level: Node = null
var chapter := 0
var checkpoint := "start"
var flags := {}
var objective_key := ""
var play_time := 0.0
var pending_player_state: Dictionary = {}
var _load_seq := 0
var unlocked := [1]
var _alerted := {}
var in_game := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_load_progress()

func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		play_time += delta
	# Intensidade da trilha a partir do nº de inimigos em alerta.
	var n := 0
	for k in _alerted.keys():
		if not is_instance_valid(k):
			_alerted.erase(k)
		else:
			n += 1
	AudioBus.intensity = clampf(0.25 * float(_alerted.size() > 0) + 0.25 * n, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not in_game:
		return
	if event.is_action_pressed("quicksave"):
		save_game("quick")
	elif event.is_action_pressed("quickload") and has_save("quick"):
		load_game("quick")

# ---------------- ruído / alerta ----------------
func emit_noise(pos: Vector3, radius: float, source: Node = null) -> void:
	noise_emitted.emit(pos, radius, source)

func set_alerted(enemy: Node, on: bool) -> void:
	if on: _alerted[enemy] = true
	else: _alerted.erase(enemy)

# ---------------- fluxo ----------------
func new_game() -> void:
	flags = {}
	play_time = 0.0
	pending_player_state = {}
	start_chapter(1, "start")

const TEST_RANGE := "res://src/levels/test_range.gd"

## Sala de Testes (capítulo 0): fora da campanha, não salva progresso.
func start_test_range(cp := "start") -> void:
	flags = {}
	pending_player_state = {}
	chapter = 0
	checkpoint = cp
	_load_level(TEST_RANGE)
	chapter_started.emit(0)

func start_chapter(n: int, cp := "start") -> void:
	if n == 0:
		start_test_range(cp)
		return
	var info: Dictionary = CHAPTERS[n - 1]
	if not info["ready"]:
		push_warning("Capítulo %d ainda não implementado" % n)
		return
	chapter = n
	checkpoint = cp
	if not unlocked.has(n):
		unlocked.append(n); _save_progress()
	_load_level(info["script"])
	chapter_started.emit(n)

func _load_level(script_path: String) -> void:
	get_tree().paused = false
	Dialogue.clear_speakers()
	_alerted.clear()
	var root := get_tree().root
	var main := root.get_node_or_null("Main")
	if main and main.has_method("show_loading"):
		main.show_loading(true)
	_load_seq += 1
	var my_seq := _load_seq
	await get_tree().process_frame
	if my_seq != _load_seq: return  # outra carga foi pedida depois desta: ela vence
	if is_instance_valid(level):
		level.queue_free()
	# garante que nenhuma fase antiga fique viva (ex.: duas cargas no mesmo quadro)
	if main and main.has_node("World"):
		for c in main.get_node("World").get_children():
			if c.has_method("build") and not c.is_queued_for_deletion(): c.queue_free()
	await get_tree().process_frame
	if my_seq != _load_seq: return
	var script: GDScript = load(script_path)
	var lvl := Node3D.new()
	lvl.name = "Level"
	lvl.set_script(script)
	level = lvl
	in_game = true
	if main:
		main.get_node("World").add_child(lvl)
		if main.has_method("on_level_loaded"):
			main.on_level_loaded(lvl)
	else:
		root.add_child(lvl)
	if lvl.has_signal("built"):
		await lvl.built
	if main and main.has_method("show_loading"):
		main.show_loading(false)

func complete_chapter() -> void:
	var nxt := chapter + 1
	if nxt <= CHAPTERS.size() and not unlocked.has(nxt) and CHAPTERS[nxt - 1]["ready"]:
		unlocked.append(nxt)
	_save_progress()
	var main := get_tree().root.get_node_or_null("Main")
	if nxt <= CHAPTERS.size() and CHAPTERS[nxt - 1]["ready"]:
		pending_player_state = player.get_state() if is_instance_valid(player) else {}
		start_chapter(nxt)
	elif main:
		in_game = false
		main.show_ending()

func quit_to_menu() -> void:
	in_game = false
	get_tree().paused = false
	Dialogue.clear_speakers()
	AudioBus.stop_music(); AudioBus.stop_ambience()
	if is_instance_valid(level):
		level.queue_free()
	level = null
	player = null
	var main := get_tree().root.get_node_or_null("Main")
	if main: main.show_main_menu()

func reach_checkpoint(id: String) -> void:
	if checkpoint == id:
		return
	checkpoint = id
	checkpoint_reached.emit(id)
	save_game("auto")

func set_objective(key: String) -> void:
	objective_key = key
	objective_changed.emit(key)

func on_player_died() -> void:
	player_died.emit()

func retry() -> void:
	if chapter == 0:
		start_test_range()
	elif has_save("auto"):
		load_game("auto")
	else:
		start_chapter(chapter, "start")

# ---------------- salvamento ----------------
func save_game(slot: String) -> bool:
	if not in_game or not is_instance_valid(player) or chapter == 0:
		return false
	var d := {
		"version": VERSION, "chapter": chapter, "checkpoint": checkpoint, "flags": flags,
		"player": player.get_state(), "time": play_time, "objective": objective_key,
		"date": Time.get_datetime_string_from_system(), "level_state": level.get_state() if level.has_method("get_state") else {},
	}
	var f := FileAccess.open(SAVE_DIR + slot + ".json", FileAccess.WRITE)
	if f == null:
		push_error("Não foi possível salvar: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	game_saved.emit(slot)
	_save_progress()
	return true

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(SAVE_DIR + slot + ".json")

func read_save(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var txt := FileAccess.get_file_as_string(SAVE_DIR + slot + ".json")
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != VERSION:
		push_warning("Save inválido ou de versão incompatível: " + slot)
		return {}
	return d

func latest_save() -> String:
	var best := ""
	var best_t := 0
	for s in ["auto", "quick", "manual"]:
		var p: String = SAVE_DIR + s + ".json"
		if FileAccess.file_exists(p):
			var t := FileAccess.get_modified_time(p)
			if t >= best_t:
				best_t = t; best = s
	return best

func load_game(slot: String) -> void:
	var d := read_save(slot)
	if d.is_empty():
		return
	flags = d.get("flags", {})
	play_time = float(d.get("time", 0.0))
	pending_player_state = d.get("player", {})
	pending_player_state["_level_state"] = d.get("level_state", {})
	objective_key = String(d.get("objective", ""))
	start_chapter(int(d["chapter"]), String(d["checkpoint"]))

func _save_progress() -> void:
	var f := FileAccess.open(SAVE_DIR + "progress.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": unlocked}))

func _load_progress() -> void:
	var p := SAVE_DIR + "progress.json"
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(d) == TYPE_DICTIONARY:
			unlocked = []
			for n in d.get("unlocked", [1]):
				unlocked.append(int(n))
	if not unlocked.has(1):
		unlocked.append(1)
