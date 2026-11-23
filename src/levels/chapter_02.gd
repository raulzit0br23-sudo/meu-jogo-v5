extends LevelBase
## Capítulo 2 — "Praça do Terminal" (Ato I).
## A) Rua do Terminal com Irina (bloqueio de Vigilantes) · B) Praça monumental, Discurso do Ar Puro,
## holofote que varre a praça (furtividade opcional) · C) Bloco 14: cinco andares, escadaria,
## apartamentos, Matvei e a espingarda · D) Batida policial → fuga pelos telhados, salto, viga,
## Irina separada · E) escada para o Distrito Leste → fim do capítulo.

const CP_ORDER := ["start", "street2", "plaza", "block", "floor5", "roof", "roofs2"]
const FLOOR_H := 3.2
var D := {}
var cp_i := 0
var M := {}
var _sun: DirectionalLight3D
var _irina: NpcAlly
var _matvei: NpcAlly
var _search: Searchlight
var _screens: Array[MeshInstance3D] = []
var _plaza_enemies: Array[EnemyAI] = []

func _mats() -> void:
	M = {
		"conc": Mats.get_mat("concrete", 0.35, Color(0.72, 0.72, 0.69)),
		"conc_dark": Mats.get_mat("concrete", 0.35, Color(0.48, 0.49, 0.48)),
		"paving": Mats.get_mat("tiles", 0.25, Color(0.55, 0.56, 0.54)),
		"asphalt": Mats.get_mat("asphalt", 0.3, Color(0.75, 0.75, 0.75)),
		"brick": Mats.get_mat("brick", 0.4, Color(0.72, 0.66, 0.62)),
		"brick_dark": Mats.get_mat("brick", 0.4, Color(0.5, 0.46, 0.44)),
		"plaster": Mats.get_mat("concrete", 0.5, Color(0.7, 0.66, 0.56)),
		"plaster_g": Mats.get_mat("concrete", 0.5, Color(0.52, 0.6, 0.55)),
		"tiles": Mats.get_mat("tiles", 0.6, Color(0.75, 0.77, 0.72)),
		"paint": Mats.get_mat("rusted_paint", 0.5, Color(0.55, 0.66, 0.62)),
		"steel": Mats.get_mat("steel", 0.6, Color(0.6, 0.6, 0.58)),
		"dominion": Mats.get_mat("dominion", 0.3),
		"wood": Mats.get_mat("wood", 0.8, Color(0.72, 0.62, 0.5)),
		"gravel": Mats.get_mat("gravel", 0.3, Color(0.9, 0.88, 0.85)),
		"tarp_r": Mats.get_mat("fabric", 0.6, Color(0.75, 0.32, 0.26)),
		"tarp_g": Mats.get_mat("fabric", 0.6, Color(0.4, 0.52, 0.42)),
		"tarp_b": Mats.get_mat("fabric", 0.6, Color(0.34, 0.4, 0.55)),
		"fabric": Mats.get_mat("fabric", 0.6, Color(0.62, 0.55, 0.48)),
		"glass": Mats.glass(),
	}

func build() -> void:
	_mats()
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch2.json"))
	cp_i = maxi(0, CP_ORDER.find(Game.checkpoint))
	grid = {"street": 20.0, "plaza": 20.0, "roofs": 20.0, "far": 60.0}
	grid_y = {"block": 6.4}
	outdoor = {"street": true, "plaza": true, "roofs": true, "far": true}
	setup_env(Color(0.2, 0.23, 0.27), Color(0.3, 0.33, 0.36), 0.6, Color(0.24, 0.27, 0.3), 0.014, 0.0, 0.5)
	env.tonemap_exposure = 1.2
	_sun = sun(Vector3(-18, 200, 0), Color(0.75, 0.8, 0.95), 0.55, true)
	_sun.light_cull_mask = 3
	_build_street()
	_build_plaza()
	_build_block()
	_build_roofs()
	_build_far()
	checkpoints["start"] = [Vector3(0, 0.05, 4), 0.0]
	checkpoints["roof"] = [Vector3(-37.0, FLOOR_H * 5 + 0.05, -109.0), PI]
	# fechamentos entre prédios da praça
	box("plaza", Vector3(-43, 3, -103.0), Vector3(16, 6, 2.0), M["brick_dark"])
	box("plaza", Vector3(41, 3, -130.5), Vector3(12, 6, 3.0), M["brick_dark"])

func after_build() -> void:
	AudioBus.start_music()
	AudioBus.play_ambience("res://assets/audio/ambience/wind_city.wav", "res://assets/audio/ambience/rain.wav", -9.0)
	AudioBus.set_room(0.2, 0.08)
	# Irina acompanha o jogador até a batida no Bloco 14
	_irina = NpcAlly.make("irina", "conscript", 77, "rifle")
	_irina.body.palette["mask"] = false
	add_child(_irina)
	var ip := player.global_position + player.global_basis * Vector3(1.4, 0, 1.2)
	if cp_i >= CP_ORDER.find("roof"):
		ip = Vector3(-38, 16.05, -108)
	_irina.global_position = ip
	_irina.set_mode(NpcAlly.Mode.FOLLOW if cp_i < CP_ORDER.find("roof") else NpcAlly.Mode.IDLE)
	_irina.visible = cp_i < CP_ORDER.find("roofs2")
	if not flag("raid") and cp_i <= CP_ORDER.find("floor5"):
		_irina.follow_dist = 2.4
	match Game.checkpoint:
		"start", "street2": Game.set_objective("obj.ch2.street")
		"plaza": Game.set_objective("obj.ch2.plaza")
		"block", "floor5": Game.set_objective("obj.ch2.matvei" if not flag("shotgun") else "obj.ch2.roof")
		"roof": Game.set_objective("obj.ch2.roofs")
		"roofs2": Game.set_objective("obj.ch2.ladder")
	player.set_mask(true)
	if flag("shotgun") and not flag("raid_done"):
		_raid()

