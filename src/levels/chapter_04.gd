extends LevelBase
## Capítulo 4 — "A Muralha" (Ato I, encerramento).
## A) Coletor de esgoto sob a Fundição: passarelas, canal central, patrulha de Vigilantes,
##    comporta fechada → roda de manivela na sala de bombas (passarela elevada)
## B) Doca velha: o barco de Irina · C) Canal oeste: pontes, Discurso do Regente nas telas,
##    o helicóptero Caçador persegue o barco · D) Barreira no canal: desembarcar, cabine do cais,
##    abrir a grade · E) Reservatório: canhão antiaéreo no píer, derrubar o Caçador
## F) Cais de carga aos pés da Muralha: contêineres, holofotes, soldados · G) Elevador → topo.
## Inspirações (conceitos de canais/Muralha/costa dos roteiros 2001–2002 do HL2 beta, ver
## docs/01_PESQUISA_HL2_BETA.md); geometria, roteiro e personagens são originais.

const CP_ORDER := ["start", "dock", "barrier", "basin", "quay"]
const WATER_Y := -1.0
const CANAL_FLOOR := -2.6
const CANAL_Z0 := -60.0
const CANAL_Z1 := -240.0
const BASIN_Z1 := -320.0
const WALL_Z := -420.0
const BOAT_SPAWN := {
	"start": [Vector3(-1.5, WATER_Y, -72.0), 0.0], "dock": [Vector3(-1.5, WATER_Y, -72.0), 0.0],
	"barrier": [Vector3(2.6, WATER_Y, -189.0), 0.0], "basin": [Vector3(18.5, WATER_Y, -268.0), 0.0],
	"quay": [Vector3(3.6, WATER_Y, -314.0), 0.0],
}
var D := {}
var cp_i := 0
var M := {}
var _sun: DirectionalLight3D
var _gate: AnimatableBody3D
var _crank: Interactables.Switch
var _grate: AnimatableBody3D
var _grate_btn: Interactables.Switch
var _boat: Vehicle
var _heli: HunterHeli
var _turret: FlakTurret
var _lights_search: Array[Searchlight] = []
var _elevator: AnimatableBody3D
var _elev_lever: Interactables.Switch
var _kovac: NpcAlly
var _irina: NpcAlly
var _quay_enemies: Array[EnemyAI] = []
var _heli_hit_said := false

func _mats() -> void:
	M = {
		"conc": Mats.get_mat("concrete", 0.35, Color(0.66, 0.66, 0.63)),
		"conc_dark": Mats.get_mat("concrete", 0.35, Color(0.4, 0.42, 0.41)),
		"sewer": Mats.get_mat("brick", 0.4, Color(0.42, 0.44, 0.38)),
		"sewer_floor": Mats.get_mat("tiles", 0.3, Color(0.42, 0.44, 0.4)),
		"brick": Mats.get_mat("brick", 0.4, Color(0.6, 0.54, 0.5)),
		"asphalt": Mats.get_mat("asphalt", 0.3, Color(0.72, 0.72, 0.72)),
		"paving": Mats.get_mat("tiles", 0.25, Color(0.55, 0.56, 0.54)),
		"paint": Mats.get_mat("rusted_paint", 0.5, Color(0.55, 0.66, 0.62)),
		"paint_y": Mats.get_mat("rusted_paint", 0.5, Color(0.85, 0.7, 0.3)),
		"paint_r": Mats.get_mat("rusted_paint", 0.5, Color(0.72, 0.38, 0.32)),
		"paint_b": Mats.get_mat("rusted_paint", 0.5, Color(0.4, 0.5, 0.62)),
		"steel": Mats.get_mat("steel", 0.6, Color(0.6, 0.6, 0.58)),
		"steel_dark": Mats.get_mat("steel", 0.6, Color(0.36, 0.36, 0.35)),
		"grate": Mats.get_mat("grate", 0.6, Color(0.7, 0.7, 0.68)),
		"corr": Mats.get_mat("corrugated", 0.35, Color(0.62, 0.66, 0.6)),
		"corr_r": Mats.get_mat("corrugated", 0.35, Color(0.7, 0.42, 0.34)),
		"corr_b": Mats.get_mat("corrugated", 0.35, Color(0.42, 0.52, 0.62)),
		"dominion": Mats.get_mat("dominion", 0.12),
		"wood": Mats.get_mat("wood", 0.8, Color(0.62, 0.54, 0.44)),
		"gravel": Mats.get_mat("gravel", 0.3, Color(0.75, 0.74, 0.72)),
		"silt": Mats.get_mat("cracked_earth", 0.3, Color(0.42, 0.42, 0.38)),
		"water": Mats.water(Color(0.55, 0.62, 0.6)),
		"glass": Mats.glass(),
	}

func build() -> void:
	_mats()
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch4.json"))
	cp_i = maxi(0, CP_ORDER.find(Game.checkpoint))
	grid = {"sewer": 16.0, "canal": 24.0, "basin": 24.0, "quay": 24.0}
	outdoor = {"canal": true, "basin": true, "quay": true, "wall": true}
	sector("canal", 150.0)
	setup_env(Color(0.1, 0.12, 0.15), Color(0.36, 0.4, 0.44), 0.9, Color(0.2, 0.23, 0.26), 0.012, 0.0, 0.5)
	env.tonemap_exposure = 1.4
	_sun = sun(Vector3(-28, 200, 0), Color(0.72, 0.8, 0.95), 0.55, true)
	_sun.light_cull_mask = 2
	nav_aabb = AABB(Vector3(-45, -4, -430), Vector3(90, 40, 432))
	_build_sewer()
	_build_canal()
	_build_barrier()
	_build_basin()
	_build_quay()
	_build_wall()
	checkpoints["start"] = [Vector3(2.0, 0.05, -2), 0.0]

