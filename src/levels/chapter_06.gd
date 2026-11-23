extends LevelBase
## Capítulo 6 — "Mar Seco" (Ato II).
## Travessia de buggy (o Besouro) pelo leito seco do mar: balizas piscando marcam a rota,
## A) o casco do petroleiro "Aurora" (passagem por dentro do rasgo no costado) · B) ossadas de
## baleia com ninhos de Rastejadores · C) posto avançado do Domínio com cancela e cabine
## D) tempestade de partículas: fora do Besouro ou de um abrigo o jogador sofre dano
## E) costa rochosa e o farol do Depósito → fim do capítulo.
## Inspiração: os conceitos "Wasteland / Dry Sea / Coast" dos roteiros 2001–2002 do HL2 beta
## (ver docs/01_PESQUISA_HL2_BETA.md). Navios, criaturas, falas e mapa são originais.

const CP_ORDER := ["start", "tanker", "bones", "outpost", "storm", "coast"]
const TANKER_Z := -240.0
const BONES_Z0 := -360.0
const OUTPOST_Z := -520.0
const STORM_Z0 := -600.0
const STORM_Z1 := -780.0
const LIGHT_Z := -880.0
var D := {}
var cp_i := 0
var M := {}
var _buggy: Vehicle
var _boom: AnimatableBody3D
var _boom_btn: Interactables.Switch
var _beacon_mat: StandardMaterial3D
var _beacon_t := 0.0
var _storm_on := false
var _storm_fx: CPUParticles3D
var _storm_snd: AudioStreamPlayer
var _shelters: Array[AABB] = []
var _storm_tick := 0.0
var _crawlers_spawned := false
var _lamp_pivot: Node3D
var _env_fog := 0.0

static func rx(z: float) -> float:
	return 18.0 * sin(z * 0.008)

func _h(x: float, z: float) -> float:
	var d := absf(x - rx(z))
	var dune := 2.4 * sin(x * 0.045 + z * 0.021) * cos(z * 0.027) + 1.3 * sin(x * 0.12 - z * 0.065) + 0.6 * sin(x * 0.31 + z * 0.17)
	dune += 2.6
	var f := smoothstep(8.0, 26.0, d)
	# planície do posto avançado e do cais rochoso
	if absf(z - OUTPOST_Z) < 30.0 and d < 60.0:
		f *= smoothstep(18.0, 30.0, absf(z - OUTPOST_Z))
	var h := dune * f
	# paredões do cânion (limite do mundo)
	h += pow(maxf(0.0, d - 50.0), 1.25) * 0.9
	# costa: o leito sobe para as rochas do farol
	if z < -820.0:
		h += (-820.0 - z) * 0.06 * smoothstep(6.0, 30.0, d) + maxf(0.0, -860.0 - z) * 0.05
	return h

func _mats() -> void:
	M = {
		"sand": Mats.get_mat("sand", 0.12, Color(0.86, 0.78, 0.64)),
		"earth": Mats.get_mat("cracked_earth", 0.12, Color(0.74, 0.66, 0.54)),
		"rust": Mats.get_mat("rusted_paint", 0.15, Color(0.62, 0.38, 0.3)),
		"rust_d": Mats.get_mat("rusted_paint", 0.15, Color(0.42, 0.3, 0.26)),
		"hull_b": Mats.get_mat("rusted_paint", 0.15, Color(0.3, 0.34, 0.38)),
		"steel": Mats.get_mat("steel", 0.4, Color(0.58, 0.58, 0.56)),
		"steel_dark": Mats.get_mat("steel", 0.4, Color(0.34, 0.34, 0.33)),
		"bone": Mats.get_mat("concrete", 0.4, Color(0.9, 0.86, 0.76)),
		"conc": Mats.get_mat("concrete", 0.35, Color(0.66, 0.66, 0.63)),
		"dominion": Mats.get_mat("dominion", 0.12),
		"grate": Mats.get_mat("grate", 0.6, Color(0.7, 0.7, 0.68)),
		"corr": Mats.get_mat("corrugated", 0.35, Color(0.6, 0.62, 0.6)),
		"rock": Mats.get_mat("concrete", 0.1, Color(0.5, 0.46, 0.42)),
		"white": Mats.get_mat("concrete", 0.3, Color(0.9, 0.9, 0.86)),
		"red": Mats.get_mat("rusted_paint", 0.5, Color(0.75, 0.32, 0.28)),
		"glass": Mats.glass(),
	}