# =====================================================================
# A) RUA DO TERMINAL (z 8 .. -62)
# =====================================================================
func _build_street() -> void:
	var sec := "street"
	box(sec, Vector3(0, -0.15, -27), Vector3(14, 0.3, 72), M["asphalt"])
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(6.25 * s, 0.075, -27), Vector3(1.5, 0.15, 72), M["conc"])
		box(sec, Vector3(5.45 * s, 0.08, -27), Vector3(0.12, 0.16, 72), M["conc_dark"], Vector3.ZERO, false)
	# muro do pátio atrás (portão do Cap. 1)
	box(sec, Vector3(0, 2.5, 9.2), Vector3(14, 5, 0.6), M["dominion"])
	poster(Vector3(0, 3.2, 8.88), PI, "res://assets/textures/sign_4.png", Vector2(2.4, 0.6))
	# prédios dos dois lados
	var segs := [[8.0, -8.0], [-11.0, -28.0], [-31.0, -50.0], [-52.0, -62.0]]
	var i := 0
	for sg in segs:
		for s: float in [-1.0, 1.0]:
			var len: float = sg[0] - sg[1]
			var h := 12.8 + float((i * 7) % 3) * 3.2
			facade_block(sec, Vector3(13.0 * s, 0, (sg[0] + sg[1]) * 0.5), Vector3(12, h, len), M["brick"] if (i + int(s)) % 2 == 0 else M["plaster"], 20 + i, ["e"] if s < 0 else ["w"])
			i += 1
	# becos (fechados por cercas/entulho)
	for z: float in [-9.5, -29.5, -51.0]:
		for s: float in [-1.0, 1.0]:
			box(sec, Vector3(9.5 * s, 1.5, z), Vector3(0.1, 3.0, 2.6), M["steel"], Vector3(0, PI * 0.5, 0), true)
			prop("crate", Vector3(8.2 * s, 0.5, z + 0.6), randf() * PI)
	# carros e barricadas
	car_wreck(sec, Vector3(-3.2, 0, -14), 0.2, Color(0.45, 0.5, 0.55))
	car_wreck(sec, Vector3(3.6, 0, -24), -0.1, Color(0.6, 0.45, 0.3))
	car_wreck(sec, Vector3(-3.0, 0, -36), 2.9, Color(0.4, 0.45, 0.4))
	for x: float in [-4.6, -1.6, 1.6, 4.6]:
		if x != 1.6:
			barrier(sec, Vector3(x, 0, -46), PI * 0.5, 2.6)
	box(sec, Vector3(0, 2.6, -47.5), Vector3(0.3, 5.2, 0.3), M["steel"])
	poster(Vector3(0, 4.3, -47.3), 0.0, "res://assets/textures/sign_2.png", Vector2(1.8, 0.45), true)
	for p: Vector3 in [Vector3(-5.5, 0, -6), Vector3(5.5, 0, -18), Vector3(-5.5, 0, -30), Vector3(5.5, 0, -42), Vector3(-5.5, 0, -54)]:
		sodium_lamp(sec, p, -PI * 0.5 if p.x > 0 else PI * 0.5, 6.5, 2.0, p.z > -10.0)
	for p in [["bucket", Vector3(4.8, 0.3, -8)], ["cinder", Vector3(-4.5, 0.2, -20)], ["barrel", Vector3(5.0, 0.5, -31)], ["explosive", Vector3(-4.2, 0.5, -49.5)], ["explosive", Vector3(4.6, 0.5, -51)], ["crate_small", Vector3(-1.8, 0.3, -44.0)]]:
		prop(p[0], p[1])
	for z: float in [-4.0, -22.0, -40.0]:
		poster(Vector3(-6.98, 2.2, z), PI * 0.5, "res://assets/textures/poster_%d.png" % (int(-z) % 3))
		poster(Vector3(6.98, 2.2, z - 6.0), -PI * 0.5, "res://assets/textures/poster_%d.png" % (int(-z + 1) % 3))
	# roteiro
	Interactables.trigger(self, Vector3(0, 1, -5), Vector3(12, 3, 2), func():
		say("street_intro", D["street_intro"]))
	Interactables.trigger(self, Vector3(0, 1, -26), Vector3(12, 3, 2), func():
		say("kovac_radio", D["kovac_radio"]))
	checkpoint("street2", Vector3(0, 1, -40), Vector3(12, 3, 2), Vector3(0, 0.05, -39), 0.0)
	if cp_i <= CP_ORDER.find("street2"):
		enemy("st_v1", "vigilante_pistol", Vector3(-3.0, 0.05, -50.5), 0.0)
		enemy("st_v2", "vigilante_pistol", Vector3(3.2, 0.05, -51.5), 0.2)
		enemy("st_v3", "vigilante_baton", Vector3(0.0, 0.05, -55.0), 0.0, [Vector3(0, 0, -55), Vector3(-4, 0, -58)] as Array[Vector3])
	pickup("st_med", Vector3(-5.6, 0.25, -12.0), "medkit")
	pickup("st_ammo", Vector3(5.4, 0.25, -37.5), "ammo_9mm", 24)

