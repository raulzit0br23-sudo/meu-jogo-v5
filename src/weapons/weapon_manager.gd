class_name WeaponManager
extends Node3D
## Arsenal do jogador: definição de armas, inventário de munição, disparo hitscan com dispersão,
## modos de tiro (automático / rajada / semi), disparo alternativo, luneta, projéteis, arremessáveis,
## lança-chamas, recuo, corpo a corpo, recarga (pente ou cartucho a cartucho), mira, assistência de mira
## e viewmodels procedurais animados (saque, disparo, recarga, balanço, oscilação).
##
## O arsenal é ORIGINAL, inspirado nas armas cortadas do Half-Life 2 Beta documentadas em
## combineoverwiki.net / half-life.fandom.com (ver docs/06_ARSENAL_E_PERSONAGENS.md). Nenhum modelo,
## som ou textura da Valve é usado.

signal ammo_changed(clip: int, reserve: int, weapon_name: String)
signal weapon_switched(id: String)
signal notice(text: String)

## type: melee | manip | gun | proj | throw | flame | beam | binoc
const DEFS := {
	# --- slot 1: corpo a corpo
	"wrench": {"slot": 1, "type": "melee", "damage": 28.0, "rate": 0.48, "range": 1.9, "name": "item.wrench"},
	"iceaxe": {"slot": 1, "type": "melee", "damage": 38.0, "rate": 0.62, "range": 2.0, "heavy": 85.0, "name": "item.iceaxe"},
	"crowbar": {"slot": 1, "type": "melee", "damage": 25.0, "rate": 0.4, "range": 1.9, "name": "item.crowbar"},
	"stunbaton": {"slot": 1, "type": "melee", "damage": 22.0, "rate": 0.45, "range": 1.9, "dmg_type": "shock", "name": "item.stunbaton"},
	# --- slot 2: armas de mão
	"pistol": {"slot": 2, "type": "gun", "damage": 15.0, "rate": 0.16, "auto": false, "mag": 15, "ammo": "9mm", "spread": 0.7,
		"recoil": 1.3, "range": 120.0, "sound": "pistol_fire", "reload_t": 1.3, "reload_snd": "reload_pistol", "name": "item.pistol"},
	"magnum": {"slot": 2, "type": "gun", "damage": 75.0, "rate": 0.75, "auto": false, "mag": 6, "ammo": "357", "spread": 0.35,
		"recoil": 8.0, "range": 220.0, "sound": "magnum_fire", "reload_t": 3.0, "reload_snd": "magnum_reload", "zoom": 0.7, "name": "item.magnum"},
	"flaregun": {"slot": 2, "type": "proj", "proj": "flare", "rate": 0.5, "mag": 1, "ammo": "flare", "recoil": 2.0,
		"sound": "flare_fire", "reload_t": 1.1, "reload_snd": "reload_pistol", "name": "item.flaregun"},
	# --- slot 3: automáticas
	"smg1": {"slot": 3, "type": "gun", "damage": 8.0, "rate": 0.068, "auto": true, "mag": 30, "ammo": "9mm", "spread": 2.0,
		"recoil": 0.45, "range": 90.0, "sound": "smg1_fire", "reload_t": 1.5, "reload_snd": "reload_smg", "name": "item.smg1"},
	"smg": {"slot": 3, "type": "gun", "damage": 9.0, "rate": 0.075, "auto": true, "mag": 60, "ammo": "9mm", "spread": 2.4,
		"recoil": 0.55, "range": 90.0, "sound": "smg_fire", "reload_t": 1.8, "reload_snd": "reload_smg", "modes": ["auto", "burst"], "name": "item.smg"},
	"ar1": {"slot": 3, "type": "gun", "damage": 13.0, "rate": 0.1, "auto": true, "mag": 30, "ammo": "762", "spread": 1.8,
		"recoil": 0.95, "range": 140.0, "sound": "ar1_fire", "reload_t": 2.0, "reload_snd": "reload_rifle", "modes": ["auto", "burst", "semi"], "name": "item.ar1"},
	"oicw": {"slot": 3, "type": "gun", "damage": 11.0, "rate": 0.095, "auto": true, "mag": 30, "ammo": "556", "spread": 1.3,
		"recoil": 0.7, "range": 160.0, "sound": "oicw_fire", "reload_t": 2.1, "reload_snd": "reload_rifle", "zoom": 0.4, "scope": true,
		"alt": "gren20", "alt_ammo": "20mm", "name": "item.oicw"},
	"ar2": {"slot": 3, "type": "gun", "damage": 11.0, "rate": 0.1, "auto": true, "mag": 30, "ammo": "ar2", "spread": 1.1,
		"recoil": 0.75, "range": 160.0, "sound": "ar2_fire", "reload_t": 1.6, "reload_snd": "ar2_reload", "tracer": Color(0.5, 0.85, 1.0),
		"alt": "cball", "alt_ammo": "cball", "name": "item.ar2"},
	# --- slot 4: pesadas
	"shotgun": {"slot": 4, "type": "gun", "damage": 9.0, "pellets": 8, "rate": 0.85, "auto": false, "mag": 6, "ammo": "12", "spread": 6.5,
		"recoil": 4.5, "range": 45.0, "sound": "shotgun_fire", "shell_reload": true, "reload_t": 0.5, "reload_snd": "shotgun_shell",
		"alt": "double", "name": "item.shotgun"},
	"hmg": {"slot": 4, "type": "gun", "damage": 14.0, "rate": 0.088, "auto": true, "mag": 100, "ammo": "762", "spread": 3.2,
		"recoil": 0.9, "range": 140.0, "sound": "hmg_fire", "reload_t": 3.2, "reload_snd": "reload_hmg", "speed": 0.78,
		"modes": ["auto", "burst"], "name": "item.hmg"},
	"sniper": {"slot": 4, "type": "gun", "damage": 95.0, "rate": 1.35, "auto": false, "mag": 5, "ammo": "338", "spread": 2.8, "scoped_spread": 0.02,
		"recoil": 6.0, "range": 400.0, "sound": "sniper_fire", "reload_t": 2.4, "reload_snd": "reload_rifle", "zoom": 0.16, "scope": true,
		"bolt": "sniper_bolt", "name": "item.sniper"},
	"crossbow": {"slot": 4, "type": "proj", "proj": "xbolt", "rate": 0.3, "mag": 1, "ammo": "xbolt", "recoil": 3.0, "zoom": 0.22, "scope": true,
		"sound": "crossbow_fire", "reload_t": 1.8, "reload_snd": "crossbow_reload", "name": "item.crossbow"},
	# --- slot 5: especiais
	"manipulator": {"slot": 5, "type": "manip", "manip": true, "rate": 0.5, "range": 12.0, "pull_range": 11.0, "max_mass": 150.0, "name": "item.manipulator"},
	"gravitygun": {"slot": 5, "type": "manip", "manip": true, "rate": 0.45, "range": 14.0, "pull_range": 13.0, "max_mass": 250.0,
		"punt": 30.0, "fx": Color(1.0, 0.62, 0.2), "name": "item.gravitygun"},
	"physgun": {"slot": 5, "type": "manip", "phys": true, "rate": 0.3, "range": 45.0, "max_mass": 450.0, "fx": Color(0.35, 0.65, 1.0), "name": "item.physgun"},
	"rpg": {"slot": 5, "type": "proj", "proj": "rocket", "rate": 1.4, "mag": 1, "ammo": "rocket", "recoil": 3.8, "laser": true,
		"sound": "rocket_fire", "reload_t": 1.9, "reload_snd": "reload_hmg", "alt": "guide", "name": "item.rpg"},
	"missile": {"slot": 5, "type": "proj", "proj": "rocket", "rate": 1.2, "mag": 1, "ammo": "rocket", "recoil": 3.5,
		"sound": "rocket_fire", "reload_t": 1.8, "reload_snd": "reload_hmg", "alt": "guide", "name": "item.missile"},
	"immolator": {"slot": 5, "type": "flame", "rate": 0.07, "ammo": "fuel", "range": 7.5, "damage": 4.0, "name": "item.immolator"},
	"irifle": {"slot": 5, "type": "proj", "proj": "bolt_inc", "rate": 0.55, "mag": 5, "ammo": "bolt", "recoil": 2.2, "zoom": 0.5,
		"sound": "irifle_fire", "reload_t": 2.0, "reload_snd": "reload_rifle", "name": "item.irifle"},
	"guardgun": {"slot": 5, "type": "beam", "rate": 1.6, "ammo": "guard", "charge": 0.75, "damage": 160.0, "radius": 3.2, "name": "item.guardgun"},
	# --- slot 6: arremessáveis e utilidades
	"grenade": {"slot": 6, "type": "throw", "throw": "grenade", "rate": 1.0, "ammo": "grenade", "name": "item.grenade"},
	"molotov": {"slot": 6, "type": "throw", "throw": "molotov", "rate": 1.0, "ammo": "molotov", "name": "item.molotov"},
	"hopwire": {"slot": 6, "type": "throw", "throw": "hopwire", "rate": 1.0, "ammo": "hopwire", "name": "item.hopwire"},
	"slam": {"slot": 6, "type": "throw", "throw": "slam", "rate": 0.8, "ammo": "slam", "alt": "detonate", "name": "item.slam"},
	"brickbat": {"slot": 6, "type": "throw", "throw": "brick", "rate": 0.6, "ammo": "brick", "name": "item.brickbat"},
	"bugbait": {"slot": 6, "type": "throw", "throw": "bugbait", "rate": 0.8, "ammo": "bugbait", "alt": "squeeze", "name": "item.bugbait"},
	"binoculars": {"slot": 6, "type": "binoc", "rate": 0.3, "zoom": 0.2, "scope": true, "name": "item.binoculars"},
}
const MAX_AMMO := {"9mm": 180, "12": 36, "762": 240, "556": 180, "20mm": 6, "338": 30, "flare": 12, "rocket": 5,
	"fuel": 300, "bolt": 25, "guard": 10, "grenade": 5, "molotov": 5, "hopwire": 3, "slam": 5, "brick": 10,
	"357": 18, "ar2": 90, "cball": 3, "xbolt": 10, "bugbait": 9}