func build() -> void:
	_mats()
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch6.json"))
	cp_i = maxi(0, CP_ORDER.find(Game.checkpoint))
	grid = {"dunes": 60.0, "props": 60.0}
	outdoor = {"dunes": true, "props": true, "far": true}
	sector("dunes", 420.0)
	sector("props", 300.0)
	sector("far", 900.0)
	setup_env(Color(0.62, 0.55, 0.46), Color(0.72, 0.66, 0.58), 0.85, Color(0.7, 0.6, 0.48), 0.006, 0.0, 0.45)
	env.tonemap_exposure = 1.05
	_env_fog = env.fog_density
	var s := sun(Vector3(-35, 210, 0), Color(1.0, 0.88, 0.7), 1.25, true)
	s.light_cull_mask = 2
	s.directional_shadow_max_distance = 70.0
	nav_aabb = AABB(Vector3(-70, -4, -560), Vector3(140, 30, 230))
	terrain("dunes", -110.0, -910.0, 220.0, 930.0, 8.0, _h, M["sand"], 60.0, 6.0)
	_build_beacons()
	_build_tanker()
	_build_bones()
	_build_outpost()
	_build_storm()
	_build_coast()
	checkpoints["start"] = [Vector3(-3.0, 0.1, -4.0), 0.0]

const BUGGY_SPAWN := {"start": Vector3(0.0, 0.8, -8.0), "tanker": Vector3(0.0, 0.8, -196.0), "bones": Vector3(0.0, 0.8, -336.0),
	"outpost": Vector3(0.0, 0.8, -476.0), "storm": Vector3(0.0, 0.8, -572.0), "coast": Vector3(0.0, 0.8, -790.0)}

func after_build() -> void:
	AudioBus.start_music()
	AudioBus.play_ambience("res://assets/audio/ambience/wind_city.wav", "", -10.0)
	AudioBus.set_room(0.2, 0.05)
	player.set_mask(false)
	ensure_loadout(["wrench", "pistol", "smg", "shotgun", "manipulator"])
	if flag("boom_open"):
		_boom.rotation.z = PI * 0.45
		_boom_btn.used = true
	_buggy = Vehicle.make("buggy")
	add_child(_buggy)
	var bp: Vector3 = BUGGY_SPAWN.get(Game.checkpoint, BUGGY_SPAWN["start"])
	bp.x = rx(bp.z) + 1.5
	_buggy.global_position = bp
	_buggy.rotation.y = 0.0
	_buggy.entered.connect(func(_b): pass)
	_buggy.exited.connect(_on_buggy_exited)
	match Game.checkpoint:
		"start":
			Game.set_objective("obj.ch6.beacons")
			say("start", D["start"])
		"tanker", "bones": Game.set_objective("obj.ch6.beacons")
		"outpost": Game.set_objective("obj.ch6.beacons" if flag("boom_open") else "obj.ch6.outpost")
		"storm": Game.set_objective("obj.ch6.storm")
		"coast": Game.set_objective("obj.ch6.lighthouse")
	if Game.checkpoint == "storm":
		_start_storm()

func _process(delta: float) -> void:
	# balizas piscando (um único material compartilhado: custo zero por baliza)
	_beacon_t += delta
	if is_instance_valid(_beacon_mat):
		_beacon_mat.emission_energy_multiplier = 3.0 if fmod(_beacon_t, 1.6) < 0.25 else 0.15
	if is_instance_valid(_lamp_pivot):
		_lamp_pivot.rotation.y += delta * 0.9
	if not is_instance_valid(player): return
	# tempestade: entra/sai pela posição do jogador
	var pz := player.global_position.z
	var inside := pz < STORM_Z0 and pz > STORM_Z1
	if inside and not _storm_on:
		_start_storm()
	elif not inside and _storm_on and pz <= STORM_Z1:
		_stop_storm()
	if _storm_on:
		if is_instance_valid(_storm_fx):
			_storm_fx.global_position = player.global_position + Vector3(30, 4, 0)
		_storm_tick -= delta
		if _storm_tick <= 0.0:
			_storm_tick = 0.5
			if not _sheltered():
				player.take_damage(3.0, player.global_position + Vector3(10, 1, 0), "storm")
				get_tree().call_group("hud", "notice", Loc.t("hud.storm"))

func _sheltered() -> bool:
	if player.vehicle != null: return true
	for a in _shelters:
		if a.has_point(player.global_position + Vector3.UP * 0.5): return true
	return false

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, _h(x, z), z)