# =====================================================================
# B) PRAÇA DO TERMINAL (x -35..35, z -62..-132)
# =====================================================================
func _build_plaza() -> void:
	var sec := "plaza"
	for ix in range(-35, 35, 14):
		for iz in range(-132, -62, 14):
			box(sec, Vector3(ix + 7, -0.15, iz + 7), Vector3(14, 0.3, 14), M["paving"])
	# prédios que cercam a praça (ver Bloco 14 a oeste)
	facade_block(sec, Vector3(-21, 0, -67), Vector3(28, 16, 10), M["plaster_g"], 51, ["n"])
	facade_block(sec, Vector3(21, 0, -67), Vector3(28, 19.2, 10), M["brick_dark"], 52, ["n"])
	facade_block(sec, Vector3(41, 0, -98), Vector3(12, 22.4, 62), M["plaster"], 53, ["w"])
	facade_block(sec, Vector3(-43, 0, -87), Vector3(16, 16, 30), M["brick"], 54, ["e"])
	facade_block(sec, Vector3(0, 0, -138), Vector3(70, 25.6, 12), M["plaster_g"], 55, ["s"])
	facade_block(sec, Vector3(-43, 0, -128), Vector3(16, 9.6, 16), M["brick_dark"], 56, ["e", "s"])
	# Terminal (fachada monumental ao norte, portões fechados)
	box(sec, Vector3(0, 6, -131.6), Vector3(24, 12, 0.6), M["dominion"])
	for x: float in [-9.0, -3.0, 3.0, 9.0]:
		mesh_at(sec, MeshKit.cylinder(0.6, 12, 14, 0.05), Transform3D(Basis(), Vector3(x, 6, -130.6)), M["conc"], Vector3(1.2, 12, 1.2))
	poster(Vector3(0, 10.0, -131.25), 0.0, "res://assets/textures/sign_0.png", Vector2(6, 1.5), true)
	# monumento central com telões do Regente
	box(sec, Vector3(0, 1.0, -97), Vector3(9, 2, 9), M["conc"], Vector3.ZERO, true, 0.1)
	for k in 3:
		box(sec, Vector3(0, 0.15 + k * 0.3, -97), Vector3(11.0 - k * 0.6, 0.3, 11.0 - k * 0.6), M["conc_dark"], Vector3.ZERO, true, 0.03)
	var ob := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(2.6, 0.0), Vector2(2.2, 14.0), Vector2(1.2, 22.0), Vector2(0.0, 24.0)]), 4, true, true, false)
	mesh_at(sec, ob, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 2, -97)), M["dominion"], Vector3(4.2, 20, 4.2), Vector3(0, 10, 0))
	for k in 4:
		var a := k * PI * 0.5
		var d := Vector3(sin(a), 0, cos(a))
		box(sec, Vector3(0, 9.0, -97) + d * 2.35, Vector3(5.4, 3.4, 0.25), M["dominion"], Vector3(0, a, 0), false)
		_screens.append(poster(Vector3(0, 9.0, -97) + d * 2.5, a, "res://assets/textures/screen_regent.png", Vector2(5.0, 3.0), true))
	light(Vector3(0, 9, -97), Color(0.5, 0.8, 0.85), 16.0, 1.6)
	# bancas do mercado (cobertura e sombras)
	var tarps := [M["tarp_r"], M["tarp_g"], M["tarp_b"]]
	var n := 0
	for x: float in [-22.0, -12.0, 12.0, 22.0]:
		for z: float in [-76.0, -90.0, -106.0, -118.0]:
			if absf(x) < 13.0 and z > -110.0 and z < -84.0:
				continue
			_stall(sec, Vector3(x, 0, z), tarps[n % 3], n)
			n += 1
	# torre do holofote
	var tp := Vector3(24, 0, -124)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		mesh_at(sec, MeshKit.cylinder(0.14, 10.4, 8), Transform3D(Basis(Vector3.FORWARD, c.x * 0.06) * Basis(Vector3.RIGHT, -c.y * 0.06), tp + Vector3(c.x * 1.1, 5.2, c.y * 1.1)), M["steel"], Vector3(0.3, 10.4, 0.3))
	box(sec, tp + Vector3(0, 10.4, 0), Vector3(3.0, 0.2, 3.0), M["steel"])
	box(sec, tp + Vector3(0, 11.0, 1.45), Vector3(3.0, 1.0, 0.06), M["steel"], Vector3.ZERO, false)
	_search = Searchlight.new()
	add_child(_search)
	_search.position = tp + Vector3(0, 11.4, 0)
	_search.sweep_center = atan2(24.0, -27.0)
	_search.sweep_arc = 0.62
	_search.pitch = -0.32
	_search.sweep_speed = 0.22
	_search.spotted.connect(_on_spotted)
	_search.enabled = not flag("spotted_done")
	# luzes
	for p: Vector3 in [Vector3(-30, 0, -74), Vector3(30, 0, -80), Vector3(-30, 0, -104), Vector3(30, 0, -112), Vector3(-14, 0, -128), Vector3(14, 0, -128)]:
		sodium_lamp(sec, p, atan2(-p.x, -(p.z + 97.0)), 7.5, 2.2)
	# props
	for p in [["crate", Vector3(-17, 0.5, -82)], ["crate", Vector3(17, 0.5, -112)], ["barrel", Vector3(-26, 0.5, -96)], ["explosive", Vector3(26, 0.5, -95)], ["suitcase", Vector3(-6, 0.3, -88)], ["bucket", Vector3(9, 0.3, -122)], ["bottle", Vector3(12.2, 1.05, -76.2)]]:
		prop(p[0], p[1])
	# cidadãos na praça
	if cp_i <= CP_ORDER.find("plaza"):
		var spots := [Vector3(-8, 0.05, -80), Vector3(-6.8, 0.05, -80.5), Vector3(8, 0.05, -112), Vector3(-20, 0.05, -100), Vector3(6, 0.05, -84)]
		for k in spots.size():
			var c := NpcAlly.make("", "citizen", 300 + k)
			add_child(c)
			c.global_position = spots[k]
			c.rotation.y = PI * 0.8 * k
		var pats := [
			["pz_v1", "vigilante_pistol", Vector3(-16, 0.05, -84), [Vector3(-16, 0, -84), Vector3(-16, 0, -112), Vector3(-4, 0, -114)]],
			["pz_v2", "vigilante_pistol", Vector3(16, 0.05, -80), [Vector3(16, 0, -80), Vector3(6, 0, -80), Vector3(6, 0, -110), Vector3(16, 0, -110)]],
			["pz_v3", "vigilante_baton", Vector3(-6, 0.05, -122), [Vector3(-6, 0, -122), Vector3(-28, 0, -118)]],
			["pz_s1", "soldier", Vector3(-30, 0.05, -108), [Vector3(-30, 0, -108), Vector3(-30, 0, -92)]],
		]
		for pz in pats:
			var e := enemy(pz[0], pz[1], pz[2], 0.0, Array(pz[3], TYPE_VECTOR3, "", null))
			if e:
				_plaza_enemies.append(e)
	pickup("pz_med", Vector3(22.0, 1.05, -118.2), "medkit")
	pickup("pz_ammo", Vector3(-22.0, 1.05, -76.2), "ammo_9mm", 30)
	pickup("pz_filter", Vector3(-12.0, 1.05, -118.2), "filter")
	checkpoint("plaza", Vector3(0, 1, -63), Vector3(12, 3, 2), Vector3(0, 0.05, -62), 0.0)
	Interactables.trigger(self, Vector3(0, 1, -66), Vector3(14, 3, 2), func():
		Game.set_objective("obj.ch2.plaza")
		say("speech", D["speech"])
		say("plaza_search", D["plaza_search"]))

