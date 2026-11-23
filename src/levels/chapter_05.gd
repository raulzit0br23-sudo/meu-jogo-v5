extends LevelBase
## Capítulo 5 — "Ferro-Velho" (Ato II, abertura).
## A) Portão do ferro-velho de Lindqvist · B) Lindqvist entrega o Manipulador; latas e garrafas
##    para treinar · C) Motor de caminhão (110 kg) bloqueia a portinhola do galpão → puxar com o
##    Manipulador · D) Bateria no telhado do depósito → empilhar caixas, subir, levar a bateria ao
##    soquete do portão do pátio · E) Rastejadores saem da terra; lâminas de serra como munição
## F) Oficina: a planta do Trocador de Ar, o Besouro (buggy) → fim do capítulo.
## Inspiração: o conceito de "ferro-velho / oficina no Ermo" e do veículo improvisado dos roteiros
## 2002 do HL2 beta (ver docs/01_PESQUISA_HL2_BETA.md). Personagens, mapa e falas são originais.

const CP_ORDER := ["start", "yard", "inner", "workshop"]
const SOCKET := Vector3(4.6, 0.0, -63.0)
const ENGINE_HOME := Vector3(7.0, 0.5, -30.0)
const BATTERY_HOME := Vector3(13.0, 2.8, -48.0)
const WORKSHOP := Vector3(0, 0, -104.0)
var D := {}
var cp_i := 0
var M := {}
var _lindqvist: NpcAlly
var _engine: PhysicsProp
var _battery: PhysicsProp
var _socket_area: Area3D
var _gate: AnimatableBody3D
var _socket_glow: OmniLight3D
var _buggy: Vehicle
var _garage: AnimatableBody3D
var _crawlers_alive := 0
var _crawler_wave := 0
var _check_t := 0.0

func _mats() -> void:
	M = {
		"ground": Mats.get_mat("gravel", 0.22, Color(0.62, 0.58, 0.5)),
		"dirt": Mats.get_mat("cracked_earth", 0.2, Color(0.62, 0.54, 0.44)),
		"conc": Mats.get_mat("concrete", 0.35, Color(0.66, 0.65, 0.6)),
		"brick": Mats.get_mat("brick", 0.4, Color(0.66, 0.55, 0.48)),
		"corr": Mats.get_mat("corrugated", 0.35, Color(0.66, 0.62, 0.55)),
		"corr_r": Mats.get_mat("corrugated", 0.35, Color(0.72, 0.44, 0.34)),
		"corr_b": Mats.get_mat("corrugated", 0.35, Color(0.44, 0.54, 0.6)),
		"corr_g": Mats.get_mat("corrugated", 0.35, Color(0.48, 0.56, 0.44)),
		"rust": Mats.get_mat("rusted_paint", 0.5, Color(0.7, 0.5, 0.38)),
		"rust_y": Mats.get_mat("rusted_paint", 0.5, Color(0.88, 0.72, 0.32)),
		"rust_b": Mats.get_mat("rusted_paint", 0.5, Color(0.42, 0.52, 0.64)),
		"steel": Mats.get_mat("steel", 0.6, Color(0.62, 0.62, 0.6)),
		"steel_dark": Mats.get_mat("steel", 0.6, Color(0.36, 0.36, 0.35)),
		"gun": Mats.get_mat("gunmetal", 0.8, Color(0.6, 0.6, 0.62)),
		"grate": Mats.get_mat("grate", 0.6, Color(0.7, 0.7, 0.68)),
		"wood": Mats.get_mat("wood", 0.8, Color(0.62, 0.54, 0.44)),
		"wood_d": Mats.get_mat("wood", 0.8, Color(0.42, 0.36, 0.3)),
		"tiles": Mats.get_mat("tiles", 0.3, Color(0.6, 0.6, 0.56)),
		"fabric": Mats.get_mat("fabric", 0.6, Color(0.5, 0.56, 0.44)),
		"rubber": Mats.get_mat("rubber", 1.0, Color(0.5, 0.5, 0.5)),
		"door": Mats.get_mat("door_metal_red", 1.0),
		"door_g": Mats.get_mat("door_metal_grey", 1.0),
		"glass": Mats.glass(),
	}

func build() -> void:
	_mats()
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch5.json"))
	cp_i = maxi(0, CP_ORDER.find(Game.checkpoint))
	grid = {"yard": 24.0, "inner": 24.0, "shop": 16.0}
	outdoor = {"yard": true, "inner": true, "far": true}
	sector("far", 400.0)
	setup_env(Color(0.48, 0.42, 0.36), Color(0.6, 0.54, 0.48), 0.9, Color(0.56, 0.48, 0.4), 0.008, 0.0, 0.5)
	env.tonemap_exposure = 1.15
	var s := sun(Vector3(-22, 230, 0), Color(1.0, 0.82, 0.62), 1.1, true)
	s.light_cull_mask = 2
	nav_aabb = AABB(Vector3(-42, -2, -122), Vector3(84, 14, 126))
	_build_ground()
	_build_entrance()
	_build_shed()
	_build_depot()
	_build_gate()
	_build_inner()
	_build_workshop()
	_build_far()
	checkpoints["start"] = [Vector3(0, 0.05, -3.0), 0.0]