# =====================================================================
# Balizas de rota
# =====================================================================
func _build_beacons() -> void:
	_beacon_mat = Mats.emissive(Color(1.0, 0.3, 0.15), 3.0).duplicate()
	var pole := MeshKit.combine([[MeshKit.cylinder(0.06, 3.2, 8), Transform3D(Basis(), Vector3(0, 1.6, 0))],
		[MeshKit.bevel_box(Vector3(0.5, 0.12, 0.5), 0.02, 1), Transform3D(Basis(), Vector3(0, 0.06, 0))],
		[MeshKit.bevel_box(Vector3(0.3, 0.5, 0.06), 0.01, 1), Transform3D(Basis(), Vector3(0, 2.4, 0.05))]])
	var lamp := MeshKit.cylinder(0.13, 0.22, 10)
	var z := -30.0
	var i := 0
	while z > -840.0:
		if absf(z - TANKER_Z) > 20.0 and absf(z - OUTPOST_Z) > 14.0:
			var side := 1.0 if i % 2 == 0 else -1.0
			var p := _ground(rx(z) + side * 9.0, z)
			mesh_at("props", pole, Transform3D(Basis(), p), M["rust"], Vector3(0.25, 3.2, 0.25), Vector3(0, 1.6, 0))
			mesh_at("props", lamp, Transform3D(Basis(), p + Vector3(0, 3.3, 0)), _beacon_mat)
			if i % 4 == 0:
				light(p + Vector3(0, 3.4, 0), Color(1.0, 0.4, 0.2), 9.0, 0.8)
		z -= 55.0
		i += 1
	# carcaças de barcos de pesca encalhados ao longo da rota
	var r := RandomNumberGenerator.new(); r.seed = 61
	for k in 9:
		var bz := -60.0 - k * 85.0 - r.randf_range(0, 30)
		var bx := rx(bz) + (1.0 if k % 2 == 0 else -1.0) * r.randf_range(16, 34)
		_boat_wreck(_ground(bx, bz), r.randf() * TAU, r.randf_range(0.2, 0.45) * (1.0 if k % 2 == 0 else -1.0))
	# placas e destroços do porto antigo
	for k in 6:
		var pz := -120.0 - k * 120.0
		var p := _ground(rx(pz) - 12.0, pz)
		box("props", p + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), M["rust_d"])
		box("props", p + Vector3(0, 1.9, 0), Vector3(1.4, 0.8, 0.05), M["red"], Vector3(0, 0.3, 0.06))
	pickup("c6_am1", _ground(rx(-90.0) + 6.0, -90.0) + Vector3(0, 0.3, 0), "ammo_9mm", 45)

func _boat_wreck(p: Vector3, yaw: float, roll: float) -> void:
	# casco de pesqueiro: perfil de lathe achatado, cabine, mastro
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll)
	var hull := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -4.5), Vector2(1.2, -3.6), Vector2(2.0, -1.5), Vector2(2.1, 1.5), Vector2(1.6, 3.6), Vector2(0.2, 4.6)]), 12, true, true)
	var parts := [[hull, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.0, 0.55)), Vector3(0, 0.6, 0))],
		[MeshKit.bevel_box(Vector3(2.2, 1.8, 2.4), 0.06), Transform3D(Basis(), Vector3(0, 2.2, 0.8))],
		[MeshKit.cylinder(0.1, 5.0, 8), Transform3D(Basis(), Vector3(0, 4.0, -1.5))]]
	mesh_at("props", MeshKit.combine(parts), Transform3D(b, p), M["hull_b"] if int(p.z) % 2 == 0 else M["rust"], Vector3(4.0, 2.4, 9.0), Vector3(0, 1.0, 0))

