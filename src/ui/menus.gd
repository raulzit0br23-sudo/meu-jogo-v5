class_name Menus
extends Control
## Todas as telas de menu: principal, capítulos, carregar, configurações (gráficos, áudio,
## controles com remapeamento, toque, acessibilidade), pausa, créditos, final e carregamento.
## Navegáveis por toque, controle (foco + D-pad/analógico, B = voltar) e teclado/mouse.

signal request_touch_edit

var _stack: Array[String] = []
var _screen: Control
var _rebinding := ""
var _rebind_btn: Button
var _credits_scroll: ScrollContainer
var _credits_speed := 0.0
var _bg: ColorRect

func _ready() -> void:
	UIKit.full_rect(self)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	UIKit.full_rect(_bg)
	add_child(_bg)

func _clear() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null

func open(name: String, push := true) -> void:
	if push and (_stack.is_empty() or _stack.back() != name):
		_stack.append(name)
	visible = true
	_clear()
	_bg.color = Color(0.0, 0.0, 0.0, 0.35) if name in ["main", "chapters", "load", "credits_menu", "plan"] and not Game.in_game else Color(0.02, 0.025, 0.03, 0.82)
	match name:
		"main": _screen = _main()
		"chapters": _screen = _chapters()
		"plan": _screen = _plan()
		"load": _screen = _load()
		"settings": _screen = _settings()
		"pause": _screen = _pause()
		"credits", "credits_menu": _screen = _credits(name == "credits")
		"loading": _screen = _loading()
	add_child(_screen)
	UIKit.focus_first(_screen)

func back() -> void:
	if _rebinding != "":
		_rebinding = ""
		return
	if _stack.size() <= 1:
		if _stack.size() == 1 and _stack[0] == "pause":
			get_parent().resume()
		return
	_stack.pop_back()
	AudioBus.play_ui("ui_back")
	open(_stack.back(), false)

func close() -> void:
	_stack.clear()
	_clear()
	visible = false

func current() -> String:
	return "" if _stack.is_empty() else _stack.back()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _rebinding != "":
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_rebinding = ""; open("settings", false); get_viewport().set_input_as_handled(); return
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			InputRouter.rebind(_rebinding, event)
			Settings.save_settings()
			_rebinding = ""
			open("settings", false)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		if current() in ["credits", "ending"]:
			_finish_credits()
		else:
			back()
		get_viewport().set_input_as_handled()

# ---------------- telas ----------------
func _frame(title: String, width := 620) -> Array:
	var root := Control.new()
	UIKit.full_rect(root)
	var center := CenterContainer.new()
	UIKit.full_rect(center)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	if title != "":
		v.add_child(UIKit.label(title.to_upper(), 30, UIKit.ACCENT))
		var sep := ColorRect.new(); sep.color = UIKit.LINE; sep.custom_minimum_size.y = 1
		v.add_child(sep)
	return [root, v]

