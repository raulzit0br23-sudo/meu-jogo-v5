class_name HUD
extends Control
## HUD: vitalidade/filtro, munição, mira, dica de interação, objetivo, legendas com nome do falante,
## avisos (checkpoint, autosave, item), indicadores de direção de dano, vinheta, tela de morte e inventário.

var player: Player
var _hp: Label
var _hp_bar: ProgressBar
var _filter: Label
var _filter_bar: ProgressBar
var _ammo: Label
var _ammo_res: Label
var _wname: Label
var _cross: Control
var _hint: Label
var _obj_box: PanelContainer
var _obj: Label
var _sub_box: PanelContainer
var _sub: RichTextLabel
var _sub_t := 0.0
var _notice: Label
var _notice_t := 0.0
var _vignette: ColorRect
var _dmg_arrows: Array = []
var _death: Control
var _inv: Control
var _inv_list: VBoxContainer
var _fps: Label
var _obj_t := 0.0

const SPEAKER_COLORS := {"Bohdan": "#e6b36a", "Irina": "#7fd1c4", "Alto-falante": "#9aa5a8", "O Regente": "#d07a6a", "Vigilante": "#a8b8c0"}

func _ready() -> void:
	add_to_group("hud")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.full_rect(self)
	theme = UIKit.theme()
	_vignette = ColorRect.new()
	UIKit.full_rect(_vignette)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; uniform float amount = 0.0; uniform vec4 tint : source_color = vec4(0.6,0.02,0.0,1.0);\nvoid fragment(){ float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.8, d) * amount); }"
	var sm := ShaderMaterial.new(); sm.shader = sh
	_vignette.material = sm
	sm.set_shader_parameter("amount", 0.0)
	add_child(_vignette)
	# vitalidade (inferior esquerdo)
	var vb := VBoxContainer.new()
	vb.anchor_top = 1.0; vb.anchor_bottom = 1.0
	vb.offset_left = 28; vb.offset_top = -150; vb.offset_right = 288; vb.offset_bottom = -20
	vb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	var r1 := HBoxContainer.new(); vb.add_child(r1)
	var l1 := UIKit.label(Loc.t("hud.health").to_upper(), 16, UIKit.DIM); l1.autowrap_mode = TextServer.AUTOWRAP_OFF
	l1.custom_minimum_size.x = 92; l1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r1.add_child(l1)
	_hp = UIKit.label("100", 40, UIKit.ACCENT); _hp.autowrap_mode = TextServer.AUTOWRAP_OFF; r1.add_child(_hp)
	_hp_bar = _bar(UIKit.ACCENT); vb.add_child(_hp_bar)
	var r2 := HBoxContainer.new(); vb.add_child(r2)
	var l2 := UIKit.label(Loc.t("hud.suit").to_upper(), 16, UIKit.DIM); l2.autowrap_mode = TextServer.AUTOWRAP_OFF
	l2.custom_minimum_size.x = 92; l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r2.add_child(l2)
	_filter = UIKit.label("0", 28, UIKit.TEAL); _filter.autowrap_mode = TextServer.AUTOWRAP_OFF; r2.add_child(_filter)
	_filter_bar = _bar(UIKit.TEAL); vb.add_child(_filter_bar)
	# munição (inferior direito)
	var ab := VBoxContainer.new()
	ab.anchor_left = 1.0; ab.anchor_right = 1.0; ab.anchor_top = 1.0; ab.anchor_bottom = 1.0
	ab.offset_left = -480; ab.offset_top = -140; ab.offset_right = -28; ab.offset_bottom = -20
	ab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ab.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ab.alignment = BoxContainer.ALIGNMENT_END
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ab)
	_wname = UIKit.label("", 16, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT); ab.add_child(_wname)
	var ar := HBoxContainer.new(); ar.alignment = BoxContainer.ALIGNMENT_END; ab.add_child(ar)
	_ammo = UIKit.label("", 44, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT); ar.add_child(_ammo)
	_ammo_res = UIKit.label("", 24, UIKit.DIM); ar.add_child(_ammo_res)
	for l: Label in [_ammo, _ammo_res, _wname]:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	# mira
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	add_child(_cross)
	# dica de interação
	_hint = UIKit.label("", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_preset(Control.PRESET_CENTER)
	_hint.position = Vector2(-300, 40); _hint.custom_minimum_size.x = 600
	add_child(_hint)
	# objetivo
	_obj_box = PanelContainer.new()
	_obj_box.position = Vector2(24, 24)
	_obj_box.add_theme_stylebox_override("panel", UIKit.sb(Color(0.03, 0.04, 0.04, 0.6), Color(0.95, 0.62, 0.25, 0.6), 0, 2, 14))
	_obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov := VBoxContainer.new(); _obj_box.add_child(ov)
	ov.add_child(UIKit.label(Loc.t("hud.objective").to_upper(), 14, UIKit.ACCENT))
	_obj = UIKit.label("", 20); _obj.custom_minimum_size.x = 360; ov.add_child(_obj)
	_obj_box.modulate.a = 0.0
	add_child(_obj_box)
	# legendas
	_sub_box = PanelContainer.new()
	_sub_box.anchor_left = 0.5; _sub_box.anchor_right = 0.5; _sub_box.anchor_top = 1.0; _sub_box.anchor_bottom = 1.0
	_sub_box.add_theme_stylebox_override("panel", UIKit.sb(Color(0, 0, 0, 0.62), Color(0, 0, 0, 0), 0, 3, 16))
	_sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.custom_minimum_size = Vector2(760, 0)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_box.add_child(_sub)
	_sub_box.visible = false
	add_child(_sub_box)
	# avisos
	_notice = UIKit.label("", 20, UIKit.TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	_notice.anchor_left = 1.0; _notice.anchor_right = 1.0
	_notice.position = Vector2(-520, 24); _notice.custom_minimum_size.x = 490
	add_child(_notice)
	for i in 4:
		var a := Label.new()
		a.text = ["▲", "▶", "▼", "◀"][i]
		a.add_theme_font_size_override("font_size", 46)
		a.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1))
		a.set_anchors_preset(Control.PRESET_CENTER)
		a.position = [Vector2(-14, -170), Vector2(150, -28), Vector2(-14, 110), Vector2(-180, -28)][i]
		a.modulate.a = 0.0
		add_child(a)
		_dmg_arrows.append(a)
	_fps = UIKit.label("", 14, UIKit.DIM)
	_fps.anchor_left = 1.0; _fps.anchor_right = 1.0
	_fps.position = Vector2(-110, 2)
	add_child(_fps)
	_build_death()
	_build_inventory()
	Dialogue.line_started.connect(_on_line)
	Game.objective_changed.connect(_on_objective)
	Game.checkpoint_reached.connect(func(_id): notice(Loc.t("hud.checkpoint")))
	Game.game_saved.connect(func(slot): notice(Loc.t("hud.autosave") if slot == "auto" else Loc.t("menu.saved")))
	Game.player_died.connect(_on_died)
	if Game.objective_key != "":
		_on_objective(Game.objective_key)