# =====================================================================
# A) Petroleiro "Aurora": rasgo no costado, a rota passa por dentro
# =====================================================================
func _build_tanker() -> void:
	var sec := "props"
	var cx := rx(TANKER_Z)
	var z0 := TANKER_Z + 9.0     # costado sul
	var z1 := TANKER_Z - 9.0     # costado norte
	var L := 120.0
	var H := 16.0
	var y0 := -2.0
	var gap := 9.0
	var gh := 6.0
	for zz: float in [z0, z1]:
		# costado com rasgo (abertura irregular) na rota
		box(sec, Vector3(cx - (L * 0.5 + gap * 0.5) * 0.5 - gap * 0.25, y0 + H * 0.5, zz), Vector3(L * 0.5 - gap * 0.5, H, 0.4), M["rust"])
		box(sec, Vector3(cx + (L * 0.5 + gap * 0.5) * 0.5 + gap * 0.25, y0 + H * 0.5, zz), Vector3(L * 0.5 - gap * 0.5, H, 0.4), M["rust"])
		box(sec, Vector3(cx, y0 + gh + 2.0 + (H - gh - 2.0) * 0.5, zz), Vector3(gap + 0.2, H - gh - 2.0, 0.4), M["rust"])
		# chapas retorcidas na borda do rasgo
		for k in 5:
			var sx := -1.0 if k % 2 == 0 else 1.0
			box(sec, Vector3(cx + sx * (gap * 0.5 - 0.3), y0 + 2.6 + k * 1.3, zz + (0.6 if zz == z0 else -0.6)), Vector3(1.4, 1.2, 0.08), M["rust_d"],
				Vector3(0.3 * sx, 0.6 * sx, 0.4), false)
		# faixa de casco inferior escura (linha d'água antiga)
		box(sec, Vector3(cx, y0 + 2.5, zz + (0.22 if zz == z0 else -0.22)), Vector3(L, 1.2, 0.04), M["hull_b"], Vector3.ZERO, false)
		box(sec, Vector3(cx - L * 0.25, y0 + 2.5, zz + (0.22 if zz == z0 else -0.22)), Vector3(L * 0.5 - gap * 0.5, 4.8, 0.04), M["hull_b"], Vector3.ZERO, false)
	# convés, proa, popa e anteparas internas
	box(sec, Vector3(cx, y0 + H + 0.2, TANKER_Z), Vector3(L, 0.4, 18.4), M["steel_dark"])
	box(sec, Vector3(cx - L * 0.5, y0 + H * 0.5, TANKER_Z), Vector3(0.4, H, 18.4), M["rust"])
	box(sec, Vector3(cx + L * 0.5 + 6.0, y0 + H * 0.5, TANKER_Z), Vector3(0.4, H, 13.0), M["rust"], Vector3(0, 0.7, 0))
	box(sec, Vector3(cx + L * 0.5 + 6.0, y0 + H * 0.5, TANKER_Z), Vector3(0.4, H, 13.0), M["rust"], Vector3(0, -0.7, 0))
	for k in 12:
		var fx := cx - L * 0.5 + 5.0 + k * 10.0
		if absf(fx - cx) < 7.0: continue
		box(sec, Vector3(fx, y0 + H * 0.5, TANKER_Z), Vector3(0.3, H, 17.6), M["rust_d"], Vector3.ZERO, true)
	# cavernas (nervuras) no corredor de passagem
	for k in 4:
		var fz := TANKER_Z - 6.0 + k * 4.0
		box(sec, Vector3(cx - 7.0, y0 + H * 0.5, fz), Vector3(0.4, H, 0.4), M["steel_dark"])
		box(sec, Vector3(cx + 7.0, y0 + H * 0.5, fz), Vector3(0.4, H, 0.4), M["steel_dark"])
		box(sec, Vector3(cx, y0 + H - 0.4, fz), Vector3(14.4, 0.4, 0.4), M["steel_dark"])
	# superestrutura na popa (ponte de comando)
	box(sec, Vector3(cx - L * 0.5 + 10.0, y0 + H + 5.0, TANKER_Z), Vector3(14.0, 10.0, 14.0), M["white"])
	box(sec, Vector3(cx - L * 0.5 + 10.0, y0 + H + 8.5, TANKER_Z + 7.05), Vector3(12.0, 1.4, 0.06), M["glass"], Vector3.ZERO, false)
	box(sec, Vector3(cx - L * 0.5 + 6.0, y0 + H + 14.0, TANKER_Z), Vector3(2.4, 8.0, 2.4), M["red"])
	# nome pintado no costado
	var lbl := Label3D.new()
	lbl.text = "AURORA"
	lbl.font_size = 400
	lbl.pixel_size = 0.01
	lbl.modulate = Color(0.85, 0.82, 0.74)
	lbl.outline_size = 0
	lbl.position = Vector3(cx + 30.0, y0 + H - 3.0, z0 + 0.25)
	lbl.shaded = true
	add_child(lbl)
	# interior escuro com luz filtrando pelos furos do convés
	light(Vector3(cx, y0 + H - 3.0, TANKER_Z), Color(1.0, 0.85, 0.6), 16.0, 1.3)
	spot(Vector3(cx + 3.0, y0 + H - 0.5, TANKER_Z + 2.0), Vector3(cx + 2.0, 0, TANKER_Z), Color(1.0, 0.9, 0.7), 20.0, 20.0, 2.0)
	box(sec, Vector3(cx - 3.0, 0.3, TANKER_Z - 4.0), Vector3(3.0, 0.6, 1.2), M["rust_d"], Vector3(0, 0.4, 0.2))
	prop("barrel", Vector3(cx + 4.0, 1.0, TANKER_Z + 3.0))
	prop("explosive", Vector3(cx - 5.0, 1.0, TANKER_Z - 2.0))
	pickup("c6_med1", Vector3(cx + 5.5, 0.6, TANKER_Z - 5.0), "medkit")
	pickup("c6_am2", Vector3(cx + 5.0, 0.6, TANKER_Z - 6.0), "ammo_12", 8)
	acoustic_zone(Vector3(cx, 6, TANKER_Z), Vector3(16, 14, 18), 0.85, 0.45)
	checkpoint("tanker", Vector3(rx(-190.0), 1.5, -190.0), Vector3(40, 6, 3), Vector3(rx(-190.0) - 3.0, 0.3, -190.0), 0.0)
	Interactables.trigger(self, Vector3(rx(-175.0), 1.5, -175.0), Vector3(60, 8, 4), func(): say("tanker", D["tanker"]))