func after_build() -> void:
	AudioBus.start_music()
	AudioBus.play_ambience("res://assets/audio/ambience/junkyard.wav", "", -8.0)
	AudioBus.set_room(0.35, 0.1)
	player.set_mask(false)
	ensure_loadout(["wrench", "pistol", "smg", "shotgun"])
	if flag("manip") and not player.weapons.owned.has("manipulator"):
		player.weapons.give("manipulator")
	# objetos do quebra-cabeça (estado persistente)
	_engine = prop("engine", ENGINE_HOME + (Vector3(-2.6, 0, 2.2) if flag("engine_moved") else Vector3.ZERO), PI * 0.5)
	if flag("battery_in"):
		_battery = prop("battery", SOCKET + Vector3(0, 1.25, 0))
		_battery.freeze = true
		_gate.position.y = 3.6
		_socket_glow.light_color = Color(0.4, 1.0, 0.5)
	else:
		_battery = prop("battery", BATTERY_HOME)
	_buggy = Vehicle.make("buggy")
	add_child(_buggy)
	_buggy.global_position = WORKSHOP + Vector3(3.0, 0.6, -1.0)
	_buggy.rotation.y = PI
	_buggy.entered.connect(_on_buggy_entered)
	if flag("blueprint"):
		_garage.position.y = 4.2
	match Game.checkpoint:
		"start":
			Game.set_objective("obj.ch5.find")
			say("arrival", D["arrival"])
		"yard":
			Game.set_objective("obj.ch5.engine" if not flag("engine_moved") else ("obj.ch5.stack" if not flag("battery_up") else "obj.ch5.battery"))
		"inner":
			if flag("crawlers_done"):
				Game.set_objective("obj.ch5.workshop")
			else:
				Game.set_objective("obj.ch5.crawlers")
				_crawler_wave = 0
				_spawn_wave()
		"workshop":
			Game.set_objective("obj.ch5.buggy" if flag("blueprint") else "obj.ch5.workshop")

func _physics_process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0: return
	_check_t = 0.25
	# motor afastado da portinhola?
	if not flag("engine_moved") and is_instance_valid(_engine) and _engine.global_position.distance_to(ENGINE_HOME) > 1.6:
		set_flag("engine_moved")
		if flag("manip"):
			say("stack", D["stack"])
		Game.set_objective("obj.ch5.stack")
	# bateria tirada do telhado
	if not flag("battery_up") and is_instance_valid(_battery) and _battery.global_position.distance_to(BATTERY_HOME) > 1.2:
		set_flag("battery_up")
		say("battery", D["battery"])
		Game.set_objective("obj.ch5.battery")

