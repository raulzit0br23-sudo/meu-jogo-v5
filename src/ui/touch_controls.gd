class_name TouchControls
extends Control
## Controles de toque multitoque: joystick analógico dinâmico (esquerda), área de visão (direita),
## botões de ação (o botão de tiro também gira a câmera ao arrastar). Cada dedo é rastreado
## pelo índice, permitindo mover + mirar + atirar ao mesmo tempo.
## Modo de edição: arrastar botões para reposicionar, botões +/- para tamanho; salvo em Settings.

const BUTTONS := [
	# nome, ação, chave de rótulo, posição relativa (x,y), raio base, segurar?
	["fire", "fire", "touch.fire", Vector2(0.86, 0.62), 70.0, true],
	["aim", "aim", "touch.aim", Vector2(0.94, 0.42), 44.0, true],
	["jump", "jump", "touch.jump", Vector2(0.95, 0.82), 46.0, false],
	["crouch", "crouch", "touch.crouch", Vector2(0.75, 0.86), 42.0, false],
	["use", "use", "touch.use", Vector2(0.74, 0.62), 42.0, false],
	["reload", "reload", "touch.reload", Vector2(0.84, 0.36), 38.0, false],
	["alt", "alt_fire", "touch.alt", Vector2(0.94, 0.24), 36.0, false],
	["sprint", "sprint", "touch.sprint", Vector2(0.08, 0.42), 38.0, true],
	["next", "next_weapon", "touch.next", Vector2(0.62, 0.9), 38.0, false],
	["light", "flashlight", "touch.light", Vector2(0.62, 0.08), 32.0, false],
	["inv", "inventory", "touch.inv", Vector2(0.72, 0.08), 32.0, false],
	["pause", "pause", "touch.pause", Vector2(0.95, 0.08), 32.0, false],
]

var edit_mode := false
var _fingers := {}           # index -> {"role": "move"/"look"/"btn", "btn": name, "start": pos, "last": pos}
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_active := false
var _pressed := {}           # nome -> bool
var _selected := ""
var _edit_bar: HBoxContainer
const STICK_R := 90.0

func _ready() -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_bar = HBoxContainer.new()
	_edit_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_edit_bar.position = Vector2(-330, 120)
	_edit_bar.add_theme_constant_override("separation", 10)
	_edit_bar.add_child(UIKit.button("−", func(): _scale_selected(-0.1), 80))
	_edit_bar.add_child(UIKit.button("+", func(): _scale_selected(0.1), 80))
	_edit_bar.add_child(UIKit.button(Loc.t("set.reset"), _reset_layout, 220))
	_edit_bar.add_child(UIKit.button(Loc.t("menu.done"), func(): set_edit_mode(false), 180))
	_edit_bar.visible = false
	_edit_bar.theme = UIKit.theme()
	add_child(_edit_bar)

func set_edit_mode(on: bool) -> void:
	edit_mode = on
	_edit_bar.visible = on
	_edit_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	if not on:
		Settings.save_settings()
		if get_parent().has_method("on_touch_edit_done"):
			get_parent().on_touch_edit_done()
	_release_all()
	queue_redraw()

func _layout(name: String) -> Array:
	var l: Dictionary = Settings.data["touch_layout"]
	for b in BUTTONS:
		if b[0] == name:
			if l.has(name):
				return [Vector2(l[name][0], l[name][1]), float(l[name][2]) if l[name].size() > 2 else 1.0]
			return [b[3], 1.0]
	return [Vector2.ZERO, 1.0]

func _btn_geom(b: Array) -> Array:
	var lay := _layout(b[0])
	var vs := get_viewport_rect().size
	var r: float = b[4] * float(Settings.get_v("controls", "touch_scale", 1.0)) * lay[1] * (vs.y / 720.0)
	return [Vector2(lay[0].x * vs.x, lay[0].y * vs.y), r]

func _hit_button(p: Vector2) -> String:
	for b in BUTTONS:
		var g := _btn_geom(b)
		if p.distance_to(g[0]) <= g[1] * 1.15:
			return b[0]
	return ""

func _active() -> bool:
	return visible and (edit_mode or (Game.in_game and not get_tree().paused))

func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)

func _touch_down(i: int, p: Vector2) -> void:
	if edit_mode:
		if _edit_bar.get_global_rect().has_point(p):
			return
		var bn := _hit_button(p)
		_selected = bn
		_fingers[i] = {"role": "edit", "btn": bn, "last": p}
		queue_redraw()
		return
	var bn := _hit_button(p)
	if bn != "":
		_fingers[i] = {"role": "btn", "btn": bn, "last": p}
		_press(bn, true)
		get_viewport().set_input_as_handled()
	elif p.x < get_viewport_rect().size.x * 0.42 and p.y > get_viewport_rect().size.y * 0.3:
		_fingers[i] = {"role": "move", "last": p}
		_stick_center = p
		_stick_pos = p
		_stick_active = true
	else:
		_fingers[i] = {"role": "look", "last": p}
	queue_redraw()

