extends LevelBase
## Capítulo 3 — "Distrito Leste" (Ato I, fim da demo).
## A) Beco de acesso à Fundição Quatro · B) Galpão de montagem: esteiras, operários, capataz,
## Vigilantes de turno · C) Fosso dos Escribas: guindaste de pórtico controlável (mover + baixar)
## vira ponte · D) Sala da prensa: três válvulas de alívio, alarme e reforços, alavanca de
## sobrecarga, explosão · E) Fuga pelo dreno até o rio, reencontro com Irina → fim do capítulo.

const CP_ORDER := ["start", "hall", "pit", "press", "drain"]
const PIT_Z0 := -79.0
const PIT_Z1 := -93.0
const BRIDGE_UP := Vector3(10.0, 7.0, -86.0)
const BRIDGE_DOWN := Vector3(0.0, -0.2, -86.0)
var D := {}
var cp_i := 0
var M := {}
var _sun: DirectionalLight3D
var _bridge: AnimatableBody3D
var _trolley: Node3D
var _cables: MeshInstance3D
var _btn_move: Interactables.Switch
var _btn_lower: Interactables.Switch
var _valves: Array[Interactables.Switch] = []
var _overload: Interactables.Switch
var _drain_door: AnimatableBody3D
var _ram: AnimatableBody3D
var _ram_tw: Tween
var _alarm_lights: Array[OmniLight3D] = []
var _hall_lights: Array[OmniLight3D] = []
var _irina: NpcAlly
var _alarm_on := false
var _alarm_t := 0.0

func _mats() -> void:
	M = {
		"conc": Mats.get_mat("concrete", 0.35, Color(0.66, 0.66, 0.63)),
		"conc_dark": Mats.get_mat("concrete", 0.35, Color(0.42, 0.43, 0.42)),
		"floor": Mats.get_mat("tiles", 0.25, Color(0.5, 0.5, 0.47)),
		"asphalt": Mats.get_mat("asphalt", 0.3, Color(0.75, 0.75, 0.75)),
		"brick": Mats.get_mat("brick", 0.4, Color(0.62, 0.55, 0.5)),
		"brick_dark": Mats.get_mat("brick", 0.4, Color(0.45, 0.41, 0.39)),
		"paint": Mats.get_mat("rusted_paint", 0.5, Color(0.55, 0.66, 0.62)),
		"paint_y": Mats.get_mat("rusted_paint", 0.5, Color(0.85, 0.7, 0.3)),
		"paint_red": Mats.get_mat("rusted_paint", 0.5, Color(0.7, 0.42, 0.35)),
		"steel": Mats.get_mat("steel", 0.6, Color(0.6, 0.6, 0.58)),
		"steel_dark": Mats.get_mat("steel", 0.6, Color(0.36, 0.36, 0.35)),
		"grate": Mats.get_mat("grate", 0.6, Color(0.7, 0.7, 0.68)),
		"dominion": Mats.get_mat("dominion", 0.3),
		"wood": Mats.get_mat("wood", 0.8, Color(0.72, 0.62, 0.5)),
		"gravel": Mats.get_mat("gravel", 0.3, Color(0.8, 0.78, 0.75)),
		"earth": Mats.get_mat("cracked_earth", 0.3, Color(0.6, 0.58, 0.55)),
		"rubber": Mats.get_mat("rubber", 1.0, Color(0.5, 0.5, 0.5)),
		"paper": Mats.get_mat("fabric", 1.5, Color(0.95, 0.92, 0.85)),
		"water": Mats.glass(),
		"glass": Mats.glass(),
	}

func build() -> void:
	_mats()
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch3.json"))
	cp_i = maxi(0, CP_ORDER.find(Game.checkpoint))
	grid = {"hall": 16.0, "pit": 16.0, "press": 16.0, "drain": 16.0}
	outdoor = {"alley": true, "outfall": true}
	setup_env(Color(0.16, 0.17, 0.19), Color(0.42, 0.42, 0.42), 0.95, Color(0.22, 0.22, 0.22), 0.02, 0.0, 0.5)
	env.tonemap_exposure = 1.45
	_sun = sun(Vector3(-25, 160, 0), Color(0.75, 0.8, 0.95), 0.5, true)
	_sun.light_cull_mask = 2
	_build_alley()
	_build_hall()
	_build_pit()
	_build_press()
	_build_drain()
	checkpoints["start"] = [Vector3(0, 0.05, -2), 0.0]