func after_build() -> void:
	AudioBus.start_music()
	AudioBus.play_ambience("res://assets/audio/ambience/sewer.wav" if cp_i == 0 else "res://assets/audio/ambience/canal.wav", "", -8.0)
	AudioBus.set_room(0.7, 0.45 if cp_i == 0 else 0.15)
	player.set_mask(true)
	ensure_loadout(["wrench", "pistol", "smg", "shotgun"])
	# barco
	_boat = Vehicle.make("boat")
	_boat.water_y = WATER_Y
	add_child(_boat)
	var bs: Array = BOAT_SPAWN.get(Game.checkpoint, BOAT_SPAWN["start"])
	_boat.global_position = bs[0]
	_boat.rotation.y = bs[1]
	_boat.entered.connect(_on_boat_entered)
	# estado persistente
	if flag("gate_open"):
		_gate.position.y = 4.4
		_crank.used = true
	if flag("barrier_open"):
		_grate.position.y = 4.6
		_grate_btn.used = true
	match Game.checkpoint:
		"start": Game.set_objective("obj.ch4.sewer")
		"dock": Game.set_objective("obj.ch4.boat")
		"barrier": Game.set_objective("obj.ch4.boat" if flag("barrier_open") else "obj.ch4.barrier")
		"basin": Game.set_objective("obj.ch4.heli" if not flag("heli_dead") else "obj.ch4.wall")
		"quay": Game.set_objective("obj.ch4.wall")
	if cp_i >= CP_ORDER.find("barrier") and cp_i <= CP_ORDER.find("basin") and not flag("heli_dead"):
		_spawn_heli(Vector3(0, 22, _boat.global_position.z - 50.0))
		if cp_i == CP_ORDER.find("basin"):
			_heli_to_basin()
	# Kovač e Irina no topo da Muralha
	_kovac = NpcAlly.make("kovac", "conscript", 41, "rifle")
	add_child(_kovac)
	_kovac.global_position = Vector3(5.5, 30.05, WALL_Z + 4.5)
	_kovac.rotation.y = PI
	_kovac.set_mode(NpcAlly.Mode.IDLE)
	_irina = NpcAlly.make("irina", "conscript", 77, "rifle")
	_irina.body.palette["mask"] = false
	add_child(_irina)
	_irina.global_position = Vector3(-5.5, 30.05, WALL_Z + 4.5)
	_irina.rotation.y = PI
	_irina.set_mode(NpcAlly.Mode.IDLE)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(_heli) and _heli.alive and not _heli_hit_said and _heli.health < _heli.max_health * 0.6:
		_heli_hit_said = true
		say("heli_hit", D["heli_hit"])