func _stall(sec: String, p: Vector3, tarp: Material, n: int) -> void:
	box(sec, p + Vector3(0, 0.5, 0.8), Vector3(2.6, 1.0, 0.8), M["wood"], Vector3.ZERO, true, 0.03)
	box(sec, p + Vector3(0, 2.3, 0), Vector3(3.0, 0.06, 2.6), tarp, Vector3(0.12, 0, 0), false)
	for c: Vector2 in [Vector2(-1.4, -1.2), Vector2(1.4, -1.2), Vector2(-1.4, 1.2), Vector2(1.4, 1.2)]:
		mesh_at(sec, MeshKit.cylinder(0.04, 2.3, 6), Transform3D(Basis(), p + Vector3(c.x, 1.15, c.y)), M["steel"])
	box(sec, p + Vector3(0, 1.05, 0.8), Vector3(2.2, 0.1, 0.5), M["fabric"], Vector3.ZERO, false)
	if n % 2 == 0:
		prop("crate_small", p + Vector3(-0.6, 0.3, -0.6))
	cover(p + Vector3(0, 0, 1.6))
	cover(p + Vector3(0, 0, -0.2))

func _on_spotted(pos: Vector3) -> void:
	if flag("spotted_done"):
		return
	set_flag("spotted_done")
	AudioBus.play_3d("alarm", _search.global_position, 0.0, 0.0, 90.0)
	say("spotted", D["spotted"])
	Game.emit_noise(pos, 70.0, null)
	for e in _plaza_enemies:
		if is_instance_valid(e) and e.alive:
			e.hear_alert(pos)
	# reforço
	var r := enemy("pz_r1", "soldier", Vector3(30, 0.05, -126), PI)
	if r: r.hear_alert(pos)

# =====================================================================
# C) BLOCO 14 (x -51..-35, z -104..-120, 5 andares)
# =====================================================================
const BX0 := -51.0
const BX1 := -35.0
const BZ0 := -104.0
const BZ1 := -120.0
const SW_X0 := -38.2   # poço da escada
const SW_Z0 := -113.5
const SW_Z1 := -118.3

func _build_block() -> void:
	var sec := "block"
	var c := Vector3((BX0 + BX1) * 0.5, 0, (BZ0 + BZ1) * 0.5)
	var h := FLOOR_H * 5.0
	room("plaza", c, Vector3(BX1 - BX0, h, BZ0 - BZ1), M["brick"], M["tiles"], null, [["e", 0.0, 1.6, 2.4]])
	facade_block("plaza", c + Vector3(8.16, 0, 0), Vector3(0.02, h, 16), M["brick"], 70, ["e"], 1)
	box("plaza", Vector3(BX1 + 0.3, 2.6, c.z), Vector3(0.5, 0.2, 2.4), M["conc"], Vector3.ZERO, false)
	poster(Vector3(BX1 + 0.17, 3.2, c.z - 2.0), PI * 0.5, "res://assets/textures/sign_1.png", Vector2(1.4, 0.35))
	box("plaza", Vector3(BX1 + 0.18, 3.0, c.z + 1.6), Vector3(0.05, 0.5, 0.7), Mats.emissive(Color(0.9, 0.85, 0.6), 1.2), Vector3.ZERO, false)
	# lajes com abertura do poço da escada
	for f in range(1, 6):
		var y := f * FLOOR_H
		_slab(sec if f < 5 else "roofs", y, f == 5)
	# escadaria (5 lances alternando lados)
	for f in range(5):
		var y := f * FLOOR_H
		if f % 2 == 0:
			stair(sec, Vector3(SW_X0 + 0.75, y, SW_Z0), 0.0, 1.45, FLOOR_H, M["conc"])
		else:
			stair(sec, Vector3(BX1 - 0.75, y, SW_Z1), PI, 1.45, FLOOR_H, M["conc"])
		# parede central do poço
		box(sec, Vector3(SW_X0 + 1.5, y + FLOOR_H * 0.5, (SW_Z0 + SW_Z1) * 0.5), Vector3(0.08, FLOOR_H, SW_Z0 - SW_Z1), M["plaster"], Vector3.ZERO, true)
		# parede do poço para o corredor (com aberturas nos patamares)
		box(sec, Vector3(SW_X0 - 0.06, y + FLOOR_H * 0.5, (SW_Z0 + SW_Z1) * 0.5), Vector3(0.12, FLOOR_H, SW_Z0 - SW_Z1), M["plaster"], Vector3.ZERO, true)
		if f < 5:
			tube_lamp(sec, Vector3(SW_X0 - 2.5, y + FLOOR_H - 0.33, -112.0), 0.0, Color(0.95, 0.85, 0.6), 1.3, 9.0, f == 2)
		_floor_interior(sec, f, y)
		if f < 5:
			light(Vector3(-40.5, y + 2.5, -117.5), Color(1.0, 0.8, 0.55), 7.0, 0.9)
	# porta interna/saguão
	poster(Vector3(BX1 - 0.17, 1.8, -108.0), -PI * 0.5, "res://assets/textures/poster_1.png")
	acoustic_zone(Vector3(c.x, h * 0.5, c.z), Vector3(15.6, h, 15.6), 0.45, 0.25)
	occluder(Vector3(BX1, h * 0.5, c.z - 5), Vector3(0.3, h, 5.5))
	# saída/entrada (troca interior/exterior)
	Interactables.trigger(self, Vector3(BX1 - 1.0, 1.2, c.z), Vector3(1.2, 2.4, 2.0), func(): _set_outdoor(false), false)
	Interactables.trigger(self, Vector3(BX1 + 1.2, 1.2, c.z), Vector3(1.2, 2.4, 2.0), func(): _set_outdoor(true), false)
	checkpoint("block", Vector3(BX1 - 2.0, 1.2, c.z), Vector3(2.0, 2.4, 3.0), Vector3(BX1 - 2.0, 0.05, c.z + 1.5), PI * 0.5)
	Interactables.trigger(self, Vector3(BX1 + 6.0, 1, c.z), Vector3(4, 3, 6), func():
		say("block_enter", D["block_enter"])
		if not flag("shotgun"): Game.set_objective("obj.ch2.matvei"))
	checkpoint("floor5", Vector3(SW_X0 - 1.0, FLOOR_H * 4 + 1.0, SW_Z1 - 0.8), Vector3(2.0, 2, 1.6), Vector3(SW_X0 - 1.5, FLOOR_H * 4 + 0.05, SW_Z1 - 0.8), PI * 0.5)