func _main() -> Control:
	var root := Control.new()
	UIKit.full_rect(root)
	var v := VBoxContainer.new()
	v.position = Vector2(80, 60)
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)
	var title := UIKit.label("ATMOSFERA ZERO", 60, UIKit.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(title)
	v.add_child(UIKit.label(Loc.t("menu.subtitle"), 22, UIKit.ACCENT))
	var spacer := Control.new(); spacer.custom_minimum_size.y = 18; v.add_child(spacer)
	var latest := Game.latest_save()
	if latest != "":
		v.add_child(UIKit.button(Loc.t("menu.continue"), func(): Game.load_game(latest)))
	v.add_child(UIKit.button(Loc.t("menu.new_game"), func(): Game.new_game()))
	v.add_child(UIKit.button(Loc.t("menu.load"), func(): open("load")))
	v.add_child(UIKit.button(Loc.t("menu.chapters"), func(): open("chapters")))
	v.add_child(UIKit.button(Loc.t("menu.plan"), func(): open("plan")))
	v.add_child(UIKit.button(Loc.t("menu.test_range"), func(): Game.start_test_range()))
	v.add_child(UIKit.button(Loc.t("menu.settings"), func(): open("settings")))
	v.add_child(UIKit.button(Loc.t("menu.credits"), func(): open("credits_menu")))
	if not OS.has_feature("web"):
		v.add_child(UIKit.button(Loc.t("menu.quit"), func(): get_tree().quit()))
	var ver := UIKit.label("v%s · Godot %s · %s" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"], str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))], 14, UIKit.DIM)
	ver.autowrap_mode = TextServer.AUTOWRAP_OFF
	ver.anchor_top = 1.0; ver.anchor_bottom = 1.0
	ver.position = Vector2(24, -36)
	root.add_child(ver)
	return root

func _chapters() -> Control:
	var f := _frame(Loc.t("menu.chapters"), 760)
	var v: VBoxContainer = f[1]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll)
	for ch in Game.CHAPTERS:
		var n: int = ch["n"]
		var ready: bool = ch["ready"]
		var unlocked: bool = Game.unlocked.has(n)
		var txt := "%s %s %d — %s   [%s %s]" % ["" if ready else "·", Loc.t("menu.chapter"), n, Loc.t("ch.%d" % n), Loc.t("menu.act"), ch["act"]]
		if not ready:
			txt += "   (" + Loc.t("menu.locked") + ")"
		var b := UIKit.button(txt, func(): Game.start_chapter(n), 700)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not (ready and unlocked)
		list.add_child(b)
	v.add_child(UIKit.button(Loc.t("menu.back"), back))
	return f[0]

# ---------------- Planejamento: concept art dos 30 capítulos ----------------
var _plan_data: Array = []
var _plan_sel := 1
var _plan_img: TextureRect
var _plan_title: Label
var _plan_meta: Label
var _plan_sum: Label
var _plan_play: Button
var _plan_thumbs := {}

func _plan_load() -> void:
	if _plan_data.is_empty():
		var txt := FileAccess.get_file_as_string("res://data/campaign_plan.json")
		var d = JSON.parse_string(txt)
		if d is Array: _plan_data = d

func _plan() -> Control:
	_plan_load()
	_plan_thumbs.clear()
	var root := Control.new()
	UIKit.full_rect(root)
	var panel := PanelContainer.new()
	UIKit.full_rect(panel)
	panel.offset_left = 24; panel.offset_top = 20; panel.offset_right = -24; panel.offset_bottom = -20
	root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := UIKit.label(Loc.t("plan.title"), 28, UIKit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var playable := 0
	for c in Game.CHAPTERS:
		if c["ready"]: playable += 1
	var cnt := UIKit.label("%s: %d / %d" % [Loc.t("plan.playable"), playable, _plan_data.size()], 18, UIKit.DIM)
	cnt.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(cnt)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	outer.add_child(body)
	# coluna de detalhe (arte grande + texto)
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.size_flags_stretch_ratio = 1.6
	det.add_theme_constant_override("separation", 6)
	body.add_child(det)
	_plan_img = TextureRect.new()
	_plan_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plan_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plan_img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plan_img.size_flags_stretch_ratio = 3.0
	_plan_img.custom_minimum_size = Vector2(320, 180)
	det.add_child(_plan_img)
	_plan_title = UIKit.label("", 26, UIKit.TEXT)
	det.add_child(_plan_title)
	_plan_meta = UIKit.label("", 17, UIKit.ACCENT)
	det.add_child(_plan_meta)
	_plan_sum = UIKit.label("", 18, UIKit.TEXT)
	_plan_sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plan_sum.custom_minimum_size.y = 54
	det.add_child(_plan_sum)
	var note := UIKit.label(Loc.t("plan.note"), 13, UIKit.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(note)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	det.add_child(btns)
	btns.add_child(UIKit.button(Loc.t("plan.prev"), func(): _plan_show(wrapi(_plan_sel - 1, 1, _plan_data.size() + 1)), 140))
	btns.add_child(UIKit.button(Loc.t("plan.next"), func(): _plan_show(wrapi(_plan_sel + 1, 1, _plan_data.size() + 1)), 140))
	_plan_play = UIKit.button(Loc.t("plan.play"), func(): Game.start_chapter(_plan_sel), 140)
	btns.add_child(_plan_play)
	btns.add_child(UIKit.button(Loc.t("menu.back"), back, 140))
	# coluna de miniaturas, agrupadas por ato
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var grid: GridContainer = null
	var act := ""
	for c in _plan_data:
		if c["act"] != act:
			act = c["act"]
			list.add_child(UIKit.label("%s %s" % [Loc.t("menu.act").to_upper(), act], 18, UIKit.ACCENT))
			grid = GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			list.add_child(grid)
		var n: int = c["n"]
		var ready: bool = Game.CHAPTERS[n - 1]["ready"] if n <= Game.CHAPTERS.size() else false
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(196, 138)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var tp := "res://assets/concept/thumbs/ch%02d.jpg" % n
		if ResourceLoader.exists(tp):
			b.icon = load(tp)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = "%s%d · %s" % ["" if ready else "· ", n, Loc.t("ch.%d" % n)]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			AudioBus.play_ui("ui_accept")
			_plan_show(n))
		b.focus_entered.connect(func():
			AudioBus.play_ui("ui_move", -14.0)
			_plan_show(n))
		grid.add_child(b)
		_plan_thumbs[n] = b
	_plan_show(_plan_sel)
	return root

func _plan_show(n: int) -> void:
	if _plan_data.is_empty() or not is_instance_valid(_plan_img): return
	_plan_sel = clampi(n, 1, _plan_data.size())
	var c: Dictionary = _plan_data[_plan_sel - 1]
	var en := TranslationServer.get_locale().begins_with("en")
	var path := "res://assets/concept/ch%02d.jpg" % _plan_sel
	_plan_img.texture = load(path) if ResourceLoader.exists(path) else null
	var ready: bool = Game.CHAPTERS[_plan_sel - 1]["ready"] if _plan_sel <= Game.CHAPTERS.size() else false
	_plan_title.text = "%s %d — %s" % [Loc.t("menu.chapter"), _plan_sel, c["en"] if en else c["pt"]]
	_plan_meta.text = "%s %s   ·   %s" % [Loc.t("menu.act"), c["act"], Loc.t("plan.playable") if ready else Loc.t("plan.planned")]
	_plan_meta.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55) if ready else UIKit.ACCENT)
	_plan_sum.text = c["sum_en"] if en else c["sum_pt"]
	if is_instance_valid(_plan_play):
		_plan_play.disabled = not (ready and Game.unlocked.has(_plan_sel))
	for k in _plan_thumbs:
		var tb: Button = _plan_thumbs[k]
		if is_instance_valid(tb):
			tb.modulate = Color(1, 1, 1) if k == _plan_sel else Color(0.72, 0.72, 0.72)