# =====================================================================
# A) COLETOR (z 0 .. -60): passarelas laterais, canal central raso
# =====================================================================
func _build_sewer() -> void:
	var sec := "sewer"
	var z0 := 1.0
	var z1 := CANAL_Z0
	var L := z0 - z1
	var zc := (z0 + z1) * 0.5
	# passarelas e canal
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(2.0 * s, -0.15, zc), Vector3(2.0, 0.3, L), M["sewer_floor"])
		box(sec, Vector3(1.05 * s, -0.2, zc), Vector3(0.1, 0.4, L), M["conc_dark"], Vector3.ZERO, false)
		if s < 0.0:
			box(sec, Vector3(3.15 * s, 1.8, zc), Vector3(0.3, 3.6, L), M["sewer"])
		else:
			box(sec, Vector3(3.15, 1.8, (z0 - 23.0) * 0.5), Vector3(0.3, 3.6, z0 + 23.0), M["sewer"])
			box(sec, Vector3(3.15, 1.8, (-25.0 + z1) * 0.5), Vector3(0.3, 3.6, -25.0 - z1), M["sewer"])
			box(sec, Vector3(3.15, 3.1, -24.0), Vector3(0.3, 1.0, 2.0), M["sewer"])
		# tubulações nas paredes
		mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(2.8 * s, 2.9, z0), Vector3(2.8 * s, 2.9, z1)]), 0.14, 10), Transform3D(), M["steel_dark"])
		mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(2.85 * s, 0.5, z0), Vector3(2.85 * s, 0.5, z1)]), 0.08, 8), Transform3D(), M["paint"])
	box(sec, Vector3(0, -0.55, zc), Vector3(2.0, 0.3, L), M["silt"])
	box(sec, Vector3(0, -0.28, zc), Vector3(2.0, 0.04, L), M["water"], Vector3.ZERO, false)
	box(sec, Vector3(0, 3.75, zc), Vector3(6.6, 0.3, L), M["sewer"])
	box(sec, Vector3(0, 1.8, z0 + 0.15), Vector3(6.6, 3.6, 0.3), M["sewer"])
	# arcos estruturais a cada 8 m
	for z in range(-6, int(z1), -8):
		for s: float in [-1.0, 1.0]:
			box(sec, Vector3(2.85 * s, 1.8, z), Vector3(0.3, 3.6, 0.5), M["conc_dark"], Vector3.ZERO, false)
		box(sec, Vector3(0, 3.45, z), Vector3(6.0, 0.3, 0.5), M["conc_dark"], Vector3.ZERO, false)
	# rampas para sair do canal
	for z: float in [-14.0, -40.0, -52.0]:
		ramp(sec, Vector3(0.5, -0.4, z), Vector3(1.2, 0.0, z), 1.2)
		box(sec, Vector3(0.55, -0.22, z), Vector3(0.9, 0.36, 1.2), M["conc"], Vector3(0, 0, 0.45), false)
	for z: float in [-8.0, -20.0, -32.0, -44.0, -56.0]:
		tube_lamp(sec, Vector3(0, 3.55, z), 0.0, Color(0.7, 0.9, 0.78), 0.9, 9.0, z == -20.0 or z == -44.0)
	# comporta (z -34)
	_gate = AnimatableBody3D.new()
	_gate.sync_to_physics = false
	_gate.set_meta("surface", "metal")
	var gcs := CollisionShape3D.new(); var gbs := BoxShape3D.new(); gbs.size = Vector3(6.0, 4.0, 0.3); gcs.shape = gbs
	_gate.add_child(gcs)
	var gp := []
	for i in 13:
		gp.append([MeshKit.cylinder(0.05, 4.0, 6), Transform3D(Basis(), Vector3(-2.8 + i * 0.466, 0, 0))])
	for y: float in [-1.6, -0.4, 0.8, 1.8]:
		gp.append([MeshKit.bevel_box(Vector3(6.0, 0.18, 0.22), 0.02, 1), Transform3D(Basis(), Vector3(0, y, 0))])
	var gm := MeshInstance3D.new(); gm.mesh = MeshKit.combine(gp); gm.material_override = M["steel_dark"]
	_gate.add_child(gm)
	add_child(_gate)
	_gate.position = Vector3(0, 1.4, -34.0)
	poster(Vector3(0, 3.0, -33.8), 0.0, "res://assets/textures/sign_1.png", Vector2(1.6, 0.4), true)
	# sala de bombas (lado leste, z -20 .. -32): passarela elevada a 2,2 m
	var rc := Vector3(7.3, 0, -26.0)
	room(sec, rc, Vector3(8.0, 6.0, 12.0), M["sewer"], M["sewer_floor"], M["conc_dark"], [["w", 2.0, 2.0, 2.6]])
	var top := stair(sec, Vector3(5.2, 0, -21.0), 0.0, 1.4, 2.2, M["steel"])
	box(sec, Vector3(7.3, 2.125, -28.2), Vector3(8.0, 0.15, 7.6), M["grate"])
	ramp(sec, top, top + Vector3(0, 0, -0.5), 1.4)
	box(sec, Vector3(8.8, 2.75, -24.45), Vector3(4.4, 1.1, 0.06), M["paint_y"])
	# bombas (cilindros) no piso
	for x: float in [6.6, 9.6]:
		mesh_at(sec, MeshKit.cylinder(0.9, 1.6, 16, 0.04), Transform3D(Basis(), Vector3(x, 0.8, -29.0)), M["paint_b"], Vector3(1.8, 1.6, 1.8))
		mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(x, 1.6, -29.0), Vector3(x, 4.6, -29.0), Vector3(x, 4.6, -31.7)]), 0.12, 8), Transform3D(), M["steel_dark"])
	_crank = Interactables.lever(self, Vector3(9.8, 2.2, -31.6), 0.0)
	_crank.hint_key = "hud.use"
	_crank.activated.connect(_open_gate)
	mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(0.38, -0.03), Vector2(0.42, 0.0), Vector2(0.38, 0.03), Vector2(0.34, 0.0)]), 16, false, false), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(9.8, 3.6, -31.8)), M["paint_r"])
	light(Vector3(7.3, 4.8, -26), Color(1.0, 0.85, 0.6), 10.0, 1.4)
	light(Vector3(9.5, 3.6, -30.5), Color(0.9, 0.55, 0.3), 5.0, 0.8)
	for p in [["barrel", Vector3(4.2, 0.5, -30.5)], ["crate", Vector3(10.5, 0.5, -21.0)], ["bucket", Vector3(4.5, 0.3, -23.5)]]:
		prop(p[0], p[1])
	pickup("s_filter", Vector3(10.5, 1.05, -21.0), "filter")
	pickup("s_flare", Vector3(5.0, 2.4, -31.0), "flaregun")
	pickup("s_9mm", Vector3(-2.4, 0.1, -46.0), "ammo_9mm", 24)
	acoustic_zone(Vector3(0, 1.8, -30), Vector3(6, 3.6, 60), 0.8, 0.55, "res://assets/audio/ambience/sewer.wav", -8.0)
	# roteiro
	Interactables.trigger(self, Vector3(0, 1, -4), Vector3(6, 3, 2), func():
		say("sewer_intro", D["sewer_intro"]))
	Interactables.trigger(self, Vector3(0, 1, -12), Vector3(6, 3, 2), func():
		say("vig_radio", D["vig_radio"]))
	Interactables.trigger(self, Vector3(0, 1, -29.5), Vector3(6, 3, 2), func():
		if not flag("gate_open"):
			say("gate_closed", D["gate_closed"])
			Game.set_objective("obj.ch4.gate"))
	if cp_i == 0:
		enemy("s_v1", "vigilante_baton", Vector3(2.0, 0.05, -24.0), 0.0, [Vector3(2.0, 0.05, -26.0), Vector3(2.0, 0.05, -10.0)] as Array[Vector3])
		enemy("s_v2", "vigilante_pistol", Vector3(-2.0, 0.05, -48.0), 0.0, [Vector3(-2.0, 0.05, -50.0), Vector3(-2.0, 0.05, -38.0)] as Array[Vector3])
		enemy("s_v3", "vigilante_pistol", Vector3(7.5, 2.25, -30.5), PI)

func _water_ladder(base: Vector3, yaw: float, h: float) -> void:
	Interactables.ladder(self, base, yaw, h)

func _open_gate() -> void:
	set_flag("gate_open")
	AudioBus.play_3d("gate_motor", _gate.global_position, 2.0, 0.0, 60.0)
	if is_instance_valid(player): player.shake(0.2)
	var tw := create_tween()
	tw.tween_property(_gate, "position:y", 4.4, 4.0).set_trans(Tween.TRANS_SINE)
	say("gate_open", D["gate_open"])
	Game.set_objective("obj.ch4.sewer")

# =====================================================================
# B/C) DOCA + CANAL OESTE (z -60 .. -240), canal x ±7
# =====================================================================
func _canal_section(sec: String, z0: float, z1: float, half_w: float) -> void:
	var L := z0 - z1
	var zc := (z0 + z1) * 0.5
	box(sec, Vector3(0, CANAL_FLOOR - 0.15, zc), Vector3(half_w * 2.0, 0.3, L), M["silt"])
	box(sec, Vector3(0, WATER_Y - 0.03, zc), Vector3(half_w * 2.0, 0.06, L), M["water"], Vector3.ZERO, false)