# =====================================================================
# Chão, cerca e pilhas de sucata
# =====================================================================
func _build_ground() -> void:
	box("yard", Vector3(0, -0.25, -30), Vector3(84, 0.5, 64), M["ground"])
	box("inner", Vector3(0, -0.25, -92), Vector3(84, 0.5, 60), M["dirt"])
	# cerca perimetral de chapas onduladas (alturas e cores variadas)
	var r := RandomNumberGenerator.new(); r.seed = 55
	for side: float in [-1.0, 1.0]:
		var z := 2.0
		while z > -122.0:
			var h := r.randf_range(3.2, 4.4)
			var m: Material = [M["corr"], M["corr_r"], M["corr_b"], M["corr_g"]][r.randi() % 4]
			box("yard" if z > -62.0 else "inner", Vector3(side * 40.0, h * 0.5, z - 3.0), Vector3(0.12, h, 6.1), m, Vector3(0, 0, r.randf_range(-0.04, 0.04)))
			box("yard" if z > -62.0 else "inner", Vector3(side * 40.2, h * 0.5, z - 6.0), Vector3(0.2, h + 0.3, 0.2), M["steel_dark"])
			z -= 6.0
	for x0: float in [-40.0, -28.0, -16.0, 4.0, 16.0, 28.0]:
		var w := 12.0 if x0 != -16.0 and x0 != 4.0 else 12.0
		box("inner", Vector3(x0 + w * 0.5, 2.0, -122.0), Vector3(w, 4.0, 0.12), M["corr_r"] if int(x0) % 8 == 0 else M["corr"])
	box("inner", Vector3(-6.0 + 2.0, 2.0, -122.0), Vector3(4.0, 4.0, 0.12), M["corr"])
	# pilhas de sucata (colisão simplificada por pilha)
	for p: Array in [[Vector3(-26, 0, -8), 7.0, 1], [Vector3(-30, 0, -30), 9.0, 2], [Vector3(26, 0, -10), 8.0, 3],
			[Vector3(28, 0, -44), 7.0, 4], [Vector3(-28, 0, -50), 6.0, 5], [Vector3(-26, 0, -86), 9.0, 6],
			[Vector3(28, 0, -82), 8.0, 7], [Vector3(-30, 0, -112), 6.0, 8], [Vector3(26, 0, -112), 7.0, 9]]:
		_scrap_pile("yard" if p[0].z > -62.0 else "inner", p[0], p[1], p[2])
	# carros abandonados empilhados
	car_wreck("yard", Vector3(-14, 0, -10), 0.4, Color(0.55, 0.3, 0.25))
	car_wreck("yard", Vector3(-17, 0, -14), -0.3, Color(0.35, 0.42, 0.5))
	car_wreck("yard", Vector3(18, 0, -18), 1.2, Color(0.55, 0.52, 0.38))
	car_wreck("yard", Vector3(20, 0, -6), 1.7, Color(0.4, 0.45, 0.38))
	car_wreck("inner", Vector3(-15, 0, -80), 0.2, Color(0.48, 0.32, 0.28))
	car_wreck("inner", Vector3(16, 0, -94), -0.6, Color(0.36, 0.4, 0.46))
	mesh_at("yard", MeshKit.combine([[MeshKit.bevel_box(Vector3(1.7, 0.7, 4.2), 0.12, 2), Transform3D(Basis(), Vector3(0, 0.65, 0))],
		[MeshKit.bevel_box(Vector3(1.5, 0.55, 2.2), 0.15, 2), Transform3D(Basis(), Vector3(0, 1.25, 0.2))]]),
		Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, 0.25), Vector3(-15.5, 1.75, -12.0)), M["rust_b"], Vector3(1.7, 1.5, 4.2), Vector3(0, 0.75, 0))
	# pneus empilhados (estáticos) e alguns soltos (física)
	var tire := MeshKit.lathe(PackedVector2Array([Vector2(0.22, -0.13), Vector2(0.36, -0.14), Vector2(0.4, -0.08), Vector2(0.4, 0.08), Vector2(0.36, 0.14), Vector2(0.22, 0.13), Vector2(0.21, -0.13)]), 14, false, false)
	for st: Vector3 in [Vector3(-8, 0, -12), Vector3(9, 0, -8), Vector3(-6, 0, -44), Vector3(10, 0, -76), Vector3(-10, 0, -98)]:
		for i in 4:
			mesh_at("yard" if st.z > -62.0 else "inner", tire, Transform3D(Basis(Vector3.UP, i * 0.7), st + Vector3(0, 0.14 + i * 0.28, 0)), M["rubber"],
				Vector3(0.8, 0.28, 0.8) if i == 0 else Vector3.ZERO, Vector3.ZERO)
	for p: Vector3 in [Vector3(-7, 0.4, -14), Vector3(8, 0.4, -10), Vector3(-4, 0.4, -40)]:
		prop("tire", p)
	# luzes de serviço (gambiarra de lâmpadas)
	for p: Vector3 in [Vector3(-10, 4.5, -20), Vector3(8, 4.5, -40), Vector3(-6, 4.5, -60), Vector3(0, 4.5, -84)]:
		box("yard" if p.z > -62.0 else "inner", Vector3(p.x, p.y * 0.5, p.z), Vector3(0.18, p.y, 0.18), M["wood_d"])
		mesh_at("yard" if p.z > -62.0 else "inner", MeshKit.cylinder(0.12, 0.2, 10), Transform3D(Basis(), p + Vector3(0, 0.05, 0)), Mats.emissive(Color(1.0, 0.8, 0.5), 2.0))
		light(p, Color(1.0, 0.78, 0.5), 11.0, 1.1)

