extends LevelBase
## Capítulo 1 — "Linha Nove" (Ato I). Vertical slice completo.
## Seções: A) trem de realocação atravessando o Mar Seco · B) Estação Central e inspeção ·
## C) corredores de manutenção (chave inglesa, tábuas, empilhar caixas, duto) · D) casa de bombas
## (pistola, primeiro tiroteio) · E) pátio ferroviário sob névoa (vagões, barris, guarita, alavanca,
## vagão secreto) · F) portão e encontro com Irina → fim do capítulo.

const CP_ORDER := ["start", "station", "maint", "vent", "pump", "yard", "gate"]
var D := {}                 # sequências de diálogo
var cp_i := 0
var ride_speed := 0.0
var _scroller: Node3D
var _scroll_items: Array[Node3D] = []
## Cenário distante (Air Exchange, cidade) que se desloca com o trem durante a viagem.
var _far_nodes: Array[Node3D] = []
var _far_off := 0.0
const FAR_START := -200.0
const TERRAIN_PERIOD := 400.0
var _train_doors: Array[AnimatableBody3D] = []
var _riding := false
var _bohdan: NpcAlly
var _irina: NpcAlly
var _passenger: NpcAlly
var _citizens: Array[NpcAlly] = []
var _station_guards: Array[EnemyAI] = []
var _service_door: Interactables.PhysDoor
var _alarm_light: OmniLight3D
var _alarm_on := false
var _sun: DirectionalLight3D
var _gate_l: AnimatableBody3D
var _gate_r: AnimatableBody3D
var _gate_open := 0.0
var _gate_opening := false
var _screen_regent: MeshInstance3D
var _sway_t := 0.0

# materiais
var M := {}

func _mats() -> void:
	M = {
		"conc": Mats.get_mat("concrete", 0.35, Color(0.78, 0.78, 0.74)),
		"conc_dark": Mats.get_mat("concrete", 0.35, Color(0.5, 0.52, 0.5)),
		"tiles": Mats.get_mat("tiles", 0.6, Color(0.8, 0.82, 0.78)),
		"brick": Mats.get_mat("brick", 0.4, Color(0.75, 0.7, 0.66)),
		"paint": Mats.get_mat("rusted_paint", 0.5, Color(0.55, 0.66, 0.62)),
		"paint_red": Mats.get_mat("rusted_paint", 0.5, Color(0.7, 0.42, 0.35)),
		"steel": Mats.get_mat("steel", 0.6, Color(0.6, 0.6, 0.58)),
		"dominion": Mats.get_mat("dominion", 0.3),
		"earth": Mats.get_mat("cracked_earth", 0.12, Color(0.75, 0.72, 0.66)),
		"asphalt": Mats.get_mat("asphalt", 0.3, Color(0.6, 0.6, 0.6)),
		"wood": Mats.get_mat("wood", 0.8, Color(0.72, 0.62, 0.5)),
		"grate": Mats.get_mat("grate", 0.8),
		"gravel": Mats.get_mat("gravel", 0.3, Color(0.95, 0.92, 0.88)),
		"rubber": Mats.get_mat("rubber", 1.0, Color(0.5, 0.5, 0.48)),
		"glass": Mats.glass(),
		"yellow": Mats.get_mat("rusted_paint", 0.6, Color(0.95, 0.78, 0.25)),
	}

func build() -> void:
	_mats()
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch1.json"))
	cp_i = maxi(0, CP_ORDER.find(Game.checkpoint))
	grid = {"station": 14.0, "yard": 22.0, "outside": 40.0}
	outdoor = {"outside": true, "yard": true}
	sector("outside", 0.0)
	setup_env(Color(0.36, 0.38, 0.37), Color(0.34, 0.36, 0.36), 0.55, Color(0.4, 0.42, 0.41), 0.012, 0.0, 0.5)
	_sun = sun(Vector3(-24, 145, 0), Color(1.0, 0.84, 0.64), 0.9, true)
	_build_outside()
	_build_train()
	_build_station()
	_build_maintenance()
	_build_pump_room()
	_build_yard()
	checkpoints["start"] = [Vector3(0.6, 0.05, 2.0), PI * 0.5]
	checkpoints["station"] = [Vector3(5.0, 0.05, 0.0), -PI * 0.5]
	checkpoints["maint"] = [Vector3(12.0, 0.05, -19.0), 0.0]
	checkpoints["vent"] = [Vector3(15.0, 0.05, -46.5), 0.0]
	checkpoints["pump"] = [Vector3(15.0, 0.05, -66.0), 0.0]
	checkpoints["yard"] = [Vector3(15.0, 0.05, -80.0), 0.0]
	checkpoints["gate"] = [Vector3(50.0, 3.1, -139.5), PI]

func after_build() -> void:
	AudioBus.start_music()
	Game.objective_key = ""
	if cp_i == 0:
		_start_ride()
	else:
		_arrive(true)
		AudioBus.play_ambience("res://assets/audio/ambience/station_hall.wav", "", -12.0)
	match Game.checkpoint:
		"station": Game.set_objective("obj.ch1.platform")
		"maint": Game.set_objective("obj.ch1.wrench" if not state["picked"].has("wrench") else "obj.ch1.vent")
		"vent": Game.set_objective("obj.ch1.vent")
		"pump", "yard":
			Game.set_objective("obj.ch1.yard")
			_set_outdoor(Game.checkpoint == "yard")
		"gate":
			Game.set_objective("obj.ch1.gate")
			_set_outdoor(true)
	if cp_i >= CP_ORDER.find("maint"):
		player.set_mask(true)
	# restaura o estado do portão ao carregar um save
	if flag("gate_open"):
		_gate_open = 1.0
		_gate_l.position.x = 18.5 - 3.2
		_gate_r.position.x = 21.5 + 3.2
		_irina.visible = true
		_irina.global_position = Vector3(20, 0.05, -167)
		Game.set_objective("obj.ch1.exit")
	elif flag("lever"):
		_gate_opening = true
		_irina.visible = true
		Game.set_objective("obj.ch1.exit")

# =====================================================================
# A) EXTERIOR DO TREM / MAR SECO
# =====================================================================
func _build_outside() -> void:
	# leito ferroviário e planície do Mar Seco (em ladrilhos para o limite de luzes por malha)
	for ix in range(-4, 4):
		for iz in range(-5, 3):
			var c := Vector3(ix * 50.0 + 25.0, -1.0, iz * 50.0 + 25.0)
			var t := MeshKit.terrain(Vector2(50, 50), 10, func(x: float, z: float) -> float:
				var wx := x + c.x
				var wz := z + c.z
				# periódico em Z (400 m) para os ladrilhos poderem "rolar" sem costura durante a viagem
				var kz := wz * TAU / TERRAIN_PERIOD
				var hgt := sin(wx * 0.03) * 1.2 + cos(kz * 2.0) * 1.5 + sin(wx * 0.011 + kz) * 2.0
				if wx > -40.0 and wx < 70.0:
					return 0.0
				if wx > -60.0 and wx < 90.0:
					return hgt * (minf(absf(wx - 15.0) - 55.0, 20.0) / 20.0)
				return hgt)
			mesh_at("outside", t, Transform3D(Basis(), c), M["earth"])
	# piso de colisão sob a área jogável externa (pátio fica em y=0)
	_trocador(Vector3(-260, -1, -140), 1.0)
	_trocador(Vector3(140, -1, -420), 0.7)
	# cidade distante: blocos residenciais brutalistas (silhuetas na névoa)
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var city := []
	for i in 14:
		var a := rng.randf_range(-0.6, 0.9)
		var dist := rng.randf_range(180, 300)
		var p := Vector3(cos(a) * dist + 60.0, -1.0, -sin(a) * dist - 120.0)
		var h := rng.randf_range(18, 48)
		var s := Vector3(rng.randf_range(14, 30), h, rng.randf_range(10, 18))
		city.append([MeshKit.bevel_box(s, 0.3, 1), Transform3D(Basis(Vector3.UP, rng.randf() * PI), p + Vector3(0, h * 0.5, 0))])
	var cm := MeshInstance3D.new(); cm.name = "CidadeDistante"
	cm.mesh = MeshKit.combine(city); cm.material_override = M["conc_dark"]; cm.layers = 3
	add_child(cm)
	_far_nodes.append(cm)