func _build_canal() -> void:
	var sec := "canal"
	# saída do coletor: plataforma de concreto de margem a margem
	box(sec, Vector3(0, -0.15, -63.0), Vector3(14.0, 0.3, 6.0), M["conc"])
	box(sec, Vector3(0, (CANAL_FLOOR - 0.3) * 0.5, -66.15), Vector3(14.0, -CANAL_FLOOR + 0.3, 0.3), M["conc_dark"])
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(12.65 * s, 6.0, -59.85), Vector3(19.0, 12.0, 0.3), M["brick"])
	box(sec, Vector3(0, 7.8, -59.85), Vector3(6.6, 8.4, 0.3), M["brick"])
	# pontão (doca velha) e degraus
	box(sec, Vector3(-5.0, -0.65, -72.5), Vector3(3.6, 0.3, 10.0), M["wood"])
	stair(sec, Vector3(-5.0, -0.5, -68.0), PI, 2.0, 0.5, M["wood"])
	box(sec, Vector3(-5.0, -0.15, -66.6), Vector3(2.0, 0.3, 1.2), M["wood"])
	_water_ladder(Vector3(-3.1, CANAL_FLOOR, -74.0), PI * 0.5, 2.1)
	for z: float in [-67.0, -71.5, -76.0]:
		mesh_at(sec, MeshKit.cylinder(0.14, 2.4, 10), Transform3D(Basis(), Vector3(-3.3, -1.4, z)), M["wood"])
	_canal_section(sec, -66.0, CANAL_Z1, 7.0)
	# muros do canal e cais
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(7.3 * s, (CANAL_FLOOR) * 0.5 - 0.15, (-60.0 + CANAL_Z1) * 0.5), Vector3(0.6, -CANAL_FLOOR + 0.3, -60.0 - CANAL_Z1), M["conc_dark"])
		box(sec, Vector3(15.0 * s, -0.15, (-60.0 + CANAL_Z1) * 0.5), Vector3(15.4, 0.3, -60.0 - CANAL_Z1), M["paving"])
		if s < 0.0:
			box(sec, Vector3(-7.45, 0.5, (-66.0 + CANAL_Z1) * 0.5), Vector3(0.3, 1.0, -66.0 - CANAL_Z1), M["conc"])
		else:
			box(sec, Vector3(7.45, 0.5, (-66.0 - 194.0) * 0.5), Vector3(0.3, 1.0, 194.0 - 66.0), M["conc"])
			box(sec, Vector3(7.45, 0.5, (-199.0 + CANAL_Z1) * 0.5), Vector3(0.3, 1.0, -199.0 - CANAL_Z1), M["conc"])
		# fachadas residenciais dos dois lados
		var z := -66.0
		var i := 0
		while z > CANAL_Z1 + 10.0:
			var w := 18.0 + float((i * 7) % 3) * 4.0
			var h := 16.0 + float((i * 5) % 4) * 3.2
			facade_block(sec, Vector3(26.0 * s, 0, z - w * 0.5), Vector3(12.0, h, w), M["brick"] if i % 2 == 0 else M["conc"], 400 + i * 13 + int(s * 3.0), ["w"] if s > 0.0 else ["e"])
			z -= w + 2.0
			i += 1
		# postes de sódio
		for zz in range(-80, int(CANAL_Z1), -28):
			sodium_lamp(sec, Vector3(9.0 * s, 0, zz), PI * 0.5 * s, 6.0, 1.8, false)
	# pontes (o barco passa por baixo)
	for bz: float in [-112.0, -168.0]:
		box(sec, Vector3(0, 4.6, bz), Vector3(44.0, 0.7, 6.0), M["conc"], Vector3.ZERO, true, 0.04)
		for s: float in [-1.0, 1.0]:
			box(sec, Vector3(0, 5.5, bz + 2.85 * s), Vector3(44.0, 1.1, 0.25), M["conc_dark"])
			box(sec, Vector3(11.0 * s, 2.1, bz), Vector3(1.2, 4.3, 5.0), M["conc_dark"])
		poster(Vector3(0, 7.2, bz + 3.1), 0.0, "res://assets/textures/screen_regent.png", Vector2(4.0, 2.25), true)
		box(sec, Vector3(0, 7.2, bz + 3.0), Vector3(4.4, 2.6, 0.2), M["steel_dark"], Vector3.ZERO, false)
		light(Vector3(0, 3.2, bz), Color(0.9, 0.95, 1.0), 12.0, 1.0)
	# barcos e destroços
	for p in [[Vector3(-5.2, WATER_Y + 0.2, -128.0), 0.2], [Vector3(5.0, WATER_Y + 0.1, -150.0), -0.3]]:
		mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(0.05, -2.2), Vector2(0.8, -1.4), Vector2(0.9, 1.0), Vector2(0.6, 2.2), Vector2(0.05, 2.3)]), 10), Transform3D(Basis(Vector3.UP, p[1]) * Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(1, 0.4, 1)), p[0]), M["paint_r"])
	for p in [["barrel", Vector3(10.0, 0.5, -90.0)], ["crate", Vector3(-11.0, 0.5, -100.0)], ["explosive", Vector3(-9.0, 4.9, -168.0)], ["explosive", Vector3(9.0, 4.9, -112.0)], ["crate", Vector3(12.0, 0.5, -140.0)]]:
		prop(p[0], p[1])
	car_wreck(sec, Vector3(13.0, 0, -125.0), 0.3, Color(0.45, 0.32, 0.25))
	car_wreck(sec, Vector3(-12.0, 0, -150.0), -2.0, Color(0.3, 0.38, 0.42))
	pickup("c_med", Vector3(-11.0, 1.05, -100.0), "medkit")
	pickup("c_smg1", Vector3(12.0, 1.05, -140.0), "smg1")
	acoustic_zone(Vector3(0, 2, -63), Vector3(14, 4, 4), 0.35, 0.12, "res://assets/audio/ambience/canal.wav", -8.0)
	# roteiro
	checkpoint("dock", Vector3(0, 1, -62.5), Vector3(14, 3, 2), Vector3(-5.0, -0.45, -69.0), 0.0)
	Interactables.trigger(self, Vector3(0, 1, -64), Vector3(14, 3, 3), func():
		say("boat", D["boat"])
		Game.set_objective("obj.ch4.boat"))
	Interactables.trigger(self, Vector3(0, 0, -106), Vector3(14, 4, 3), func():
		say("regente_canal", D["regente_canal"]))
	Interactables.trigger(self, Vector3(0, 0, -132), Vector3(14, 4, 3), func():
		if not flag("heli_dead") and not is_instance_valid(_heli):
			_spawn_heli(Vector3(-20, 26, -190))
			say("heli_appears", D["heli_appears"], true))
	if cp_i <= CP_ORDER.find("dock"):
		enemy("c_v1", "vigilante_pistol", Vector3(-6.0, 5.0, -168.0), 0.0)
		enemy("c_v2", "vigilante_pistol", Vector3(5.0, 5.0, -168.0), 0.0)
		enemy("c_v3", "vigilante_pistol", Vector3(10.0, 0.05, -92.0), PI * 0.5)