func _load() -> Control:
	var f := _frame(Loc.t("menu.load"))
	var v: VBoxContainer = f[1]
	var any := false
	for slot in ["auto", "quick", "manual"]:
		var d := Game.read_save(slot)
		if d.is_empty():
			continue
		any = true
		var dt := String(d.get("date", "")).replace("T", " ")
		var txt := "%s — %s %d: %s · %s" % [Loc.t("menu.slot_" + slot), Loc.t("menu.chapter"), int(d.get("chapter", 1)), Loc.t("ch.%d" % int(d.get("chapter", 1))), dt]
		v.add_child(UIKit.button(txt, func(): Game.load_game(slot), 580))
	if not any:
		v.add_child(UIKit.label(Loc.t("menu.no_save"), 20, UIKit.DIM))
	v.add_child(UIKit.button(Loc.t("menu.back"), back))
	return f[0]

func _pause() -> Control:
	var f := _frame(Loc.t("menu.paused"), 480)
	var v: VBoxContainer = f[1]
	v.add_child(UIKit.label(Loc.t("ch.0") if Game.chapter == 0 else "%s %d — %s" % [Loc.t("menu.chapter"), Game.chapter, Loc.t("ch.%d" % Game.chapter)], 18, UIKit.DIM))
	if Game.objective_key != "":
		v.add_child(UIKit.label(Loc.t("hud.objective") + ": " + Loc.t(Game.objective_key), 18))
	v.add_child(UIKit.button(Loc.t("menu.resume"), func(): get_parent().resume()))
	var save_b := UIKit.button(Loc.t("menu.save"), func(): pass)
	save_b.pressed.connect(func():
		var ok := Game.save_game("manual")
		save_b.text = Loc.t("menu.saved") if ok else "—")
	v.add_child(save_b)
	v.add_child(UIKit.button(Loc.t("menu.load"), func(): open("load")))
	v.add_child(UIKit.button(Loc.t("menu.settings"), func(): open("settings")))
	v.add_child(UIKit.button(Loc.t("menu.main_menu"), func(): Game.quit_to_menu()))
	return f[0]