func _slab(sec: String, y: float, roof: bool) -> void:
	var t := 0.25
	var mat: Material = M["conc_dark"] if roof else M["tiles"]
	var yc := y - t * 0.5
	# partes: oeste do poço, norte e sul do poço
	box(sec, Vector3((BX0 + SW_X0) * 0.5, yc, (BZ0 + BZ1) * 0.5), Vector3(SW_X0 - BX0, t, BZ0 - BZ1), mat)
	box(sec, Vector3((SW_X0 + BX1) * 0.5, yc, (BZ0 + SW_Z0) * 0.5), Vector3(BX1 - SW_X0, t, BZ0 - SW_Z0), mat)
	box(sec, Vector3((SW_X0 + BX1) * 0.5, yc, (SW_Z1 + BZ1) * 0.5), Vector3(BX1 - SW_X0, t, SW_Z1 - BZ1), mat)
	if not roof:
		# teto rebocado logo abaixo
		box(sec, Vector3((BX0 + BX1) * 0.5, y - t - 0.01, (BZ0 + BZ1) * 0.5), Vector3(BX1 - BX0, 0.02, BZ0 - BZ1), M["plaster"], Vector3.ZERO, false)

func _floor_interior(sec: String, f: int, y: float) -> void:
	var wall: Material = M["plaster"] if f % 2 == 0 else M["plaster_g"]
	var hh := FLOOR_H - 0.25
	# parede corredor/apartamentos em x = -43 com portas em z -108 e -116
	_wall_x(sec, -43.0, y, BZ0, BZ1, hh, [-108.0, -116.0], wall)
	# parede entre apartamentos em z = -112
	box(sec, Vector3((BX0 - 43.0) * 0.5, y + hh * 0.5, -112.0), Vector3(43.0 - BX0 - 0.0, hh, 0.12), wall)
	# rodapé/corredor
	box(sec, Vector3(-40.5, y + 0.05, -112.0), Vector3(4.6, 0.02, 15.6), M["wood"], Vector3.ZERO, false)
	var rng := RandomNumberGenerator.new(); rng.seed = 900 + f
	# apartamentos: norte (z -112..-120) e sul (z -104..-112)
	for apt in 2:
		var zc := -108.0 if apt == 0 else -116.0
		var ap := Vector3(-47.0, y, zc)
		# cama, mesa, cadeira, armário, lâmpada
		box(sec, ap + Vector3(-2.6, 0.25, -2.4 if apt == 0 else 2.4), Vector3(1.8, 0.5, 0.95), M["fabric"], Vector3.ZERO, true, 0.05)
		box(sec, ap + Vector3(1.0, 0.75, 0.0), Vector3(1.2, 0.06, 0.8), M["wood"], Vector3.ZERO, true, 0.01)
		for lx: float in [-0.5, 0.5]:
			for lz: float in [-0.32, 0.32]:
				box(sec, ap + Vector3(1.0 + lx, 0.36, lz), Vector3(0.05, 0.72, 0.05), M["wood"], Vector3.ZERO, false)
		box(sec, ap + Vector3(-3.6, 1.0, 1.6 if apt == 0 else -1.6), Vector3(0.6, 2.0, 1.2), M["wood"], Vector3.ZERO, true, 0.02)
		poster(ap + Vector3(-3.93, 1.6, 0.0), PI * 0.5, "res://assets/textures/poster_%d.png" % ((f + apt) % 3), Vector2(0.8, 1.1))
		if rng.randf() < 0.7:
			prop(["bottle", "bucket", "suitcase", "cinder"][rng.randi() % 4], ap + Vector3(rng.randf_range(-2, 2), 0.3, rng.randf_range(-1.5, 1.5)))
	light(Vector3(-47.0, y + 2.4, -108.0 if f % 2 == 0 else -116.0), Color(1.0, 0.78, 0.5), 9.0, 1.3)
	# moradores
	if f in [1, 3] and cp_i <= CP_ORDER.find("floor5"):
		var cz := NpcAlly.make("", "citizen", 400 + f)
		add_child(cz)
		cz.global_position = Vector3(-46.0, y + 0.05, -107.0)
		cz.rotation.y = PI * 0.5
	# andar 5: Matvei e o armário com a espingarda
	if f == 4:
		var mz := -116.0
		box(sec, Vector3(-50.3, y + 1.0, mz - 2.5), Vector3(0.9, 2.0, 1.4), M["paint"], Vector3.ZERO, true, 0.03)
		if not flag("shotgun"):
			var sg := pickup("shotgun", Vector3(-49.8, y + 1.1, mz - 2.5), "shotgun")
			if sg:
				var cb := sg.on_pick
				sg.on_pick = func():
					cb.call()
					set_flag("shotgun")
					Game.set_objective("obj.ch2.roof")
					_raid()
		pickup("ammo12_a", Vector3(-46.0, y + 0.82, mz), "ammo_12", 12)
		pickup("med_f5", Vector3(-45.6, y + 0.82, mz + 0.3), "medkit")
		_matvei = NpcAlly.make("matvei", "citizen", 611)
		_matvei.body.palette["mask"] = false
		add_child(_matvei)
		_matvei.global_position = Vector3(-44.8, y + 0.05, mz + 2.6)
		_matvei.rotation.y = -PI * 0.75
		_matvei.set_mode(NpcAlly.Mode.SIT)
		_matvei.use_hint = "hud.talk"
		_matvei.on_use = func(): say("matvei", D["matvei"])
		box(sec, Vector3(-44.8, y + 0.22, mz + 2.6), Vector3(0.55, 0.44, 0.55), M["wood"], Vector3.ZERO, true, 0.02)

