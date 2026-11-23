extends Node
## Roteador de entrada multiplataforma.
## - Cria o InputMap padrão (teclado/mouse + controles Xbox/PlayStation/genéricos via SDL).
## - Detecta o dispositivo ativo e emite device_changed para a UI trocar os ícones/prompts.
## - Recebe eixos virtuais dos controles de toque (joystick e área de câmera).
## - Remapeamento persistente de teclas (Settings.data.bindings).

signal device_changed(device: int)

enum Device { KBM, GAMEPAD, TOUCH }

var device: int = Device.KBM
var touch_move := Vector2.ZERO      # -1..1, do joystick virtual
var _touch_look := Vector2.ZERO     # pixels acumulados no quadro
var _mouse_look := Vector2.ZERO
var touch_enabled := false

const ACTIONS := {
	# ação: [teclas], [botões mouse], [botões joypad], [eixo joypad, direção]
	"move_forward": [[KEY_W, KEY_UP], [], [], [JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [[KEY_S, KEY_DOWN], [], [], [JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [[KEY_A, KEY_LEFT], [], [], [JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[KEY_D, KEY_RIGHT], [], [], [JOY_AXIS_LEFT_X, 1.0]],
	"look_up": [[], [], [], [JOY_AXIS_RIGHT_Y, -1.0]],
	"look_down": [[], [], [], [JOY_AXIS_RIGHT_Y, 1.0]],
	"look_left": [[], [], [], [JOY_AXIS_RIGHT_X, -1.0]],
	"look_right": [[], [], [], [JOY_AXIS_RIGHT_X, 1.0]],
	"jump": [[KEY_SPACE], [], [JOY_BUTTON_A], []],
	"crouch": [[KEY_CTRL, KEY_C], [], [JOY_BUTTON_B], []],
	"sprint": [[KEY_SHIFT], [], [JOY_BUTTON_LEFT_STICK], []],
	"use": [[KEY_E], [], [JOY_BUTTON_X], []],
	"fire": [[], [MOUSE_BUTTON_LEFT], [], [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"aim": [[], [MOUSE_BUTTON_RIGHT], [], [JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"alt_fire": [[KEY_Q], [MOUSE_BUTTON_MIDDLE], [JOY_BUTTON_RIGHT_STICK], []],
	"reload": [[KEY_R], [], [JOY_BUTTON_Y], []],
	"next_weapon": [[], [MOUSE_BUTTON_WHEEL_DOWN], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"prev_weapon": [[], [MOUSE_BUTTON_WHEEL_UP], [JOY_BUTTON_LEFT_SHOULDER], []],
	"flashlight": [[KEY_F], [], [JOY_BUTTON_DPAD_UP], []],
	"inventory": [[KEY_TAB, KEY_I], [], [JOY_BUTTON_BACK], []],
	"pause": [[KEY_ESCAPE, KEY_P], [], [JOY_BUTTON_START], []],
	"quicksave": [[KEY_F5], [], [], []],
	"quickload": [[KEY_F9], [], [], []],
	"weapon_1": [[KEY_1], [], [], []], "weapon_2": [[KEY_2], [], [], []], "weapon_3": [[KEY_3], [], [], []],
	"weapon_4": [[KEY_4], [], [], []], "weapon_5": [[KEY_5], [], [], []],
	"weapon_6": [[KEY_6], [], [JOY_BUTTON_DPAD_DOWN], []],
}
const REBINDABLE := ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint", "use",
	"fire", "aim", "alt_fire", "reload", "next_weapon", "prev_weapon", "flashlight", "inventory", "quicksave"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_default_map()
	touch_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if OS.has_feature("mobile"):
		device = Device.TOUCH
	Input.joy_connection_changed.connect(_on_joy_changed)
	if Input.get_connected_joypads().size() > 0 and not OS.has_feature("mobile"):
		device = Device.GAMEPAD

func _build_default_map() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.25)
		_add_default_events(action)
	# Navegação da UI também por controle (ui_* já existem; reforça D-pad/stick).
	for pair in [["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN], ["ui_left", JOY_BUTTON_DPAD_LEFT],
			["ui_right", JOY_BUTTON_DPAD_RIGHT], ["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)

func _add_default_events(action: String, keyboard := true, gamepad := true) -> void:
	var spec: Array = ACTIONS[action]
	if keyboard:
		for k in spec[0]:
			var ev := InputEventKey.new(); ev.physical_keycode = k; InputMap.action_add_event(action, ev)
		for b in spec[1]:
			var ev := InputEventMouseButton.new(); ev.button_index = b; InputMap.action_add_event(action, ev)
	if gamepad:
		for b in spec[2]:
			var ev := InputEventJoypadButton.new(); ev.button_index = b; InputMap.action_add_event(action, ev)
		if spec[3].size() == 2:
			var ev := InputEventJoypadMotion.new(); ev.axis = spec[3][0]; ev.axis_value = spec[3][1]; InputMap.action_add_event(action, ev)

## Aplica remapeamentos salvos (apenas teclado/mouse; controles mantêm layout padrão do SDL).
func apply_bindings(bindings: Dictionary) -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)
		for b in bindings[action]:
			if b.get("type") == "key":
				var ev := InputEventKey.new(); ev.physical_keycode = int(b["code"]); InputMap.action_add_event(action, ev)
			elif b.get("type") == "mouse":
				var ev := InputEventMouseButton.new(); ev.button_index = int(b["button"]); InputMap.action_add_event(action, ev)

func rebind(action: String, event: InputEvent) -> void:
	var entry := {}
	if event is InputEventKey:
		entry = {"type": "key", "code": int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)}
	elif event is InputEventMouseButton:
		entry = {"type": "mouse", "button": int(event.button_index)}
	else:
		return
	var b: Dictionary = Settings.data["bindings"]
	b[action] = [entry]
	Settings.set_v("bindings", action, [entry])

func binding_text(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if device == Device.GAMEPAD and (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
			return _pad_name(ev)
		if device != Device.GAMEPAD and ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode if ev.physical_keycode else ev.keycode)
		if device != Device.GAMEPAD and ev is InputEventMouseButton:
			return ["", "Mouse1", "Mouse2", "Mouse3", "Roda+", "Roda-"][clampi(ev.button_index, 0, 5)]
	return "?"

func _pad_name(ev: InputEvent) -> String:
	var ps := false
	for j in Input.get_connected_joypads():
		var n := Input.get_joy_name(j).to_lower()
		if n.contains("ps") or n.contains("dualsense") or n.contains("dualshock") or n.contains("sony"):
			ps = true
	if ev is InputEventJoypadButton:
		var xbox := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
			JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "View", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_DPAD_UP: "D-Cima"}
		var sony := {JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△", JOY_BUTTON_LEFT_SHOULDER: "L1",
			JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Share", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_DPAD_UP: "D-Cima"}
		return (sony if ps else xbox).get(ev.button_index, "Btn%d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		if ev.axis == JOY_AXIS_TRIGGER_RIGHT: return "R2" if ps else "RT"
		if ev.axis == JOY_AXIS_TRIGGER_LEFT: return "L2" if ps else "LT"
	return "?"

func _input(event: InputEvent) -> void:
	var new_dev := device
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # eventos de mouse emulados a partir do toque
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_dev = Device.TOUCH
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		new_dev = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		new_dev = Device.KBM
	if new_dev != device:
		device = new_dev
		device_changed.emit(device)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_look += event.relative

func add_touch_look(delta_px: Vector2) -> void:
	_touch_look += delta_px

## Retorna o vetor de rotação da câmera (graus) neste quadro, unificado entre dispositivos.
func consume_look(delta: float) -> Vector2:
	var c: Dictionary = Settings.data["controls"]
	var out := _mouse_look * float(c["mouse_sens"]) + _touch_look * float(c["touch_sens"])
	_mouse_look = Vector2.ZERO
	_touch_look = Vector2.ZERO
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.12)
	# Curva de resposta quadrática para precisão perto do centro.
	stick = stick * stick.length()
	out += stick * float(c["pad_sens"]) * 60.0 * delta
	if c["invert_y"]:
		out.y = -out.y
	return out

func get_move() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.15)
	if touch_move.length() > 0.05:
		v = touch_move
	return v.limit_length(1.0)

func vibrate(weak: float, strong: float, duration: float) -> void:
	if not Settings.get_v("controls", "vibration", true):
		return
	for j in Input.get_connected_joypads():
		Input.start_joy_vibration(j, weak, strong, duration)
	if device == Device.TOUCH and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(duration * 1000.0 * strong))

func _on_joy_changed(_id: int, connected: bool) -> void:
	if connected and not OS.has_feature("mobile"):
		device = Device.GAMEPAD
		device_changed.emit(device)