func _trocador(pos: Vector3, sc: float) -> void:
	var dark := Mats.flat(Color(0.13, 0.14, 0.15), 0.55, 0.6)
	var body := MeshKit.lathe(PackedVector2Array([Vector2(34, 0), Vector2(28, 25), Vector2(19, 75), Vector2(15, 120), Vector2(21, 128), Vector2(12, 142), Vector2(5, 165), Vector2(2, 180)]), 24)
	var x := Transform3D(Basis().scaled(Vector3.ONE * sc), pos)
	var t := MeshInstance3D.new(); t.mesh = body; t.material_override = dark; t.transform = x; t.layers = 3
	add_child(t); _far_nodes.append(t)
	var ribs := []
	for i in 10:
		var a := TAU * i / 10.0
		ribs.append([MeshKit.bevel_box(Vector3(2.5, 135, 3.5), 0.4, 1), Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.1), Vector3(cos(a) * 22.0, 62, sin(a) * 22.0))])
	var r := MeshInstance3D.new(); r.mesh = MeshKit.combine(ribs); r.material_override = dark; r.transform = x; r.layers = 3
	add_child(r); _far_nodes.append(r)
	for i in 6:
		var a := TAU * i / 6.0
		var bm := MeshInstance3D.new(); bm.mesh = MeshKit.bevel_box(Vector3(1.6, 1.6, 1.6), 0.3, 1)
		bm.material_override = Mats.emissive(Color(1.0, 0.25, 0.1), 5.0)
		bm.position = pos + Vector3(cos(a) * 17.5, 122, sin(a) * 17.5) * sc
		add_child(bm); _far_nodes.append(bm)
	# coluna de exaustão (partículas lentas, leves)
	var smoke := CPUParticles3D.new()
	smoke.amount = int(24 * float(Settings.get_v("graphics", "particles", 1.0)))
	smoke.lifetime = 14.0
	smoke.position = pos + Vector3(0, 180 * sc, 0)
	smoke.direction = Vector3(0.3, 1, 0)
	smoke.initial_velocity_min = 3.0; smoke.initial_velocity_max = 5.0
	smoke.gravity = Vector3(1.2, 0.2, 0)
	smoke.scale_amount_min = 14.0 * sc; smoke.scale_amount_max = 26.0 * sc
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.3, 0.32, 0.32, 0.35)
	sm.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/textures/fx_smoke.png"):
		sm.albedo_texture = load("res://assets/textures/fx_smoke.png")
	q.material = sm
	smoke.mesh = q
	add_child(smoke); _far_nodes.append(smoke)

# =====================================================================
# A) VAGÃO
# =====================================================================
func _build_train() -> void:
	var wall: Material = M["paint"]
	var sec := "train"
	box(sec, Vector3(0, -0.15, 0), Vector3(3.4, 0.3, 16.4), M["rubber"])
	box(sec, Vector3(0, 2.55, 0), Vector3(3.4, 0.3, 16.4), M["steel"])
	box(sec, Vector3(0, 1.2, -8.2), Vector3(3.4, 2.5, 0.2), wall)
	box(sec, Vector3(0, 1.2, 8.2), Vector3(3.4, 2.5, 0.2), wall)
	for side: float in [-1.0, 1.0]:
		var x := 1.62 * side
		if side > 0:
			box(sec, Vector3(x, 0.475, -4.4), Vector3(0.12, 0.95, 7.2), wall)
			box(sec, Vector3(x, 0.475, 4.4), Vector3(0.12, 0.95, 7.2), wall)
		else:
			box(sec, Vector3(x, 0.475, 0), Vector3(0.12, 0.95, 16.0), wall)
		box(sec, Vector3(x, 2.15, 0), Vector3(0.12, 0.6, 16.0), wall)
		for z: float in [-8.0, -5.5, -3.0, -0.9, 0.9, 3.0, 5.5, 8.0]:
			box(sec, Vector3(x, 1.4, z), Vector3(0.14, 0.9, 0.5), wall)
		# vidros
		for zr: Vector2 in [Vector2(-7.75, -5.75), Vector2(-5.25, -3.25), Vector2(-2.75, -1.15), Vector2(1.15, 2.75), Vector2(3.25, 5.25), Vector2(5.75, 7.75)]:
			box(sec, Vector3(x, 1.4, (zr.x + zr.y) * 0.5), Vector3(0.03, 0.9, zr.y - zr.x), M["glass"])
		if side < 0:
			box(sec, Vector3(x, 1.4, 0), Vector3(0.03, 0.9, 1.3), M["glass"])
		# bancos longitudinais
		for zr: Vector2 in [Vector2(-7.6, -1.3), Vector2(1.3, 7.6)]:
			var len := zr.y - zr.x
			var cz := (zr.x + zr.y) * 0.5
			box(sec, Vector3(1.3 * side, 0.45, cz), Vector3(0.5, 0.08, len), M["wood"], Vector3.ZERO, true, 0.02)
			box(sec, Vector3(1.5 * side, 0.75, cz), Vector3(0.08, 0.55, len), M["wood"], Vector3(0, 0, -0.12 * side), false, 0.02)
			box(sec, Vector3(1.3 * side, 0.22, cz), Vector3(0.4, 0.44, len - 0.2), M["steel"])
		# barras de apoio
		for z: float in [-5.0, 5.0]:
			mesh_at(sec, MeshKit.cylinder(0.025, 2.4, 8), Transform3D(Basis(), Vector3(0.55 * side, 1.2, z)), M["steel"])
		mesh_at(sec, MeshKit.cylinder(0.02, 15.8, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.75 * side, 2.1, 0)), M["steel"])
	# portas deslizantes (lado leste)
	for s: float in [-1.0, 1.0]:
		var d := AnimatableBody3D.new()
		d.sync_to_physics = false
		d.set_meta("surface", "metal")
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.08, 1.85, 0.8); cs.shape = bs
		d.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.box_sheet(Vector3(0.08, 1.85, 0.8))
		mi.material_override = Mats.sheet("door_train")
		d.add_child(mi)
		add_child(d)
		d.position = Vector3(1.6, 0.925, 0.4 * s)
		d.set_meta("closed_z", 0.4 * s)
		d.set_meta("open_z", 1.15 * s)
		_train_doors.append(d)
	for z: float in [-5.0, 0.0, 5.0]:
		tube_lamp(sec, Vector3(0, 2.38, z), 0.0, Color(0.95, 0.9, 0.75), 0.9, 7.0, z > 4.0)
	# máscara no banco
	if cp_i == 0:
		var mask := Interactables.pickup(self, Vector3(-1.25, 0.62, -2.2), "mask", 0)
		mask.on_pick = _after_mask
	# NPCs do vagão
	if cp_i <= 1:
		_bohdan = NpcAlly.make("bohdan", "citizen", 7)
		_bohdan.body.palette["mask"] = false
		add_child(_bohdan)
		_bohdan.global_position = Vector3(-1.2, 0.05, -3.2)
		_bohdan.rotation.y = PI * 0.5
		if cp_i == 0:
			_bohdan.set_mode(NpcAlly.Mode.SIT)
			_bohdan.use_hint = "hud.talk"
			_bohdan.on_use = _talk_bohdan
		_passenger = NpcAlly.make("passenger", "citizen", 21)
		add_child(_passenger)
		_passenger.global_position = Vector3(1.2, 0.05, 5.5)
		_passenger.rotation.y = -PI * 0.5
		_passenger.set_mode(NpcAlly.Mode.SIT if cp_i == 0 else NpcAlly.Mode.IDLE)
		var p2 := NpcAlly.make("", "citizen", 33)
		add_child(p2)
		p2.global_position = Vector3(-1.2, 0.05, 6.4)
		p2.rotation.y = PI * 0.5
		p2.set_mode(NpcAlly.Mode.SIT)
		_citizens.append(p2)
	# cenário em movimento (postes da catenária, muros, galpões)
	_scroller = Node3D.new(); _scroller.name = "Scroller"
	add_child(_scroller)
	var pole_mesh := MeshKit.combine([[MeshKit.bevel_box(Vector3(0.3, 7.5, 0.3), 0.03, 1), Transform3D(Basis(), Vector3(0, 3.75, 0))],
		[MeshKit.bevel_box(Vector3(4.5, 0.2, 0.2), 0.03, 1), Transform3D(Basis(), Vector3(2.1, 7.0, 0))]])
	for i in 14:
		for s: float in [-1.0, 1.0]:
			var p := MeshInstance3D.new()
			p.mesh = pole_mesh
			p.material_override = M["steel"]
			p.position = Vector3(5.5 * s, -1.0, -100.0 + i * 15.0)
			p.rotation.y = 0.0 if s < 0 else PI
			_scroller.add_child(p)
			_scroll_items.append(p)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in 10:
		var w := MeshInstance3D.new()
		var h := rng.randf_range(2.5, 9.0)
		w.mesh = MeshKit.bevel_box(Vector3(rng.randf_range(4, 9), h, rng.randf_range(6, 16)), 0.1, 1)
		w.material_override = M["conc_dark"] if i % 2 == 0 else M["brick"]
		w.position = Vector3((14.0 + rng.randf_range(0, 20)) * (1 if i % 2 == 0 else -1), -1.0 + h * 0.5, -100.0 + i * 21.0)
		_scroller.add_child(w)
		_scroll_items.append(w)