func _on_boat_entered(_by: Node) -> void:
	if Game.checkpoint in ["start", "dock"] and not flag("left_dock"):
		set_flag("left_dock")
		AudioBus.play_ambience("res://assets/audio/ambience/canal.wav", "", -8.0)
		AudioBus.set_room(0.3, 0.1)

func _spawn_heli(at: Vector3) -> void:
	_heli = HunterHeli.new()
	_heli.name = "Hunter"
	add_child(_heli)
	_heli.global_position = at
	_heli.bounds_min = Vector3(-40, 10, BASIN_Z1 + 10.0)
	_heli.bounds_max = Vector3(40, 40, -80)
	_heli.follow_dist = 24.0
	_heli.altitude = 15.0
	_heli.died_signal.connect(_on_heli_dead)

func _heli_to_basin() -> void:
	if not is_instance_valid(_heli): return
	_heli.bounds_min = Vector3(-30, 12, BASIN_Z1 + 8.0)
	_heli.bounds_max = Vector3(30, 34, CANAL_Z1 - 8.0)
	_heli.follow_dist = 30.0

func _on_heli_dead(_n: Node) -> void:
	set_flag("heli_dead")
	Game.set_objective("obj.ch4.wall")
	say("heli_down", D["heli_down"], true)

# =====================================================================
# D) BARREIRA (z -200): grade no canal, cabine no cais leste
# =====================================================================
func _build_barrier() -> void:
	var sec := "canal"
	_grate = AnimatableBody3D.new()
	_grate.sync_to_physics = false
	_grate.set_meta("surface", "metal")
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(14.0, 5.0, 0.4); cs.shape = bs
	_grate.add_child(cs)
	var parts := []
	for i in 22:
		parts.append([MeshKit.bevel_box(Vector3(0.14, 5.0, 0.14), 0.02, 1), Transform3D(Basis(), Vector3(-6.6 + i * 0.63, 0, 0))])
	for y: float in [-2.2, -0.8, 0.6, 2.2]:
		parts.append([MeshKit.bevel_box(Vector3(14.0, 0.3, 0.3), 0.03, 1), Transform3D(Basis(), Vector3(0, y, 0))])
	var gm := MeshInstance3D.new(); gm.mesh = MeshKit.combine(parts); gm.material_override = M["paint_y"]
	_grate.add_child(gm)
	add_child(_grate)
	_grate.position = Vector3(0, -0.6, -200.0)
	# pórtico da barreira
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(8.2 * s, 4.0, -200.0), Vector3(1.0, 8.0, 1.0), M["steel_dark"], Vector3.ZERO, true, 0.04)
	box(sec, Vector3(0, 8.3, -200.0), Vector3(17.4, 0.8, 1.0), M["steel_dark"], Vector3.ZERO, true, 0.04)
	poster(Vector3(0, 8.3, -199.45), 0.0, "res://assets/textures/sign_4.png", Vector2(4.0, 0.7), true)
	# pontão de desembarque (lado leste) + degraus
	box(sec, Vector3(5.6, -0.65, -189.0), Vector3(2.8, 0.3, 10.0), M["wood"])
	var top := stair(sec, Vector3(5.6, -0.5, -194.1), 0.0, 2.6, 0.5, M["conc"])
	box(sec, Vector3(5.6, -0.15, (top.z - 199.0) * 0.5), Vector3(2.8, 0.3, top.z + 199.0), M["conc"])
	_water_ladder(Vector3(4.1, CANAL_FLOOR, -186.0), -PI * 0.5, 2.1)
	# cabine de controle
	var cc := Vector3(12.0, 0, -197.0)
	room(sec, cc, Vector3(4.4, 3.0, 4.4), M["corr_b"], M["conc"], M["steel_dark"], [["w", 0.0, 1.2, 2.2]], 0.15)
	box(sec, cc + Vector3(1.4, 0.55, 0), Vector3(1.0, 1.1, 2.4), M["steel"], Vector3.ZERO, true, 0.03)
	_grate_btn = Interactables.button(self, cc + Vector3(0.88, 1.25, 0), -PI * 0.5)
	_grate_btn.activated.connect(_open_grate)
	light(cc + Vector3(0, 2.6, 0), Color(1.0, 0.85, 0.6), 6.0, 1.0)
	poster(cc + Vector3(2.04, 1.9, 0), -PI * 0.5, "res://assets/textures/poster_1.png", Vector2(0.9, 1.25))
	for p in [["crate", Vector3(10.0, 0.5, -192.0)], ["barrel", Vector3(14.5, 0.5, -192.5)], ["explosive", Vector3(9.5, 0.5, -203.0)]]:
		prop(p[0], p[1])
	for p: Vector3 in [Vector3(10.0, 0, -190.8), Vector3(14.5, 0, -191.2), Vector3(13.5, 0, -203.0)]:
		cover(p)
	pickup("b_ammo", Vector3(10.0, 1.05, -192.0), "ammo_9mm", 30)
	pickup("b_med", cc + Vector3(-1.4, 0.4, 1.6), "medkit")
	pickup("b_grenade", cc + Vector3(-1.4, 0.4, -1.6), "grenade")
	checkpoint("barrier", Vector3(5.6, 1, -197.5), Vector3(2.8, 3, 2), Vector3(5.6, 0.05, -197.5), -PI * 0.5)
	Interactables.trigger(self, Vector3(0, 0, -183), Vector3(14, 4, 3), func():
		if not flag("barrier_open"):
			say("barrier", D["barrier"])
			Game.set_objective("obj.ch4.barrier"))
	if cp_i <= CP_ORDER.find("barrier") and not flag("barrier_open"):
		enemy("b_v1", "vigilante_pistol", Vector3(15.0, 0.05, -199.0), PI * 0.5, [Vector3(15.0, 0.05, -188.0), Vector3(15.0, 0.05, -206.0)] as Array[Vector3])
		enemy("b_s1", "soldier", Vector3(11.0, 0.05, -206.0), 0.0)
		enemy("b_v2", "vigilante_baton", Vector3(-12.0, 0.05, -200.0), -PI * 0.5)