func _bar(c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(220, 6)
	b.max_value = 100
	var f := UIKit.sb(c, Color(0, 0, 0, 0), 0, 1, 0)
	b.add_theme_stylebox_override("fill", f)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func bind_player(p: Player) -> void:
	player = p
	p.health_changed.connect(_on_health)
	p.interact_hint.connect(func(t: String): _hint.text = t)
	p.weapons.ammo_changed.connect(_on_ammo)
	if not p.weapons.notice.is_connected(notice):
		p.weapons.notice.connect(notice)
	p.died.connect(_on_died)
	_on_health(p.health, p.filter)
	p.weapons._emit_ammo()
	_death.visible = false

func _on_health(hp: float, f: float) -> void:
	_hp.text = str(int(ceil(hp)))
	_hp_bar.value = hp
	_filter.text = str(int(f))
	_filter_bar.value = f
	_hp.add_theme_color_override("font_color", UIKit.DANGER if hp < 25 else UIKit.ACCENT)

func _on_ammo(c: int, r: int, n: String) -> void:
	_wname.text = n.to_upper()
	_ammo.text = "" if c < 0 else str(c)
	_ammo_res.text = "" if r < 0 else "  /" + str(r)

func _on_objective(key: String) -> void:
	_obj.text = Loc.t(key)
	_obj_t = 9.0
	if key != "":
		notice(Loc.t("hud.objective_updated"))

func _on_line(speaker: String, text: String, dur: float) -> void:
	if not Settings.get_v("access", "subtitles", true):
		return
	var col: String = SPEAKER_COLORS.get(speaker, "#d8d4c8")
	var size := int(24 * float(Settings.get_v("access", "sub_size", 1.0)))
	_sub.text = "[center][font_size=%d][color=%s]%s:[/color] %s[/font_size][/center]" % [size, col, speaker, text]
	_sub_box.visible = true
	_sub_t = dur + 0.6

func notice(t: String) -> void:
	_notice.text = t
	_notice_t = 3.0

func flash_pickup(t: String) -> void:
	notice("+ " + t)

func show_damage_dir(world_dir: Vector3) -> void:
	if player == null:
		return
	var local := player.global_basis.inverse() * world_dir
	var ang := atan2(local.x, -local.z)   # 0 = frente
	var idx := int(round(ang / (PI * 0.5))) % 4
	if idx < 0: idx += 4
	_dmg_arrows[idx].modulate.a = 1.0
	(_vignette.material as ShaderMaterial).set_shader_parameter("amount", 0.8)

func _draw_cross() -> void:
	var c := Color(0.9, 0.88, 0.8, 0.75)
	var g := 6.0
	if player and player.weapons.current != "" and player.weapons.DEFS[player.weapons.current].get("type", "") != "melee":
		g = 6.0 + player.velocity.length() * 1.5
	_cross.draw_line(Vector2(-g - 8, 0), Vector2(-g, 0), c, 2.0)
	_cross.draw_line(Vector2(g, 0), Vector2(g + 8, 0), c, 2.0)
	_cross.draw_line(Vector2(0, g), Vector2(0, g + 8), c, 2.0)
	_cross.draw_circle(Vector2.ZERO, 1.5, c)

func _process(delta: float) -> void:
	_cross.queue_redraw()
	_cross.visible = player != null and player.alive and not player.weapons.is_aiming()
	_sub_t -= delta
	if _sub_t <= 0.0:
		_sub_box.visible = false
	_sub_box.position = Vector2(-_sub_box.size.x * 0.5, -_sub_box.size.y - 170)
	_notice_t -= delta
	_notice.modulate.a = clampf(_notice_t, 0.0, 1.0)
	_obj_t -= delta
	_obj_box.modulate.a = clampf(_obj_t, 0.0, 1.0) if not _inv.visible else 1.0
	for a in _dmg_arrows:
		a.modulate.a = maxf(0.0, a.modulate.a - delta * 1.2)
	var sm := _vignette.material as ShaderMaterial
	var amt := float(sm.get_shader_parameter("amount")) if sm.get_shader_parameter("amount") != null else 0.0
	var low := 0.0
	if is_instance_valid(player):
		low = clampf((30.0 - player.health) / 30.0, 0.0, 1.0) * (0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.006))
	sm.set_shader_parameter("amount", maxf(low, amt - delta * 1.5))
	if Settings.get_v("graphics", "show_fps", false):
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	else:
		_fps.text = ""