func _talk_bohdan() -> void:
	say("train_bohdan", D["train_bohdan"])
	say("train_passenger", D["train_passenger"])

func _after_mask() -> void:
	set_flag("mask")
	# Interrompe a conversa opcional com o Bohdan: a máscara é o gatilho da chegada.
	say("train_mask", D["train_mask"], true)
	# A frenagem começa logo após a primeira fala; o resto do diálogo continua na plataforma.
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree(): return
	_brake()

func _start_ride() -> void:
	_riding = true
	ride_speed = 16.0
	set_sector_visible("station", false)
	set_sector_visible("yard", false)
	_far_begin()
	AudioBus.play_ambience("res://assets/audio/ambience/train_interior.wav", "res://assets/audio/ambience/wind_city.wav", -6.0)
	AudioBus.set_room(0.25, 0.15)
	Game.set_objective("obj.ch1.ride")
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	if not flag("mask"):
		say("train_pa", D["train_pa"])

func _far_begin() -> void:
	for n in _far_nodes:
		if is_instance_valid(n) and not n.has_meta("base_z"):
			n.set_meta("base_z", n.position.z)
	for mi in _sector_nodes.get("outside", []):
		if not mi.has_meta("base_z"):
			mi.set_meta("base_z", mi.position.z)
			mi.set_meta("cz", (mi.get_aabb().get_center()).z)
	_far_off = FAR_START
	_far_apply()

func _far_apply() -> void:
	for n in _far_nodes:
		if is_instance_valid(n) and n.has_meta("base_z"):
			n.position.z = float(n.get_meta("base_z")) + _far_off
	# ladrilhos de terreno: rolam com período de 400 m (relevo é periódico em Z)
	for mi in _sector_nodes.get("outside", []):
		if mi.has_meta("base_z"):
			var cz: float = mi.get_meta("cz")
			var nz := fposmod(cz + _far_off + 250.0, TERRAIN_PERIOD) - 250.0
			mi.position.z = float(mi.get_meta("base_z")) + nz - cz

func _brake() -> void:
	var tw := create_tween()
	tw.tween_property(self, "ride_speed", 5.0, 3.0).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree(): return
	# túnel de entrada: escurece, troca o cenário pela estação
	var fade := ColorRect.new(); fade.color = Color(0, 0, 0, 0)
	UIKit.full_rect(fade)
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl); cl.add_child(fade)
	var t2 := create_tween()
	t2.tween_property(fade, "color:a", 1.0, 0.8)
	await t2.finished
	_arrive(false)
	var t3 := create_tween()
	t3.tween_property(fade, "color:a", 0.0, 1.2)
	t3.tween_callback(cl.queue_free)

func _arrive(instant: bool) -> void:
	_riding = false
	ride_speed = 0.0
	if is_instance_valid(_scroller):
		_scroller.queue_free()
	set_sector_visible("station", true)
	set_sector_visible("outside", true)
	set_sector_visible("yard", true)
	_far_off = 0.0
	_far_apply()
	AudioBus.play_3d("door_slam", Vector3(1.6, 1.0, 0), -6.0)
	for d in _train_doors:
		if instant:
			d.position.z = d.get_meta("open_z")
		else:
			var tw := create_tween()
			tw.tween_property(d, "position:z", float(d.get_meta("open_z")), 1.4).set_delay(1.2).set_trans(Tween.TRANS_SINE)
	if not instant:
		AudioBus.play_ambience("res://assets/audio/ambience/station_hall.wav", "", -12.0)
		AudioBus.set_room(0.85, 0.35)
		Game.set_objective("obj.ch1.platform")
		if is_instance_valid(_bohdan):
			_bohdan.set_mode(NpcAlly.Mode.IDLE)
			await get_tree().create_timer(2.0).timeout
			if not is_inside_tree(): return
			_bohdan.go_to(Vector3(5.0, 0, -1.0), 1.4, func(): _bohdan.go_to(Vector3(19.5, 0, 9.5), 1.4))
		if is_instance_valid(_passenger):
			_passenger.set_mode(NpcAlly.Mode.IDLE)
			_passenger.go_to(Vector3(5.5, 0, 3.0), 1.3, func(): _passenger.go_to(Vector3(22.0, 0, 6.0), 1.2))
		for c in _citizens:
			c.set_mode(NpcAlly.Mode.IDLE)
			c.go_to(Vector3(4.5, 0, 6.0), 1.2, func(): c.go_to(Vector3(26, 0, 12.0), 1.1))
	elif cp_i == 1 and is_instance_valid(_bohdan):
		_bohdan.global_position = Vector3(19.5, 0.05, 9.5)

func _process(delta: float) -> void:
	if _riding or ride_speed > 0.0:
		for it in _scroll_items:
			it.position.z += ride_speed * delta
			if it.position.z > 110.0:
				it.position.z -= 210.0
		# paralaxe do cenário distante (Air Exchange, cidade, planície)
		_far_off += ride_speed * delta
		if _far_off > 420.0:
			_far_off -= 840.0
		_far_apply()
		# balanço do vagão
		_sway_t += delta
		if is_instance_valid(player):
			player.shake(0.004 * ride_speed / 16.0)
	if _gate_opening and _gate_open < 1.0:
		_gate_open = minf(1.0, _gate_open + delta * 0.12)
		_gate_l.position.x = 18.5 - _gate_open * 3.2
		_gate_r.position.x = 21.5 + _gate_open * 3.2
		if _gate_open >= 1.0:
			_on_gate_open()
	if _alarm_on and is_instance_valid(_alarm_light):
		_alarm_light.light_energy = 2.5 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))