# =====================================================================
# B) Ossadas de baleia + Rastejadores
# =====================================================================
func _build_bones() -> void:
	var sec := "props"
	var cz := BONES_Z0 - 22.0
	var cx := rx(cz)
	# coluna vertebral ao longo da rota e costelas em arco sobre ela
	var spine := PackedVector3Array()
	for k in 12:
		var z := BONES_Z0 + 4.0 - k * 4.0
		spine.append(Vector3(cx + 9.0 + sin(k * 0.5) * 0.8, 0.6 + sin(k * 0.3) * 0.4, z))
	mesh_at(sec, MeshKit.pipe(spine, 0.45, 8), Transform3D(), M["bone"])
	for k in 10:
		var z := BONES_Z0 - k * 4.4
		var pts := PackedVector3Array()
		for j in 9:
			var t := float(j) / 8.0
			var a := lerpf(0.0, PI, t)
			pts.append(Vector3(cx + 9.0 - (1.0 - cos(a)) * 9.5, sin(a) * (8.5 - absf(k - 4.5) * 0.5) + 0.3, z + sin(t * PI) * 0.8))
		mesh_at(sec, MeshKit.pipe(pts, 0.32 - k * 0.012, 7), Transform3D(), M["bone"])
		# colisão só nas bases (para não prender o buggy)
		box(sec, Vector3(cx + 9.0, 0.8, z), Vector3(0.7, 1.6, 0.7), M["bone"], Vector3.ZERO, true) if false else _bone_base(Vector3(cx + 9.0, 0, z))
		_bone_base(Vector3(cx - 10.0, 0, z))
	# crânio (lathe achatado) e mandíbula
	var skull := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -3.0), Vector2(1.8, -2.6), Vector2(2.6, -0.5), Vector2(2.2, 2.0), Vector2(1.0, 3.6), Vector2(0.0, 4.0)]), 12)
	mesh_at(sec, skull, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.0, 0.6)), Vector3(cx + 12.0, 1.4, BONES_Z0 - 50.0)), M["bone"], Vector3(4.5, 3.0, 7.0), Vector3(0, 0, 0))
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([Vector3(cx + 10.0, 0.3, BONES_Z0 - 46.0), Vector3(cx + 6.0, 0.5, BONES_Z0 - 52.0), Vector3(cx + 4.5, 0.3, BONES_Z0 - 58.0)]), 0.4, 7), Transform3D(), M["bone"])
	# ninhos
	for k in 4:
		var nz := BONES_Z0 - 8.0 - k * 10.0
		var p := _ground(rx(nz) + (12.0 if k % 2 == 0 else -13.0), nz)
		mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(2.4, 0), Vector2(1.6, 0.4), Vector2(0.7, 0.7), Vector2(0.0, 0.5)]), 12, false, true), Transform3D(Basis(), p), M["earth"])
	checkpoint("bones", Vector3(rx(-336.0), 1.5, -336.0), Vector3(40, 6, 3), Vector3(rx(-336.0) - 3.0, 0.3, -336.0), 0.0)
	Interactables.trigger(self, Vector3(rx(-344.0), 1.5, -344.0), Vector3(50, 8, 4), func():
		say("bones", D["bones"])
		_spawn_crawlers())
	pickup("c6_mol", _ground(cx - 6.0, BONES_Z0 - 30.0) + Vector3(0, 0.4, 0), "molotov")

func _bone_base(p: Vector3) -> void:
	var body := StaticBody3D.new()
	body.set_meta("surface", "wood")
	add_child(body)
	var cs := CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = 0.45; cyl.height = 2.2
	cs.shape = cyl; cs.position = p + Vector3(0, 1.1, 0)
	body.add_child(cs)

func _spawn_crawlers() -> void:
	if _crawlers_spawned: return
	_crawlers_spawned = true
	for k in 5:
		var nz := BONES_Z0 - 8.0 - (k % 4) * 10.0
		var p := _ground(rx(nz) + (12.0 if k % 2 == 0 else -13.0), nz)
		var c := Crawler.make(600 + k)
		add_child(c)
		c.global_position = p + Vector3(0, 0.6, 0)
		c.aware = true