## Quantidade recebida ao pegar a arma pela primeira vez (armas sem pente).
const GIVE_AMMO := {"fuel": 150, "guard": 4, "grenade": 2, "molotov": 2, "hopwire": 1, "slam": 2, "brick": 5, "bugbait": 5}

var player: Node
var owned: Array[String] = []
var clip := {}
var reserve := {}
var current := ""
var _models := {}
var _view_root: Node3D
var _cool := 0.0
var _reloading := 0.0
var _reload_step := 0.0
var _draw_t := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _bob_amp := 0.0
var _aiming := false
var _aim_blend := 0.0
var _holstered := false
var _muzzle_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_t := 0.0
var _trigger_held_last := false
var _aim_held_last := false
var _manip_snd: AudioStreamPlayer
var _manip_glow := 0.0
var mode := {}               # id -> índice em DEFS[id].modes
var guided := true
var _burst_left := 0
var _charge := -1.0
var _flame_fx: CPUParticles3D
var _flame_snd: AudioStreamPlayer
var _flame_area_t := 0.0
var _scope: Control
var _bolt_t := -1.0

func setup(p: Node) -> void:
	player = p
	for k in MAX_AMMO:
		reserve[k] = 0
	_view_root = Node3D.new(); _view_root.name = "ViewRoot"
	add_child(_view_root)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.omni_range = 6.0; _muzzle_light.light_energy = 0.0; _muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	_view_root.add_child(_muzzle_light)
	_flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16)
	_flash_mesh.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if ResourceLoader.exists("res://assets/textures/fx_muzzle.png"):
		fm.albedo_texture = load("res://assets/textures/fx_muzzle.png")
	fm.albedo_color = Color(1.0, 0.8, 0.5)
	fm.no_depth_test = true
	_flash_mesh.material_override = fm
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view_root.add_child(_flash_mesh)
	var cl := CanvasLayer.new(); cl.layer = 4
	add_child(cl)
	_scope = ScopeOverlay.new()
	_scope.visible = false
	cl.add_child(_scope)

## Luneta: escurece fora do círculo, retículo fino e marcações. Desenho 2D simples (barato).
class ScopeOverlay extends Control:
	var binoc := false
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var r := s.y * 0.46
		var black := Color(0, 0, 0, 1)
		if binoc:
			var c1 := c - Vector2(r * 0.55, 0); var c2 := c + Vector2(r * 0.55, 0)
			# máscara aproximada: faixas + anéis grossos
			draw_rect(Rect2(0, 0, s.x, c.y - r * 0.8), black)
			draw_rect(Rect2(0, c.y + r * 0.8, s.x, s.y), black)
			draw_rect(Rect2(0, 0, c1.x - r * 0.8, s.y), black)
			draw_rect(Rect2(c2.x + r * 0.8, 0, s.x, s.y), black)
			draw_arc(c1, r * 0.8 + 60.0, 0, TAU, 64, black, 120.0)
			draw_arc(c2, r * 0.8 + 60.0, 0, TAU, 64, black, 120.0)
			draw_line(c - Vector2(40, 0), c + Vector2(40, 0), Color(0.6, 0.9, 0.6, 0.6), 1.0)
			for i in range(-4, 5):
				draw_line(c + Vector2(i * 20, -4), c + Vector2(i * 20, 4), Color(0.6, 0.9, 0.6, 0.6), 1.0)
			return
		draw_rect(Rect2(0, 0, c.x - r, s.y), black)
		draw_rect(Rect2(c.x + r, 0, s.x, s.y), black)
		draw_arc(c, r + s.y * 0.25, 0, TAU, 96, black, s.y * 0.5)
		draw_arc(c, r, 0, TAU, 96, Color(0.05, 0.05, 0.05), 3.0)
		var lc := Color(0.05, 0.05, 0.05, 0.9)
		draw_line(c - Vector2(r, 0), c - Vector2(14, 0), lc, 2.0)
		draw_line(c + Vector2(14, 0), c + Vector2(r, 0), lc, 2.0)
		draw_line(c - Vector2(0, r), c - Vector2(0, 14), lc, 2.0)
		draw_line(c + Vector2(0, 14), c + Vector2(0, r), lc, 2.0)
		for i in range(1, 5):
			draw_line(c + Vector2(-6, i * 22), c + Vector2(6, i * 22), lc, 1.5)
		draw_circle(c, 1.5, Color(1.0, 0.3, 0.2))