func _touch_drag(i: int, p: Vector2, rel: Vector2) -> void:
	if not _fingers.has(i):
		return
	var f: Dictionary = _fingers[i]
	match f["role"]:
		"edit":
			if f["btn"] != "":
				var vs := get_viewport_rect().size
				var l: Dictionary = Settings.data["touch_layout"]
				var cur := _layout(f["btn"])
				l[f["btn"]] = [clampf(p.x / vs.x, 0.03, 0.97), clampf(p.y / vs.y, 0.04, 0.96), cur[1]]
		"move":
			var d := p - _stick_center
			if d.length() > STICK_R:
				# joystick flutuante: o centro acompanha o dedo
				_stick_center = p - d.normalized() * STICK_R
				d = p - _stick_center
			_stick_pos = p
			InputRouter.touch_move = d / STICK_R
			# empurrar até a borda = correr
			if d.length() > STICK_R * 0.97 and d.y < -STICK_R * 0.8:
				Input.action_press("sprint")
			elif not _pressed.get("sprint", false):
				Input.action_release("sprint")
		"look":
			InputRouter.add_touch_look(rel)
		"btn":
			if f["btn"] in ["fire", "aim"]:
				InputRouter.add_touch_look(rel)
	f["last"] = p
	queue_redraw()

func _touch_up(i: int) -> void:
	if not _fingers.has(i):
		return
	var f: Dictionary = _fingers[i]
	match f["role"]:
		"move":
			_stick_active = false
			InputRouter.touch_move = Vector2.ZERO
			if not _pressed.get("sprint", false):
				Input.action_release("sprint")
		"btn":
			_press(f["btn"], false)
	_fingers.erase(i)
	queue_redraw()

func _press(bn: String, down: bool) -> void:
	for b in BUTTONS:
		if b[0] != bn:
			continue
		_pressed[bn] = down
		var ev := InputEventAction.new()
		ev.action = b[1]
		ev.pressed = down
		ev.strength = 1.0
		Input.parse_input_event(ev)
		if down and not b[5]:
			# botões de toque simples: solta no quadro seguinte
			get_tree().create_timer(0.06, true).timeout.connect(func():
				var up := InputEventAction.new(); up.action = b[1]; up.pressed = false
				Input.parse_input_event(up))
		if down:
			InputRouter.vibrate(0.0, 0.15, 0.03)

func _release_all() -> void:
	for k in _pressed.keys():
		if _pressed[k]:
			_press(k, false)
	_fingers.clear()
	_stick_active = false
	InputRouter.touch_move = Vector2.ZERO

func _scale_selected(d: float) -> void:
	if _selected == "":
		return
	var cur := _layout(_selected)
	Settings.data["touch_layout"][_selected] = [cur[0].x, cur[0].y, clampf(cur[1] + d, 0.6, 1.8)]
	queue_redraw()

func _reset_layout() -> void:
	Settings.data["touch_layout"] = {}
	queue_redraw()

func _process(_d: float) -> void:
	var want := (InputRouter.device == InputRouter.Device.TOUCH and Game.in_game) or edit_mode
	if visible != want:
		visible = want
		if not want:
			_release_all()
	if get_tree().paused and not edit_mode and not _fingers.is_empty():
		_release_all()

func _draw() -> void:
	var op: float = Settings.get_v("controls", "touch_opacity", 0.55)
	var font := get_theme_default_font()
	for b in BUTTONS:
		var g := _btn_geom(b)
		var pressed: bool = _pressed.get(b[0], false)
		var col := Color(0.95, 0.62, 0.25, op) if pressed else Color(0.85, 0.85, 0.8, op * 0.55)
		draw_circle(g[0], g[1], Color(0.05, 0.06, 0.06, op * 0.45))
		draw_arc(g[0], g[1], 0, TAU, 40, col, 3.0 if b[0] != _selected or not edit_mode else 6.0, true)
		var txt := Loc.t(b[2])
		var fs := int(clampf(g[1] * 0.32, 12, 26))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, g[0] + Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, op + 0.2))
	var vs := get_viewport_rect().size
	if _stick_active:
		draw_circle(_stick_center, STICK_R, Color(0.05, 0.06, 0.06, op * 0.35))
		draw_arc(_stick_center, STICK_R, 0, TAU, 48, Color(0.85, 0.85, 0.8, op * 0.5), 2.0, true)
		draw_circle(_stick_pos, 38, Color(0.95, 0.62, 0.25, op * 0.7))
	elif not edit_mode:
		var hint_c := Vector2(vs.x * 0.16, vs.y * 0.72)
		draw_arc(hint_c, STICK_R * 0.8, 0, TAU, 48, Color(0.85, 0.85, 0.8, op * 0.25), 2.0, true)
	if edit_mode:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25))
		draw_string(font, Vector2(vs.x * 0.5 - 300, 90), Loc.t("menu.layout_edit"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIKit.ACCENT)