# =====================================================================
# B) ESTAÇÃO CENTRAL
# =====================================================================
func _build_station() -> void:
	var sec := "station"
	# plataforma
	box(sec, Vector3(4.65, -0.25, 0), Vector3(6.1, 0.5, 28.4), M["conc"])
	box(sec, Vector3(1.85, 0.005, 0), Vector3(0.3, 0.02, 28.0), M["yellow"], Vector3.ZERO, false)
	box(sec, Vector3(4.65, 4.65, 0), Vector3(6.3, 0.3, 28.4), M["conc_dark"])
	box(sec, Vector3(4.65, 2.2, -14.35), Vector3(6.3, 4.6, 0.3), M["tiles"])
	box(sec, Vector3(4.65, 2.2, 14.35), Vector3(6.3, 4.6, 0.3), M["tiles"])
	for z: float in [-10.0, -3.5, 3.5, 10.0]:
		mesh_at(sec, MeshKit.cylinder(0.32, 4.5, 12, 0.05), Transform3D(Basis(), Vector3(5.8, 2.25, z)), M["tiles"], Vector3(0.64, 4.5, 0.64))
		tube_lamp(sec, Vector3(4.2, 4.45, z), PI * 0.5, Color(0.8, 0.92, 0.88), 0.9, 7.0, z < -9.0)
	# trincheira dos trilhos e vagões vizinhos (fecham o mundo a oeste)
	box(sec, Vector3(-1.0, -1.25, 0), Vector3(5.5, 0.5, 60), M["asphalt"])
	box(sec, Vector3(-4.0, 2.0, 0), Vector3(0.4, 7.0, 60), M["conc_dark"])
	for z: float in [-16.6, 16.6]:
		box(sec, Vector3(0, 1.2, z), Vector3(3.4, 2.8, 16.4), M["paint"], Vector3.ZERO, true, 0.08)
	box(sec, Vector3(0, -0.6, 0), Vector3(3.2, 0.8, 16.0), M["steel"])
	# salão (abóbada brutalista)
	var hall_c := Vector3(22, 0, 0)
	room(sec, hall_c, Vector3(28, 7, 32), M["conc"], M["tiles"], null,
		[["w", -7.0, 3.2, 3.2], ["w", 7.0, 3.2, 3.2], ["n", -10.0, 1.2, 2.2], ["n", 0.0, 6.0, 5.0]])
	var vault := MeshKit.vault(28.6, 6.0, 32.6, 0.4, 16)
	mesh_at(sec, vault, Transform3D(Basis(), Vector3(22, 7.0, 0)), M["conc_dark"])
	for z: float in [-16.3, 16.3]:
		box(sec, Vector3(22, 10.0, z), Vector3(28.6, 6.0, 0.3), M["conc"], Vector3.ZERO, false)
	# nervuras da abóbada
	for z: float in [-12.0, -4.0, 4.0, 12.0]:
		var rib := MeshKit.vault(27.8, 5.8, 0.6, 0.5, 16)
		mesh_at(sec, rib, Transform3D(Basis(), Vector3(22, 7.0, z)), M["conc"])
		for x: float in [14.0, 30.0]:
			mesh_at(sec, MeshKit.bevel_box(Vector3(1.1, 7.0, 1.1), 0.08, 1), Transform3D(Basis(), Vector3(x, 3.5, z)), M["conc"], Vector3(1.1, 7.0, 1.1))
	# portão principal (fechado — leva ao Capítulo 2)
	box(sec, Vector3(22, 2.5, -16.05), Vector3(6.0, 5.0, 0.15), M["dominion"])
	poster(Vector3(22, 5.6, -15.8), 0.0, "res://assets/textures/sign_1.png", Vector2(2.4, 0.6), true)
	# porta de serviço (trancada até o alarme)
	_service_door = Interactables.door(self, Vector3(11.42, 0.0, -16.15), 0.0, Vector3(1.15, 2.15, 0.07), true, Mats.sheet("door_metal_red"))
	poster(Vector3(12, 2.55, -15.95), 0.0, "res://assets/textures/sign_3.png", Vector2(1.6, 0.4))
	# placas e cartazes
	poster(Vector3(8.05, 3.6, -7.0), PI * 0.5, "res://assets/textures/sign_0.png", Vector2(2.4, 0.6), true)
	poster(Vector3(8.05, 3.6, 7.0), PI * 0.5, "res://assets/textures/sign_0.png", Vector2(2.4, 0.6), true)
	for z: float in [-12.0, 0.0, 12.0]:
		poster(Vector3(8.05, 2.0, z), PI * 0.5, "res://assets/textures/poster_%d.png" % (int(z + 12) / 12 % 3))
	for x: float in [12.0, 32.0]:
		poster(Vector3(x, 2.0, 15.85), PI, "res://assets/textures/poster_%d.png" % (int(x) % 3))
	for z: float in [-10.0, 10.0]:
		poster(Vector3(35.85, 2.0, z), -PI * 0.5, "res://assets/textures/poster_1.png")
	poster(Vector3(5.0, 2.4, -14.18), 0.0, "res://assets/textures/poster_0.png")
	poster(Vector3(5.0, 2.4, 14.18), PI, "res://assets/textures/poster_2.png")
	# telão do Regente
	box(sec, Vector3(35.7, 4.6, 0), Vector3(0.3, 5.6, 9.6), M["dominion"])
	_screen_regent = poster(Vector3(35.52, 4.6, 0), -PI * 0.5, "res://assets/textures/screen_regent.png", Vector2(9.0, 5.0), true)
	light(Vector3(33.0, 4.6, 0), Color(0.55, 0.8, 0.85), 14.0, 1.4)
	# fila: grades
	for x: float in [20.6, 23.4]:
		box(sec, Vector3(x, 0.9, 2.0), Vector3(0.06, 0.06, 16.0), M["steel"], Vector3.ZERO, false)
		box(sec, Vector3(x, 0.5, 2.0), Vector3(0.08, 1.0, 16.0), Mats.flat(Color(0, 0, 0, 0)), Vector3.ZERO, true)
		for z in range(-6, 11, 2):
			mesh_at(sec, MeshKit.cylinder(0.03, 0.95, 6), Transform3D(Basis(), Vector3(x, 0.475, z)), M["steel"])
	# posto de inspeção: arco detector + mesa
	for x: float in [20.5, 23.5]:
		box(sec, Vector3(x, 1.2, -8.0), Vector3(0.3, 2.4, 0.5), M["dominion"], Vector3.ZERO, true, 0.04)
	box(sec, Vector3(22, 2.55, -8.0), Vector3(3.3, 0.3, 0.5), M["dominion"], Vector3.ZERO, true, 0.04)
	var strip := MeshInstance3D.new(); strip.mesh = MeshKit.bevel_box(Vector3(2.6, 0.05, 0.1), 0.01, 1)
	strip.material_override = Mats.emissive(Color(0.3, 0.9, 0.8), 3.0); strip.position = Vector3(22, 2.38, -8.0)
	add_child(strip)
	box(sec, Vector3(25.2, 0.5, -9.0), Vector3(1.6, 1.0, 0.8), M["steel"], Vector3.ZERO, true, 0.03)
	poster(Vector3(22, 3.1, -7.74), 0.0, "res://assets/textures/sign_2.png", Vector2(2.0, 0.5), true)
	_alarm_light = light(Vector3(22, 2.2, -8.6), Color(1.0, 0.2, 0.1), 12.0, 0.0)
	for z: float in [-10.0, -2.0, 6.0, 13.0]:
		for x: float in [16.0, 28.0]:
			tube_lamp(sec, Vector3(x, 6.9, z), 0.0, Color(0.85, 0.92, 0.9), 1.1, 10.0, x > 27.0 and z > 12.0)
	# bancos
	for z: float in [-12.0, 12.0]:
		for x: float in [11.0, 33.0]:
			box(sec, Vector3(x, 0.45, z), Vector3(0.6, 0.08, 3.0), M["wood"], Vector3.ZERO, true, 0.02)
			box(sec, Vector3(x, 0.22, z), Vector3(0.4, 0.44, 2.6), M["steel"])
	# props físicos na estação
	prop("suitcase", Vector3(12.5, 0.3, 9.0), 0.4)
	prop("suitcase", Vector3(30.0, 0.3, -3.0), 1.4)
	prop("bucket", Vector3(9.5, 0.3, -14.5))
	prop("bottle", Vector3(33.2, 0.6, 12.4))
	prop("cinder", Vector3(14.6, 0.2, -15.2))
	occluder(Vector3(7.85, 3.5, 0), Vector3(0.3, 7.0, 32.0))
	reflection_probe(Vector3(22, 5, 0), Vector3(28, 12, 32))
	acoustic_zone(Vector3(22, 3.5, 0), Vector3(27, 7, 31), 0.9, 0.38, "res://assets/audio/ambience/station_hall.wav", -12.0)
	acoustic_zone(Vector3(4.6, 2.0, 0), Vector3(5.6, 4, 27), 0.6, 0.25)
	# NPCs da estação
	if cp_i <= 1:
		for i in 4:
			var c := NpcAlly.make("", "citizen", 100 + i)
			add_child(c)
			c.global_position = Vector3(22.0 + randf_range(-0.2, 0.2), 0.05, 3.5 - i * 2.2)
			c.rotation.y = PI
			_citizens.append(c)
		var guards := [[Vector3(24.6, 0.05, -10.0), 0.3], [Vector3(19.2, 0.05, -10.5), -0.4], [Vector3(30.0, 0.05, 6.0), PI * 0.5]]
		for gi in guards.size():
			var g := enemy("st_guard_%d" % gi, "vigilante_baton", guards[gi][0], guards[gi][1])
			if g:
				g.passive = true
				_station_guards.append(g)
		Interactables.trigger(self, Vector3(4.6, 1.0, 0), Vector3(5.5, 2, 27), func():
			Game.reach_checkpoint("station"))
		Interactables.trigger(self, Vector3(22, 1.0, 9.0), Vector3(2.6, 2, 2.0), _queue_enter)
		Interactables.trigger(self, Vector3(22, 1.0, -6.6), Vector3(2.6, 2, 1.2), _inspection)
		checkpoints["station"] = [Vector3(5.0, 0.05, 0.0), -PI * 0.5]
	_service_door.opened.connect(func():
		if not flag("fled"):
			set_flag("fled"))