func _scrap_pile(sec: String, c: Vector3, rad: float, seed_v: int) -> void:
	var r := RandomNumberGenerator.new(); r.seed = seed_v * 977
	var mats: Array = [M["rust"], M["corr"], M["corr_r"], M["steel_dark"], M["rust_b"], M["rust_y"], M["wood_d"]]
	for i in 16:
		var a := r.randf() * TAU
		var d := r.randf() * rad * 0.8
		var y := r.randf_range(0.2, 2.6) * (1.0 - d / rad)
		var sz := Vector3(r.randf_range(0.6, 2.6), r.randf_range(0.05, 0.9), r.randf_range(0.6, 2.4))
		box(sec, c + Vector3(cos(a) * d, y, sin(a) * d), sz, mats[r.randi() % mats.size()],
			Vector3(r.randf_range(-0.5, 0.5), r.randf() * TAU, r.randf_range(-0.5, 0.5)), false, 0.02)
	# tambores e canos
	for i in 4:
		var a := r.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * rad * r.randf_range(0.6, 0.95)
		mesh_at(sec, MeshKit.cylinder(0.3, 0.9, 12, 0.02), Transform3D(Basis(Vector3.FORWARD, r.randf_range(0, 1.4)), p + Vector3(0, 0.35, 0)),
			Mats.get_mat("barrel_red" if i % 2 == 0 else "barrel_blue", 1.0))
	# colisão: um monte baixo que o jogador contorna (sem malha extra)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = rad * 0.7; cyl.height = 2.4
	cs.shape = cyl; cs.position = c + Vector3(0, 1.2, 0)
	body.add_child(cs)

# =====================================================================
# A/B) Entrada, cabana de Lindqvist, o cão-robô, latas de treino
# =====================================================================
func _build_entrance() -> void:
	var sec := "yard"
	# portão de entrada aberto + placa
	for sx: float in [-4.0, 4.0]:
		box(sec, Vector3(sx, 2.5, 0.5), Vector3(0.4, 5.0, 0.4), M["steel_dark"])
	box(sec, Vector3(0, 4.9, 0.5), Vector3(8.4, 0.3, 0.3), M["steel_dark"])
	box(sec, Vector3(0, 4.3, 0.62), Vector3(4.6, 0.8, 0.06), M["rust_y"])
	for sx: float in [-1.0, 1.0]:
		box(sec, Vector3(sx * 6.2, 1.6, 1.6), Vector3(0.08, 3.2, 3.8), M["grate"], Vector3(0, sx * 0.9, 0), false)
	box(sec, Vector3(-22, 2.0, 0.6), Vector3(36, 4.0, 0.12), M["corr"])
	box(sec, Vector3(22, 2.0, 0.6), Vector3(36, 4.0, 0.12), M["corr_r"])
	box(sec, Vector3(0, 2.0, 4.0), Vector3(8.0, 4.0, 0.12), M["corr"])
	# cabana de Lindqvist (tijolo + telhado de chapa)
	var cc := Vector3(-12, 0, -24)
	room(sec, cc, Vector3(7.0, 3.0, 5.0), M["brick"], M["wood"], M["corr"], [["e", 0.8, 1.2, 2.2], ["n", -1.5, 1.6, 1.1]], 0.25)
	box(sec, cc + Vector3(0, 3.3, 0), Vector3(8.0, 0.1, 6.0), M["corr_r"], Vector3(0, 0, 0.08), false)
	mesh_at(sec, MeshKit.bevel_box(Vector3(1.6, 1.0, 0.04), 0.005, 1), Transform3D(Basis(), cc + Vector3(-1.5, 1.6, -2.62)), M["glass"])
	box(sec, cc + Vector3(-2.2, 0.45, 1.5), Vector3(2.0, 0.9, 1.0), M["wood"])
	box(sec, cc + Vector3(2.4, 0.5, -1.6), Vector3(1.2, 1.0, 0.8), M["steel"])
	light(cc + Vector3(0, 2.6, 0), Color(1.0, 0.82, 0.55), 6.0, 1.0)
	poster(cc + Vector3(-3.37, 1.8, 0.5), PI * 0.5, "res://assets/textures/blueprint.png", Vector2(1.2, 0.9))
	# Lindqvist
	_lindqvist = NpcAlly.make("lindqvist", "citizen", 3301)
	add_child(_lindqvist)
	_lindqvist.global_position = cc + Vector3(4.6, 0.05, 1.0)
	_lindqvist.rotation.y = PI * 0.6
	_lindqvist.set_mode(NpcAlly.Mode.IDLE)
	_lindqvist.on_use = _talk_lindqvist
	Interactables.trigger(self, cc + Vector3(6.0, 1, 1.0), Vector3(6, 3, 6), func():
		if not flag("manip"): _talk_lindqvist())
	# cão-robô (decoração, inacabado)
	_robot_dog(sec, cc + Vector3(5.8, 0, -1.2), -0.6)
	Interactables.trigger(self, cc + Vector3(5.8, 1, -1.2), Vector3(2.0, 2, 2.0), func():
		if flag("manip"): say("dog", D["dog"]))
	# bancada de latas e garrafas (treino do Manipulador)
	var tb := Vector3(-4.0, 0, -26.0)
	box(sec, tb + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.9), M["wood_d"])
	for i in 5:
		prop("bottle" if i % 2 == 0 else "bucket", tb + Vector3(-0.9 + i * 0.45, 1.1, 0))
	prop("barrel", tb + Vector3(2.0, 0.5, 0.6))
	prop("crate_small", tb + Vector3(-2.0, 0.3, 0.8))
	prop("brick", tb + Vector3(0.6, 1.0, 0.25))
	checkpoint("yard", cc + Vector3(7.0, 1, 1.0), Vector3(3, 3, 6), cc + Vector3(7.5, 0.05, 1.0), PI * 0.5)