func after_build() -> void:
	AudioBus.start_music()
	AudioBus.play_ambience("res://assets/audio/ambience/industrial_hum.wav", "", -8.0)
	AudioBus.set_room(0.6, 0.3)
	player.set_mask(true)
	match Game.checkpoint:
		"start", "hall": Game.set_objective("obj.ch3.hall")
		"pit": Game.set_objective("obj.ch3.pit")
		"press": Game.set_objective("obj.ch3.valves" if _valves_closed() < 3 else "obj.ch3.overload")
		"drain": Game.set_objective("obj.ch3.drain")
	# restaura estado do guindaste
	if flag("crane_moved"):
		_trolley.position.x = 0.0
		_bridge.position = Vector3(0.0, BRIDGE_UP.y, BRIDGE_UP.z)
		_btn_move.used = true
		_btn_lower.enabled = true
	if flag("crane_done"):
		_bridge.position = BRIDGE_DOWN
		_btn_lower.used = true
	_update_cables()
	for i in 3:
		if flag("valve_%d" % i):
			_valves[i].used = true
			_valves[i].handle.rotation.x = -0.7
	_overload.enabled = _valves_closed() >= 3 and not flag("overload")
	if flag("overload"):
		_overload.used = true
		_after_explosion_state()
	_irina = NpcAlly.make("irina", "conscript", 77, "rifle")
	_irina.body.palette["mask"] = false
	add_child(_irina)
	_irina.global_position = Vector3(50.5, 0.05, -134.5)
	_irina.rotation.y = PI * 0.5
	_irina.set_mode(NpcAlly.Mode.IDLE)
	if flag("valve_0") and not flag("overload"):
		_set_alarm(true)

func _physics_process(delta: float) -> void:
	if _alarm_on:
		_alarm_t += delta
		var k := 0.5 + 0.5 * sin(_alarm_t * 6.0)
		for l in _alarm_lights:
			l.light_energy = 0.3 + 2.2 * k
		if fmod(_alarm_t, 3.2) < delta:
			AudioBus.play_3d("alarm", Vector3(0, 8, -121), -6.0, 0.0, 120.0)

# =====================================================================
# A) BECO (z 0 .. -14)
# =====================================================================
func _build_alley() -> void:
	var sec := "alley"
	room(sec, Vector3(0, 0, -7), Vector3(8, 6, 14), M["brick_dark"], M["asphalt"], null, [["n", 0.0, 4.0, 4.2]])
	box(sec, Vector3(0, 7.5, -14.15), Vector3(8.6, 3.0, 0.3), M["brick"])
	poster(Vector3(0, 5.0, -13.98), 0.0, "res://assets/textures/sign_3.png", Vector2(2.6, 0.65), true)
	for p in [["barrel", Vector3(-3.0, 0.5, -3.0)], ["crate", Vector3(3.0, 0.5, -5.0)], ["bucket", Vector3(-2.6, 0.3, -9.0)], ["crate_small", Vector3(2.9, 1.2, -5.0)]]:
		prop(p[0], p[1])
	poster(Vector3(-3.98, 2.0, -6.0), PI * 0.5, "res://assets/textures/poster_0.png")
	sodium_lamp(sec, Vector3(3.6, 0, -8.0), -PI * 0.5, 5.0, 1.6, true)
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(-3.8, 5.5, 0.0), Vector3(-3.8, 5.5, -13.8), Vector3(-2.0, 5.5, -13.8)]), 0.16, 10), Transform3D(), M["steel_dark"])
	Interactables.trigger(self, Vector3(0, 1, -5), Vector3(8, 3, 2), func():
		say("factory_intro", D["factory_intro"]))