# ---------------- inventário ----------------
func give(id: String, with_ammo := true) -> bool:
	if not DEFS.has(id):
		return false
	var d: Dictionary = DEFS[id]
	var fresh := not owned.has(id)
	if fresh:
		owned.append(id)
		owned.sort_custom(func(a, b): return DEFS[a]["slot"] * 100 + _order(a) < DEFS[b]["slot"] * 100 + _order(b))
		clip[id] = d.get("mag", 0)
		_models[id] = ViewModels.build(id)
		_models[id].visible = false
		_view_root.add_child(_models[id])
		if d.has("ammo") and GIVE_AMMO.has(d["ammo"]):
			reserve[d["ammo"]] = maxi(reserve[d["ammo"]], GIVE_AMMO[d["ammo"]])
		if d.has("alt_ammo"):
			reserve[d["alt_ammo"]] = maxi(reserve[d["alt_ammo"]], 2)
		equip(id)
	elif with_ammo and d.has("ammo"):
		return add_ammo(d["ammo"], d.get("mag", GIVE_AMMO.get(d["ammo"], 1)))
	return fresh

static func _order(id: String) -> int:
	return DEFS.keys().find(id)

func add_ammo(type: String, amount: int) -> bool:
	if not reserve.has(type) or reserve[type] >= MAX_AMMO[type]:
		return false
	reserve[type] = mini(MAX_AMMO[type], reserve[type] + amount)
	_emit_ammo()
	return true

func get_state() -> Dictionary:
	return {"owned": owned.duplicate(), "clip": clip.duplicate(), "reserve": reserve.duplicate(), "current": current, "mode": mode.duplicate()}

func set_state(d: Dictionary) -> void:
	for id in d.get("owned", []):
		if not owned.has(id) and DEFS.has(id):
			give(id, false)
	for k in d.get("clip", {}):
		clip[k] = int(d["clip"][k])
	for k in d.get("reserve", {}):
		if reserve.has(k):
			reserve[k] = int(d["reserve"][k])
	for k in d.get("mode", {}):
		mode[k] = int(d["mode"][k])
	if d.get("current", "") in owned:
		equip(d["current"])
	_emit_ammo()

func equip(id: String) -> void:
	if not owned.has(id) or id == current:
		return
	if current != "" and _models.has(current):
		_models[current].visible = false
	_stop_flame()
	_phys_release()
	current = id
	_models[id].visible = not _holstered
	_draw_t = 0.0
	_reloading = 0.0
	_burst_left = 0
	_charge = -1.0
	AudioBus.play_3d("weapon_draw", global_position, -10.0)
	weapon_switched.emit(id)
	_emit_ammo()

func cycle(dir: int) -> void:
	if owned.size() < 2:
		return
	var i := owned.find(current)
	equip(owned[(i + dir + owned.size()) % owned.size()])

## Teclas de slot: repetir a tecla alterna entre as armas do mesmo slot.
func select_slot(slot: int) -> void:
	var list: Array = owned.filter(func(id): return DEFS[id]["slot"] == slot)
	if list.is_empty():
		return
	var i := list.find(current)
	equip(list[(i + 1) % list.size()] if i >= 0 else list[0])

func holster(on: bool) -> void:
	_holstered = on
	if current != "":
		_models[current].visible = not on
	if on:
		_stop_flame()
	else:
		_draw_t = 0.0

func is_aiming() -> bool:
	return _aiming and not _holstered

func is_scoped() -> bool:
	return is_aiming() and DEFS.get(current, {}).get("scope", false) and _aim_blend > 0.85

func look_mult() -> float:
	if not is_aiming():
		return 1.0
	return clampf(DEFS[current].get("zoom", 0.78) * 1.2, 0.18, 0.6)

func speed_mult() -> float:
	return DEFS.get(current, {}).get("speed", 1.0) if not _holstered else 1.0

func set_bob(t: float, amp: float) -> void:
	_bob_t = t
	_bob_amp = amp

func _mode_name(id: String) -> String:
	var d: Dictionary = DEFS[id]
	if not d.has("modes"):
		return ""
	return d["modes"][mode.get(id, 0)]

func _emit_ammo() -> void:
	if current == "":
		ammo_changed.emit(-1, -1, "")
		return
	var d: Dictionary = DEFS[current]
	var n := Loc.t(d["name"])
	if d.has("modes"):
		n += "  [" + Loc.t("hud.mode_" + _mode_name(current)) + "]"
	if d.has("alt_ammo"):
		n += "  [%s: %d]" % [Loc.t("item.ammo_" + d["alt_ammo"]), reserve[d["alt_ammo"]]]
	match d["type"]:
		"melee", "manip", "binoc":
			ammo_changed.emit(-1, -1, n)
		"throw", "flame", "beam":
			ammo_changed.emit(reserve[d["ammo"]], -1, n)
		_:
			ammo_changed.emit(clip[current], reserve[d["ammo"]], n)

# ---------------- ciclo ----------------
func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.alive or not player.input_enabled or get_tree().paused:
		return
	if event.is_action_pressed("next_weapon"): cycle(1)
	elif event.is_action_pressed("prev_weapon"): cycle(-1)
	elif event.is_action_pressed("reload"): _start_reload()
	elif event.is_action_pressed("alt_fire"): _alt_fire()
	for i in 6:
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			select_slot(i + 1)

func _process(delta: float) -> void:
	if player == null:
		return
	_cool = maxf(0.0, _cool - delta)
	_draw_t = minf(1.0, _draw_t + delta * 3.0)
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	_flash_t -= delta
	_flash_mesh.visible = _flash_t > 0.0
	_muzzle_light.light_energy = maxf(0.0, _flash_t) * 60.0
	var active: bool = current != "" and not _holstered and player.alive and player.input_enabled and not get_tree().paused
	var d0: Dictionary = DEFS.get(current, {})
	var t0: String = d0.get("type", "")
	_aiming = active and Input.is_action_pressed("aim") and not (t0 in ["melee", "manip", "throw", "flame", "beam"])
	_aim_blend = move_toward(_aim_blend, 1.0 if _aiming and _reloading <= 0.0 else 0.0, delta * 6.0)
	var base_fov: float = Settings.get_v("graphics", "fov", 80.0)
	player.camera.fov = lerpf(base_fov, base_fov * d0.get("zoom", 0.78), _aim_blend)
	var scoped := is_scoped()
	if _scope.visible != scoped or (scoped and _scope.binoc != (t0 == "binoc")):
		_scope.binoc = t0 == "binoc"
		_scope.visible = scoped
		_scope.queue_redraw()
	if _models.has(current):
		_models[current].visible = not _holstered and not scoped
	if _bolt_t > -0.5:
		var was := _bolt_t
		_bolt_t -= delta
		if was > 0.0 and _bolt_t <= 0.0 and d0.has("bolt"):
			AudioBus.play_3d(d0["bolt"], global_position, -4.0)
	if active:
		var d: Dictionary = d0
		var trig := Input.is_action_pressed("fire")
		match t0:
			"manip":
				_manip_update(d, delta, trig)
			"flame":
				_flame_update(d, delta, trig)
			"beam":
				_beam_update(d, delta, trig)
			"binoc":
				pass
			_:
				if _reloading > 0.0:
					_update_reload(delta)
				elif _burst_left > 0:
					if _cool <= 0.0:
						_burst_left -= 1
						_fire()
				elif trig and _cool <= 0.0 and _draw_t > 0.6 and (_is_auto(d) or not _trigger_held_last or t0 == "melee"):
					if _mode_name(current) == "burst":
						_burst_left = 2
					_fire()
		_trigger_held_last = trig
	else:
		_stop_flame()
		_charge = -1.0
	_update_laser(active and d0.get("laser", false) and guided)
	_animate(delta)