func _talk_lindqvist() -> void:
	if not flag("manip"):
		set_flag("manip")
		say("greet", D["greet"], true)
		await say_done("greet")
		if not is_inside_tree(): return
		player.weapons.give("manipulator")
		player.weapons.equip("manipulator")
		say("manip_tutorial", D["manip_tutorial"])
		Game.set_objective("obj.ch5.manip")
		await say_done("manip_tutorial")
		if not is_inside_tree(): return
		if not flag("engine_moved"):
			say("engine_block", D["engine_block"])
			Game.set_objective("obj.ch5.engine")
	elif flag("crawlers_done") and not flag("blueprint"):
		Game.set_objective("obj.ch5.workshop")
	else:
		say("dog", D["dog"])

func _robot_dog(sec: String, pos: Vector3, yaw: float) -> void:
	# quadrúpede de sucata: chassi de radiador, pernas de amortecedor, "cabeça" de farol
	var b := Basis(Vector3.UP, yaw)
	var parts := [[MeshKit.bevel_box(Vector3(0.5, 0.32, 1.1), 0.05), Transform3D(Basis(), Vector3(0, 0.75, 0))],
		[MeshKit.bevel_box(Vector3(0.34, 0.26, 0.36), 0.05), Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.02, -0.68))],
		[MeshKit.cylinder(0.08, 0.06, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.02, -0.87))]]
	for sx: float in [-0.22, 0.22]:
		for sz: float in [-0.4, 0.4]:
			parts.append([MeshKit.pipe(PackedVector3Array([Vector3(sx, 0.7, sz), Vector3(sx * 1.3, 0.38, sz + 0.12), Vector3(sx * 1.25, 0.04, sz)]), 0.045, 6), Transform3D()])
			parts.append([MeshKit.bevel_box(Vector3(0.12, 0.05, 0.18), 0.01, 1), Transform3D(Basis(), Vector3(sx * 1.25, 0.03, sz - 0.03))])
	mesh_at(sec, MeshKit.combine(parts), Transform3D(b, pos), M["rust_y"], Vector3(0.6, 1.1, 1.2), Vector3(0, 0.55, 0))
	mesh_at(sec, MeshKit.cylinder(0.06, 0.03, 10), Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), pos + b * Vector3(0, 1.02, -0.9)), Mats.emissive(Color(1.0, 0.7, 0.3), 1.2))
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.85, 0.52), Vector3(0, 1.05, 0.7), Vector3(0, 1.0, 0.85)]), 0.02, 5), Transform3D(b, pos), M["rubber"])

# =====================================================================
# C) Galpão com portinhola bloqueada pelo motor
# =====================================================================
func _build_shed() -> void:
	var sec := "yard"
	var c := Vector3(12.0, 0, -30.0)
	# portinhola baixa (1,1 x 1,5 m) na parede oeste: agachado passa, com o motor na frente não
	room(sec, c, Vector3(9.0, 3.6, 7.0), M["corr_b"], M["conc"], M["corr"], [["w", 0.0, 1.1, 1.5], ["n", 0.0, 3.0, 3.2]], 0.2)
	box(sec, c + Vector3(-4.62, 0.75, 0.0), Vector3(0.06, 1.5, 0.08), M["rust_y"])
	# portão norte fechado (chapa) — a saída real é pela portinhola
	box(sec, c + Vector3(0, 1.6, -3.62), Vector3(3.0, 3.2, 0.08), M["door_g"])
	light(c + Vector3(0, 3.2, 0), Color(0.95, 0.85, 0.65), 8.0, 1.0)
	# caixas para empilhar (dentro do galpão)
	for i in 5:
		prop("crate", c + Vector3(-1.5 + (i % 3) * 1.1, 0.42 + (i / 3) * 0.82, -1.6 + (i % 2) * 0.6))
	prop("crate_small", c + Vector3(2.8, 0.3, 2.0))
	prop("pallet", c + Vector3(2.6, 0.1, -2.2))
	# ferramentas: tijolos e garrafas para treinar
	pickup("c5_brick", c + Vector3(3.6, 0.9, 2.6), "brickbat")
	box(sec, c + Vector3(3.6, 0.4, 2.6), Vector3(1.2, 0.8, 0.8), M["wood_d"])
	pickup("c5_am1", c + Vector3(-3.6, 0.2, 2.8), "ammo_9mm", 30)
	acoustic_zone(c + Vector3(0, 1.8, 0), Vector3(9, 3.6, 7), 0.45, 0.25)