# =====================================================================
# B) GALPÃO DE MONTAGEM (x ±14, z -14 .. -74, altura 10)
# =====================================================================
func _build_hall() -> void:
	var sec := "hall"
	room(sec, Vector3(0, 0, -44), Vector3(28, 10, 60), M["brick"], M["floor"], M["conc_dark"],
		[["s", 0.0, 4.0, 4.2], ["n", 0.0, 10.0, 6.5]])
	# pilares e treliças do telhado
	for z: float in [-24.0, -34.0, -44.0, -54.0, -64.0]:
		for x: float in [-10.0, 10.0]:
			box(sec, Vector3(x, 5, z), Vector3(0.6, 10, 0.6), M["conc"], Vector3.ZERO, true, 0.03)
		mesh_at(sec, MeshKit.bevel_box(Vector3(28, 0.5, 0.35), 0.02, 1), Transform3D(Basis(), Vector3(0, 9.4, z)), M["steel_dark"])
	# esteiras de montagem (velocidade constante empurra caixas e o jogador)
	for x: float in [-6.0, 6.0]:
		_conveyor(sec, Vector3(x, 0, -43), 46.0, Vector3(0, 0, 1.1))
	# bancadas e operários
	var wseed := 300
	for z: float in [-26.0, -36.0, -48.0, -60.0]:
		for s: float in [-1.0, 1.0]:
			var bx := 3.9 * s
			box(sec, Vector3(bx - 0.0, 0.45, z), Vector3(0.9, 0.9, 2.0), M["steel"], Vector3.ZERO, true, 0.02)
			mesh_at(sec, MeshKit.cylinder(0.25, 0.4, 12, 0.02), Transform3D(Basis(), Vector3(bx, 1.1, z + 0.5)), M["paint"])
			var w := NpcAlly.make("worker" if (z == -36.0 and s < 0) else "", "citizen", wseed)
			wseed += 7
			add_child(w)
			w.global_position = Vector3(bx + 0.9 * s, 0.05, z)
			w.rotation.y = PI * 0.5 * s
			w.set_mode(NpcAlly.Mode.IDLE)
	# luzes industriais (pendentes)
	for z: float in [-22.0, -38.0, -54.0, -68.0]:
		for x: float in [-6.0, 6.0]:
			mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(0.05, 0.4), Vector2(0.45, 0.0), Vector2(0.5, -0.05)]), 12), Transform3D(Basis(), Vector3(x, 7.0, z)), M["steel_dark"])
			mesh_at(sec, MeshKit.cylinder(0.01, 2.6, 4), Transform3D(Basis(), Vector3(x, 8.6, z)), M["steel_dark"])
		_hall_lights.append(light(Vector3(0, 6.6, z), Color(1.0, 0.88, 0.68), 16.0, 2.0, z == -38.0))
	# cabine do capataz (vidro)
	var bc := Vector3(11.5, 0, -62)
	room(sec, bc, Vector3(4.4, 3.0, 6.0), M["paint"], M["wood"], M["conc_dark"], [["w", 0.0, 1.2, 2.2]], 0.12)
	mesh_at(sec, MeshKit.bevel_box(Vector3(0.05, 1.2, 4.0), 0.005, 1), Transform3D(Basis(), Vector3(bc.x - 2.25, 1.8, bc.z - 0.0)), M["glass"])
	box(sec, bc + Vector3(1.2, 0.4, -1.5), Vector3(1.4, 0.8, 0.7), M["wood"])
	light(bc + Vector3(0, 2.6, 0), Color(0.85, 0.95, 0.9), 5.0, 0.8)
	var fm := NpcAlly.make("foreman", "citizen", 912)
	add_child(fm)
	fm.global_position = bc + Vector3(0.4, 0.05, 0.6)
	fm.rotation.y = PI * 0.5
	fm.on_use = func():
		say("foreman", D["foreman"])
		Game.set_objective("obj.ch3.pit")
	# pôsteres e telas
	for z: float in [-20.0, -40.0, -58.0]:
		poster(Vector3(-13.98, 2.4, z), PI * 0.5, "res://assets/textures/poster_%d.png" % (int(-z) % 3))
	poster(Vector3(0, 7.4, -73.8), 0.0, "res://assets/textures/screen_regent.png", Vector2(4.0, 2.25), true)
	# caixas de peças, carrinhos
	for p in [["crate", Vector3(-12.2, 0.5, -30)], ["crate", Vector3(-12.2, 0.5, -31.2)], ["crate", Vector3(12.2, 0.5, -40)], ["barrel", Vector3(-12.5, 0.5, -52)],
			["explosive", Vector3(12.4, 0.5, -48)], ["crate_small", Vector3(-11.8, 1.2, -30.5)], ["bucket", Vector3(12.0, 0.3, -20)]]:
		prop(p[0], p[1])
	for p: Vector3 in [Vector3(-11.5, 0, -42), Vector3(11.5, 0, -30), Vector3(-11.5, 0, -64), Vector3(11.0, 0, -52)]:
		cover(p)
	acoustic_zone(Vector3(0, 5, -44), Vector3(28, 10, 60), 0.75, 0.35)
	# roteiro
	checkpoint("hall", Vector3(0, 1, -17), Vector3(10, 3, 2), Vector3(0, 0.05, -17), 0.0)
	Interactables.trigger(self, Vector3(0, 1, -21), Vector3(10, 3, 2), func():
		say("pa_shift", D["pa_shift"]))
	Interactables.trigger(self, Vector3(-2.0, 1, -36), Vector3(3.6, 3, 4), func():
		say("worker", D["worker"]))
	if cp_i <= CP_ORDER.find("hall"):
		enemy("h_v1", "vigilante_pistol", Vector3(0, 0.05, -44), 0.0, [Vector3(0, 0.05, -30), Vector3(0, 0.05, -66)] as Array[Vector3])
		enemy("h_v2", "vigilante_baton", Vector3(-12.0, 0.05, -60), PI * 0.5, [Vector3(-12, 0.05, -58), Vector3(-12, 0.05, -22)] as Array[Vector3])
		enemy("h_v3", "vigilante_pistol", Vector3(8.5, 0.05, -70), PI)
	pickup("h_ammo12", Vector3(-12.2, 1.05, -31.2), "ammo_12", 8)
	pickup("h_med", Vector3(12.4, 0.95, -60.5), "medkit")
	pickup("h_9mm", Vector3(12.2, 1.05, -40), "ammo_9mm", 30)

func _conveyor(sec: String, c: Vector3, length: float, vel: Vector3) -> void:
	var h := 0.85
	# chassi
	box(sec, c + Vector3(0, h * 0.5 - 0.05, 0), Vector3(1.3, h - 0.1, length), M["steel_dark"], Vector3.ZERO, false)
	for i in int(length / 2.0):
		var z := c.z - length * 0.5 + 1.0 + i * 2.0
		mesh_at(sec, MeshKit.cylinder(0.07, 1.4, 8), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(c.x, h - 0.02, z)), M["steel"])
	box(sec, c + Vector3(0, h + 0.01, 0), Vector3(1.2, 0.04, length), M["rubber"], Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		box(sec, c + Vector3(0.68 * s, h + 0.12, 0), Vector3(0.06, 0.28, length), M["paint_y"])
	# corpo da esteira (move objetos)
	var b := StaticBody3D.new()
	b.set_meta("surface", "metal")
	b.constant_linear_velocity = vel
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.3, h, length); cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.position = c + Vector3(0, h * 0.5, 0)
	# batente no fim e carcaças de filtro na esteira
	box(sec, c + Vector3(0, h + 0.3, length * 0.5 - 0.2), Vector3(1.3, 0.6, 0.2), M["paint_y"])
	for i in 3:
		prop("crate_small", c + Vector3(0, h + 0.35, -length * 0.3 + i * 5.0), randf() * PI)

