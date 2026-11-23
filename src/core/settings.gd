extends Node
## Configurações persistentes (user://settings.cfg): gráficos, áudio, controles, acessibilidade,
## layout dos controles de toque e remapeamento de teclas.

signal changed(section: String)

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

const PRESETS := {
	# render_scale, shadows(0-3), view_distance(m), particles(0-1), effects, texture_quality(0-2), msaa
	"low":    {"render_scale": 0.6,  "shadows": 0, "view_distance": 70.0,  "particles": 0.35, "effects": false, "msaa": 0, "decals": 16, "tex_quality": 0, "light_dist": 22.0},
	"medium": {"render_scale": 0.8,  "shadows": 1, "view_distance": 120.0, "particles": 0.65, "effects": true,  "msaa": 0, "decals": 32, "tex_quality": 1, "light_dist": 32.0},
	"high":   {"render_scale": 1.0,  "shadows": 2, "view_distance": 180.0, "particles": 1.0,  "effects": true,  "msaa": 1, "decals": 64, "tex_quality": 2, "light_dist": 45.0},
	"ultra":  {"render_scale": 1.0,  "shadows": 3, "view_distance": 260.0, "particles": 1.0,  "effects": true,  "msaa": 2, "decals": 128, "tex_quality": 3, "light_dist": 70.0},
}

var data := {
	"graphics": {"preset": "medium", "render_scale": 0.8, "shadows": 1, "view_distance": 120.0, "particles": 0.65,
		"effects": true, "msaa": 0, "decals": 32, "tex_quality": 1, "light_dist": 32.0, "fps_limit": 60, "vsync": true, "fullscreen": false, "fov": 80.0,
		"resolution": 1, "show_fps": false},
	"audio": {"master": 0.9, "music": 0.6, "sfx": 0.9, "voice": 1.0},
	"controls": {"mouse_sens": 0.12, "pad_sens": 3.2, "touch_sens": 0.22, "invert_y": false, "vibration": true,
		"aim_assist": true, "touch_opacity": 0.55, "touch_scale": 1.0, "head_bob": true},
	"access": {"difficulty": 1, "camera_shake": 1.0, "high_contrast": false, "subtitles": true, "sub_size": 1.0, "language": "pt", "voice_lang": "pt"},
	"touch_layout": {},   # nome_do_botao -> [x_rel, y_rel]
	"bindings": {},       # ação -> [{"type":"key","code":int} | {"type":"mouse","button":int}]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_default_preset()
	load_settings()
	# QA: força um preset pela linha de comando (AZ_PRESET=low|medium|high|ultra)
	if PRESETS.has(OS.get_environment("AZ_PRESET")):
		apply_preset(OS.get_environment("AZ_PRESET"), false)

func _detect_default_preset() -> void:
	# Primeira execução: Android começa em "low"/"medium" conforme a memória; PC em "high".
	if FileAccess.file_exists(PATH):
		return
	if OS.has_feature("mobile"):
		# Celular sempre começa em BAIXO: o jogador sobe o preset se o aparelho aguentar
		# (o painel de desempenho da Sala de Testes mostra o FPS real).
		apply_preset("low", false)
		data["graphics"]["fullscreen"] = true
	else:
		apply_preset("high", false)

func get_v(section: String, key: String, default = null):
	return data.get(section, {}).get(key, default)

func set_v(section: String, key: String, value, apply_now := true) -> void:
	if not data.has(section):
		data[section] = {}
	data[section][key] = value
	if section == "graphics" and key != "preset" and PRESETS.has(data["graphics"]["preset"]) and PRESETS[data["graphics"]["preset"]].has(key):
		data["graphics"]["preset"] = "custom"
	if apply_now:
		apply_all()
	changed.emit(section)

func apply_preset(name: String, apply_now := true) -> void:
	if not PRESETS.has(name):
		return
	for k in PRESETS[name]:
		data["graphics"][k] = PRESETS[name][k]
	data["graphics"]["preset"] = name
	if apply_now:
		apply_all()
	changed.emit("graphics")

func apply_all() -> void:
	var g: Dictionary = data["graphics"]
	Engine.max_fps = int(g["fps_limit"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g["vsync"] else DisplayServer.VSYNC_DISABLED)
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if g["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		if not g["fullscreen"]:
			var res: Vector2i = RESOLUTIONS[clampi(int(g.get("resolution", 1)), 0, RESOLUTIONS.size() - 1)]
			if DisplayServer.window_get_size() != res:
				DisplayServer.window_set_size(res)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = clampf(float(g["render_scale"]), 0.4, 1.0)
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(int(g["msaa"]), 0, 2)]
		vp.positional_shadow_atlas_size = [512, 1024, 2048, 4096][clampi(int(g["shadows"]), 0, 3)]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 2048, 4096][clampi(int(g["shadows"]), 0, 3)], true)
	Mats.set_quality(int(g.get("tex_quality", 1)))
	if is_inside_tree():
		var ld := float(g.get("light_dist", 32.0))
		for l in get_tree().get_nodes_in_group("az_lights"):
			if l is Light3D:
				l.distance_fade_begin = ld
				l.distance_fade_length = ld * 0.35
		for e in get_tree().get_nodes_in_group("az_env"):
			if e is WorldEnvironment and e.environment:
				e.environment.glow_enabled = bool(g["effects"]) and RenderingServer.get_rendering_device() != null and OS.get_environment("AZ_FORCE_COMPAT") == ""
	var a: Dictionary = data["audio"]
	for bus_name in ["Master", "Music", "SFX", "Voice"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var v: float = a.get(bus_name.to_lower(), 1.0)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	Loc.set_language(data["access"]["language"])
	InputRouter.apply_bindings(data["bindings"])

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for section in data:
		for key in data[section]:
			cfg.set_value(section, key, data[section][key])
	var err := cfg.save(PATH)
	if err != OK:
		push_error("Falha ao salvar configurações: %s" % err)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for section in cfg.get_sections():
			if not data.has(section):
				data[section] = {}
			for key in cfg.get_section_keys(section):
				data[section][key] = cfg.get_value(section, key)
		# configurações salvas por versões anteriores: completa chaves novas a partir do preset
		var pr: String = data["graphics"].get("preset", "")
		if PRESETS.has(pr):
			for k in PRESETS[pr]:
				if not cfg.has_section_key("graphics", k):
					data["graphics"][k] = PRESETS[pr][k]
	call_deferred("apply_all")

func reset_section(section: String) -> void:
	match section:
		"graphics":
			apply_preset("low" if OS.has_feature("mobile") else "high", false)
		"controls":
			data["controls"] = {"mouse_sens": 0.12, "pad_sens": 3.2, "touch_sens": 0.22, "invert_y": false, "vibration": true,
				"aim_assist": true, "touch_opacity": 0.55, "touch_scale": 1.0, "head_bob": true}
			data["bindings"] = {}
			data["touch_layout"] = {}
	apply_all()
	changed.emit(section)