# =====================================================================
# D) Depósito baixo com a bateria no telhado
# =====================================================================
func _build_depot() -> void:
	var sec := "yard"
	var c := Vector3(13.0, 0, -48.0)
	room(sec, c, Vector3(8.0, 2.15, 6.0), M["brick"], M["conc"], M["corr_r"], [], 0.3)
	# beiral + telhado com caixas d'água velhas
	box(sec, c + Vector3(0, 2.52, 0), Vector3(8.8, 0.12, 6.8), M["rust"], Vector3.ZERO, false)
	box(sec, c + Vector3(2.8, 2.9, 2.0), Vector3(1.2, 0.8, 1.2), M["steel"])
	box(sec, c + Vector3(-3.8, 1.2, -2.0), Vector3(0.12, 2.4, 0.4), M["steel_dark"])
	# escada caída (decoração)
	box(sec, c + Vector3(-5.2, 0.15, 1.8), Vector3(0.5, 0.12, 3.0), M["rust"], Vector3(0, 0.3, 0.1), false)
	# porta trancada (enferrujada)
	box(sec, c + Vector3(-4.18, 1.0, 1.2), Vector3(0.06, 2.0, 1.0), M["door"])
	light(c + Vector3(0, 3.6, 0), Color(1.0, 0.8, 0.55), 6.0, 0.8)

# =====================================================================
# Portão do pátio com soquete de bateria
# =====================================================================
func _build_gate() -> void:
	var sec := "yard"
	var gz := -64.0
	# muro de blocos com o portão no meio
	box(sec, Vector3(-23.0, 2.0, gz), Vector3(34.0, 4.0, 0.5), M["conc"])
	box(sec, Vector3(23.0, 2.0, gz), Vector3(34.0, 4.0, 0.5), M["conc"])
	box(sec, Vector3(0, 4.4, gz), Vector3(12.0, 0.8, 0.6), M["conc"])
	for sx: float in [-6.0, 6.0]:
		box(sec, Vector3(sx, 2.0, gz), Vector3(0.6, 4.0, 0.8), M["steel_dark"])
	_gate = AnimatableBody3D.new()
	_gate.sync_to_physics = false
	add_child(_gate)
	var g := MeshInstance3D.new()
	var gp := []
	for i in 14:
		gp.append([MeshKit.bevel_box(Vector3(0.1, 3.8, 0.1), 0.01, 1), Transform3D(Basis(), Vector3(-5.2 + i * 0.8, 0, 0))])
	for y: float in [-1.5, 0.0, 1.5]:
		gp.append([MeshKit.bevel_box(Vector3(11.0, 0.16, 0.14), 0.01, 1), Transform3D(Basis(), Vector3(0, y, 0))])
	g.mesh = MeshKit.combine(gp); g.material_override = M["rust_y"]
	_gate.add_child(g)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(11.4, 3.8, 0.3); cs.shape = bs
	_gate.add_child(cs)
	_gate.position = Vector3(0, 1.9, gz)
	# soquete da bateria (pedestal com terminais) + luz indicadora
	box(sec, SOCKET + Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.7), M["steel"])
	box(sec, SOCKET + Vector3(0, 1.04, 0), Vector3(0.62, 0.08, 0.36), M["rubber"])
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([SOCKET + Vector3(0.3, 0.8, -0.3), SOCKET + Vector3(0.5, 1.6, -0.6), SOCKET + Vector3(1.3, 2.6, -0.9)]), 0.035, 6), Transform3D(), M["rubber"])
	box(sec, SOCKET + Vector3(0.9, 2.2, -0.5), Vector3(0.6, 0.8, 0.3), M["rust_b"])
	_socket_glow = light(SOCKET + Vector3(0.9, 2.8, -0.2), Color(1.0, 0.3, 0.2), 4.0, 1.2)
	_socket_area = Area3D.new()
	_socket_area.collision_layer = 0
	_socket_area.collision_mask = 4 | 1
	add_child(_socket_area)
	_socket_area.global_position = SOCKET + Vector3(0, 1.3, 0)
	var ac := CollisionShape3D.new(); var ab := BoxShape3D.new(); ab.size = Vector3(1.2, 0.9, 1.1); ac.shape = ab
	_socket_area.add_child(ac)
	_socket_area.body_entered.connect(_on_socket_body)

func _on_socket_body(b: Node) -> void:
	if flag("battery_in") or b != _battery: return
	_insert_battery()