# =====================================================================
# C) FOSSO DOS ESCRIBAS (z -74 .. -100) — guindaste vira ponte
# =====================================================================
func _build_pit() -> void:
	var sec := "pit"
	var top := 14.0
	var bot := -8.0
	# bordas (sul e norte) e fundo
	box(sec, Vector3(0, -0.15, (-74.0 + PIT_Z0) * 0.5), Vector3(28.6, 0.3, -74.0 - PIT_Z0), M["conc"])
	box(sec, Vector3(0, -0.15, (PIT_Z1 - 100.0) * 0.5), Vector3(28.6, 0.3, PIT_Z1 + 100.0), M["conc"])
	box(sec, Vector3(0, bot - 0.15, (PIT_Z0 + PIT_Z1) * 0.5), Vector3(28.6, 0.3, PIT_Z0 - PIT_Z1), M["earth"])
	# paredes do fosso (faces internas das bordas)
	box(sec, Vector3(0, bot * 0.5 - 0.15, PIT_Z0 - 0.15), Vector3(28.6, -bot, 0.3), M["conc_dark"])
	box(sec, Vector3(0, bot * 0.5 - 0.15, PIT_Z1 + 0.15), Vector3(28.6, -bot, 0.3), M["conc_dark"])
	# paredes laterais
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(14.15 * s, (top + bot) * 0.5, -87.0), Vector3(0.3, top - bot, 26.0), M["brick_dark"])
	box(sec, Vector3(0, top + 0.15, -87.0), Vector3(28.6, 0.3, 26.0), M["conc_dark"])
	# parede sul acima do galpão (galpão tem 10 m; fosso 14 m)
	box(sec, Vector3(0, 12.0, -74.15), Vector3(28.6, 4.0, 0.3), M["brick_dark"])
	# guarda-corpos com vão para a ponte
	for z: float in [PIT_Z0 + 0.1, PIT_Z1 - 0.1]:
		for s: float in [-1.0, 1.0]:
			box(sec, Vector3(7.8 * s, 0.55, z), Vector3(12.4, 1.1, 0.08), M["paint_y"], Vector3.ZERO, true)
	# o fundo: arquivos e registros descartados
	var rng := RandomNumberGenerator.new(); rng.seed = 31
	for i in 26:
		var p := Vector3(rng.randf_range(-13, 13), bot, rng.randf_range(PIT_Z1 + 1.0, PIT_Z0 - 1.0))
		var sz := Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 1.2), rng.randf_range(0.4, 1.0))
		box(sec, p + Vector3(0, sz.y * 0.5, 0), sz, M["paper"] if i % 3 else M["steel_dark"], Vector3(0, rng.randf() * PI, rng.randf_range(-0.2, 0.2)), false, 0.02)
	light(Vector3(0, -5.5, -86), Color(0.5, 0.65, 0.9), 16.0, 1.4)
	light(Vector3(-9, 9.0, -80), Color(1.0, 0.85, 0.65), 16.0, 1.3)
	light(Vector3(9, 9.0, -96), Color(1.0, 0.85, 0.65), 16.0, 1.3)
	# queda no fosso é fatal
	Interactables.trigger(self, Vector3(0, bot + 1.5, -86), Vector3(28, 2, PIT_Z0 - PIT_Z1), func():
		if is_instance_valid(player): player.take_damage(1000.0), false)
	# trilho do pórtico
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(0, 12.2, -86.0 + 1.2 * s), Vector3(28.0, 0.5, 0.3), M["paint_y"], Vector3.ZERO, false)
	_trolley = Node3D.new()
	add_child(_trolley)
	_trolley.position = Vector3(BRIDGE_UP.x, 11.6, -86.0)
	var tm := MeshInstance3D.new()
	tm.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(2.2, 0.8, 3.0), 0.04), Transform3D()],
		[MeshKit.cylinder(0.35, 2.6, 14), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, -0.5, 0))]])
	tm.material_override = M["paint_y"]
	_trolley.add_child(tm)
	_cables = MeshInstance3D.new()
	_cables.material_override = M["steel_dark"]
	add_child(_cables)
	# plataforma suspensa (vira ponte)
	_bridge = AnimatableBody3D.new()
	_bridge.sync_to_physics = false
	_bridge.set_meta("surface", "metal")
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3.0, 0.4, 16.0); cs.shape = bs
	_bridge.add_child(cs)
	var parts := [[MeshKit.bevel_box(Vector3(3.0, 0.12, 16.0), 0.02, 1), Transform3D(Basis(), Vector3(0, 0.14, 0))]]
	for s: float in [-1.0, 1.0]:
		parts.append([MeshKit.bevel_box(Vector3(0.2, 0.4, 16.0), 0.02, 1), Transform3D(Basis(), Vector3(1.4 * s, 0, 0))])
		parts.append([MeshKit.bevel_box(Vector3(0.06, 0.9, 16.0), 0.01, 1), Transform3D(Basis(), Vector3(1.45 * s, 0.65, 0))])
	for i in 9:
		parts.append([MeshKit.bevel_box(Vector3(3.0, 0.3, 0.15), 0.01, 1), Transform3D(Basis(), Vector3(0, -0.05, -7.6 + i * 1.9))])
	var bm := MeshInstance3D.new(); bm.mesh = MeshKit.combine(parts); bm.material_override = M["steel"]
	_bridge.add_child(bm)
	# corrimãos com colisão (impede cair pelos lados)
	for s: float in [-1.0, 1.0]:
		var rc := CollisionShape3D.new(); var rb := BoxShape3D.new(); rb.size = Vector3(0.1, 1.0, 16.0); rc.shape = rb
		rc.position = Vector3(1.45 * s, 0.7, 0)
		_bridge.add_child(rc)
	add_child(_bridge)
	_bridge.position = BRIDGE_UP
	# painel de controle
	box(sec, Vector3(-4.0, 0.55, -77.4), Vector3(1.4, 1.1, 0.6), M["paint"], Vector3.ZERO, true, 0.03)
	_btn_move = Interactables.button(self, Vector3(-4.35, 1.25, -77.05), 0.0)
	_btn_lower = Interactables.button(self, Vector3(-3.65, 1.25, -77.05), 0.0)
	_btn_lower.enabled = false
	_btn_move.activated.connect(_crane_move)
	_btn_lower.activated.connect(_crane_lower)
	poster(Vector3(-4.0, 1.75, -77.69), 0.0, "res://assets/textures/sign_1.png", Vector2(1.2, 0.3), true)
	light(Vector3(-4.0, 3.0, -76.0), Color(1.0, 0.7, 0.4), 6.0, 0.9)
	light(Vector3(0, 10.0, -86.0), Color(0.9, 0.85, 0.75), 18.0, 1.2, true)
	checkpoint("pit", Vector3(0, 1, -75.5), Vector3(10, 3, 2), Vector3(0, 0.05, -75.5), 0.0)
	Interactables.trigger(self, Vector3(0, 1, -76.5), Vector3(10, 3, 1.5), func():
		say("pit", D["pit"])
		Game.set_objective("obj.ch3.pit"))
	pickup("p_med", Vector3(12.5, 0.4, -76.0), "medkit")
	prop("crate", Vector3(12.5, 0.5, -95.5))
	pickup("p_ammo12", Vector3(12.5, 1.05, -95.5), "ammo_12", 8)