## Ponto do laser do RPG (o foguete segue o ponto enquanto a guia estiver ligada).
var _laser_dot: MeshInstance3D
func _update_laser(on: bool) -> void:
	if _laser_dot == null or not is_instance_valid(_laser_dot):
		if not on: return
		_laser_dot = MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.05; sm.height = 0.1; sm.radial_segments = 8; sm.rings = 4
		_laser_dot.mesh = sm
		var mat := Mats.emissive(Color(1.0, 0.1, 0.05), 6.0)
		mat.no_depth_test = false
		_laser_dot.material_override = mat
		_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Effects._world().add_child(_laser_dot)
	_laser_dot.visible = on
	if not on: return
	var cam: Camera3D = player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 300.0, 1 | 4 | 8)
	q.exclude = [player.get_rid()]
	var h: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	_laser_dot.visible = not h.is_empty()
	if not h.is_empty():
		_laser_dot.global_position = h["position"] + h["normal"] * 0.03

func _is_auto(d: Dictionary) -> bool:
	var m := _mode_name(current)
	if m != "":
		return m == "auto"
	return d.get("auto", false)

## Disparo alternativo por arma (tecla Q / botão do meio / R3 / botão ALT. no toque).
func _alt_fire() -> void:
	if current == "" or _holstered or _reloading > 0.0:
		return
	var d: Dictionary = DEFS[current]
	if d.has("modes"):
		mode[current] = (mode.get(current, 0) + 1) % d["modes"].size()
		AudioBus.play_3d("firemode", global_position, -6.0)
		notice.emit(Loc.t("hud.mode_" + _mode_name(current)))
		_emit_ammo()
		return
	match d.get("alt", ""):
		"gren20":
			if _cool > 0.0: return
			var a: String = d["alt_ammo"]
			if reserve[a] <= 0:
				AudioBus.play_3d("dry_fire", global_position, -8.0); return
			reserve[a] -= 1
			_cool = 0.9
			var cam: Camera3D = player.camera
			Projectile.spawn("gren20", cam.global_position - cam.global_basis.z * 0.6 - cam.global_basis.y * 0.1, -cam.global_basis.z, player)
			AudioBus.play_3d("oicw_grenade", global_position, 0.0)
			player.add_recoil(3.0, 0.0); _kick = 1.0
			InputRouter.vibrate(0.4, 0.4, 0.12)
			_emit_ammo()
		"cball":
			# AR2: esfera de energia escura (quica nas paredes e desintegra quem tocar)
			if _cool > 0.0: return
			var ca: String = d["alt_ammo"]
			if reserve[ca] <= 0:
				AudioBus.play_3d("dry_fire", global_position, -8.0); return
			reserve[ca] -= 1
			_cool = 1.2
			AudioBus.play_3d("ar2_charge", global_position, -2.0)
			await get_tree().create_timer(0.45).timeout
			if current != "ar2" or not is_instance_valid(player): return
			var cam2: Camera3D = player.camera
			Projectile.spawn("cball", cam2.global_position - cam2.global_basis.z * 0.8 - cam2.global_basis.y * 0.1, -cam2.global_basis.z, player)
			AudioBus.play_3d("ar2_ball", global_position, 2.0)
			player.add_recoil(4.0, 0.0); _kick = 1.4
			player.shake(0.3)
			InputRouter.vibrate(0.6, 0.6, 0.2)
			_emit_ammo()
		"squeeze":
			# isca: apertar chama as criaturas aliadas/feromônio para perto do jogador
			if _cool > 0.0: return
			_cool = 1.0
			_kick = 0.6
			AudioBus.play_3d("bugbait_squeeze", global_position, -2.0)
			Effects.burst(player.camera.global_position - player.camera.global_basis.z * 0.5, Vector3.UP, Color(0.6, 0.75, 0.25), 10, false, 0.5)
			Game.emit_noise(player.global_position, 30.0, player)
		"double":
			if _cool > 0.0 or clip[current] < 2: return
			clip[current] -= 1
			_fire(2.0)
		"guide":
			guided = not guided
			AudioBus.play_3d("firemode", global_position, -6.0)
			notice.emit(Loc.t("hud.guided_on" if guided else "hud.guided_off"))
		"detonate":
			var n := 0
			for s in get_tree().get_nodes_in_group("slam_remote"):
				if s.has_method("detonate_remote"):
					s.detonate_remote(); n += 1
			AudioBus.play_3d("slam_beep", global_position, -4.0)
			if n > 0: notice.emit(Loc.t("hud.slam_detonate"))
		_:
			if d.get("phys", false):
				_phys_cycle_dist()
				return
			if d["type"] == "melee" and d.has("heavy") and _cool <= 0.0:
				_cool = 1.1
				var hd := d.duplicate(); hd["damage"] = d["heavy"]
				_melee(hd)
				_kick = 1.4

# ---------------- Physgun (beta 2002/2003) ----------------
## Disparo (segurar): levita o objeto na distância em que foi pego, sem puxá-lo — ele segue a mira.
## Mira (com objeto preso): fixa o objeto parado no ar (congela). Mirar num objeto fixado e disparar
## o solta de novo. ALT com objeto preso: afasta/aproxima (alterna 3 distâncias).
var _phys_body: RigidBody3D
var _phys_dist := 6.0
var _phys_beam: MeshInstance3D
var _phys_snd: AudioStreamPlayer