func _wall_x(sec: String, x: float, y: float, z0: float, z1: float, h: float, doors: Array, mat: Material) -> void:
	var cur := z0
	var ds := doors.duplicate(); ds.sort(); ds.reverse()
	for dz: float in ds:
		var a := dz + 0.6
		var b := dz - 0.6
		if cur > a:
			box(sec, Vector3(x, y + h * 0.5, (cur + a) * 0.5), Vector3(0.12, h, cur - a), mat)
		box(sec, Vector3(x, y + (h + 2.1) * 0.5, dz), Vector3(0.12, h - 2.1, 1.2), mat)
		cur = b
	if cur > z1:
		box(sec, Vector3(x, y + h * 0.5, (cur + z1) * 0.5), Vector3(0.12, h, cur - z1), mat)

func _raid() -> void:
	if flag("raid"):
		return
	set_flag("raid")
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree(): return
	AudioBus.play_3d("door_slam", Vector3(BX1, 1, -112), 4.0, 0.0, 90.0)
	say("raid", D["raid"], true)
	var y4 := FLOOR_H * 4
	var specs := [["rd_v1", "vigilante_pistol", Vector3(-37.0, 0.05, -110.0)], ["rd_v2", "vigilante_pistol", Vector3(-41.0, 0.05, -110.0)],
		["rd_s1", "soldier", Vector3(-40.5, FLOOR_H * 3 + 0.05, -119.0)], ["rd_b1", "vigilante_baton", Vector3(-40.5, FLOOR_H * 2 + 0.05, -106.0)]]
	for s in specs:
		var e := enemy(s[0], s[1], s[2])
		if e:
			e.hear_alert(Vector3(-40.0, y4, -114.0))
	if is_instance_valid(_irina):
		_irina.set_mode(NpcAlly.Mode.FOLLOW)
	pickup("raid_ammo", Vector3(-39.5, y4 + 0.3, -119.0), "ammo_12", 8)
	# Irina segue à frente para o telhado quando o jogador chega lá
	Interactables.trigger(self, Vector3(-36.5, FLOOR_H * 5 + 1.0, -118.0), Vector3(3, 2, 3), func():
		set_flag("raid_done")
		Game.reach_checkpoint("roof")
		Game.set_objective("obj.ch2.roofs")
		_set_outdoor(true))