func _queue_enter() -> void:
	if is_instance_valid(_bohdan):
		say("station_queue", D["station_queue"])
	say("regente", D["regente"])

func _inspection() -> void:
	if flag("alarm"):
		return
	set_flag("alarm")
	player.input_enabled = true
	say("inspection", D["inspection"], true)
	await Dialogue.line_finished
	if not is_inside_tree(): return
	AudioBus.play_3d("button_press", Vector3(22, 2.3, -8), 0.0)
	await Dialogue.line_finished
	if not is_inside_tree(): return
	_alarm_on = true
	var alarm := AudioBus.play_3d("alarm", Vector3(22, 5, -8), 2.0, 0.0, 80.0)
	_service_door.set_locked(false)
	_service_door.apply_impulse(Vector3(0, 0, 8), Vector3(0.5, 0, 0))
	Game.set_objective("obj.ch1.flee")
	for g in _station_guards:
		if is_instance_valid(g):
			g.activate(player.global_position)
	for c in _citizens:
		if is_instance_valid(c):
			c._flee_from = player.global_position
			c.mode = NpcAlly.Mode.FLEE
	if is_instance_valid(_bohdan):
		_bohdan.go_to(Vector3(22, 0, -7.0), 4.0)
		# Bohdan agarra o guarda mais próximo: o guarda fica ocupado alguns segundos
		if _station_guards.size() > 0 and is_instance_valid(_station_guards[0]):
			_station_guards[0].target_override = _bohdan
			get_tree().create_timer(6.0).timeout.connect(func():
				if is_instance_valid(_station_guards[0]): _station_guards[0].target_override = null)
	Game.emit_noise(Vector3(22, 1, -8), 40.0, null)
	await get_tree().create_timer(10.0).timeout
	_alarm_on = false

# =====================================================================
# C) MANUTENÇÃO
# =====================================================================
func _build_maintenance() -> void:
	var sec := "maint"
	var wall: Material = M["paint"]
	var floor_m: Material = M["conc_dark"]
	# corredor A (z -16.3 .. -28)
	room(sec, Vector3(12, 0, -22.2), Vector3(3.0, 3.0, 11.8), wall, floor_m, M["conc_dark"], [["s", 0.0, 1.25, 2.2], ["n", 0.0, 2.0, 2.4]])
	_pipes(sec, Vector3(10.7, 2.6, -16.5), Vector3(10.7, 2.6, -28.0), 0.09)
	_pipes(sec, Vector3(13.3, 2.4, -16.5), Vector3(13.3, 2.4, -28.0), 0.06)
	tube_lamp(sec, Vector3(12, 2.95, -19.0), 0.0, Color(0.9, 0.85, 0.6), 0.8, 6.0, true)
	tube_lamp(sec, Vector3(12, 2.95, -25.0), 0.0, Color(0.9, 0.85, 0.6), 0.7, 6.0)
	checkpoint("maint", Vector3(12, 1, -20), Vector3(2.8, 2, 2), Vector3(12, 0.05, -19), 0.0)
	Interactables.trigger(self, Vector3(12, 1, -24), Vector3(2.8, 2, 2), func():
		AudioBus.set_room(0.35, 0.2)
		AudioBus.play_ambience("res://assets/audio/ambience/industrial_hum.wav", "", -10.0)
		say("maint_radio", D["maint_radio"])
		if not state["picked"].has("wrench"):
			Game.set_objective("obj.ch1.wrench"))
	# oficina B (x 7..17, z -28.3 .. -38.3)
	room(sec, Vector3(12, 0, -33.3), Vector3(10, 3.5, 10), wall, floor_m, M["conc_dark"], [["s", 0.0, 2.0, 2.4], ["n", 3.0, 1.6, 2.2]])
	box(sec, Vector3(9.0, 0.45, -37.4), Vector3(3.0, 0.9, 1.0), M["wood"], Vector3.ZERO, true, 0.03)
	box(sec, Vector3(7.6, 1.6, -34.0), Vector3(0.6, 3.2, 3.0), M["steel"], Vector3.ZERO, true, 0.03)
	for i in 3:
		box(sec, Vector3(7.6, 0.8 + i * 0.8, -34.0), Vector3(0.62, 0.05, 2.9), M["steel"], Vector3.ZERO, false)
	tube_lamp(sec, Vector3(12, 3.45, -33.3), PI * 0.5, Color(0.95, 0.85, 0.6), 1.0, 9.0)
	light(Vector3(9.0, 1.6, -37.0), Color(1.0, 0.7, 0.4), 4.0, 0.8)
	if cp_i <= CP_ORDER.find("maint"):
		var w := pickup("wrench", Vector3(9.0, 1.05, -37.4), "wrench")
		if w:
			var cb := w.on_pick
			w.on_pick = func():
				cb.call()
				Game.set_objective("obj.ch1.vent")
	for p in [["crate_small", Vector3(14.5, 0.3, -36.5)], ["bucket", Vector3(16.0, 0.3, -30.0)], ["cinder", Vector3(10.5, 0.2, -30.5)], ["bottle", Vector3(9.5, 1.0, -37.6)]]:
		prop(p[0], p[1])
	# tábuas bloqueando a passagem norte
	if cp_i <= CP_ORDER.find("maint") and not flag("boards"):
		_boards(Vector3(15.0, 0, -38.45))
	# corredor C e sala do duto D (x 11..19, z -44 .. -54)
	room(sec, Vector3(15, 0, -41.2), Vector3(1.6, 2.4, 5.2), wall, floor_m, M["conc_dark"], [["s", 0.0, 1.6, 2.2], ["n", 0.0, 1.6, 2.2]])
	room(sec, Vector3(15, 0, -49.0), Vector3(8, 4.5, 10), M["brick"], floor_m, M["conc_dark"], [["s", 0.0, 1.6, 2.2], ["n", 0.0, 1.4, 4.5]])
	# saliência de 1,75 m e boca do duto (só alcançável empilhando caixas)
	box(sec, Vector3(15, 0.875, -53.9), Vector3(1.4, 1.75, 2.3), M["conc_dark"])
	box(sec, Vector3(15, 3.7, -54.6), Vector3(1.4, 1.6, 0.9), M["brick"])
	box(sec, Vector3(15, 2.95, -54.2), Vector3(1.5, 0.08, 0.1), M["steel"], Vector3.ZERO, false)
	tube_lamp(sec, Vector3(15, 4.45, -49.0), 0.0, Color(0.9, 0.9, 0.75), 1.0, 9.0)
	light(Vector3(15, 2.6, -55.5), Color(0.6, 0.75, 0.8), 4.0, 0.6)
	checkpoint("vent", Vector3(15, 1, -46.5), Vector3(2.0, 2, 1.5), Vector3(15, 0.05, -46.5), 0.0)
	if cp_i <= CP_ORDER.find("vent"):
		prop("crate", Vector3(12.5, 0.5, -45.5), 0.3)
		prop("crate", Vector3(17.6, 0.5, -51.0), 1.1)
		prop("crate_small", Vector3(12.2, 0.4, -52.5))
		prop("pallet", Vector3(18.0, 0.2, -46.0))
	# duto (agachado): z -55 .. -62, piso em y = 1.75, altura 1.15
	var duct = M["steel"]
	box(sec, Vector3(15, 1.71, -58.6), Vector3(1.4, 0.08, 7.2), duct)
	box(sec, Vector3(15, 2.94, -58.6), Vector3(1.4, 0.08, 7.2), duct)
	box(sec, Vector3(14.26, 2.3, -58.6), Vector3(0.08, 1.3, 7.2), duct)
	box(sec, Vector3(15.74, 2.3, -58.6), Vector3(0.08, 1.3, 7.2), duct)
	box(sec, Vector3(15, 2.3, -62.25), Vector3(1.4, 1.3, 0.1), duct)
	light(Vector3(15, 2.6, -60.0), Color(0.5, 0.7, 0.75), 3.0, 0.35)
	Interactables.trigger(self, Vector3(15, 2.3, -56.0), Vector3(1.2, 1.0, 1.0), func():
		Game.set_objective("obj.ch1.yard"))
	acoustic_zone(Vector3(15, 2.3, -58.6), Vector3(1.3, 1.1, 7.0), 0.15, 0.45)

