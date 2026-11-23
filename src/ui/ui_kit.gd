class_name UIKit
## Tema visual (gerado em código) e construtores de widgets acessíveis por toque, controle e teclado.
## Estética: painéis de aço escuro, texto osso, destaque âmbar de lâmpada de sódio.

const BG := Color(0.035, 0.045, 0.05, 0.92)
const PANEL := Color(0.07, 0.085, 0.09, 0.94)
const LINE := Color(0.3, 0.33, 0.31)
const TEXT := Color(0.86, 0.84, 0.78)
const DIM := Color(0.55, 0.56, 0.52)
const ACCENT := Color(0.95, 0.62, 0.25)
const DANGER := Color(0.85, 0.25, 0.2)
const TEAL := Color(0.35, 0.75, 0.7)

static var _theme: Theme

static func sb(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 2, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", sb(Color(0.1, 0.115, 0.12, 0.9), LINE, 1, 2, 16))
	t.set_stylebox("hover", "Button", sb(Color(0.16, 0.15, 0.12, 0.95), ACCENT, 1, 2, 16))
	t.set_stylebox("pressed", "Button", sb(Color(0.25, 0.17, 0.08, 1.0), ACCENT, 2, 2, 16))
	t.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), ACCENT, 2, 2, 16))
	t.set_stylebox("disabled", "Button", sb(Color(0.06, 0.065, 0.07, 0.8), Color(0.18, 0.19, 0.18), 1, 2, 16))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color(1, 0.85, 0.6))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.38))
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, LINE, 1, 3, 18))
	t.set_stylebox("panel", "Panel", sb(PANEL, LINE, 1, 3, 18))
	var slider_bg := sb(Color(0.15, 0.16, 0.16), Color(0, 0, 0, 0), 0, 2, 0)
	slider_bg.content_margin_top = 4; slider_bg.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider_bg)
	var fill := sb(ACCENT * Color(1, 1, 1, 0.8), Color(0, 0, 0, 0), 0, 2, 0)
	fill.content_margin_top = 4; fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _grabber_tex()
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	t.set_stylebox("focus", "HSlider", sb(Color(0, 0, 0, 0), ACCENT, 2, 2, 4))
	t.set_stylebox("normal", "OptionButton", t.get_stylebox("normal", "Button"))
	t.set_stylebox("hover", "OptionButton", t.get_stylebox("hover", "Button"))
	t.set_stylebox("focus", "OptionButton", t.get_stylebox("focus", "Button"))
	t.set_stylebox("pressed", "OptionButton", t.get_stylebox("pressed", "Button"))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", sb(PANEL, ACCENT, 1, 2, 8))
	t.set_font_size("font_size", "PopupMenu", 22)
	t.set_stylebox("normal", "CheckButton", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2, 8))
	t.set_stylebox("focus", "CheckButton", sb(Color(0, 0, 0, 0), ACCENT, 2, 2, 8))
	t.set_stylebox("tab_selected", "TabBar", sb(Color(0.2, 0.15, 0.09), ACCENT, 1, 2, 14))
	t.set_stylebox("tab_unselected", "TabBar", sb(Color(0.08, 0.09, 0.095), LINE, 1, 2, 14))
	t.set_stylebox("tab_hovered", "TabBar", sb(Color(0.14, 0.13, 0.1), ACCENT, 1, 2, 14))
	t.set_stylebox("tab_focus", "TabBar", sb(Color(0, 0, 0, 0), ACCENT, 2, 2, 14))
	t.set_color("font_selected_color", "TabBar", ACCENT)
	t.set_color("font_unselected_color", "TabBar", DIM)
	t.set_stylebox("panel", "TabContainer", sb(Color(0.05, 0.06, 0.065, 0.6), LINE, 1, 2, 16))
	t.set_stylebox("tab_selected", "TabContainer", t.get_stylebox("tab_selected", "TabBar"))
	t.set_stylebox("tab_unselected", "TabContainer", t.get_stylebox("tab_unselected", "TabBar"))
	t.set_stylebox("tab_hovered", "TabContainer", t.get_stylebox("tab_hovered", "TabBar"))
	t.set_stylebox("tab_focus", "TabContainer", t.get_stylebox("tab_focus", "TabBar"))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_stylebox("background", "ProgressBar", sb(Color(0.1, 0.1, 0.1, 0.7), Color(0, 0, 0, 0), 0, 1, 0))
	t.set_stylebox("fill", "ProgressBar", sb(ACCENT, Color(0, 0, 0, 0), 0, 1, 0))
	t.set_constant("v_grab_scroll", "ScrollContainer", 1)
	_theme = t
	return t

static func _grabber_tex() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d := Vector2(x - 11.5, y - 11.5).length()
			img.set_pixel(x, y, Color(0.95, 0.75, 0.45, clampf(11.0 - d, 0, 1)))
	return ImageTexture.create_from_image(img)

static func label(text: String, size := 22, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable, min_w := 340) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		AudioBus.play_ui("ui_accept")
		cb.call())
	b.focus_entered.connect(func(): AudioBus.play_ui("ui_move", -14.0))
	b.mouse_entered.connect(func(): if InputRouter.device == InputRouter.Device.KBM: b.grab_focus())
	return b

## Linha de configuração com rótulo e controle (slider, alternador, opções).
static func row(title: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size.y = 54
	var l := label(title, 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	control.custom_minimum_size.x = 320
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	return h

static func slider(value: float, mn: float, mx: float, step: float, cb: Callable, fmt := "%.2f") -> HBoxContainer:
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = mn; s.max_value = mx; s.step = step; s.value = value
	s.custom_minimum_size = Vector2(240, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	var v := label(fmt % value, 18, DIM)
	v.custom_minimum_size.x = 70
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(x: float):
		v.text = fmt % x
		cb.call(x))
	h.add_child(s)
	h.add_child(v)
	return h

static func toggle(on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(x: bool):
		AudioBus.play_ui("ui_move", -10.0)
		cb.call(x))
	return c

static func options(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, items.size() - 1))
	o.focus_mode = Control.FOCUS_ALL
	o.custom_minimum_size.y = 50
	o.item_selected.connect(func(i: int):
		AudioBus.play_ui("ui_accept", -10.0)
		cb.call(i))
	return o

static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

static func centered_column(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v

## Foca o primeiro controle focável (navegação por controle/teclado).
static func focus_first(root: Node) -> void:
	if InputRouter.device == InputRouter.Device.TOUCH:
		return
	var c := _first_focusable(root)
	if c:
		c.call_deferred("grab_focus")

static func _first_focusable(n: Node) -> Control:
	for ch in n.get_children():
		if ch is Control and ch.visible:
			if ch.focus_mode == Control.FOCUS_ALL and not (ch is Button and ch.disabled):
				return ch
			var r := _first_focusable(ch)
			if r:
				return r
	return null