# =====================================================================
# D) TELHADOS
# =====================================================================
func _build_roofs() -> void:
	var sec := "roofs"
	var y := FLOOR_H * 5.0
	# telhado do Bloco 14: parapeitos, caixa d'água, antenas
	for s in [[Vector3(-43, y + 0.45, BZ0 - 0.0), Vector3(16.6, 0.9, 0.3)], [Vector3(BX0, y + 0.45, -112), Vector3(0.3, 0.9, 16.6)], [Vector3(BX1, y + 0.45, -112), Vector3(0.3, 0.9, 16.6)]]:
		box(sec, s[0], s[1], M["conc_dark"])
	box(sec, Vector3(-48.7, y + 0.45, BZ1), Vector3(4.6, 0.9, 0.3), M["conc_dark"])
	box(sec, Vector3(-37.4, y + 0.45, BZ1), Vector3(4.6, 0.9, 0.3), M["conc_dark"])
	# guarda-corpo em volta do poço da escada no telhado
	box(sec, Vector3(SW_X0 - 0.05, y + 0.5, (SW_Z0 + SW_Z1) * 0.5), Vector3(0.08, 1.0, SW_Z0 - SW_Z1), M["steel"])
	box(sec, Vector3((SW_X0 + BX1) * 0.5, y + 0.5, SW_Z0 + 0.05), Vector3(BX1 - SW_X0, 1.0, 0.08), M["steel"])
	var tank := MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(1.3, 0), Vector2(1.3, 2.2), Vector2(0.9, 2.8), Vector2(0, 2.9)]), 14)
	mesh_at(sec, tank, Transform3D(Basis(), Vector3(-48, y + 1.2, -107)), M["paint"], Vector3(2.6, 2.9, 2.6), Vector3(0, 1.45, 0))
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		box(sec, Vector3(-48 + c.x, y + 0.6, -107 + c.y), Vector3(0.12, 1.2, 0.12), M["steel"])
	for p: Vector3 in [Vector3(-44, y, -106), Vector3(-41, y, -117)]:
		mesh_at(sec, MeshKit.cylinder(0.04, 4.5, 6), Transform3D(Basis(), p + Vector3(0, 2.25, 0)), M["steel"])
		box(sec, p + Vector3(0, 4.0, 0), Vector3(1.6, 0.04, 0.04), M["steel"], Vector3.ZERO, false)
	box(sec, Vector3(-45, y + 0.5, -113), Vector3(2.0, 1.0, 1.4), M["steel"], Vector3.ZERO, true, 0.05)
	cover(Vector3(-45, y, -111.8))
	light(Vector3(-40, y + 3.0, -112), Color(0.9, 0.75, 0.55), 10.0, 0.6)
	# tábua para atravessar (opcional — também dá para saltar correndo)
	if cp_i <= CP_ORDER.find("roof"):
		var pl := prop("plank", Vector3(-48.5, y + 0.2, -116.5), PI * 0.5)
		pl.rotation.y = PI * 0.5
	Interactables.trigger(self, Vector3(-43, y + 1.0, -118.5), Vector3(5, 2, 2), func():
		say("roof_gap", D["roof_gap"]))
	# telhado B (1 m mais baixo, vão de 3,5 m)
	var yb := y - 1.0
	facade_block(sec, Vector3(-44, 0, -132.0), Vector3(16, yb, 16.5), M["plaster_g"], 81, ["e", "w"])
	box(sec, Vector3(-44, yb + 0.02, -132.0), Vector3(16, 0.04, 16.5), M["gravel"], Vector3.ZERO, false)
	for s in [[Vector3(-52, yb + 0.45, -132), Vector3(0.3, 0.9, 16.5)], [Vector3(-36, yb + 0.45, -132), Vector3(0.3, 0.9, 16.5)]]:
		box(sec, s[0], s[1], M["conc_dark"])
	for p: Vector3 in [Vector3(-48, yb, -129), Vector3(-40, yb, -135), Vector3(-46, yb, -137)]:
		box(sec, p + Vector3(0, 0.7, 0), Vector3(2.2, 1.4, 1.4), M["steel"], Vector3.ZERO, true, 0.06)
		mesh_at(sec, MeshKit.cylinder(0.55, 0.1, 14), Transform3D(Basis(), p + Vector3(0, 1.45, 0)), M["steel"])
		cover(p + Vector3(0, 0, 1.2)); cover(p + Vector3(0, 0, -1.2))
	box(sec, Vector3(-40.5, yb + 0.6, -128.5), Vector3(1.4, 1.2, 1.4), M["conc_dark"])
	for p: Vector3 in [Vector3(-50, yb, -139), Vector3(-38, yb, -125)]:
		mesh_at(sec, MeshKit.bevel_box(Vector3(1.0, 3.0, 1.0), 0.04, 1), Transform3D(Basis(), p + Vector3(0, 1.5, 0)), M["brick_dark"], Vector3(1, 3, 1))
	Interactables.trigger(self, Vector3(-44, yb + 1.0, -126.0), Vector3(14, 2, 3), _roof_b)
	pickup("rb_ammo", Vector3(-48.0, yb + 1.55, -129.0), "ammo_12", 8)
	pickup("rb_med", Vector3(-40.0, yb + 1.55, -135.0), "medkit")
	# viga de aço até o telhado C (vão de 6 m)
	box(sec, Vector3(-44, yb - 0.15, -143.0), Vector3(0.55, 0.3, 6.6), M["steel"])
	box(sec, Vector3(-44, yb - 0.45, -143.0), Vector3(0.12, 0.3, 6.6), M["steel"], Vector3.ZERO, false)
	box(sec, Vector3(-41.5, yb - 0.6, -142.2), Vector3(0.5, 0.25, 3.2), M["steel"], Vector3(0.4, 0.3, 0.6), false)
	box(sec, Vector3(-48.3, yb + 0.45, -140.25), Vector3(7.4, 0.9, 0.3), M["conc_dark"])
	box(sec, Vector3(-39.7, yb + 0.45, -140.25), Vector3(7.4, 0.9, 0.3), M["conc_dark"])
	# telhado C
	facade_block(sec, Vector3(-44, 0, -155.5), Vector3(16, yb, 18), M["brick"], 82, ["e", "w", "n"])
	box(sec, Vector3(-44, yb + 0.02, -155.5), Vector3(16, 0.04, 18), M["gravel"], Vector3.ZERO, false)
	box(sec, Vector3(-52, yb + 0.45, -155.5), Vector3(0.3, 0.9, 18), M["conc_dark"])
	box(sec, Vector3(-36, yb + 0.45, -155.5), Vector3(0.3, 0.9, 18), M["conc_dark"])
	box(sec, Vector3(-49.5, yb + 0.45, -164.5), Vector3(5, 0.9, 0.3), M["conc_dark"])
	box(sec, Vector3(-39.5, yb + 0.45, -164.5), Vector3(7, 0.9, 0.3), M["conc_dark"])
	for p: Vector3 in [Vector3(-48, yb, -150), Vector3(-40, yb, -158)]:
		box(sec, p + Vector3(0, 0.9, 0), Vector3(1.8, 1.8, 3.0), M["paint"], Vector3.ZERO, true, 0.05)
		cover(p + Vector3(1.4, 0, 0)); cover(p + Vector3(-1.4, 0, 0))
	checkpoint("roofs2", Vector3(-44, yb + 1.0, -148.0), Vector3(14, 2, 2), Vector3(-44, yb + 0.05, -148.5), 0.0)
	Interactables.trigger(self, Vector3(-44, yb + 1.0, -147.0), Vector3(14, 2, 2), func():
		Game.set_objective("obj.ch2.ladder"))
	if cp_i <= CP_ORDER.find("roofs2"):
		enemy("rc_s1", "soldier", Vector3(-38, yb + 0.05, -161), PI)
		enemy("rc_v1", "vigilante_pistol", Vector3(-49, yb + 0.05, -160), PI)
	# escada para o beco (desce 14,8 m)
	Interactables.ladder(self, Vector3(-45.0, 0, -164.95), 0.0, yb + 0.2)
	ramp(sec, Vector3(-45.0, yb + 0.01, -164.0), Vector3(-45.0, yb + 0.01, -164.9), 1.0)
	mesh_at(sec, MeshKit.bevel_box(Vector3(0.9, 0.08, 0.6), 0.01, 1), Transform3D(Basis(), Vector3(-45, yb + 0.04, -164.4)), M["steel"])
	light(Vector3(-45, 3.0, -166.5), Color(1.0, 0.6, 0.3), 8.0, 1.2)
	# beco no chão
	box(sec, Vector3(-44, -0.15, -171), Vector3(16, 0.3, 12), M["asphalt"])
	box(sec, Vector3(-52.3, 3, -171), Vector3(0.6, 6, 12), M["brick_dark"])
	box(sec, Vector3(-35.7, 3, -171), Vector3(0.6, 6, 12), M["brick_dark"])
	box(sec, Vector3(-44, 3, -177.3), Vector3(16, 6, 0.6), M["dominion"])
	for p in [["barrel", Vector3(-50, 0.5, -170)], ["crate", Vector3(-38, 0.5, -175)], ["bucket", Vector3(-41, 0.3, -168)]]:
		prop(p[0], p[1])
	Interactables.trigger(self, Vector3(-44, 1.0, -174.5), Vector3(8, 2.5, 2), _exit_reached)