func _pipes(sec: String, a: Vector3, b: Vector3, r: float) -> void:
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([a, b]), r, 8), Transform3D(), M["steel"])

func _boards(pos: Vector3) -> void:
	var b := Boards.new()
	add_child(b)
	b.global_position = pos
	b.broken.connect(func():
		set_flag("boards")
		Game.set_objective("obj.ch1.vent"))

## Tábuas pregadas: só quebram com dano corpo a corpo (chave inglesa) ou explosão.
class Boards extends StaticBody3D:
	signal broken
	var hp := 45.0
	var _planks: Array[MeshInstance3D] = []
	func _ready() -> void:
		collision_layer = 1
		set_meta("surface", "wood")
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.7, 2.3, 0.25); cs.shape = bs
		cs.position.y = 1.15
		add_child(cs)
		var mat := Mats.prop("wood", 1.5, Color(0.7, 0.58, 0.45))
		for i in 5:
			var p := MeshInstance3D.new()
			p.mesh = MeshKit.bevel_box(Vector3(1.9, 0.2, 0.05), 0.01, 1)
			p.material_override = mat
			p.position = Vector3(0, 0.3 + i * 0.45, 0.0)
			p.rotation.z = randf_range(-0.18, 0.18)
			add_child(p)
			_planks.append(p)
	func get_hint() -> String:
		return Loc.t("hud.break")
	func interact(_by: Node) -> void:
		AudioBus.play_3d("impact_wood", global_position + Vector3.UP, -6.0)
	func take_damage(amount: float, pos: Vector3 = Vector3.ZERO, type := "bullet") -> void:
		if type == "bullet":
			Effects.impact(pos, Vector3.BACK, "wood", Vector3.FORWARD)
			return
		hp -= amount
		AudioBus.play_3d("impact_wood", pos, 0.0)
		if _planks.size() > 0:
			var p: MeshInstance3D = _planks.pop_back()
			p.queue_free()
		if hp <= 0.0:
			AudioBus.play_3d("wood_break", global_position + Vector3.UP, 2.0)
			Effects.burst(global_position + Vector3.UP, Vector3.BACK, Color(0.6, 0.5, 0.35), 18, false, 1.2)
			for pl in _planks:
				pl.queue_free()
			broken.emit()
			queue_free()

# =====================================================================
# D) CASA DE BOMBAS (x 8..22, z -63 .. -77)
# =====================================================================
func _build_pump_room() -> void:
	var sec := "maint"
	room(sec, Vector3(15, 0, -70), Vector3(14, 5.5, 14), M["conc"], M["grate"], M["conc_dark"], [["n", 0.0, 1.6, 2.3]])
	# abertura no teto onde o duto termina (o jogador cai do duto)
	box(sec, Vector3(15, 2.3, -62.9), Vector3(1.4, 1.3, 0.2), M["conc"], Vector3.ZERO, false)
	# tanques e bombas (cobertura)
	for p: Vector3 in [Vector3(11, 0, -67), Vector3(19, 0, -67), Vector3(11, 0, -73.5), Vector3(19.5, 0, -74)]:
		var tank := MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(1.1, 0.0), Vector2(1.2, 0.3), Vector2(1.2, 2.4), Vector2(0.9, 2.9), Vector2(0.3, 3.1), Vector2(0, 3.1)]), 16)
		mesh_at(sec, tank, Transform3D(Basis(), p), M["paint"], Vector3(2.2, 3.0, 2.2), Vector3(0, 1.5, 0))
		_pipes(sec, p + Vector3(0, 2.9, 0), p + Vector3(0, 5.4, 0), 0.12)
		cover(p + Vector3(0, 0, 1.6))
		cover(p + Vector3(0, 0, -1.6))
	box(sec, Vector3(15, 0.6, -70.0), Vector3(3.0, 1.2, 1.0), M["steel"], Vector3.ZERO, true, 0.05)
	cover(Vector3(15, 0, -69.0))
	tube_lamp(sec, Vector3(15, 5.4, -66), 0.0, Color(0.9, 0.85, 0.65), 1.0, 10.0)
	tube_lamp(sec, Vector3(15, 5.4, -74), 0.0, Color(0.9, 0.85, 0.65), 0.9, 10.0, true)
	checkpoint("pump", Vector3(15, 1, -65), Vector3(3, 2, 2), Vector3(15, 0.05, -66.0), 0.0)
	acoustic_zone(Vector3(15, 2.5, -70), Vector3(13.5, 5, 13.5), 0.55, 0.3, "res://assets/audio/ambience/industrial_hum.wav", -9.0)
	# esconderijo da Resistência: pistola, munição e kit médico
	box(sec, Vector3(8.6, 0.45, -76.0), Vector3(1.0, 0.9, 1.6), M["wood"], Vector3.ZERO, true, 0.03)
	poster(Vector3(8.02, 1.9, -76.0), PI * 0.5, "res://assets/textures/poster_2.png", Vector2(0.8, 1.1))
	light(Vector3(9.2, 1.5, -76.0), Color(1.0, 0.75, 0.45), 4.0, 0.9)
	if cp_i <= CP_ORDER.find("pump"):
		var pk := pickup("pistol", Vector3(8.6, 1.05, -75.6), "pistol")
		if pk:
			var cb := pk.on_pick
			pk.on_pick = func():
				cb.call()
				_pump_ambush()
		pickup("ammo_pump", Vector3(8.6, 0.98, -76.4), "ammo_9mm", 30)
		pickup("med_pump", Vector3(12.5, 0.12, -76.5), "medkit")
	prop("explosive", Vector3(20.5, 0.5, -64.5))
	prop("barrel", Vector3(9.0, 0.5, -64.5))
	prop("crate_small", Vector3(17.5, 0.3, -76.3))

func _pump_ambush() -> void:
	if flag("ambush"):
		return
	set_flag("ambush")
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return
	AudioBus.play_3d("door_slam", Vector3(15, 1, -77), 0.0)
	var e1 := enemy("pump_v1", "vigilante_pistol", Vector3(14.0, 0.05, -78.5), 0.0)
	var e2 := enemy("pump_v2", "vigilante_pistol", Vector3(16.0, 0.05, -79.5), 0.0)
	for e in [e1, e2]:
		if e:
			e.hear_alert(player.global_position)