func _phys_update(d: Dictionary, delta: float, trig: bool) -> void:
	var aim := Input.is_action_pressed("aim")
	var aim_just := aim and not _aim_held_last
	_aim_held_last = aim
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var m: Node3D = _models.get(current)
	if m and m.has_meta("glow_light"):
		(m.get_meta("glow_light") as OmniLight3D).light_energy = 0.3 + (1.6 if _phys_body else 0.0) + _kick
	if trig and _phys_body == null and not _trigger_held_last and _cool <= 0.0:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * d["range"], 1 | 4 | 8)
		q.exclude = [player.get_rid()]
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] is RigidBody3D and not hit["collider"].has_meta("no_manip"):
			var b := hit["collider"] as RigidBody3D
			if b.freeze and not b.has_meta("phys_frozen"):
				pass
			elif b.mass > d["max_mass"]:
				AudioBus.play_3d("manip_deny", player.global_position, -10.0)
				_cool = 0.5
			else:
				if b.has_meta("phys_frozen"):
					b.remove_meta("phys_frozen"); b.freeze = false
				_phys_body = b
				_phys_dist = from.distance_to(b.global_position)
				b.sleeping = false
				AudioBus.play_3d("physgun_grab", b.global_position, -4.0)
		else:
			AudioBus.play_3d("manip_deny", player.global_position, -14.0)
			_cool = 0.3
	if _phys_body and not is_instance_valid(_phys_body):
		_phys_body = null
	if _phys_body:
		if not trig:
			_phys_release()
		elif aim_just:
			_phys_body.linear_velocity = Vector3.ZERO; _phys_body.angular_velocity = Vector3.ZERO
			_phys_body.freeze = true
			_phys_body.set_meta("phys_frozen", true)
			AudioBus.play_3d("physgun_freeze", _phys_body.global_position, 0.0)
			Effects.burst(_phys_body.global_position, Vector3.UP, d["fx"], 12, true, 0.6)
			notice.emit(Loc.t("hud.phys_frozen"))
			_phys_body = null
			_cool = 0.4
		else:
			var target := from + dir * _phys_dist
			var err := target - _phys_body.global_position
			_phys_body.linear_velocity = _phys_body.linear_velocity.lerp(err * 9.0, clampf(delta * 12.0, 0.0, 1.0)).limit_length(30.0)
			_phys_body.angular_velocity *= 0.9
	_phys_draw_beam(d)
	if _phys_snd == null:
		_phys_snd = AudioStreamPlayer.new(); _phys_snd.bus = "SFX"; _phys_snd.volume_db = -14.0
		var st := AudioBus.get_stream("physgun_loop")
		if st is AudioStreamWAV:
			st = st.duplicate(); st.loop_mode = AudioStreamWAV.LOOP_FORWARD; st.loop_end = int(st.get_length() * st.mix_rate)
		_phys_snd.stream = st
		add_child(_phys_snd)
	if _phys_body and not _phys_snd.playing: _phys_snd.play()
	elif _phys_body == null and _phys_snd.playing: _phys_snd.stop()

func _phys_release() -> void:
	if is_instance_valid(_phys_body):
		_phys_body.angular_velocity *= 0.5
	_phys_body = null
	_phys_draw_beam({})
	if _phys_snd and _phys_snd.playing: _phys_snd.stop()

## ALT da Physgun: alterna a distância de levitação (perto / médio / longe).
func _phys_cycle_dist() -> void:
	if _phys_body == null: return
	_phys_dist = 3.0 if _phys_dist > 14.0 else (8.0 if _phys_dist < 6.0 else 18.0)
	AudioBus.play_3d("firemode", global_position, -6.0)

func _phys_draw_beam(d: Dictionary) -> void:
	if _phys_beam == null:
		_phys_beam = MeshInstance3D.new()
		_phys_beam.mesh = MeshKit.cylinder(0.012, 1.0, 6)
		var bm := Mats.emissive(Color(0.35, 0.65, 1.0), 5.0)
		_phys_beam.material_override = bm
		_phys_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Effects._world().add_child(_phys_beam)
	if not is_instance_valid(_phys_beam):
		_phys_beam = null; return
	_phys_beam.visible = _phys_body != null and current == "physgun"
	if not _phys_beam.visible:
		return
	var m: Node3D = _models.get(current)
	var mz: Node3D = m.get_node_or_null("Muzzle") if m else null
	var a: Vector3 = mz.global_position if mz else player.camera.global_position
	var b := _phys_body.global_position
	var l := maxf(a.distance_to(b), 0.05)
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.FORWARD
	_phys_beam.global_transform = Transform3D(Basis.looking_at((b - a) / l, up) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1, l, 1)), (a + b) * 0.5)

# ---------------- Manipulador (canhão de tração ressonante) ----------------
## Disparo: empurrão (impulso forte até 12 m; objetos e criaturas). Mira (segurar): puxa um objeto
## de até 150 kg a até 11 m; quando chega perto ele é agarrado. Disparo segurando: arremesso forte.
## Mira de novo segurando: solta.
func _manip_update(d: Dictionary, delta: float, trig: bool) -> void:
	if d.get("phys", false):
		_phys_update(d, delta, trig)
		return
	var aim := Input.is_action_pressed("aim")
	var aim_just := aim and not _aim_held_last
	_aim_held_last = aim
	var m: Node3D = _models.get(current)
	_manip_glow = move_toward(_manip_glow, 1.0 if player.is_holding() else 0.0, delta * 4.0)
	if m and m.has_meta("glow_light"):
		var gl: OmniLight3D = m.get_meta("glow_light")
		gl.light_energy = 0.3 + _manip_glow * 1.2 + _kick * 2.0
		for i in 3:
			var cl: Node3D = m.get_node_or_null("Claw%d" % i)
			if cl: cl.rotation.x = cl.get_meta("rest_rx") - (0.35 * _manip_glow if true else 0.0) + 0.2 * _kick
	if _manip_snd == null:
		_manip_snd = AudioStreamPlayer.new(); _manip_snd.bus = "SFX"; _manip_snd.volume_db = -16.0
		var st := AudioBus.get_stream("manip_hold_loop")
		if st is AudioStreamWAV:
			st = st.duplicate(); st.loop_mode = AudioStreamWAV.LOOP_FORWARD; st.loop_end = int(st.get_length() * st.mix_rate)
		_manip_snd.stream = st
		add_child(_manip_snd)
	if player.is_holding():
		if not _manip_snd.playing: _manip_snd.play()
		if trig and not _trigger_held_last and _cool <= 0.0:
			_cool = d["rate"]
			_kick = 1.0
			player.throw_held(2.4)
			player.add_recoil(1.5, 0.0)
			InputRouter.vibrate(0.4, 0.4, 0.1)
		elif aim_just:
			player.release_held()
			_cool = 0.25
		return
	if _manip_snd.playing: _manip_snd.stop()
	if trig and not _trigger_held_last and _cool <= 0.0:
		_cool = d["rate"]
		_manip_punt(d)
	elif aim and _cool <= 0.0:
		_manip_pull(d, delta)