func _open_grate() -> void:
	set_flag("barrier_open")
	AudioBus.play_3d("gate_motor", _grate.global_position, 4.0, 0.0, 90.0)
	var tw := create_tween()
	tw.tween_property(_grate, "position:y", 4.6, 5.0).set_trans(Tween.TRANS_SINE)
	say("barrier_open", D["barrier_open"])
	Game.set_objective("obj.ch4.boat")

# =====================================================================
# E) RESERVATÓRIO (z -240 .. -320, x ±40) + píer com canhão antiaéreo
# =====================================================================
func _build_basin() -> void:
	var sec := "basin"
	var zc := (CANAL_Z1 + BASIN_Z1) * 0.5
	var L := CANAL_Z1 - BASIN_Z1
	box(sec, Vector3(0, CANAL_FLOOR - 0.15, zc), Vector3(80.0, 0.3, L), M["silt"])
	box(sec, Vector3(0, WATER_Y - 0.03, zc), Vector3(80.0, 0.06, L), M["water"], Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(40.3 * s, 2.0, zc), Vector3(0.6, 9.2, L), M["conc_dark"])
		box(sec, Vector3(23.6 * s, 2.0, CANAL_Z1 + 0.3), Vector3(33.4, 9.2, 0.6), M["conc_dark"])
	# píer leste (deck baixo) com o canhão
	box(sec, Vector3(30.0, -0.6, -268.0), Vector3(20.0, 0.3, 5.0), M["wood"])
	for x in range(22, 40, 4):
		for s: float in [-1.0, 1.0]:
			mesh_at(sec, MeshKit.cylinder(0.16, 2.2, 10), Transform3D(Basis(), Vector3(x, -1.7, -268.0 + 2.3 * s)), M["wood"])
	box(sec, Vector3(30.0, -0.2, -265.45), Vector3(20.0, 0.5, 0.1), M["steel_dark"], Vector3.ZERO, false)
	_water_ladder(Vector3(19.9, CANAL_FLOOR, -269.0), -PI * 0.5, 2.0)
	_turret = FlakTurret.new()
	add_child(_turret)
	_turret.global_position = Vector3(32.0, -0.45, -268.0)
	_turret.rotation.y = PI * 0.5
	for p in [["crate", Vector3(36.5, -0.0, -269.5)], ["crate", Vector3(37.0, -0.0, -266.8)]]:
		prop(p[0], p[1])
	pickup("bs_med", Vector3(36.5, 0.6, -269.5), "medkit")
	pickup("bs_ammo", Vector3(37.0, 0.6, -266.8), "ammo_762", 60)
	light(Vector3(32.0, 3.0, -268.0), Color(1.0, 0.8, 0.55), 10.0, 1.2)
	# torres de iluminação
	for p: Vector3 in [Vector3(-30, 0, -250), Vector3(30, 0, -310), Vector3(-25, 0, -305)]:
		mesh_at(sec, MeshKit.cylinder(0.25, 14.0, 8), Transform3D(Basis(), p + Vector3(0, 6.0, 0)), M["steel_dark"])
		light(p + Vector3(0, 12.5, 0), Color(0.85, 0.9, 1.0), 30.0, 1.8)
	checkpoint("basin", Vector3(30.0, 0.5, -268.0), Vector3(16, 3, 4), Vector3(26.0, -0.4, -268.0), PI * 0.5)
	Interactables.trigger(self, Vector3(0, 0, CANAL_Z1 - 6.0), Vector3(14, 6, 4), func():
		say("basin", D["basin"], true)
		if not flag("heli_dead"):
			Game.set_objective("obj.ch4.heli")
			if not is_instance_valid(_heli): _spawn_heli(Vector3(0, 24, -300))
			_heli_to_basin())

# =====================================================================
# F) CAIS DE CARGA (z -320 .. -420): contêineres, holofotes, soldados
# =====================================================================
func _container(sec: String, pos: Vector3, yaw: float, mat: Material) -> void:
	var sz := Vector3(2.5, 2.6, 6.1)
	var b := Basis(Vector3.UP, yaw)
	var parts := [[MeshKit.box_uv(sz), Transform3D()]]
	mesh_at(sec, MeshKit.combine(parts), Transform3D(b, pos + Vector3(0, sz.y * 0.5, 0)), mat, sz)
	var fr := []
	for x: float in [-1.22, 1.22]:
		for z: float in [-3.02, 3.02]:
			fr.append([MeshKit.bevel_box(Vector3(0.12, 2.62, 0.12), 0.01, 1), Transform3D(Basis(), Vector3(x, 0, z))])
	mesh_at(sec, MeshKit.combine(fr), Transform3D(b, pos + Vector3(0, sz.y * 0.5, 0)), M["steel_dark"])