# =====================================================================
# C) Posto avançado do Domínio
# =====================================================================
func _build_outpost() -> void:
	var sec := "props"
	var cx := rx(OUTPOST_Z)
	var z := OUTPOST_Z
	# muralha de barreiras e cerca até os paredões do cânion
	for sx: float in [-1.0, 1.0]:
		var x := cx + sx * 5.0
		while absf(x - cx) < 66.0:
			barrier(sec, Vector3(x + sx * 1.5, _h(x + sx * 1.5, z), z), PI * 0.5, 3.0)
			box(sec, Vector3(x + sx * 1.5, _h(x + sx * 1.5, z) + 2.2, z - 0.6), Vector3(3.0, 1.6, 0.06), M["grate"], Vector3.ZERO, true)
			x += sx * 3.0
	# pilares da cancela + cancela (AnimatableBody gira no pivô)
	for sx: float in [-1.0, 1.0]:
		box(sec, Vector3(cx + sx * 4.6, 1.5, z), Vector3(0.8, 3.0, 0.8), M["dominion"])
	_boom = AnimatableBody3D.new()
	_boom.sync_to_physics = false
	add_child(_boom)
	_boom.position = Vector3(cx - 4.2, 1.2, z)
	var bm := MeshInstance3D.new()
	bm.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(8.4, 0.3, 0.25), 0.04), Transform3D(Basis(), Vector3(4.2, 0, 0))],
		[MeshKit.bevel_box(Vector3(8.4, 0.9, 0.06), 0.01, 1), Transform3D(Basis(), Vector3(4.2, -0.6, 0))]])
	bm.material_override = M["red"]
	_boom.add_child(bm)
	var bc := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(8.4, 1.6, 0.4); bc.shape = bb; bc.position = Vector3(4.2, -0.3, 0)
	_boom.add_child(bc)
	# cabine de controle (lado leste)
	var cc := Vector3(cx + 12.0, 0, z + 6.0)
	room(sec, cc, Vector3(4.0, 2.8, 4.0), M["dominion"], M["conc"], M["steel_dark"], [["w", 0.0, 1.2, 2.2]], 0.2)
	box(sec, cc + Vector3(-2.1, 1.9, 1.2), Vector3(0.06, 0.8, 1.2), M["glass"], Vector3.ZERO, false)
	box(sec, cc + Vector3(1.4, 0.5, 0), Vector3(0.8, 1.0, 2.4), M["steel"])
	_boom_btn = Interactables.button(self, cc + Vector3(0.98, 1.2, 0), -PI * 0.5)
	_boom_btn.activated.connect(_open_boom)
	light(cc + Vector3(0, 2.5, 0), Color(0.8, 0.9, 1.0), 6.0, 1.0)
	poster(cc + Vector3(0, 1.8, -2.05), 0.0, "res://assets/textures/screen_regent.png", Vector2(1.4, 0.8), true)
	# torre de vigia e barracas
	var tw := Vector3(cx - 14.0, 0, z + 4.0)
	for dx: float in [-1.4, 1.4]:
		for dz: float in [-1.4, 1.4]:
			box(sec, tw + Vector3(dx, 3.0, dz), Vector3(0.2, 6.0, 0.2), M["steel_dark"])
	box(sec, tw + Vector3(0, 6.1, 0), Vector3(3.6, 0.2, 3.6), M["grate"])
	box(sec, tw + Vector3(0, 7.8, 0), Vector3(3.8, 0.15, 3.8), M["corr"])
	spot(tw + Vector3(0, 7.0, 1.8), tw + Vector3(4, 0, 18), Color(0.85, 0.92, 1.0), 40.0, 22.0, 3.0)
	for k in 3:
		var tp := Vector3(cx - 18.0 + k * 7.0, 0, z - 12.0)
		mesh_at(sec, MeshKit.vault(5.0, 2.6, 6.0, 0.1, 10), Transform3D(Basis(Vector3.UP, PI * 0.5), tp), Mats.get_mat("fabric", 0.4, Color(0.48, 0.5, 0.44)), Vector3(5.0, 2.6, 6.0), Vector3(0, 1.3, 0))
	box(sec, Vector3(cx + 8.0, 0.6, z - 6.0), Vector3(2.4, 1.2, 1.2), M["steel_dark"])
	for p: Vector3 in [Vector3(cx + 6, 0.5, z - 3), Vector3(cx - 7, 0.5, z - 4), Vector3(cx + 3, 0.5, z + 8)]:
		prop("crate", p)
	prop("explosive", Vector3(cx - 6.0, 0.5, z + 7.0))
	for p: Vector3 in [Vector3(cx + 6, 0, z - 3), Vector3(cx - 7, 0, z - 4), Vector3(cx + 8, 0, z - 6), Vector3(cx + 3, 0, z + 8), Vector3(cx - 6, 0, z + 9)]:
		cover(p)
	# guarnição
	enemy("o_s1", "soldier", Vector3(cx + 3.0, 0.1, z + 4.0), 0.0, [Vector3(cx + 3.0, 0.1, z + 4.0), Vector3(cx - 3.0, 0.1, z + 4.0)])
	enemy("o_s2", "soldier", Vector3(cx + 9.0, 0.1, z + 3.0), 0.0)
	enemy("o_s3", "soldier", Vector3(cx - 8.0, 0.1, z - 8.0), 0.0)
	enemy("o_c1", "conscript_hostile", Vector3(cx - 4.0, 0.1, z - 4.0), 0.0)
	enemy("o_c2", "conscript_hostile", Vector3(cx + 5.0, 0.1, z - 10.0), 0.0)
	enemy("o_t1", "soldier", tw + Vector3(0, 6.3, 0), 0.0)
	pickup("c6_ar1", Vector3(cx + 8.0, 1.35, z - 6.0), "ar1")
	pickup("c6_hop", cc + Vector3(1.4, 1.1, 0.8), "hopwire")
	pickup("c6_am3", Vector3(cx - 7.0, 0.3, z - 9.0), "ammo_762", 60)
	pickup("c6_med2", cc + Vector3(1.4, 1.1, -0.8), "medkit")
	checkpoint("outpost", Vector3(rx(-476.0), 1.5, -476.0), Vector3(50, 6, 3), Vector3(rx(-476.0) - 3.0, 0.3, -476.0), 0.0)
	Interactables.trigger(self, Vector3(rx(-488.0), 1.5, -488.0), Vector3(60, 8, 4), func():
		if not flag("boom_open"):
			say("outpost", D["outpost"])
			Game.set_objective("obj.ch6.outpost")
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is EnemyAI and e.alive: e.hear_alert(player.global_position))