func _manip_target(dist: float) -> Dictionary:
	var from: Vector3 = player.camera.global_position
	var dir: Vector3 = -player.camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 1 | 4 | 8)
	q.exclude = [player.get_rid()]
	var hit = player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit["collider"] is RigidBody3D):
		# tolerância: esfera ao longo do raio pega objetos pequenos perto da mira
		var sq := PhysicsShapeQueryParameters3D.new()
		var sp := SphereShape3D.new(); sp.radius = 0.6
		sq.shape = sp
		sq.collision_mask = 4
		sq.exclude = [player.get_rid()]
		var maxd: float = dist if hit.is_empty() else from.distance_to(hit["position"])
		var t := 1.5
		while t < maxd:
			sq.transform = Transform3D(Basis(), from + dir * t)
			var r = player.get_world_3d().direct_space_state.intersect_shape(sq, 1)
			if r.size() > 0 and r[0]["collider"] is RigidBody3D:
				return {"collider": r[0]["collider"], "position": from + dir * t}
			t += 1.0
	return hit

func _manip_punt(d: Dictionary) -> void:
	_kick = 1.0
	var from: Vector3 = player.camera.global_position
	var dir: Vector3 = -player.camera.global_basis.z
	var hit := _manip_target(d["range"])
	AudioBus.play_3d("manip_launch", from, -4.0, 0.08)
	Game.emit_noise(from, 10.0, player)
	player.add_recoil(1.0, 0.0)
	InputRouter.vibrate(0.3, 0.3, 0.08)
	if hit.is_empty():
		return
	var c: Object = hit["collider"]
	if c is RigidBody3D and not c.freeze and not c.has_meta("no_manip"):
		var b := c as RigidBody3D
		b.sleeping = false
		b.apply_central_impulse(dir * minf(b.mass * d.get("punt", 22.0), 700.0 * d.get("punt", 22.0) / 22.0))
		if b.has_method("on_thrown"): b.on_thrown(player)
		Effects.burst(hit["position"], -dir, d.get("fx", Color(0.6, 0.85, 1.0)), 8, true, 0.6)
	elif c.has_method("take_hit"):
		Combat.apply_hit(c, 8.0, hit["position"], dir * 6.0, player, "physics")
		if c is CharacterBody3D:
			c.velocity += dir * 8.0 + Vector3.UP * 2.0

func _manip_pull(d: Dictionary, _delta: float) -> void:
	var hit := _manip_target(d["pull_range"])
	if hit.is_empty() or not (hit["collider"] is RigidBody3D):
		return
	var b := hit["collider"] as RigidBody3D
	if b.freeze or b.has_meta("no_manip") or b.has_meta("no_carry"):
		return
	if b.mass > d["max_mass"]:
		if _cool <= 0.0:
			AudioBus.play_3d("manip_deny", player.global_position, -10.0)
			_cool = 0.6
		return
	var from: Vector3 = player.camera.global_position
	var dist := from.distance_to(b.global_position)
	if dist < 3.0:
		player.grab_with_manip(b)
		AudioBus.play_3d("manip_pickup", b.global_position, -6.0)
		_cool = 0.2
	else:
		b.sleeping = false
		var to := (from - b.global_position).normalized()
		b.linear_velocity = b.linear_velocity.lerp(to * clampf(90.0 / sqrt(b.mass), 4.0, 14.0), 0.25)

func _fire(mult := 1.0) -> void:
	var d: Dictionary = DEFS[current]
	_cool = d["rate"] * (1.4 if mult > 1.0 else 1.0)
	if _burst_left > 0 or (_mode_name(current) == "burst"):
		_cool = d["rate"] * (0.75 if _burst_left > 0 else 3.5)
	match d["type"]:
		"melee":
			_melee(d); return
		"throw":
			_throw(d, false); return
	if clip[current] <= 0:
		AudioBus.play_3d("dry_fire", global_position, -8.0)
		_cool = 0.3
		_burst_left = 0
		if reserve[d["ammo"]] > 0:
			_start_reload()
		return
	clip[current] -= 1
	var from: Vector3 = player.camera.global_position
	if d["type"] == "proj":
		var dir0: Vector3 = -player.camera.global_basis.z
		var spawn_at = from + dir0 * 0.7 - player.camera.global_basis.y * 0.12 + player.camera.global_basis.x * 0.08
		var pr = Projectile.spawn(d["proj"], spawn_at, dir0, player)
		if d["proj"] == "rocket":
			pr.guided = guided
	else:
		var pellets: int = int(d.get("pellets", 1) * mult)
		var spread: float = d["spread"] * (0.45 if _aiming else 1.0)
		if is_scoped() and d.has("scoped_spread"):
			spread = d["scoped_spread"]
		if not player.is_on_floor(): spread *= 1.8
		var base_dir: Vector3 = _assisted_dir(-player.camera.global_basis.z, from)
		for i in pellets:
			var dir := _spread_dir(base_dir, spread)
			_hitscan(from, dir, d["damage"], d["range"])
	AudioBus.play_3d(d["sound"], from, 2.0 if mult > 1.0 else 0.0, 0.05, 120.0)
	Game.emit_noise(from, 40.0, player)
	var rc: float = d["recoil"] * mult
	player.add_recoil(rc * randf_range(0.8, 1.2) * (0.6 if _aiming else 1.0), randf_range(-0.4, 0.4) * rc)
	_kick = 1.0
	_flash_t = 0.05
	(_flash_mesh.material_override as StandardMaterial3D).albedo_color = d.get("tracer", Color(1.0, 0.8, 0.5))
	_muzzle_light.light_color = d.get("tracer", Color(1.0, 0.75, 0.4))
	var muzzle: Node3D = _models[current].get_node_or_null("Muzzle")
	if muzzle:
		_flash_mesh.global_position = muzzle.global_position
		_muzzle_light.global_position = muzzle.global_position
		_flash_mesh.rotation.z = randf() * TAU
	InputRouter.vibrate(0.2, 0.35 if d.get("pellets", 1) > 1 or rc > 3.0 else 0.15, 0.08)
	if current == "shotgun":
		get_tree().create_timer(0.35).timeout.connect(func(): AudioBus.play_3d("shotgun_pump", global_position, -6.0))
	if d.has("bolt") and clip[current] > 0:
		_bolt_t = 0.45
	_emit_ammo()

# ---------------- arremessáveis ----------------
func _throw(d: Dictionary, lob: bool) -> void:
	var a: String = d["ammo"]
	if reserve[a] <= 0:
		AudioBus.play_3d("dry_fire", global_position, -10.0)
		_cool = 0.4
		return
	var cam: Camera3D = player.camera
	var dir: Vector3 = -cam.global_basis.z
	var from := cam.global_position + dir * 0.5 - cam.global_basis.y * 0.1
	_kick = 1.0
	if d["throw"] == "slam":
		# Colocar em parede próxima = mina de laser; senão, arremessa (detonação remota pelo ALT).
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + dir * 2.2, 1)
		var h = player.get_world_3d().direct_space_state.intersect_ray(q)
		reserve[a] -= 1
		if not h.is_empty():
			var t = Projectile.Throwable.throw("slam", h["position"] + h["normal"] * 0.05, Vector3.ZERO, player)
			t.place_as_tripmine(h["position"], h["normal"])
		else:
			Projectile.Throwable.throw("slam", from, dir * 8.0 + Vector3.UP * 1.5 + player.velocity * 0.5, player)
		_emit_ammo()
		return
	reserve[a] -= 1
	AudioBus.play_3d("throw", global_position, -4.0, 0.1)
	var v: Vector3 = dir * (7.0 if lob else 16.0) + Vector3.UP * (3.0 if lob else 2.0) + player.velocity * 0.6
	if d["throw"] == "brick":
		var b := PhysicsProp.make("brick")
		b.sharp = true
		Effects._world().add_child(b)
		b.global_position = from
		b.linear_velocity = dir * 18.0 + Vector3.UP * 1.5 + player.velocity * 0.6
		b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		b.on_thrown(player)
	else:
		Projectile.Throwable.throw(d["throw"], from, v, player)
	Game.emit_noise(from, 6.0, player)
	_emit_ammo()