func _build_quay() -> void:
	var sec := "quay"
	var zc := (BASIN_Z1 + WALL_Z) * 0.5
	box(sec, Vector3(0, -0.15, zc), Vector3(80.0, 0.3, BASIN_Z1 - WALL_Z), M["asphalt"])
	box(sec, Vector3(0, (CANAL_FLOOR) * 0.5 - 0.15, BASIN_Z1 - 0.3), Vector3(80.0, -CANAL_FLOOR + 0.3, 0.6), M["conc_dark"])
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(40.3 * s, 3.0, zc), Vector3(0.6, 6.0, BASIN_Z1 - WALL_Z), M["conc_dark"])
		box(sec, Vector3(20.0 * s, 0.5, BASIN_Z1 - 0.45), Vector3(36.0, 1.0, 0.3), M["conc"])
	# pontão de desembarque + escada no centro
	box(sec, Vector3(0, -0.65, BASIN_Z1 + 5.0), Vector3(4.0, 0.3, 8.0), M["wood"])
	stair(sec, Vector3(0, -0.5, BASIN_Z1 + 1.0), 0.0, 3.0, 0.5, M["conc"])
	_water_ladder(Vector3(-2.1, CANAL_FLOOR, BASIN_Z1 + 7.0), -PI * 0.5, 2.0)
	# contêineres
	var cols := [M["corr"], M["corr_r"], M["corr_b"]]
	var slots := [[-26, -334, 0.0], [-26, -342, 0.0], [-20, -352, PI * 0.5], [-8, -338, 0.0], [10, -334, 0.0], [16, -346, PI * 0.5],
		[26, -338, 0.0], [-14, -366, 0.0], [4, -362, PI * 0.5], [22, -370, 0.0], [-28, -378, PI * 0.5], [-6, -384, 0.0], [12, -390, PI * 0.5], [28, -396, 0.0], [-18, -400, 0.0]]
	var ci := 0
	for sl in slots:
		_container(sec, Vector3(sl[0], 0, sl[1]), sl[2], cols[ci % 3])
		if ci % 4 == 1:
			_container(sec, Vector3(sl[0], 2.6, sl[1]), sl[2], cols[(ci + 1) % 3])
		cover(Vector3(sl[0], 0, sl[1]) + Basis(Vector3.UP, sl[2]) * Vector3(1.9, 0, 0))
		ci += 1
	# guindaste portuário (decorativo, colisão nas pernas)
	for x: float in [-6.0, 6.0]:
		for z: float in [-350.0, -358.0]:
			box(sec, Vector3(x, 9.0, z), Vector3(0.7, 18.0, 0.7), M["paint_y"], Vector3.ZERO, true, 0.03)
	box(sec, Vector3(0, 18.4, -354.0), Vector3(14.0, 1.2, 10.0), M["paint_y"], Vector3.ZERO, false, 0.05)
	box(sec, Vector3(0, 18.4, -335.0), Vector3(2.0, 1.0, 30.0), M["paint_y"], Vector3.ZERO, false, 0.05)
	for p in [["barrel", Vector3(-2, 0.5, -340)], ["explosive", Vector3(18, 0.5, -360)], ["explosive", Vector3(-10, 0.5, -372)], ["crate", Vector3(6, 0.5, -376)], ["crate", Vector3(6, 1.5, -376)],
			["tire", Vector3(-22, 0.4, -360)], ["pallet", Vector3(0, 0.1, -395)]]:
		prop(p[0], p[1])
	pickup("q_med", Vector3(-23.9, 0.1, -342), "medkit")
	pickup("q_ar1", Vector3(6, 2.05, -376), "ar1")
	pickup("q_ammo556", Vector3(-6, 0.1, -390), "ammo_556", 60)
	pickup("q_filter", Vector3(28, 0.1, -401), "filter")
	for p: Vector3 in [Vector3(-34, 0, -330), Vector3(34, 0, -360), Vector3(-34, 0, -392), Vector3(30, 0, -408)]:
		sodium_lamp(sec, p, PI * 0.5 if p.x < 0 else -PI * 0.5, 7.0, 2.0, false)
	checkpoint("quay", Vector3(0, 1, BASIN_Z1 - 2.0), Vector3(6, 3, 2), Vector3(0, 0.05, BASIN_Z1 - 2.0), 0.0)
	Interactables.trigger(self, Vector3(0, 1, BASIN_Z1 - 6.0), Vector3(30, 3, 3), func():
		say("searchlights", D["searchlights"]))
	if cp_i <= CP_ORDER.find("quay"):
		var e1 := enemy("q_s1", "soldier", Vector3(-12, 0.05, -356), 0.0, [Vector3(-12, 0.05, -350), Vector3(12, 0.05, -350)] as Array[Vector3])
		var e2 := enemy("q_s2", "soldier", Vector3(18, 0.05, -382), 0.0, [Vector3(18, 0.05, -380), Vector3(-10, 0.05, -380)] as Array[Vector3])
		var e3 := enemy("q_v1", "vigilante_elite", Vector3(0, 0.05, -404), 0.0)
		var e4 := enemy("q_c1", "conscript_hostile", Vector3(-30, 0.05, -366), PI * 0.5)
		for e in [e1, e2, e3, e4]:
			if e: _quay_enemies.append(e)