func _open_boom() -> void:
	set_flag("boom_open")
	AudioBus.play_3d("gate_motor", _boom.global_position, 0.0, 0.0, 50.0)
	var tw := create_tween()
	tw.tween_property(_boom, "rotation:z", PI * 0.45, 3.0).set_trans(Tween.TRANS_SINE)
	say("outpost_open", D["outpost_open"])
	Game.set_objective("obj.ch6.beacons")

# =====================================================================
# D) Tempestade de partículas + abrigos
# =====================================================================
func _build_storm() -> void:
	var sec := "props"
	for zz: float in [-660.0, -725.0]:
		var p := _ground(rx(zz) + (9.0 if zz == -660.0 else -9.0), zz)
		p.y = minf(p.y, 0.4)
		# abrigo: casamata de concreto meio enterrada com abertura para a rota
		room(sec, p, Vector3(5.0, 2.4, 4.0), M["conc"], M["conc"], M["conc"], [["w" if zz == -660.0 else "e", 0.0, 1.6, 2.1]], 0.4)
		light(p + Vector3(0, 2.0, 0), Color(1.0, 0.8, 0.5), 5.0, 0.8)
		_shelters.append(AABB(p + Vector3(-2.5, 0, -2.0), Vector3(5.0, 2.4, 4.0)))
		pickup("c6_md%d" % int(-zz), p + Vector3(1.6, 0.2, 1.2), "medkit")
	checkpoint("storm", Vector3(rx(-572.0), 1.5, -572.0), Vector3(50, 6, 3), Vector3(rx(-572.0) - 3.0, 0.3, -572.0), 0.0)
	Interactables.trigger(self, Vector3(rx(-585.0), 1.5, -585.0), Vector3(60, 8, 4), func():
		say("storm", D["storm"], true)
		Game.set_objective("obj.ch6.storm"))

func _start_storm() -> void:
	if _storm_on: return
	_storm_on = true
	AudioBus.play_ambience("res://assets/audio/ambience/storm.wav", "", -4.0)
	var tw := create_tween()
	tw.tween_property(env, "fog_density", 0.05, 4.0)
	tw.parallel().tween_property(env, "fog_light_color", Color(0.62, 0.48, 0.32), 4.0)
	_storm_fx = CPUParticles3D.new()
	_storm_fx.amount = int(260.0 * float(Settings.get_v("graphics", "particles", 0.65)))
	_storm_fx.lifetime = 1.6
	_storm_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_storm_fx.emission_box_extents = Vector3(2, 8, 30)
	_storm_fx.direction = Vector3(-1, -0.05, 0)
	_storm_fx.spread = 6.0
	_storm_fx.gravity = Vector3.ZERO
	_storm_fx.initial_velocity_min = 30.0
	_storm_fx.initial_velocity_max = 46.0
	var qm := QuadMesh.new(); qm.size = Vector2(1.6, 0.05)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.85, 0.72, 0.52, 0.45)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = sm
	_storm_fx.mesh = qm
	add_child(_storm_fx)
	if Game.objective_key != "obj.ch6.storm": Game.set_objective("obj.ch6.storm")