# ---------------- Imolador (lança-chamas) ----------------
func _flame_update(d: Dictionary, delta: float, trig: bool) -> void:
	if not trig or reserve[d["ammo"]] <= 0 or _draw_t < 0.6:
		_stop_flame()
		if trig and not _trigger_held_last:
			AudioBus.play_3d("dry_fire", global_position, -8.0)
		return
	if _flame_fx == null:
		_flame_fx = Fire._flames(_models[current], 0.03, 40)
		_flame_fx.local_coords = false
		_flame_fx.direction = Vector3(0, 0, -1)
		_flame_fx.spread = 8.0
		_flame_fx.gravity = Vector3(0, 1.5, 0)
		_flame_fx.initial_velocity_min = 9.0
		_flame_fx.initial_velocity_max = 12.0
		_flame_fx.lifetime = 0.55
		_flame_fx.scale_amount_min = 0.3
		_flame_fx.scale_amount_max = 1.6
		var m: Node3D = _models[current].get_node_or_null("Muzzle")
		if m: _flame_fx.position = m.position
		_flame_snd = AudioStreamPlayer.new(); _flame_snd.bus = "SFX"; _flame_snd.volume_db = -4.0
		var st = AudioBus.get_stream("immolator_loop")
		if st is AudioStreamWAV:
			st = st.duplicate(); st.loop_mode = AudioStreamWAV.LOOP_FORWARD; st.loop_end = int(st.get_length() * st.mix_rate)
		_flame_snd.stream = st
		add_child(_flame_snd)
	_flame_fx.emitting = true
	if not _flame_snd.playing: _flame_snd.play()
	_muzzle_light.global_position = _flame_fx.global_position - player.camera.global_basis.z * 1.5
	_muzzle_light.light_energy = 2.0
	_flame_area_t -= delta
	if _cool > 0.0:
		return
	_cool = d["rate"]
	reserve[d["ammo"]] -= 1
	_emit_ammo()
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir: Vector3 = -cam.global_basis.z
	# cone curto: 3 raios
	for off in [Vector3.ZERO, cam.global_basis.x * 0.08, -cam.global_basis.x * 0.08]:
		var dd: Vector3 = (dir + off).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dd * d["range"], 1 | 4 | 8)
		q.exclude = [player.get_rid()]
		var h: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
		if h.is_empty():
			continue
		var c: Object = h["collider"]
		Combat.apply_hit(c, d["damage"], h["position"], dd, player, "fire")
		if c is Node and (c.is_in_group("enemy") or c is RigidBody3D):
			Fire.ignite(c, 5.0, player, 9.0)
		elif _flame_area_t <= 0.0:
			_flame_area_t = 0.45
			Fire.area(h["position"] + h["normal"] * 0.05, 1.3, 3.0, player, 10.0)
	Game.emit_noise(from, 14.0, player)
	InputRouter.vibrate(0.15, 0.1, 0.07)

func _stop_flame() -> void:
	if _flame_fx:
		_flame_fx.emitting = false
	if _flame_snd and _flame_snd.playing:
		_flame_snd.stop()

# ---------------- Canhão de Guarda (feixe com carga) ----------------
func _beam_update(d: Dictionary, delta: float, trig: bool) -> void:
	var m: Node3D = _models.get(current)
	var gl: OmniLight3D = m.get_meta("glow_light") if m and m.has_meta("glow_light") else null
	if _charge >= 0.0:
		_charge += delta
		_kick = 0.2 * sin(_charge * 60.0)
		if gl: gl.light_energy = 0.4 + _charge * 4.0
		if _charge >= d["charge"]:
			_charge = -1.0
			_guard_blast(d)
		return
	if gl: gl.light_energy = 0.3
	if trig and not _trigger_held_last and _cool <= 0.0 and _draw_t > 0.6:
		if reserve[d["ammo"]] <= 0:
			AudioBus.play_3d("dry_fire", global_position, -8.0); _cool = 0.4; return
		_charge = 0.0
		AudioBus.play_3d("guard_charge", global_position, 0.0)

func _guard_blast(d: Dictionary) -> void:
	reserve[d["ammo"]] -= 1
	_cool = d["rate"]
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir: Vector3 = -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, 1 | 4 | 8)
	q.exclude = [player.get_rid()]
	var h: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = h["position"] if not h.is_empty() else from + dir * 120.0
	AudioBus.play_3d("guard_fire", from, 3.0, 0.05, 150.0)
	if not h.is_empty():
		Combat.apply_hit(h["collider"], d["damage"] * 0.5, end, dir * 4.0, player, "explosion")
		if from.distance_to(end) > d["radius"] + 0.5:
			Effects.explosion(end, d["radius"], d["damage"], player)
		else:
			Effects.explosion(end, d["radius"] * 0.6, d["damage"] * 0.5, player)
	# feixe visual
	var muzzle: Node3D = _models[current].get_node_or_null("Muzzle")
	var a: Vector3 = muzzle.global_position if muzzle else from
	var beam := MeshInstance3D.new()
	var len := a.distance_to(end)
	beam.mesh = MeshKit.cylinder(0.05, len, 6)
	var mat := Mats.emissive(Color(0.6, 0.85, 1.0), 6.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Effects._world().add_child(beam)
	beam.global_transform = Transform3D(Basis.looking_at((end - a).normalized(), Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5), (a + end) * 0.5)
	var tw := beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(beam.queue_free)
	player.add_recoil(7.0, randf_range(-1.0, 1.0))
	player.shake(0.4)
	_kick = 1.6
	_flash_t = 0.12
	InputRouter.vibrate(0.8, 0.8, 0.25)
	Game.emit_noise(from, 60.0, player)
	_emit_ammo()

func _melee(d: Dictionary) -> void:
	_kick = 1.0
	var from: Vector3 = player.camera.global_position
	var dir = -player.camera.global_basis.z
	AudioBus.play_3d("swing", from, -8.0, 0.15)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * d["range"], 1 | 4 | 8)
	q.exclude = [player.get_rid()]
	var hit = player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var surf := Mats.surface_of(hit["collider"])
	var shock: bool = d.get("dmg_type", "") == "shock"
	if shock:
		AudioBus.play_3d("stun_hit", hit["position"], 0.0, 0.1)
		Effects.burst(hit["position"], hit["normal"], Color(0.55, 0.8, 1.0), 14, true, 0.8)
	else:
		AudioBus.play_3d("impact_metal" if surf == "metal" else ("impact_wood" if surf == "wood" else "impact_concrete"), hit["position"], -2.0)
	Effects.impact(hit["position"], hit["normal"], surf, dir, false)
	Combat.apply_hit(hit["collider"], d["damage"], hit["position"], dir * 2.5, player, "melee")
	if shock and hit["collider"] is CharacterBody3D:
		hit["collider"].velocity += dir * 5.0
	player.shake(0.12)
	InputRouter.vibrate(0.3, 0.3, 0.1)
	Game.emit_noise(from, 8.0, player)