func _update_cables() -> void:
	if not is_instance_valid(_cables): return
	var a := _trolley.position + Vector3(0, -0.8, 0)
	var parts := []
	for s: float in [-1.0, 1.0]:
		var top := a + Vector3(0, 0, 1.0 * s)
		var bot := _bridge.position + Vector3(0, 0.3, 6.5 * s)
		var len := top.distance_to(bot)
		var mid := (top + bot) * 0.5
		var up := (top - bot).normalized()
		var basis := Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) < 0.9999 else Basis()
		parts.append([MeshKit.cylinder(0.03, len, 5), Transform3D(basis, mid)])
	_cables.mesh = MeshKit.combine(parts)

func _crane_move() -> void:
	set_flag("crane_moved")
	AudioBus.play_3d("gate_motor", _trolley.global_position, 0.0, 0.0, 60.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_trolley, "position:x", 0.0, 5.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bridge, "position:x", 0.0, 5.0).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(_v): _update_cables(), 0.0, 1.0, 5.0)
	await tw.finished
	if not is_inside_tree(): return
	_btn_lower.enabled = true

func _crane_lower() -> void:
	AudioBus.play_3d("gate_motor", _bridge.global_position, 0.0, 0.0, 60.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bridge, "position:y", BRIDGE_DOWN.y, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(_v): _update_cables(), 0.0, 1.0, 4.0)
	await tw.finished
	if not is_inside_tree(): return
	AudioBus.play_3d("impact_metal_heavy", _bridge.global_position, 2.0)
	if is_instance_valid(player): player.shake(0.4)
	set_flag("crane_done")
	say("crane_done", D["crane_done"])
	Game.set_objective("obj.ch3.valves")
	# reforço do outro lado do fosso
	var e := enemy("p_v1", "vigilante_pistol", Vector3(3.5, 0.05, -97.5), 0.0)
	if e: e.hear_alert(Vector3(0, 0, -86))