# =====================================================================
# E) PÁTIO FERROVIÁRIO (x -20..60, z -77..-170)
# =====================================================================
func _build_yard() -> void:
	var sec := "yard"
	sector("yard", 0.0)
	# piso (ladrilhos de cascalho)
	for ix in range(-20, 60, 20):
		for iz in range(-170, -77, 20):
			var w := minf(20.0, 60.0 - ix)
			var d := minf(20.0, -77.0 - iz)
			box(sec, Vector3(ix + w * 0.5, -0.15, iz + d * 0.5), Vector3(w, 0.3, d), M["gravel"])
	# muros perimetrais (segmentados)
	for z in range(-170, -77, 15):
		box(sec, Vector3(-20.3, 2.5, z + 7.5), Vector3(0.6, 5, 15), M["conc_dark"])
		box(sec, Vector3(60.3, 2.5, z + 7.5), Vector3(0.6, 5, 15), M["conc_dark"])
	for x in range(-20, 60, 10):
		if x == 10:
			box(sec, Vector3(13.25, 2.5, -170.3), Vector3(6.5, 5, 0.6), M["conc_dark"])
			box(sec, Vector3(26.75, 2.5, -170.3), Vector3(6.5, 5, 0.6), M["conc_dark"])
			continue
		if x == 20:
			continue
		box(sec, Vector3(x + 5.0, 2.5, -170.3), Vector3(10, 5, 0.6), M["conc_dark"])
	# fachada sul (prédio da manutenção)
	box(sec, Vector3(0, 3.0, -77.3), Vector3(16, 6, 0.6), M["brick"])
	box(sec, Vector3(40, 3.0, -77.3), Vector3(40, 6, 0.6), M["brick"])
	box(sec, Vector3(15, 4.15, -77.3), Vector3(14, 3.7, 0.6), M["brick"])
	box(sec, Vector3(11.1, 1.15, -77.3), Vector3(6.2, 2.3, 0.6), M["brick"])
	box(sec, Vector3(18.9, 1.15, -77.3), Vector3(6.2, 2.3, 0.6), M["brick"])
	# trilhos
	for tx: float in [0.0, 8.0, 28.0, 40.0]:
		for s: float in [-0.72, 0.72]:
			for z in range(-168, -80, 22):
				mesh_at(sec, MeshKit.bevel_box(Vector3(0.1, 0.14, 22), 0.02, 1), Transform3D(Basis(), Vector3(tx + s, 0.07, z + 11)), M["steel"])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = MeshKit.bevel_box(Vector3(2.3, 0.12, 0.24), 0.02, 1)
		mm.instance_count = 70
		for i in 70:
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf_range(-0.05, 0.05)), Vector3(tx, 0.02, -82.0 - i * 1.25)))
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = M["wood"]; mmi.layers = 3
		mmi.visibility_range_end = 70.0
		add_child(mmi)
	# vagões (cobertura)
	var wagons := [[Vector3(0, 0, -100), M["paint_red"]], [Vector3(0, 0, -131), M["paint"]], [Vector3(8, 0, -116), M["paint"]],
		[Vector3(28, 0, -96), M["paint_red"]], [Vector3(40, 0, -122), M["paint"]], [Vector3(28, 0, -146), M["paint_red"]]]
	for wg in wagons:
		_wagon(sec, wg[0], wg[1])
	_secret_wagon(Vector3(40, 0, -152))
	# pilhas de dormentes e caixas
	for p: Vector3 in [Vector3(18, 0, -100), Vector3(-10, 0, -118), Vector3(20, 0, -135), Vector3(50, 0, -105), Vector3(-8, 0, -152)]:
		box(sec, p + Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 1.4), M["wood"], Vector3(0, randf() * 0.4, 0), true, 0.03)
		cover(p + Vector3(0, 0, 1.3))
		cover(p + Vector3(0, 0, -1.3))
	for p: Vector3 in [Vector3(16, 0.5, -103), Vector3(22, 0.5, -134), Vector3(-6, 0.5, -112), Vector3(46, 0.5, -134), Vector3(34, 0.5, -112)]:
		prop("crate", p, randf() * PI)
	for p: Vector3 in [Vector3(4.5, 0.5, -108), Vector3(31.5, 0.5, -104), Vector3(44.5, 0.5, -150), Vector3(24, 0.5, -152), Vector3(-3.5, 0.5, -140)]:
		prop("explosive", p)
	for p: Vector3 in [Vector3(12, 0.5, -90), Vector3(52, 0.5, -96), Vector3(-14, 0.5, -95)]:
		prop("barrel", p)
	# postes de sódio
	var lamps := [Vector3(4, 0, -88), Vector3(18, 0, -112), Vector3(34, 0, -88), Vector3(-12, 0, -130), Vector3(16, 0, -150), Vector3(48, 0, -128), Vector3(34, 0, -160), Vector3(4, 0, -162)]
	for i in lamps.size():
		sodium_lamp(sec, lamps[i], randf() * TAU, 7.0, 2.4, i < 2)
	# guarita de sinalização sobre pilares (x 48..52, z -138..-142)
	for p: Vector3 in [Vector3(48.2, 0, -138.2), Vector3(51.8, 0, -138.2), Vector3(48.2, 0, -141.8), Vector3(51.8, 0, -141.8)]:
		box(sec, p + Vector3(0, 1.45, 0), Vector3(0.3, 2.9, 0.3), M["steel"])
	box(sec, Vector3(50, 2.95, -140), Vector3(4.2, 0.2, 4.2), M["wood"])
	box(sec, Vector3(50, 5.65, -140), Vector3(4.6, 0.2, 4.6), M["steel"])
	box(sec, Vector3(50, 3.6, -142.0), Vector3(4.0, 1.1, 0.12), M["wood"])
	box(sec, Vector3(48.0, 3.6, -140), Vector3(0.12, 1.1, 4.0), M["wood"])
	box(sec, Vector3(52.0, 3.6, -140), Vector3(0.12, 1.1, 4.0), M["wood"])
	box(sec, Vector3(48.8, 3.6, -138.0), Vector3(1.6, 1.1, 0.12), M["wood"])
	box(sec, Vector3(51.2, 3.6, -138.0), Vector3(1.6, 1.1, 0.12), M["wood"])
	for c: Vector3 in [Vector3(48, 4.6, -142), Vector3(52, 4.6, -142), Vector3(48, 4.6, -138), Vector3(52, 4.6, -138)]:
		box(sec, c, Vector3(0.12, 2.0, 0.12), M["wood"])
	Interactables.ladder(self, Vector3(50, 0, -137.7), PI, 3.1)
	light(Vector3(50, 5.0, -140), Color(1.0, 0.7, 0.4), 6.0, 1.0)
	var lever := Interactables.lever(self, Vector3(50, 3.35, -141.75), 0.0)
	lever.activated.connect(_on_lever)
	if flag("lever"):
		lever.used = true
	checkpoint("gate", Vector3(50, 4.0, -140), Vector3(3.6, 1.6, 3.6), Vector3(50, 3.1, -139.5), PI)
	# portão (grade deslizante)
	_gate_l = _gate_panel(Vector3(18.5, 2.0, -170.3))
	_gate_r = _gate_panel(Vector3(21.5, 2.0, -170.3))
	box(sec, Vector3(20, 4.6, -170.3), Vector3(7.0, 0.8, 0.8), M["dominion"])
	poster(Vector3(20, 4.6, -169.88), 0.0, "res://assets/textures/sign_4.png", Vector2(2.4, 0.6))
	# além do portão: rua que leva à Praça do Terminal
	box(sec, Vector3(20, -0.15, -182), Vector3(14, 0.3, 24), M["asphalt"])
	box(sec, Vector3(12.7, 3, -182), Vector3(0.6, 6, 24), M["brick"])
	box(sec, Vector3(27.3, 3, -182), Vector3(0.6, 6, 24), M["brick"])
	box(sec, Vector3(20, 3, -194.3), Vector3(15, 6, 0.6), M["dominion"])
	sodium_lamp(sec, Vector3(14, 0, -178), PI * 0.5)
	# entrada do pátio
	checkpoint("yard", Vector3(15, 1, -79.5), Vector3(3, 2, 2), Vector3(15, 0.05, -80.0), 0.0)
	Interactables.trigger(self, Vector3(15, 1.5, -78.6), Vector3(3, 3, 1.2), func(): _set_outdoor(true), false)
	Interactables.trigger(self, Vector3(15, 1.5, -76.2), Vector3(3, 3, 1.2), func(): _set_outdoor(false), false)
	Interactables.trigger(self, Vector3(15, 1, -84), Vector3(6, 2, 2), _enter_yard)
	Interactables.trigger(self, Vector3(20, 1, -160), Vector3(16, 2, 6), _irina_call)
	Interactables.trigger(self, Vector3(20, 1, -176), Vector3(6, 3, 2), _exit_reached)
	# inimigos do pátio
	if cp_i <= CP_ORDER.find("yard"):
		enemy("yd_1", "vigilante_pistol", Vector3(6, 0.05, -95), 0.0, [Vector3(6, 0, -95), Vector3(20, 0, -110), Vector3(14, 0, -122)] as Array[Vector3])
		enemy("yd_2", "vigilante_pistol", Vector3(33, 0.05, -118), PI * 0.3)
		enemy("yd_3", "vigilante_baton", Vector3(-6, 0.05, -138), 0.0, [Vector3(-6, 0, -138), Vector3(14, 0, -150)] as Array[Vector3])
		enemy("yd_4", "vigilante_pistol", Vector3(22, 0.05, -128), PI)
	if cp_i <= CP_ORDER.find("gate"):
		enemy("yd_5", "soldier", Vector3(45, 0.05, -158), PI * 0.8, [Vector3(45, 0, -158), Vector3(52, 0, -120)] as Array[Vector3])
	# Irina (do outro lado do portão)
	_irina = NpcAlly.make("irina", "conscript", 77, "rifle")
	add_child(_irina)
	_irina.global_position = Vector3(20, 0.05, -176)
	_irina.body.palette["mask"] = false
	_irina.visible = cp_i >= CP_ORDER.find("yard")