func _start_reload() -> void:
	if current == "" or _reloading > 0.0:
		return
	var d: Dictionary = DEFS[current]
	if not (d["type"] in ["gun", "proj"]) or clip[current] >= d["mag"] or reserve[d["ammo"]] <= 0:
		return
	_burst_left = 0
	_reloading = d["reload_t"]
	_reload_step = d["reload_t"]
	AudioBus.play_3d(d["reload_snd"], global_position, -4.0)

func _update_reload(delta: float) -> void:
	var d: Dictionary = DEFS[current]
	_reloading -= delta
	if _reloading > 0.0:
		return
	var a: String = d["ammo"]
	if d.get("shell_reload", false):
		clip[current] += 1
		reserve[a] -= 1
		if clip[current] < d["mag"] and reserve[a] > 0 and not Input.is_action_pressed("fire"):
			_reloading = d["reload_t"]
			AudioBus.play_3d(d["reload_snd"], global_position, -4.0)
		else:
			_reloading = 0.0
			AudioBus.play_3d("shotgun_pump", global_position, -6.0)
	else:
		var need: int = d["mag"] - clip[current]
		var take := mini(need, reserve[a])
		clip[current] += take
		reserve[a] -= take
		_reloading = 0.0
	_emit_ammo()

func _animate(delta: float) -> void:
	if current == "" or not _models.has(current):
		return
	var m: Node3D = _models[current]
	var typ: String = DEFS[current]["type"]
	var hip: Vector3 = m.get_meta("hip", Vector3(0.2, -0.2, -0.38))
	var ads: Vector3 = m.get_meta("ads", Vector3(0.0, -0.11, -0.3))
	var pos := hip.lerp(ads, _aim_blend)
	var rot := Vector3.ZERO
	# Oscilação (sway) contrária ao movimento da câmera
	var look := Input.get_last_mouse_velocity() * 0.00002 if InputRouter.device == InputRouter.Device.KBM else Vector2.ZERO
	_sway = _sway.lerp(look, clampf(delta * 8.0, 0, 1))
	pos += Vector3(-_sway.x, _sway.y, 0) * (1.0 - _aim_blend * 0.8)
	# Balanço ao andar
	var ba := _bob_amp * (1.0 - _aim_blend * 0.85) * (1.4 if typ == "gun" and DEFS[current].has("speed") else 1.0)
	pos += Vector3(cos(_bob_t * 0.5) * 0.012, -absf(sin(_bob_t * 0.5)) * 0.014, 0) * ba
	# Recuo
	var k := ease(clampf(_kick, 0.0, 2.0) * 0.5, 0.4) * 2.0 if _kick > 1.0 else ease(maxf(_kick, 0.0), 0.4)
	match typ:
		"manip", "beam":
			pos.z += 0.07 * k
			rot.x += 0.08 * k
		"melee":
			rot += Vector3(-1.2 * k, 0.6 * k, 0.3 * k)
			pos += Vector3(-0.08 * k, 0.04 * k, -0.12 * k)
		"throw":
			rot += Vector3(0.9 * k, 0.0, 0.0)
			pos += Vector3(0.0, 0.12 * k, 0.1 * k)
		_:
			pos.z += 0.05 * k
			rot.x += 0.12 * k
	# Saque
	var dr := 1.0 - ease(_draw_t, 0.3)
	pos.y -= dr * 0.3
	rot.x -= dr * 0.9
	# Recarga
	if _reloading > 0.0:
		var t := 1.0 - _reloading / _reload_step
		var w := sin(t * PI)
		rot += Vector3(-0.35 * w, 0.15 * w, 0.55 * w)
		pos.y -= 0.06 * w
		var mag: Node3D = m.get_node_or_null("Mag")
		if mag:
			mag.position = mag.get_meta("rest") + Vector3(0, -0.16 * w, 0.02 * w)
		var pump: Node3D = m.get_node_or_null("Pump")
		if pump and DEFS[current].get("shell_reload", false):
			pump.position = pump.get_meta("rest")
	var pump2: Node3D = m.get_node_or_null("Pump")
	if pump2 and current == "shotgun" and _cool > 0.0:
		var pt = 1.0 - _cool / DEFS[current]["rate"]
		pump2.position = pump2.get_meta("rest") + Vector3(0, 0, 0.08 * sin(clampf((pt - 0.35) / 0.4, 0, 1) * PI))
	var bolt: Node3D = m.get_node_or_null("Bolt")
	if bolt and _bolt_t > -0.5 and _bolt_t < 0.0:
		var bt := clampf(-_bolt_t / 0.5, 0.0, 1.0)
		bolt.position = bolt.get_meta("rest") + Vector3(0, 0, 0.06 * sin(bt * PI))
	var slide: Node3D = m.get_node_or_null("Slide")
	if slide:
		slide.position = slide.get_meta("rest") + Vector3(0, 0, 0.03 * k)
	var barrel: Node3D = m.get_node_or_null("Spin")
	if barrel and _cool > 0.0:
		barrel.rotation.z += delta * 30.0
	m.position = m.position.lerp(pos, clampf(delta * 20.0, 0, 1))
	m.rotation = m.rotation.lerp(rot, clampf(delta * 16.0, 0, 1))

func _assisted_dir(dir: Vector3, from: Vector3) -> Vector3:
	if InputRouter.device == InputRouter.Device.KBM or not Settings.get_v("controls", "aim_assist", true):
		return dir
	var best := dir
	var best_dot := cos(deg_to_rad(4.0))
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("aim_point") or not e.alive:
			continue
		var to: Vector3 = (e.aim_point() - from)
		if to.length() > 50.0:
			continue
		var dt := to.normalized().dot(dir)
		if dt > best_dot:
			best_dot = dt
			best = dir.slerp(to.normalized(), 0.6)
	return best

func _spread_dir(dir: Vector3, deg: float) -> Vector3:
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var a := randf() * TAU
	var r := sqrt(randf()) * tan(deg_to_rad(deg))
	return (dir + side * cos(a) * r + up * sin(a) * r).normalized()

func _hitscan(from: Vector3, dir: Vector3, dmg: float, rng: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * rng, 1 | 4 | 8)
	q.exclude = [player.get_rid()]
	var hit = player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit["collider"]
	Effects.impact(hit["position"], hit["normal"], Mats.surface_of(col), dir)
	if DEFS.get(current, {}).has("tracer"):
		Effects.burst(hit["position"], hit["normal"], DEFS[current]["tracer"], 4, true, 0.4)
	Combat.apply_hit(col, dmg, hit["position"], dir, player)