# =====================================================================
# G) A MURALHA: paredão, holofotes, elevador de carga
# =====================================================================
func _build_wall() -> void:
	var sec := "wall"
	box(sec, Vector3(0, 22.0, WALL_Z - 3.0), Vector3(160.0, 44.0, 6.0), M["dominion"])
	# contrafortes
	for x in range(-72, 73, 18):
		if absi(x) < 8: continue
		box(sec, Vector3(x, 18.0, WALL_Z + 1.2), Vector3(3.0, 36.0, 2.4), M["dominion"], Vector3.ZERO, true)
	poster(Vector3(-24, 26.0, WALL_Z + 0.05), 0.0, "res://assets/textures/sign_4.png", Vector2(14.0, 3.5), true)
	poster(Vector3(24, 26.0, WALL_Z + 0.05), 0.0, "res://assets/textures/screen_regent.png", Vector2(12.0, 6.75), true)
	# holofotes no alto da Muralha
	for x: float in [-22.0, 0.0, 22.0]:
		var sl := Searchlight.new()
		add_child(sl)
		sl.position = Vector3(x, 18.0, WALL_Z + 1.2)
		sl.sweep_center = PI
		sl.sweep_arc = 0.55
		sl.pitch = -0.5
		sl.sweep_speed = 0.18 + absf(x) * 0.004
		sl.spotted.connect(_on_spotted)
		_lights_search.append(sl)
		box(sec, Vector3(x, 17.4, WALL_Z + 1.0), Vector3(2.0, 0.4, 2.0), M["steel_dark"], Vector3.ZERO, false)
	# poço e plataforma do elevador
	for x: float in [-3.6, 3.6]:
		for z: float in [WALL_Z + 0.4, WALL_Z + 7.4]:
			box(sec, Vector3(x, 16.0, z), Vector3(0.4, 32.0, 0.4), M["steel_dark"], Vector3.ZERO, true)
	for y in range(4, 32, 4):
		for x: float in [-3.6, 3.6]:
			box(sec, Vector3(x, y, WALL_Z + 3.9), Vector3(0.2, 0.2, 7.0), M["steel_dark"], Vector3.ZERO, false)
	_elevator = AnimatableBody3D.new()
	_elevator.sync_to_physics = true
	_elevator.set_meta("surface", "metal")
	var ecs := CollisionShape3D.new(); var ebs := BoxShape3D.new(); ebs.size = Vector3(6.6, 0.3, 6.6); ecs.shape = ebs
	ecs.position = Vector3(0, -0.15, 0)
	_elevator.add_child(ecs)
	for s: float in [-1.0, 1.0]:
		var rc := CollisionShape3D.new(); var rb := BoxShape3D.new(); rb.size = Vector3(0.1, 1.1, 6.6); rc.shape = rb
		rc.position = Vector3(3.2 * s, 0.55, 0)
		_elevator.add_child(rc)
	var ep := [[MeshKit.bevel_box(Vector3(6.6, 0.3, 6.6), 0.03, 1), Transform3D(Basis(), Vector3(0, -0.15, 0))]]
	for s: float in [-1.0, 1.0]:
		ep.append([MeshKit.bevel_box(Vector3(0.08, 1.1, 6.6), 0.01, 1), Transform3D(Basis(), Vector3(3.2 * s, 0.55, 0))])
	var em := MeshInstance3D.new(); em.mesh = MeshKit.combine(ep); em.material_override = M["grate"]
	_elevator.add_child(em)
	add_child(_elevator)
	_elevator.position = Vector3(0, 0.0, WALL_Z + 3.9)
	_elev_lever = Interactables.lever(_elevator, _elevator.to_global(Vector3(2.4, 0.3, 2.6)), PI)
	_elev_lever.activated.connect(_ride_elevator)
	var el := OmniLight3D.new(); el.omni_range = 8.0; el.light_energy = 1.2; el.light_color = Color(1.0, 0.7, 0.4)
	el.position = Vector3(0, 2.6, 0)
	el.add_to_group("az_lights")
	_elevator.add_child(el)
	# topo: passarelas dos dois lados do poço
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(6.9 * s, 29.85, WALL_Z + 3.9), Vector3(6.6, 0.3, 7.6), M["conc"])
		box(sec, Vector3(6.9 * s, 30.55, WALL_Z + 7.55), Vector3(6.6, 1.1, 0.3), M["conc_dark"])
		box(sec, Vector3(10.35 * s, 30.55, WALL_Z + 3.9), Vector3(0.3, 1.1, 7.6), M["conc_dark"])
	light(Vector3(0, 33.0, WALL_Z + 2.4), Color(0.9, 0.9, 1.0), 12.0, 1.2)
	Interactables.trigger(self, Vector3(0, 1, WALL_Z + 9.0), Vector3(8, 3, 2), func():
		say("elevator", D["elevator"]))
	Interactables.trigger(self, Vector3(0, 31.0, WALL_Z + 3.9), Vector3(20, 2, 7), _top_reached)

func _on_spotted(pos: Vector3) -> void:
	if flag("spotted"): return
	set_flag("spotted")
	say("spotted", D["spotted"], true)
	AudioBus.play_3d("alarm", Vector3(0, 18, WALL_Z), 2.0, 0.0, 200.0)
	for e in _quay_enemies:
		if is_instance_valid(e) and e.alive: e.hear_alert(pos)
	var r1 := enemy("q_s3", "soldier", Vector3(-4, 0.05, WALL_Z + 12.0), PI)
	var r2 := enemy("q_s4", "soldier", Vector3(4, 0.05, WALL_Z + 12.0), PI)
	for e in [r1, r2]:
		if e: e.hear_alert(pos)

func _ride_elevator() -> void:
	if flag("elevator"): return
	set_flag("elevator")
	for sl in _lights_search: sl.enabled = false
	AudioBus.play_3d("gate_motor", _elevator.global_position, 2.0, 0.0, 60.0)
	var snd := Fire.loop_player(_elevator, "elevator_loop", -6.0, 40.0)
	var tw := create_tween()
	tw.tween_property(_elevator, "position:y", 30.0, 12.0).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not is_inside_tree(): return
	if is_instance_valid(snd): snd.queue_free()
	AudioBus.play_3d("impact_metal_heavy", _elevator.global_position, 0.0)

func _top_reached() -> void:
	if flag("done"): return
	set_flag("done")
	say("top", D["top"], true)
	await say_done("top")
	if not is_inside_tree(): return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	player.input_enabled = false
	Game.complete_chapter()