func _insert_battery() -> void:
	set_flag("battery_in")
	if player._hold == _battery: player.release_held()
	_battery.freeze = true
	_battery.global_transform = Transform3D(Basis(), SOCKET + Vector3(0, 1.25, 0))
	_socket_glow.light_color = Color(0.4, 1.0, 0.5)
	AudioBus.play_3d("button_press", SOCKET, 2.0)
	AudioBus.play_3d("gate_motor", _gate.global_position, 3.0, 0.0, 70.0)
	var tw := create_tween()
	tw.tween_property(_gate, "position:y", 3.6 + 1.9, 5.0).set_trans(Tween.TRANS_SINE)
	say("battery_in", D["battery_in"], true)
	Game.set_objective("obj.ch5.crawlers")
	await say_done("battery_in")
	if not is_inside_tree(): return
	_crawler_wave = 0
	_spawn_wave()
	say("crawlers", D["crawlers"])

# =====================================================================
# E) Pátio interno: ninhos de Rastejadores, lâminas de serra
# =====================================================================
const MOUNDS := [Vector3(-12, 0, -76), Vector3(12, 0, -72), Vector3(-18, 0, -96), Vector3(18, 0, -100), Vector3(-4, 0, -88), Vector3(8, 0, -90)]

func _build_inner() -> void:
	var sec := "inner"
	# montes de terra (ninhos)
	for i in MOUNDS.size():
		var m: Vector3 = MOUNDS[i]
		mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(2.2, 0), Vector2(1.6, 0.35), Vector2(0.8, 0.6), Vector2(0.3, 0.5), Vector2(0.0, 0.3)]), 14, false, true),
			Transform3D(Basis(Vector3.UP, i * 0.9), m), M["dirt"])
	# pilha de lâminas de serra e tambores sobre paletes
	var sb := Vector3(-3.0, 0, -70.0)
	box(sec, sb + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 1.2), M["wood_d"])
	for i in 6:
		prop("sawblade", sb + Vector3(-0.6 + (i % 3) * 0.6, 1.0 + (i / 3) * 0.06, -0.2 + (i / 3) * 0.4))
	for i in 3:
		prop("sawblade", Vector3(6.0 + i * 0.9, 0.1, -82.0 - i))
	prop("explosive", Vector3(-8.0, 0.5, -84.0))
	prop("explosive", Vector3(10.0, 0.5, -96.0))
	prop("barrel", Vector3(-9.0, 0.5, -84.6))
	pickup("c5_am2", Vector3(-1.0, 0.2, -71.0), "ammo_12", 8)
	pickup("c5_mol", Vector3(4.0, 0.95, -66.5), "molotov")
	box(sec, Vector3(4.0, 0.45, -66.5), Vector3(1.0, 0.9, 0.7), M["wood_d"])
	# guindaste de sucata (silhueta) com eletroímã
	box(sec, Vector3(-20, 5.0, -70), Vector3(0.6, 10.0, 0.6), M["rust_y"])
	box(sec, Vector3(-14, 9.8, -70), Vector3(12.0, 0.5, 0.5), M["rust_y"])
	mesh_at(sec, MeshKit.cylinder(1.0, 0.4, 16), Transform3D(Basis(), Vector3(-9, 6.0, -70)), M["steel_dark"])
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(-9, 6.2, -70), Vector3(-9, 9.6, -70)]), 0.03, 4), Transform3D(), M["steel_dark"])
	checkpoint("inner", Vector3(0, 1, -67.0), Vector3(10, 3, 2), Vector3(0, 0.05, -67.0), 0.0)

func _spawn_wave() -> void:
	_crawler_wave += 1
	var n := 4 if _crawler_wave == 1 else 4
	for i in n:
		var m: Vector3 = MOUNDS[(i + _crawler_wave * 2) % MOUNDS.size()]
		var c := Crawler.make(500 + _crawler_wave * 10 + i)
		add_child(c)
		c.global_position = m + Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1))
		c.aware = true
		c.died_signal.connect(_on_crawler_dead)
		_crawlers_alive += 1
		AudioBus.play_3d("crawler_idle", c.global_position, 0.0, 0.1, 40.0)

func _on_crawler_dead(_n: Node) -> void:
	_crawlers_alive -= 1
	if _crawlers_alive > 0: return
	if _crawler_wave < 2:
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree(): return
		_spawn_wave()
		return
	set_flag("crawlers_done")
	say("crawlers_done", D["crawlers_done"], true)
	Game.set_objective("obj.ch5.workshop")