func _stop_storm() -> void:
	_storm_on = false
	AudioBus.play_ambience("res://assets/audio/ambience/wind_city.wav", "", -10.0)
	var tw := create_tween()
	tw.tween_property(env, "fog_density", _env_fog, 5.0)
	tw.parallel().tween_property(env, "fog_light_color", Color(0.7, 0.6, 0.48), 5.0)
	if is_instance_valid(_storm_fx): _storm_fx.queue_free()
	Game.set_objective("obj.ch6.lighthouse")

func _on_buggy_exited(_by: Node) -> void:
	if _storm_on and not flag("storm_warned"):
		set_flag("storm_warned")
		say("storm_out", D["storm_out"], true)

# =====================================================================
# E) Costa rochosa e o farol
# =====================================================================
func _build_coast() -> void:
	var sec := "far"
	var r := RandomNumberGenerator.new(); r.seed = 900
	for k in 22:
		var z := r.randf_range(-840.0, -905.0)
		var x := rx(z) + r.randf_range(-60.0, 60.0)
		if absf(x - rx(z)) < 10.0: x += 16.0 * signf(x - rx(z) + 0.01)
		var s := r.randf_range(3.0, 9.0)
		box(sec, _ground(x, z) + Vector3(0, s * 0.3, 0), Vector3(s, s * 0.9, s * 1.2), M["rock"], Vector3(r.randf_range(-0.4, 0.4), r.randf() * TAU, r.randf_range(-0.4, 0.4)), true, 0.4)
	var lp := _ground(rx(LIGHT_Z) + 22.0, LIGHT_Z)
	box(sec, lp + Vector3(0, 1.0, 0), Vector3(12.0, 3.0, 12.0), M["rock"], Vector3(0, 0.4, 0), true, 0.5)
	var tower := MeshKit.lathe(PackedVector2Array([Vector2(3.0, 0), Vector2(2.6, 8), Vector2(2.2, 16), Vector2(2.0, 22), Vector2(2.6, 22.3), Vector2(2.6, 23.0), Vector2(0.0, 23.0)]), 16)
	mesh_at(sec, tower, Transform3D(Basis(), lp + Vector3(0, 2.5, 0)), M["white"], Vector3(5.0, 23.0, 5.0), Vector3(0, 11.5, 0))
	for k in 3:
		mesh_at(sec, MeshKit.cylinder(2.75 - k * 0.2, 1.4, 16), Transform3D(Basis(), lp + Vector3(0, 6.0 + k * 6.0, 0)), M["red"])
	mesh_at(sec, MeshKit.cylinder(1.5, 2.6, 12), Transform3D(Basis(), lp + Vector3(0, 26.8, 0)), M["glass"])
	mesh_at(sec, MeshKit.cylinder(0.6, 1.0, 10), Transform3D(Basis(), lp + Vector3(0, 26.6, 0)), Mats.emissive(Color(1.0, 0.95, 0.75), 4.0))
	mesh_at(sec, MeshKit.lathe(PackedVector2Array([Vector2(1.9, 0), Vector2(1.0, 1.2), Vector2(0.0, 1.6)]), 12, true, false), Transform3D(Basis(), lp + Vector3(0, 28.1, 0)), M["red"])
	_lamp_pivot = Node3D.new()
	add_child(_lamp_pivot)
	_lamp_pivot.global_position = lp + Vector3(0, 26.6, 0)
	var sl := SpotLight3D.new()
	sl.light_color = Color(1.0, 0.95, 0.8); sl.spot_range = 160.0; sl.spot_angle = 9.0; sl.light_energy = 6.0
	sl.rotation = Vector3(-0.08, 0, 0)
	_lamp_pivot.add_child(sl)
	light(lp + Vector3(0, 26.6, 0), Color(1.0, 0.9, 0.7), 14.0, 1.5)
	# o Depósito ao longe (silhueta de concreto e guindastes)
	box(sec, Vector3(rx(-940.0) - 40.0, 10.0, -960.0), Vector3(80.0, 26.0, 30.0), Mats.get_mat("concrete", 0.08, Color(0.34, 0.34, 0.36)), Vector3.ZERO, false)
	for k in 3:
		box(sec, Vector3(rx(-940.0) - 70.0 + k * 22.0, 26.0, -950.0), Vector3(1.2, 30.0, 1.2), M["steel_dark"], Vector3.ZERO, false)
	checkpoint("coast", Vector3(rx(-790.0), 1.5, -790.0), Vector3(60, 8, 3), Vector3(rx(-790.0) - 3.0, 0.3, -790.0), 0.0)
	Interactables.trigger(self, Vector3(rx(-858.0), 3.0, -858.0), Vector3(70, 14, 6), _arrive)

func _arrive() -> void:
	if flag("done"): return
	set_flag("done")
	if is_instance_valid(_buggy): _buggy.locked = true
	say("arrival", D["arrival"], true)
	await say_done("arrival")
	if not is_inside_tree(): return
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	player.input_enabled = false
	Game.complete_chapter()