func _roof_b() -> void:
	if flag("roof_b"):
		return
	set_flag("roof_b")
	var yb := FLOOR_H * 5.0 - 1.0
	var e1 := enemy("rb_v1", "vigilante_pistol", Vector3(-40.5, yb + 0.05, -130.0), PI)
	var e2 := enemy("rb_v2", "vigilante_pistol", Vector3(-48.0, yb + 0.05, -138.0), PI)
	for e in [e1, e2]:
		if e: e.hear_alert(player.global_position)
	# Irina fica para trás, encurralada pelos Vigilantes que subiram
	var ys := enemy("ra_s1", "soldier", Vector3(-37.0, FLOOR_H * 5 + 0.05, -116.0), PI)
	if ys: ys.hear_alert(Vector3(-44, FLOOR_H * 5, -110))
	if is_instance_valid(_irina):
		_irina.set_mode(NpcAlly.Mode.IDLE)
		_irina.go_to(Vector3(-46.0, FLOOR_H * 5, -106.0), 3.5)
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree(): return
	say("roof_split", D["roof_split"])
	await say_done("roof_split")
	if is_instance_valid(_irina):
		_irina.visible = false

# =====================================================================
# E) HORIZONTE (cidade distante, chaminés do Distrito Leste)
# =====================================================================
func _build_far() -> void:
	var sec := "far"
	var rng := RandomNumberGenerator.new(); rng.seed = 2
	for i in 16:
		var p := Vector3(rng.randf_range(-160, 120), 0, rng.randf_range(-320, -190))
		var h := rng.randf_range(20, 55)
		mesh_at(sec, MeshKit.bevel_box(Vector3(rng.randf_range(14, 30), h, rng.randf_range(12, 22)), 0.3, 1), Transform3D(Basis(Vector3.UP, rng.randf() * 0.3), p + Vector3(0, h * 0.5, 0)), M["conc_dark"])
	for i in 4:
		var p := Vector3(-90 + i * 26, 0, -230 - i * 8)
		var stack := MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(4.5, 0), Vector2(3.0, 60), Vector2(3.3, 61), Vector2(0, 61)]), 14)
		mesh_at(sec, stack, Transform3D(Basis(), p), M["brick_dark"])
		var smoke := CPUParticles3D.new()
		smoke.amount = int(12 * float(Settings.get_v("graphics", "particles", 1.0)))
		smoke.lifetime = 10.0
		smoke.position = p + Vector3(0, 62, 0)
		smoke.direction = Vector3(0.4, 1, 0)
		smoke.initial_velocity_min = 2.0; smoke.initial_velocity_max = 3.5
		smoke.gravity = Vector3(1.0, 0.3, 0)
		smoke.scale_amount_min = 6.0; smoke.scale_amount_max = 12.0
		var q := QuadMesh.new()
		var sm := StandardMaterial3D.new()
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color(0.28, 0.27, 0.27, 0.4)
		if ResourceLoader.exists("res://assets/textures/fx_smoke.png"):
			sm.albedo_texture = load("res://assets/textures/fx_smoke.png")
		q.material = sm
		smoke.mesh = q
		add_child(smoke)
		var bl := MeshInstance3D.new(); bl.mesh = MeshKit.bevel_box(Vector3(0.8, 0.8, 0.8), 0.1, 1)
		bl.material_override = Mats.emissive(Color(1.0, 0.2, 0.1), 4.0)
		bl.position = p + Vector3(3.2, 58, 0)
		add_child(bl)

func _set_outdoor(on: bool) -> void:
	_sun.light_cull_mask = 3 if on else 2
	if on:
		AudioBus.set_room(0.2, 0.08)
		AudioBus.play_ambience("res://assets/audio/ambience/wind_city.wav", "res://assets/audio/ambience/rain.wav", -9.0)
	else:
		AudioBus.set_room(0.45, 0.25)
		AudioBus.play_ambience("res://assets/audio/ambience/industrial_hum.wav", "", -16.0)

func _exit_reached() -> void:
	if flag("done"):
		return
	set_flag("done")
	player.input_enabled = false
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	Game.complete_chapter()