# =====================================================================
# F) Oficina: planta do Trocador, o Besouro
# =====================================================================
func _build_workshop() -> void:
	var sec := "shop"
	var c := WORKSHOP
	room(sec, c, Vector3(14.0, 5.0, 10.0), M["corr_g"], M["conc"], M["corr"], [["s", 0.0, 5.0, 4.2], ["n", 3.0, 4.0, 4.0]], 0.25)
	# porta de enrolar (saída do Besouro) no lado norte
	_garage = AnimatableBody3D.new()
	_garage.sync_to_physics = false
	add_child(_garage)
	var gm := MeshInstance3D.new(); gm.mesh = MeshKit.bevel_box(Vector3(4.0, 4.0, 0.08), 0.01, 1); gm.material_override = M["corr"]
	_garage.add_child(gm)
	var gc := CollisionShape3D.new(); var gb := BoxShape3D.new(); gb.size = Vector3(4.0, 4.0, 0.2); gc.shape = gb
	_garage.add_child(gc)
	_garage.position = c + Vector3(3.0, 2.0, -5.12)
	# bancadas, ferramentas, peças do Besouro
	box(sec, c + Vector3(-5.6, 0.45, -2.0), Vector3(1.4, 0.9, 5.0), M["wood"])
	box(sec, c + Vector3(-6.6, 2.2, -2.0), Vector3(0.06, 1.6, 4.0), M["grate"])
	for i in 4:
		mesh_at(sec, MeshKit.bevel_box(Vector3(0.05, 0.4, 0.06), 0.01, 1), Transform3D(Basis(Vector3.RIGHT, 0.2 * i), c + Vector3(-6.5, 2.2, -3.4 + i * 0.8)), M["steel"])
	mesh_at(sec, MeshKit.cylinder(0.4, 0.3, 14), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), c + Vector3(-5.6, 1.2, -0.6)), M["rubber"])
	box(sec, c + Vector3(-1.2, 0.5, 3.4), Vector3(1.2, 1.0, 0.8), M["steel_dark"])
	prop("crate_small", c + Vector3(-2.4, 0.3, 3.6))
	prop("tire", c + Vector3(-3.6, 0.4, 3.6))
	# planta (pôster) na parede oeste
	poster(c + Vector3(-6.85, 2.6, 1.8), PI * 0.5, "res://assets/textures/blueprint.png", Vector2(2.4, 1.6))
	light(c + Vector3(-5.0, 3.0, 1.8), Color(0.85, 0.92, 1.0), 5.0, 1.0)
	light(c + Vector3(2.0, 4.4, 0), Color(1.0, 0.85, 0.6), 12.0, 1.2, true)
	pickup("c5_flare", c + Vector3(-5.6, 1.0, -3.6), "flaregun")
	pickup("c5_am3", c + Vector3(-5.6, 1.0, -1.0), "ammo_flare", 4)
	pickup("c5_med", c + Vector3(-1.2, 1.1, 3.4), "medkit")
	Interactables.trigger(self, c + Vector3(-4.5, 1, 1.8), Vector3(3.0, 3, 4.0), _see_blueprint)
	checkpoint("workshop", c + Vector3(0, 1, 5.5), Vector3(6, 3, 2), c + Vector3(0, 0.05, 4.0), 0.0)
	acoustic_zone(c + Vector3(0, 2.5, 0), Vector3(14, 5, 10), 0.55, 0.3)

func _see_blueprint() -> void:
	if flag("blueprint") or not flag("crawlers_done"): return
	set_flag("blueprint")
	say("blueprint", D["blueprint"], true)
	await say_done("blueprint")
	if not is_inside_tree(): return
	AudioBus.play_3d("gate_motor", _garage.global_position, 0.0, 0.0, 40.0)
	var tw := create_tween()
	tw.tween_property(_garage, "position:y", 4.2 + _garage.position.y - 2.0, 4.0)
	say("buggy", D["buggy"])
	Game.set_objective("obj.ch5.buggy")

func _on_buggy_entered(_by: Node) -> void:
	if not flag("blueprint") or flag("done"): return
	set_flag("done")
	_buggy.locked = true
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return
	Game.complete_chapter()

# =====================================================================
# Horizonte: o Mar Seco e a silhueta do Trocador de Ar
# =====================================================================
func _build_far() -> void:
	var sec := "far"
	var r := RandomNumberGenerator.new(); r.seed = 808
	for i in 18:
		var a := r.randf_range(-PI, PI)
		var d := r.randf_range(90, 170)
		var h := r.randf_range(4, 18)
		box(sec, Vector3(sin(a) * d, h * 0.5 - 1.0, -60 + cos(a) * d), Vector3(r.randf_range(14, 40), h, r.randf_range(10, 30)), M["dirt"], Vector3(0, r.randf() * TAU, 0), false)
	# Trocador de Ar distante (oeste)
	var t := MeshInstance3D.new()
	t.mesh = MeshKit.lathe(PackedVector2Array([Vector2(34, 0), Vector2(28, 25), Vector2(19, 75), Vector2(15, 120), Vector2(21, 128), Vector2(12, 142), Vector2(5, 165), Vector2(2, 180)]), 20)
	t.material_override = Mats.get_mat("concrete", 0.05, Color(0.3, 0.3, 0.32))
	t.transform = Transform3D(Basis().scaled(Vector3.ONE * 1.3), Vector3(-420, -10, -380))
	t.layers = 3
	add_child(t)