func objective_peek() -> void:
	_obj_t = 5.0

# ---------------- morte ----------------
func _build_death() -> void:
	_death = ColorRect.new()
	(_death as ColorRect).color = Color(0.05, 0, 0, 0.55)
	UIKit.full_rect(_death)
	var v := UIKit.centered_column(24)
	UIKit.full_rect(v)
	v.add_child(UIKit.label(Loc.t("hud.dead").to_upper(), 48, UIKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var c := CenterContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.add_child(UIKit.button(Loc.t("hud.retry"), func(): Game.retry()))
	inner.add_child(UIKit.button(Loc.t("menu.main_menu"), func(): Game.quit_to_menu()))
	c.add_child(inner)
	v.add_child(c)
	_death.add_child(v)
	_death.visible = false
	add_child(_death)

func _on_died() -> void:
	if _death.visible:
		return
	await get_tree().create_timer(1.4).timeout
	_death.visible = true
	_death.modulate.a = 0.0
	create_tween().tween_property(_death, "modulate:a", 1.0, 0.6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UIKit.focus_first(_death)

# ---------------- inventário ----------------
func _build_inventory() -> void:
	_inv = PanelContainer.new()
	_inv.set_anchors_preset(Control.PRESET_CENTER)
	_inv.custom_minimum_size = Vector2(560, 360)
	_inv.position = Vector2(-280, -200)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UIKit.label(Loc.t("inv.title").to_upper(), 26, UIKit.ACCENT))
	_inv_list = VBoxContainer.new()
	v.add_child(_inv_list)
	_inv.add_child(v)
	_inv.visible = false
	add_child(_inv)

func toggle_inventory() -> void:
	_inv.visible = not _inv.visible
	if not _inv.visible or player == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (_inv.visible == false and InputRouter.device == InputRouter.Device.KBM) else Input.mouse_mode
		return
	for c in _inv_list.get_children():
		c.queue_free()
	_inv_list.add_child(UIKit.label(Loc.t("inv.weapons"), 18, UIKit.DIM))
	var wm := player.weapons
	for id in wm.owned:
		var d: Dictionary = wm.DEFS[id]
		var txt: String = Loc.t(d["name"])
		if d.has("ammo"):
			txt += "   %d / %d" % [wm.clip[id], wm.reserve[d["ammo"]]]
		var b := UIKit.button(txt, func():
			wm.equip(id)
			toggle_inventory(), 500)
		_inv_list.add_child(b)
	_inv_list.add_child(UIKit.label(Loc.t("inv.items"), 18, UIKit.DIM))
	var items := "%s: %s    %s: %d%%" % [Loc.t("item.filter"), "✓" if player.has_mask else "—", Loc.t("hud.suit"), int(player.filter)]
	_inv_list.add_child(UIKit.label(items, 20))
	_inv_list.add_child(UIKit.label("%s: %s" % [Loc.t("hud.objective"), Loc.t(Game.objective_key)], 18, UIKit.TEXT))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UIKit.focus_first(_inv_list)

func inventory_open() -> bool:
	return _inv.visible