# =====================================================================
# D) SALA DA PRENSA (x ±16, z -100 .. -142, altura 12)
# =====================================================================
func _build_press() -> void:
	var sec := "press"
	var c := Vector3(0, 0, -121)
	room(sec, c, Vector3(32, 12, 42), M["brick_dark"], M["floor"], M["conc_dark"],
		[["s", 0.0, 6.0, 5.0], ["e", -13.0, 2.4, 3.0]])
	# prensa hidráulica
	box(sec, c + Vector3(0, 0.75, 0), Vector3(8, 1.5, 6), M["steel_dark"], Vector3.ZERO, true, 0.05)
	for x: float in [-3.4, 3.4]:
		for z: float in [-2.4, 2.4]:
			box(sec, c + Vector3(x, 5.75, z), Vector3(0.9, 8.5, 0.9), M["paint_y"], Vector3.ZERO, true, 0.04)
	box(sec, c + Vector3(0, 10.6, 0), Vector3(9, 1.6, 7), M["paint_y"], Vector3.ZERO, true, 0.06)
	mesh_at(sec, MeshKit.cylinder(1.1, 3.0, 18, 0.05), Transform3D(Basis(), c + Vector3(0, 8.6, 0)), M["steel"])
	_ram = AnimatableBody3D.new()
	_ram.sync_to_physics = false
	var rcs := CollisionShape3D.new(); var rbs := BoxShape3D.new(); rbs.size = Vector3(6.0, 1.8, 4.4); rcs.shape = rbs
	_ram.add_child(rcs)
	var rm := MeshInstance3D.new(); rm.mesh = MeshKit.bevel_box(Vector3(6.0, 1.8, 4.4), 0.06); rm.material_override = M["steel"]
	_ram.add_child(rm)
	add_child(_ram)
	_ram.position = c + Vector3(0, 6.2, 0)
	_ram_cycle(3.2)
	# cerca em volta da prensa
	for s: float in [-1.0, 1.0]:
		box(sec, c + Vector3(6.0 * s, 0.55, 0), Vector3(0.08, 1.1, 10.0), M["paint_y"])
		box(sec, c + Vector3(0, 0.55, 5.0 * s), Vector3(12.0, 1.1, 0.08), M["paint_y"])
	# tubulações das válvulas até a prensa
	var vp := [Vector3(-15.6, 1.2, -112.0), Vector3(15.6, 1.2, -126.0), Vector3(-8.0, 6.2, -141.6)]
	var vy := [PI * 0.5, -PI * 0.5, 0.0]
	for i in 3:
		var p: Vector3 = vp[i]
		var into := p + Basis(Vector3.UP, vy[i]) * Vector3(0, 0, 0.5)
		mesh_at(sec, MeshKit.pipe(PackedVector3Array([p + Vector3(0, 0.9, 0) + (into - p) * 0.4, Vector3(into.x, 9.0, into.z), Vector3(c.x + signf(p.x + 0.001) * 1.5, 9.0, c.z)]), 0.14, 10), Transform3D(), M["steel_dark"])
		var v := Interactables.lever(self, p, vy[i])
		v.hint_key = "hud.use"
		_valves.append(v)
		var idx := i
		v.activated.connect(func(): _valve_closed(idx))
		light(p + Basis(Vector3.UP, vy[i]) * Vector3(0, 1.4, 0.9), Color(0.9, 0.5, 0.3), 5.0, 0.7)
	# passarela norte (y 5) com escada
	var top := stair(sec, Vector3(-13.5, 0, -131.2), 0.0, 1.4, 5.0, M["steel"])
	box(sec, Vector3(0, 4.925, -140.5), Vector3(32, 0.15, 3.0), M["grate"])
	for x in range(-15, 16, 3):
		mesh_at(sec, MeshKit.bevel_box(Vector3(0.12, 0.3, 3.0), 0.01, 1), Transform3D(Basis(), Vector3(x, 4.7, -140.5)), M["steel_dark"])
	box(sec, Vector3(1.625, 5.55, -138.95), Vector3(28.75, 1.1, 0.06), M["paint_y"])
	box(sec, Vector3(-15.125, 5.55, -138.95), Vector3(1.75, 1.1, 0.06), M["paint_y"])
	ramp(sec, top, top + Vector3(0, 0, -0.6), 1.4)
	# cabine de controle (alavanca de sobrecarga)
	box(sec, Vector3(-15.0, 0.6, -124.0), Vector3(1.6, 1.2, 2.4), M["paint"], Vector3.ZERO, true, 0.04)
	_overload = Interactables.lever(self, Vector3(-14.1, 1.3, -124.0), PI * 0.5)
	_overload.enabled = false
	_overload.activated.connect(_do_overload)
	poster(Vector3(-15.98, 2.6, -124.0), PI * 0.5, "res://assets/textures/sign_0.png", Vector2(1.6, 0.4), true)
	light(Vector3(-13.5, 3.0, -124.0), Color(1.0, 0.75, 0.5), 6.0, 1.0)
	# porta do dreno (persiana) na parede leste
	_drain_door = AnimatableBody3D.new()
	_drain_door.sync_to_physics = false
	_drain_door.set_meta("surface", "metal")
	var dcs := CollisionShape3D.new(); var dbs := BoxShape3D.new(); dbs.size = Vector3(0.2, 3.0, 2.5); dcs.shape = dbs
	_drain_door.add_child(dcs)
	var dparts := []
	for i in 10:
		dparts.append([MeshKit.bevel_box(Vector3(0.2, 0.28, 2.5), 0.02, 1), Transform3D(Basis(), Vector3(0, -1.35 + i * 0.3, 0))])
	var dm := MeshInstance3D.new(); dm.mesh = MeshKit.combine(dparts); dm.material_override = Mats.get_mat("door_metal_red", 0.4, Color.WHITE, false)
	_drain_door.add_child(dm)
	add_child(_drain_door)
	_drain_door.position = Vector3(16.15, 1.5, -134.0)
	# luzes de trabalho e de alarme
	for p: Vector3 in [Vector3(-9, 10.5, -108), Vector3(9, 10.5, -108), Vector3(-9, 10.5, -132), Vector3(9, 10.5, -132)]:
		light(p, Color(1.0, 0.9, 0.75), 16.0, 1.8, p.x < 0.0 and p.z > -110.0)
		mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(0.05, 0.4), Vector2(0.45, 0.0), Vector2(0.5, -0.05)]), 12), Transform3D(Basis(), p + Vector3(0, 0.3, 0)), M["steel_dark"])
	for p: Vector3 in [Vector3(-15.4, 7.0, -121), Vector3(15.4, 7.0, -121), Vector3(0, 7.0, -101)]:
		var l := light(p, Color(1.0, 0.15, 0.08), 12.0, 0.0)
		_alarm_lights.append(l)
		mesh_at(sec, MeshKit.cylinder(0.18, 0.25, 10, 0.02), Transform3D(Basis(), p), Mats.emissive(Color(0.9, 0.1, 0.05), 1.0))
	# caixas e cobertura
	for p in [["crate", Vector3(-10, 0.5, -104)], ["crate", Vector3(-10, 1.5, -104)], ["crate", Vector3(10.5, 0.5, -116)], ["barrel", Vector3(-11, 0.5, -119)],
			["explosive", Vector3(11.0, 0.5, -105)], ["explosive", Vector3(-10.0, 0.5, -128)], ["crate", Vector3(8.0, 0.5, -136)]]:
		prop(p[0], p[1])
	for p: Vector3 in [Vector3(-10, 0, -105.5), Vector3(10.5, 0, -117.5), Vector3(8.0, 0, -134.5), Vector3(-6.5, 0, -121), Vector3(6.5, 0, -121)]:
		cover(p)
	acoustic_zone(c + Vector3(0, 6, 0), Vector3(32, 12, 42), 0.85, 0.4)
	occluder(Vector3(0, 9.0, -100.0), Vector3(32, 6, 0.3))
	checkpoint("press", Vector3(0, 1, -102.5), Vector3(6, 3, 2), Vector3(0, 0.05, -102.5), 0.0)
	pickup("pr_med", Vector3(-10, 2.05, -104), "medkit")
	pickup("pr_9mm", Vector3(10.5, 1.05, -116), "ammo_9mm", 30)
	pickup("pr_12", Vector3(8.0, 1.05, -136), "ammo_12", 12)
	pickup("pr_filter", Vector3(-15.0, 1.25, -125.0), "filter")