func _loading() -> Control:
	var root := Control.new()
	UIKit.full_rect(root)
	var l := UIKit.label(Loc.t("menu.loading"), 26, UIKit.ACCENT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = 280
	l.anchor_left = 1.0; l.anchor_right = 1.0; l.anchor_top = 1.0; l.anchor_bottom = 1.0
	l.position = Vector2(-300, -80)
	root.add_child(l)
	var tip := UIKit.label("", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	tip.set_anchors_preset(Control.PRESET_CENTER)
	tip.custom_minimum_size.x = 900; tip.position = Vector2(-450, 0)
	if Game.chapter == 0 and Game.in_game:
		tip.text = Loc.t("ch.0").to_upper()
	elif Game.chapter > 0:
		tip.text = "%s %d\n%s" % [Loc.t("menu.chapter").to_upper(), Game.chapter, Loc.t("ch.%d" % Game.chapter).to_upper()]
		tip.add_theme_font_size_override("font_size", 34)
		tip.add_theme_color_override("font_color", UIKit.TEXT)
	root.add_child(tip)
	_bg.color = Color(0.01, 0.012, 0.014, 1.0)
	return root

# ---------------- configurações ----------------
func _settings() -> Control:
	var f := _frame(Loc.t("menu.settings"), 900)
	var v: VBoxContainer = f[1]
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(860, 500)
	tabs.focus_mode = Control.FOCUS_ALL
	v.add_child(tabs)
	tabs.add_child(_tab_graphics())
	tabs.add_child(_tab_audio())
	tabs.add_child(_tab_controls())
	tabs.add_child(_tab_access())
	for i in 4:
		tabs.set_tab_title(i, Loc.t(["set.graphics", "set.audio", "set.controls", "set.access"][i]))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(UIKit.button(Loc.t("menu.back"), func():
		Settings.save_settings()
		back(), 260))
	v.add_child(h)
	return f[0]

func _scroll_tab(name: String) -> Array:
	var s := ScrollContainer.new()
	s.name = name
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	s.add_child(col)
	return [s, col]

func _sv(section: String, key: String) -> Callable:
	return func(x): Settings.set_v(section, key, x)

func _tab_graphics() -> Control:
	var t := _scroll_tab("graphics")
	var c: VBoxContainer = t[1]
	var g: Dictionary = Settings.data["graphics"]
	var presets := ["low", "medium", "high", "ultra"]
	var names := [Loc.t("set.low"), Loc.t("set.medium"), Loc.t("set.high"), Loc.t("set.ultra")]
	var pi := presets.find(g["preset"])
	if pi < 0:
		names.append("Custom"); pi = 4
	c.add_child(UIKit.row(Loc.t("set.preset"), UIKit.options(names, pi, func(i: int):
		if i < 4:
			Settings.apply_preset(presets[i])
			open("settings", false))))
	c.add_child(UIKit.row(Loc.t("set.render_scale"), UIKit.slider(g["render_scale"], 0.5, 1.0, 0.05, _sv("graphics", "render_scale"))))
	c.add_child(UIKit.row(Loc.t("set.shadows"), UIKit.options([Loc.t("set.off"), Loc.t("set.low"), Loc.t("set.medium"), Loc.t("set.high")], int(g["shadows"]), _sv("graphics", "shadows"))))
	c.add_child(UIKit.row(Loc.t("set.view_dist"), UIKit.slider(g["view_distance"], 50, 300, 10, _sv("graphics", "view_distance"), "%.0f m")))
	c.add_child(UIKit.row(Loc.t("set.particles"), UIKit.slider(g["particles"], 0.2, 1.0, 0.05, _sv("graphics", "particles"))))
	c.add_child(UIKit.row(Loc.t("set.decals"), UIKit.slider(g["decals"], 8, 128, 8, func(x): Settings.set_v("graphics", "decals", int(x)), "%.0f")))
	c.add_child(UIKit.row(Loc.t("set.effects"), UIKit.toggle(g["effects"], _sv("graphics", "effects"))))
	c.add_child(UIKit.row(Loc.t("set.msaa"), UIKit.options([Loc.t("set.off"), "2x", "4x"], int(g["msaa"]), _sv("graphics", "msaa"))))
	var fps_opts := [30, 60, 90, 120, 0]
	c.add_child(UIKit.row(Loc.t("set.fps"), UIKit.options(["30", "60", "90", "120", "∞"], maxi(0, fps_opts.find(int(g["fps_limit"]))), func(i: int): Settings.set_v("graphics", "fps_limit", fps_opts[i]))))
	c.add_child(UIKit.row(Loc.t("set.vsync"), UIKit.toggle(g["vsync"], _sv("graphics", "vsync"))))
	c.add_child(UIKit.row(Loc.t("set.fov"), UIKit.slider(g["fov"], 65, 105, 1, _sv("graphics", "fov"), "%.0f°")))
	c.add_child(UIKit.row("FPS", UIKit.toggle(g.get("show_fps", false), _sv("graphics", "show_fps"))))
	if not OS.has_feature("mobile"):
		c.add_child(UIKit.row(Loc.t("set.fullscreen"), UIKit.toggle(g["fullscreen"], _sv("graphics", "fullscreen"))))
		var res_names := []
		for r in Settings.RESOLUTIONS:
			res_names.append("%d × %d" % [r.x, r.y])
		c.add_child(UIKit.row(Loc.t("set.resolution"), UIKit.options(res_names, int(g.get("resolution", 1)), _sv("graphics", "resolution"))))
	c.add_child(UIKit.button(Loc.t("set.reset"), func():
		Settings.reset_section("graphics"); open("settings", false), 300))
	return t[0]

func _tab_audio() -> Control:
	var t := _scroll_tab("audio")
	var c: VBoxContainer = t[1]
	var a: Dictionary = Settings.data["audio"]
	for k in ["master", "music", "sfx", "voice"]:
		c.add_child(UIKit.row(Loc.t("set." + k), UIKit.slider(a[k], 0.0, 1.0, 0.05, _sv("audio", k))))
	c.add_child(UIKit.row(Loc.t("set.voice_lang"), UIKit.options([Loc.t("set.pt"), Loc.t("set.en")], 0 if Settings.get_v("access", "voice_lang", "pt") == "pt" else 1,
		func(i: int): Settings.set_v("access", "voice_lang", ["pt", "en"][i]))))
	return t[0]

func _tab_controls() -> Control:
	var t := _scroll_tab("controls")
	var c: VBoxContainer = t[1]
	var k: Dictionary = Settings.data["controls"]
	var dev_names := [Loc.t("set.kbm"), Loc.t("set.gamepad"), Loc.t("set.touch")]
	c.add_child(UIKit.label("%s: %s" % [Loc.t("set.device"), dev_names[InputRouter.device]], 18, UIKit.TEAL))
	c.add_child(UIKit.row(Loc.t("set.sens"), UIKit.slider(k["mouse_sens"], 0.02, 0.5, 0.01, _sv("controls", "mouse_sens"))))
	c.add_child(UIKit.row(Loc.t("set.pad_sens"), UIKit.slider(k["pad_sens"], 0.5, 8.0, 0.1, _sv("controls", "pad_sens"), "%.1f")))
	c.add_child(UIKit.row(Loc.t("set.touch_sens"), UIKit.slider(k["touch_sens"], 0.05, 0.8, 0.01, _sv("controls", "touch_sens"))))
	c.add_child(UIKit.row(Loc.t("set.invert_y"), UIKit.toggle(k["invert_y"], _sv("controls", "invert_y"))))
	c.add_child(UIKit.row(Loc.t("set.vibration"), UIKit.toggle(k["vibration"], _sv("controls", "vibration"))))
	c.add_child(UIKit.row(Loc.t("set.aim_assist"), UIKit.toggle(k["aim_assist"], _sv("controls", "aim_assist"))))
	c.add_child(UIKit.row(Loc.t("set.head_bob"), UIKit.toggle(k["head_bob"], _sv("controls", "head_bob"))))
	c.add_child(UIKit.label(Loc.t("set.touch_controls"), 20, UIKit.ACCENT))
	c.add_child(UIKit.row(Loc.t("set.touch_opacity"), UIKit.slider(k["touch_opacity"], 0.15, 1.0, 0.05, _sv("controls", "touch_opacity"))))
	c.add_child(UIKit.row(Loc.t("set.touch_size"), UIKit.slider(k["touch_scale"], 0.6, 1.6, 0.05, _sv("controls", "touch_scale"))))
	c.add_child(UIKit.button(Loc.t("menu.layout_edit"), func(): request_touch_edit.emit(), 420))
	c.add_child(UIKit.label(Loc.t("set.rebind").replace("...", "") + " (" + Loc.t("set.kbm") + ")", 20, UIKit.ACCENT))
	var prev_dev := InputRouter.device
	for action in InputRouter.REBINDABLE:
		var b := Button.new()
		InputRouter.device = InputRouter.Device.KBM
		b.text = InputRouter.binding_text(action)
		InputRouter.device = prev_dev
		b.custom_minimum_size = Vector2(220, 46)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func():
			_rebinding = action
			b.text = Loc.t("set.press_key"))
		c.add_child(UIKit.row(Loc.t("act." + action), b))
	var pad_info := UIKit.label("", 16, UIKit.DIM)
	InputRouter.device = InputRouter.Device.GAMEPAD
	var parts := []
	for a in ["jump", "crouch", "use", "reload", "fire", "aim", "sprint", "flashlight", "next_weapon", "pause"]:
		parts.append("%s: %s" % [Loc.t("act." + a), InputRouter.binding_text(a)])
	InputRouter.device = prev_dev
	pad_info.text = Loc.t("set.gamepad") + " — " + " · ".join(parts)
	c.add_child(pad_info)
	c.add_child(UIKit.button(Loc.t("set.reset"), func():
		Settings.reset_section("controls"); open("settings", false), 300))
	return t[0]

func _tab_access() -> Control:
	var t := _scroll_tab("access")
	var c: VBoxContainer = t[1]
	var a: Dictionary = Settings.data["access"]
	c.add_child(UIKit.row(Loc.t("set.language"), UIKit.options([Loc.t("set.pt"), Loc.t("set.en")], 0 if a["language"] == "pt" else 1, func(i: int):
		Settings.set_v("access", "language", ["pt", "en"][i])
		open("settings", false))))
	c.add_child(UIKit.row(Loc.t("set.subtitles"), UIKit.toggle(a["subtitles"], _sv("access", "subtitles"))))
	c.add_child(UIKit.row(Loc.t("set.sub_size"), UIKit.slider(a["sub_size"], 0.8, 1.8, 0.1, _sv("access", "sub_size"), "%.1f×")))
	c.add_child(UIKit.row(Loc.t("set.difficulty"), UIKit.options([Loc.t("set.easy"), Loc.t("set.normal"), Loc.t("set.hard")], int(a.get("difficulty", 1)), _sv("access", "difficulty"))))
	c.add_child(UIKit.row(Loc.t("set.camera_shake"), UIKit.slider(a.get("camera_shake", 1.0), 0.0, 1.0, 0.1, _sv("access", "camera_shake"), "%.1f")))
	return t[0]

# ---------------- créditos ----------------
const CREDITS := [
	["h", "ATMOSFERA ZERO"], ["p", "Um FPS original inspirado na atmosfera e nas ideias descartadas da fase beta (2001–2003) de um clássico do gênero."],
	["s", ""], ["h", "Direção, design e programação"], ["p", "Perplexity Computer (agente de IA) a pedido do produtor"],
	["s", ""], ["h", "Produtor"], ["p", "Construtor de Software — Curitiba, PR"],
	["s", ""], ["h", "Personagens"], ["p", "Tomás Varga · Bohdan · Irina Kovač · Cap. Anselm Kovač · Dr. Oskar Lindqvist · Dra. Marta Halden · Ezequiel Brandt · O Regente"],
	["s", ""], ["h", "Arte"], ["p", "Modelos, texturas PBR, cartazes e sinalização gerados proceduralmente por código (Python + GDScript)."],
	["s", ""], ["h", "Áudio"], ["p", "Efeitos, ambiências e trilha sintetizados proceduralmente.\nVozes PT-BR e EN geradas por síntese de voz (TTS)."],
	["s", ""], ["h", "Pesquisa histórica"], ["p", "Combine OverWiki · Half-Life Wiki (Fandom) · hl2-beta.ru · The Cutting Room Floor · ModDB · Valve Developer Community\n(somente referência conceitual; nenhum arquivo, modelo, mapa, som ou música proprietária foi utilizado)"],
	["s", ""], ["h", "Tecnologia"], ["p", "Godot Engine 4.3 (MIT) · Renderizador Mobile · GDScript"],
	["s", ""], ["h", "Aviso"], ["p", "Projeto de fã não oficial, sem afiliação com a Valve Corporation. Todos os nomes, personagens e cenários deste jogo são originais."],
	["s", ""], ["h", "Estado desta versão"], ["p", "Demo: Capítulos 1 a 3 jogáveis + Sala de Testes. Capítulos 4–12 em produção — ver docs/04_ROADMAP_E_STATUS.md."],
	["s", ""], ["s", ""], ["h", "Obrigado por jogar."],
]

func _credits(rolling: bool) -> Control:
	var root := Control.new()
	UIKit.full_rect(root)
	_credits_scroll = ScrollContainer.new()
	UIKit.full_rect(_credits_scroll)
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	_credits_scroll.add_child(col)
	var top := Control.new(); top.custom_minimum_size.y = 760 if rolling else 60; col.add_child(top)
	for e in CREDITS:
		match e[0]:
			"h": col.add_child(UIKit.label(e[1], 30, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
			"p": col.add_child(UIKit.label(e[1], 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			"s": var sp := Control.new(); sp.custom_minimum_size.y = 26; col.add_child(sp)
	var bottom := Control.new(); bottom.custom_minimum_size.y = 700 if rolling else 30; col.add_child(bottom)
	root.add_child(_credits_scroll)
	var b := UIKit.button(Loc.t("menu.back") if not rolling else Loc.t("menu.main_menu"), _finish_credits, 260)
	b.anchor_left = 1.0; b.anchor_right = 1.0; b.anchor_top = 1.0; b.anchor_bottom = 1.0
	b.position = Vector2(-290, -80)
	root.add_child(b)
	_credits_speed = 45.0 if rolling else 0.0
	if rolling:
		_stack = ["credits"]
	return root

func _finish_credits() -> void:
	_credits_speed = 0.0
	if Game.in_game:
		back()
	else:
		AudioBus.stop_theme()
		get_parent().show_main_menu()

func _process(delta: float) -> void:
	if _credits_speed > 0.0 and is_instance_valid(_credits_scroll):
		_credits_scroll.scroll_vertical += int(ceil(_credits_speed * delta))
		var vb := _credits_scroll.get_v_scroll_bar()
		if _credits_scroll.scroll_vertical >= int(vb.max_value - vb.page) - 2:
			_credits_speed = 0.0