func _wagon(sec: String, p: Vector3, mat: Material) -> void:
	box(sec, p + Vector3(0, 2.05, 0), Vector3(2.9, 3.1, 12.0), mat, Vector3.ZERO, true, 0.1)
	box(sec, p + Vector3(0, 3.7, 0), Vector3(3.0, 0.2, 12.2), M["steel"], Vector3.ZERO, false, 0.05)
	box(sec, p + Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 11.0), M["steel"])
	for z: float in [-4.5, 4.5]:
		for s: float in [-0.72, 0.72]:
			mesh_at(sec, MeshKit.cylinder(0.42, 0.12, 12), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p + Vector3(s, 0.42, z)), M["steel"])
	for s: float in [-1.0, 1.0]:
		box(sec, p + Vector3(1.47 * s, 1.8, 0), Vector3(0.05, 2.4, 2.4), M["steel"], Vector3.ZERO, false)
		cover(p + Vector3(2.2 * s, 0, 4.0))
		cover(p + Vector3(2.2 * s, 0, -4.0))

func _secret_wagon(p: Vector3) -> void:
	var sec := "yard"
	var mat: Material = M["paint"]
	box(sec, p + Vector3(0, 0.55, 0), Vector3(2.9, 0.3, 12.0), M["wood"])
	box(sec, p + Vector3(0, 3.7, 0), Vector3(3.0, 0.2, 12.2), M["steel"])
	box(sec, p + Vector3(-1.4, 2.15, 0), Vector3(0.1, 3.1, 12.0), mat)
	box(sec, p + Vector3(0, 2.15, -6.0), Vector3(2.9, 3.1, 0.1), mat)
	box(sec, p + Vector3(0, 2.15, 6.0), Vector3(2.9, 3.1, 0.1), mat)
	box(sec, p + Vector3(1.4, 2.15, -3.6), Vector3(0.1, 3.1, 4.8), mat)
	box(sec, p + Vector3(1.4, 2.15, 3.6), Vector3(0.1, 3.1, 4.8), mat)
	box(sec, p + Vector3(1.4, 3.2, 0), Vector3(0.1, 1.0, 2.4), mat)
	box(sec, p + Vector3(0, 0.2, 0), Vector3(2.2, 0.4, 11.0), M["steel"])
	box(sec, p + Vector3(2.0, 0.35, 0), Vector3(1.0, 0.7, 2.0), M["wood"], Vector3.ZERO, true, 0.03)
	light(p + Vector3(0, 2.6, 0), Color(1.0, 0.75, 0.45), 5.0, 0.5)
	if not flag("wagon_boards"):
		var b := Boards.new()
		add_child(b)
		b.global_position = p + Vector3(1.55, 0.7, 0)
		b.rotation.y = PI * 0.5
		b.scale = Vector3(1.25, 1.0, 1.0)
		b.broken.connect(func(): set_flag("wagon_boards"))
	pickup("smg_secret", p + Vector3(0, 1.1, -1.0), "smg")
	pickup("ammo_secret", p + Vector3(0, 0.82, 1.0), "ammo_9mm", 45)
	pickup("med_secret", p + Vector3(-0.8, 0.82, 2.5), "medkit")
	pickup("filter_secret", p + Vector3(-0.8, 0.82, -2.5), "filter")

func _gate_panel(pos: Vector3) -> AnimatableBody3D:
	var g := AnimatableBody3D.new()
	g.sync_to_physics = false
	g.set_meta("surface", "metal")
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(3.0, 4.0, 0.2); cs.shape = bs
	g.add_child(cs)
	var parts := []
	for i in 9:
		parts.append([MeshKit.cylinder(0.04, 4.0, 6), Transform3D(Basis(), Vector3(-1.4 + i * 0.35, 0, 0))])
	for y: float in [-1.7, 0.0, 1.7]:
		parts.append([MeshKit.bevel_box(Vector3(3.0, 0.12, 0.1), 0.02, 1), Transform3D(Basis(), Vector3(0, y, 0))])
	var mi := MeshInstance3D.new(); mi.mesh = MeshKit.combine(parts); mi.material_override = M["steel"]
	g.add_child(mi)
	add_child(g)
	g.position = pos
	return g

func _set_outdoor(on: bool) -> void:
	_sun.light_cull_mask = 3 if on else 2
	if on:
		AudioBus.set_room(0.1, 0.05)
		AudioBus.play_ambience("res://assets/audio/ambience/wind_city.wav", "res://assets/audio/ambience/rain.wav", -8.0)

func _enter_yard() -> void:
	Game.set_objective("obj.ch1.yard")
	say("yard_radio", D["yard_radio"])

func _irina_call() -> void:
	if flag("irina_called") or flag("lever"):
		return
	set_flag("irina_called")
	_irina.visible = true
	say("irina_gate", D["irina_gate"])
	Game.set_objective("obj.ch1.gate")

func _on_lever() -> void:
	if flag("lever"):
		return
	set_flag("lever")
	_irina.visible = true
	_gate_opening = true
	AudioBus.play_3d("gate_motor", Vector3(20, 2, -170), 4.0, 0.0, 90.0)
	AudioBus.play_3d("alarm", Vector3(20, 4, -170), 0.0, 0.0, 90.0)
	Game.set_objective("obj.ch1.exit")
	Game.emit_noise(Vector3(20, 1, -168), 60.0, null)
	# reforços chegam pelas laterais
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree(): return
	for spec in [["yd_r1", "vigilante_pistol", Vector3(57, 0.05, -100)], ["yd_r2", "soldier", Vector3(-17, 0.05, -125)], ["yd_r3", "vigilante_pistol", Vector3(55, 0.05, -165)]]:
		var e := enemy(spec[0], spec[1], spec[2])
		if e:
			e.hear_alert(Vector3(50, 0, -140))

func _on_gate_open() -> void:
	_gate_opening = false
	set_flag("gate_open")
	say("irina_open", D["irina_open"])
	_irina.go_to(Vector3(20, 0, -167), 2.0)

func _exit_reached() -> void:
	if flag("done"):
		return
	set_flag("done")
	player.input_enabled = false
	say("irina_exit", D["irina_exit"], true)
	await say_done("irina_exit")
	if not is_inside_tree(): return
	Game.complete_chapter()