func _ram_cycle(period: float) -> void:
	if _ram_tw: _ram_tw.kill()
	var y0 := 6.2
	_ram_tw = create_tween().set_loops()
	_ram_tw.tween_property(_ram, "position:y", 2.4, period * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ram_tw.tween_callback(func():
		if is_inside_tree(): AudioBus.play_3d("impact_metal_heavy", _ram.global_position, -4.0, 0.05, 60.0))
	_ram_tw.tween_interval(period * 0.15)
	_ram_tw.tween_property(_ram, "position:y", y0, period * 0.5).set_trans(Tween.TRANS_SINE)

func _valves_closed() -> int:
	var n := 0
	for i in 3:
		if flag("valve_%d" % i): n += 1
	return n

func _valve_closed(i: int) -> void:
	set_flag("valve_%d" % i)
	Effects.burst(_valves[i].global_position + Vector3(0, 1.0, 0), Vector3.UP, Color(0.85, 0.85, 0.85, 0.5), 24, false, 1.5)
	var n := _valves_closed()
	if n == 1:
		_set_alarm(true)
		say("press_alarm", D["press_alarm"], true)
		var e1 := enemy("pr_s1", "soldier", Vector3(2.0, 0.05, -101.0), PI)
		var e2 := enemy("pr_v1", "vigilante_pistol", Vector3(-2.0, 0.05, -101.5), PI)
		for e in [e1, e2]:
			if e: e.hear_alert(_valves[i].global_position)
		_ram_cycle(2.2)
	elif n == 2:
		say("valve", D["valve"])
		var e3 := enemy("pr_v2", "vigilante_baton", Vector3(14.0, 0.05, -139.0), PI * 0.5)
		var e4 := enemy("pr_s2", "soldier", Vector3(-6.0, 5.05, -140.5), 0.0)
		for e in [e3, e4]:
			if e: e.hear_alert(_valves[i].global_position)
		_ram_cycle(1.5)
	if n >= 3:
		_ram_cycle(0.9)
		_overload.enabled = true
		Game.set_objective("obj.ch3.overload")

func _set_alarm(on: bool) -> void:
	_alarm_on = on
	if not on:
		for l in _alarm_lights: l.light_energy = 0.0

func _do_overload() -> void:
	if flag("overload"): return
	set_flag("overload")
	say("overload", D["overload"], true)
	Game.set_objective("obj.ch3.drain")
	_open_drain()
	var e := enemy("pr_s3", "soldier", Vector3(-4.0, 5.05, -140.5), 0.0)
	if e: e.hear_alert(Vector3(-14, 1, -124))
	_ram_cycle(0.55)
	if is_instance_valid(player): player.shake(0.3)
	await get_tree().create_timer(9.0).timeout
	if not is_inside_tree(): return
	_explode_press()

func _open_drain() -> void:
	AudioBus.play_3d("gate_motor", _drain_door.global_position, 0.0, 0.0, 60.0)
	var tw := create_tween()
	tw.tween_property(_drain_door, "position:y", 4.4, 2.5).set_trans(Tween.TRANS_SINE)

func _explode_press() -> void:
	var c := Vector3(0, 0, -121)
	Effects.explosion(c + Vector3(0, 5.0, 0), 7.0, 70.0, null)
	for o: Vector3 in [Vector3(-3, 2, 2), Vector3(3, 8, -2), Vector3(0, 10, 0)]:
		Effects.burst(c + o, Vector3.UP, Color(1.0, 0.6, 0.2), 40, true, 2.0)
	if _ram_tw: _ram_tw.kill()
	var tw := create_tween()
	tw.tween_property(_ram, "position:y", 2.4, 0.25)
	_after_explosion_state()
	if is_instance_valid(player): player.shake(1.2)
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return
	say("explosion", D["explosion"], true)

func _after_explosion_state() -> void:
	_set_alarm(false)
	if _ram_tw: _ram_tw.kill()
	_drain_door.position.y = 4.4
	var fire := light(Vector3(0, 3.0, -121), Color(1.0, 0.5, 0.15), 18.0, 2.4)
	var fl := Flicker.new()
	fl.light = fire
	fl.base = 2.4
	add_child(fl)
	for l in _alarm_lights:
		l.light_color = Color(1.0, 0.45, 0.15); l.light_energy = 0.8

# =====================================================================
# E) DRENO → RIO
# =====================================================================
func _build_drain() -> void:
	var sec := "drain"
	room(sec, Vector3(28, 0, -134), Vector3(24, 3.2, 3.0), M["conc_dark"], M["conc"], M["conc_dark"], [["w", 0.0, 2.5, 3.0], ["e", 0.0, 3.0, 3.2]])
	box(sec, Vector3(28, 0.02, -134), Vector3(24, 0.04, 1.2), M["water"], Vector3.ZERO, false)
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(16.5, 2.7, -132.8), Vector3(40, 2.7, -132.8)]), 0.12, 8), Transform3D(), M["steel_dark"])
	for x: float in [21.0, 29.0, 37.0]:
		tube_lamp(sec, Vector3(x, 3.1, -134), PI * 0.5, Color(0.7, 0.9, 0.8), 0.8, 7.0, x == 29.0)
	acoustic_zone(Vector3(28, 1.6, -134), Vector3(24, 3.2, 3), 0.7, 0.5)
	checkpoint("drain", Vector3(19, 1, -134), Vector3(2, 3, 3), Vector3(19.5, 0.05, -134), -PI * 0.5)
	# saída para o rio (exterior)
	var sec2 := "outfall"
	box(sec2, Vector3(47, -0.15, -134), Vector3(14, 0.3, 14), M["gravel"])
	box(sec2, Vector3(47, -0.3, -146), Vector3(40, 0.2, 10), M["water"], Vector3.ZERO, false)
	box(sec2, Vector3(47, 2.5, -126.85), Vector3(14, 5, 0.3), M["brick_dark"])
	box(sec2, Vector3(40.15, 4.6, -134), Vector3(0.3, 2.8, 14), M["conc_dark"])
	box(sec2, Vector3(40.15, 1.6, -137.3), Vector3(0.3, 3.2, 7.4), M["conc_dark"])
	box(sec2, Vector3(40.15, 1.6, -130.2), Vector3(0.3, 3.2, 5.6), M["conc_dark"])
	box(sec2, Vector3(54.15, 2.5, -134), Vector3(0.3, 5, 14), M["brick_dark"])
	box(sec2, Vector3(47, 0.5, -140.9), Vector3(14, 1.0, 0.3), M["conc"])
	box(sec2, Vector3(47, 12, -170), Vector3(80, 24, 2), M["dominion"], Vector3.ZERO, false)
	poster(Vector3(47, 8.0, -168.9), 0.0, "res://assets/textures/sign_4.png", Vector2(6.0, 1.5), true)
	for p in [["barrel", Vector3(50, 0.5, -131)], ["crate", Vector3(52, 0.5, -137)]]:
		prop(p[0], p[1])
	sodium_lamp(sec2, Vector3(53.5, 0, -134), -PI * 0.5, 5.0, 1.6, true)
	Interactables.trigger(self, Vector3(45, 1.2, -134), Vector3(2, 3, 10), _exit_reached)

func _exit_reached() -> void:
	if flag("done"):
		return
	set_flag("done")
	say("drain_exit", D["drain_exit"], true)
	await say_done("drain_exit")
	if not is_inside_tree(): return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	player.input_enabled = false
	Game.complete_chapter()
