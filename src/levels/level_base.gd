class_name LevelBase
extends Node3D
## Base de níveis: construção modular em lote (geometria agrupada por setor e material = poucas
## draw calls), colisão agrupada por superfície, navegação gerada em tempo de execução,
## iluminação, ambiente, oclusores, checkpoints, spawns persistentes (inimigos mortos e itens
## coletados não reaparecem ao carregar) e zonas acústicas.

signal built

var nav: NavigationRegion3D
var env: Environment
var player: Player
var state := {"killed": [], "picked": [], "flags": {}}
var _batches := {}    # setor -> {material: [[mesh, xform]]}
var _bodies := {}     # "setor|superficie" -> StaticBody3D
var _sector_nodes := {}
var _sector_range := {}
var checkpoints := {}  # id -> [pos, yaw]
var nav_aabb := AABB()  # se definido, limita a área de geração da navegação (mapas abertos enormes)
var nav_cell := 0.2
var grid := {}         # setor -> tamanho da célula (divide malhas grandes p/ limite de 8 luzes por malha no Mobile)
var outdoor := {}      # setor -> true (recebe luz do sol: camada de render 2)

func _ready() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	add_child(nav)
	var ls: Dictionary = Game.pending_player_state.get("_level_state", {})
	if not ls.is_empty():
		state = ls.duplicate(true)
		for k in ["killed", "picked"]:
			if not state.has(k): state[k] = []
		if not state.has("flags"): state["flags"] = {}
	Dialogue.sequence_finished.connect(_on_seq_done)
	call_deferred("_do_build")

# ---------------- fila de diálogos ----------------
var _say_queue: Array = []

## Toca uma sequência; se outra estiver tocando, entra na fila (evita cortes entre roteiros).
func say(seq: String, lines: Array, interrupt := false) -> void:
	if interrupt:
		_say_queue.clear()
		Dialogue.stop()
	if Dialogue.is_busy():
		_say_queue.append([seq, lines])
		return
	Dialogue.play_sequence(seq, lines)

## Aguarda o fim de uma sequência específica (uso: await say_done("nome")).
func say_done(seq: String) -> void:
	while is_inside_tree():
		var n: String = await Dialogue.sequence_finished
		if n == seq:
			return

func _on_seq_done(_n: String) -> void:
	if _say_queue.size() > 0:
		var nx: Array = _say_queue.pop_front()
		Dialogue.play_sequence.call_deferred(nx[0], nx[1])

func _do_build() -> void:
	build()
	await get_tree().process_frame
	_finalize()
	_spawn_player()
	after_build()
	built.emit()

## Sobrescrito pelos capítulos.
func build() -> void:
	pass

func after_build() -> void:
	pass

func get_state() -> Dictionary:
	return state

func flag(k: String, default = false):
	return state["flags"].get(k, default)

func set_flag(k: String, v = true) -> void:
	state["flags"][k] = v

# ---------------- geometria ----------------
func sector(name: String, view_range := 0.0) -> void:
	_sector_range[name] = view_range

var grid_y := {}   # setor -> altura da célula vertical (prédios de vários andares)

func _cell(sec: String, p: Vector3) -> String:
	var key := sec
	if grid.has(sec):
		var cs: float = grid[sec]
		key = "%s~%d_%d" % [sec, int(floor(p.x / cs)), int(floor(p.z / cs))]
	if grid_y.has(sec):
		key += "^%d" % int(floor(p.y / float(grid_y[sec])))
	return key

func _add(sec: String, mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	sec = _cell(sec, xf.origin)
	if not _batches.has(sec):
		_batches[sec] = {}
	if not _batches[sec].has(mat):
		_batches[sec][mat] = []
	_batches[sec][mat].append([mesh, xf])

func _body(sec: String, surface: String) -> StaticBody3D:
	var key := sec + "|" + surface
	if not _bodies.has(key):
		var b := StaticBody3D.new()
		b.name = "Static_" + sec + "_" + surface
		b.collision_layer = 1
		b.collision_mask = 0
		b.set_meta("surface", surface)
		nav.add_child(b)
		_bodies[key] = b
	return _bodies[key]

func box(sec: String, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO, collide := true, bevel := 0.0) -> void:
	var xf := Transform3D(Basis.from_euler(rot), pos)
	var mesh: Mesh
	if bevel > 0.0:
		mesh = MeshKit.bevel_box(size, bevel, 1)
	else:
		mesh = MeshKit.box_uv(size)
	_add(sec, mesh, xf, mat)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = size
		cs.shape = bs
		cs.transform = xf
		_body(sec, mat.get_meta("surface", "concrete")).add_child(cs)

func mesh_at(sec: String, mesh: Mesh, xf: Transform3D, mat: Material, collide_size := Vector3.ZERO, collide_offset := Vector3.ZERO) -> void:
	_add(sec, mesh, xf, mat)
	if collide_size != Vector3.ZERO:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = collide_size
		cs.shape = bs
		cs.transform = xf * Transform3D(Basis(), collide_offset)
		_body(sec, mat.get_meta("surface", "concrete")).add_child(cs)

func trimesh_at(sec: String, mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	_add(sec, mesh, xf, mat)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	cs.transform = xf
	_body(sec, mat.get_meta("surface", "concrete")).add_child(cs)

## Terreno por campo de altura (dunas, leito de mar seco): malha em blocos de `chunk` metros,
## UV em metros (textura repete a cada `uv_m`), colisão trimesh por bloco. hfn(x, z) -> altura.
func terrain(sec: String, x0: float, z0: float, size_x: float, size_z: float, step: float, hfn: Callable, mat: Material, chunk := 60.0, uv_m := 6.0) -> void:
	var cx := int(ceil(size_x / chunk))
	var cz := int(ceil(size_z / chunk))
	for ci in cx:
		for cj in cz:
			var ax := x0 + ci * chunk
			var az := z0 + cj * chunk
			var bx := minf(ax + chunk, x0 + size_x)
			var bz := minf(az + chunk, z0 + size_z)
			var nx := maxi(1, int(round((bx - ax) / step)))
			var nz := maxi(1, int(round((bz - az) / step)))
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var c := Vector3((ax + bx) * 0.5, 0, (az + bz) * 0.5)
			for i in nx + 1:
				for j in nz + 1:
					var x := lerpf(ax, bx, float(i) / nx)
					var z := lerpf(az, bz, float(j) / nz)
					var h: float = hfn.call(x, z)
					# normal por diferenças finitas (contínua entre blocos)
					var e := step * 0.5
					var n := Vector3(float(hfn.call(x - e, z)) - float(hfn.call(x + e, z)), 2.0 * e, float(hfn.call(x, z - e)) - float(hfn.call(x, z + e))).normalized()
					st.set_normal(n)
					st.set_uv(Vector2(x, z) / uv_m)
					st.add_vertex(Vector3(x, h, z) - c)
			for i in nx:
				for j in nz:
					var a := i * (nz + 1) + j
					var b := (i + 1) * (nz + 1) + j
					# sentido horário visto de cima (face frontal no Godot)
					st.add_index(a); st.add_index(b); st.add_index(a + 1)
					st.add_index(b); st.add_index(b + 1); st.add_index(a + 1)
			st.generate_tangents()
			var m := st.commit()
			trimesh_at(sec, m, Transform3D(Basis(), c), mat)

## Sala retangular (piso, teto opcional, 4 paredes com aberturas): openings = [[lado, centro, largura, altura]]
## lado: "n" (-Z), "s" (+Z), "e" (+X), "w" (-X); centro relativo ao centro da parede.
func room(sec: String, center: Vector3, size: Vector3, wall: Material, floor_m: Material, ceil_m: Material = null, openings := [], t := 0.3) -> void:
	box(sec, center + Vector3(0, -t * 0.5, 0), Vector3(size.x + t * 2, t, size.z + t * 2), floor_m)
	if ceil_m:
		box(sec, center + Vector3(0, size.y + t * 0.5, 0), Vector3(size.x + t * 2, t, size.z + t * 2), ceil_m)
	for side in ["n", "s", "e", "w"]:
		var along_x = side in ["n", "s"]
		var length := size.x if along_x else size.z
		var wc := center + Vector3(0, size.y * 0.5, 0)
		match side:
			"n": wc.z -= size.z * 0.5 + t * 0.5
			"s": wc.z += size.z * 0.5 + t * 0.5
			"e": wc.x += size.x * 0.5 + t * 0.5
			"w": wc.x -= size.x * 0.5 + t * 0.5
		var ops := []
		for o in openings:
			if o[0] == side:
				ops.append(o)
		ops.sort_custom(func(a, b): return a[1] < b[1])
		var cursor := -length * 0.5
		var segs := []
		for o in ops:
			var a: float = o[1] - o[2] * 0.5
			var b: float = o[1] + o[2] * 0.5
			if a > cursor:
				segs.append([cursor, a, 0.0, size.y])
			# lintel acima da abertura
			if o[3] < size.y:
				segs.append([a, b, o[3], size.y])
			cursor = b
		if cursor < length * 0.5:
			segs.append([cursor, length * 0.5, 0.0, size.y])
		for sg in segs:
			var mid = (sg[0] + sg[1]) * 0.5
			var w: float = sg[1] - sg[0]
			var h: float = sg[3] - sg[2]
			if w < 0.01 or h < 0.01:
				continue
			var p := wc + (Vector3(mid, 0, 0) if along_x else Vector3(0, 0, mid))
			p.y = center.y + (sg[2] + sg[3]) * 0.5
			var s := Vector3(w, h, t) if along_x else Vector3(t, h, w)
			box(sec, p, s, wall)

func _finalize() -> void:
	for sec in _batches:
		var mi := MeshInstance3D.new()
		mi.name = "Geo_" + sec
		mi.mesh = MeshKit.combine_by_material(_batches[sec])
		var base_sec: String = sec.split("~")[0]
		mi.layers = 3 if outdoor.has(base_sec) else 1
		var vr: float = _sector_range.get(base_sec, 0.0)
		if vr > 0.0:
			mi.visibility_range_end = vr
			mi.visibility_range_end_margin = 4.0
		add_child(mi)
		if not _sector_nodes.has(base_sec):
			_sector_nodes[base_sec] = []
		_sector_nodes[base_sec].append(mi)
	_batches.clear()
	# Navegação: gerada a partir das colisões estáticas (camada 1).
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = nav_cell
	if nav_aabb.size != Vector3.ZERO:
		nm.filter_baking_aabb = nav_aabb
	nm.cell_height = 0.25
	nm.agent_radius = 0.4
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 40.0
	nm.region_min_size = 4.0
	nav.navigation_mesh = nm
	var t0 := Time.get_ticks_msec()
	nav.bake_navigation_mesh(false)
	print("[nav] malha de navegação gerada em %d ms, %d polígonos" % [Time.get_ticks_msec() - t0, nm.get_polygon_count()])
	NavigationServer3D.map_force_update(get_world_3d().navigation_map)

func set_sector_visible(sec: String, on: bool) -> void:
	for mi in _sector_nodes.get(sec, []):
		mi.visible = on
	for key in _bodies:
		if key.begins_with(sec + "|"):
			var b: StaticBody3D = _bodies[key]
			b.collision_layer = 1 if on else 0

# ---------------- ambiente e luz ----------------
func setup_env(bg: Color, ambient: Color, ambient_e: float, fog_c: Color, fog_d: float, fog_h := 0.0, glow := 0.6) -> Environment:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_e
	env.fog_enabled = fog_d > 0.0
	env.fog_light_color = fog_c
	env.fog_density = fog_d
	if fog_h != 0.0:
		env.fog_height = fog_h
		env.fog_height_density = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = Settings.get_v("graphics", "effects", true)
	env.glow_intensity = glow
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	# No renderizador de compatibilidade (GLES3, celulares antigos/WebGL) o glow do 4.3 estoura a imagem: desativado.
	if OS.get_environment("AZ_FORCE_COMPAT") != "" or RenderingServer.get_rendering_device() == null:
		env.glow_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.06
	var dbg := OS.get_environment("AZ_ENV")
	if dbg.contains("nofog"): env.fog_enabled = false
	if dbg.contains("noglow"): env.glow_enabled = false
	if dbg.contains("noadj"): env.adjustment_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	we.add_to_group("az_env")
	add_child(we)
	return env

func sun(rot_deg: Vector3, color: Color, energy: float, shadows := true) -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.light_cull_mask = 2
	s.rotation_degrees = rot_deg
	s.light_color = color
	s.light_energy = energy
	s.shadow_enabled = shadows and int(Settings.get_v("graphics", "shadows", 1)) > 0
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	s.directional_shadow_max_distance = 60.0
	add_child(s)
	return s

func light(pos: Vector3, color: Color, rng: float, energy: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = shadow and int(Settings.get_v("graphics", "shadows", 1)) >= 2
	l.distance_fade_enabled = true
	l.distance_fade_begin = float(Settings.get_v("graphics", "light_dist", 32.0))
	l.distance_fade_length = l.distance_fade_begin * 0.35
	l.add_to_group("az_lights")
	add_child(l)
	return l

func spot(pos: Vector3, target: Vector3, color: Color, rng: float, angle: float, energy: float, shadow := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.position = pos
	l.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	l.light_color = color
	l.spot_range = rng
	l.spot_angle = angle
	l.light_energy = energy
	l.shadow_enabled = shadow and int(Settings.get_v("graphics", "shadows", 1)) >= 1
	l.distance_fade_enabled = true
	l.distance_fade_begin = float(Settings.get_v("graphics", "light_dist", 32.0)) + 8.0
	l.distance_fade_length = l.distance_fade_begin * 0.35
	l.add_to_group("az_lights")
	return l

## Luminária tubular de teto (malha emissiva + luz).
func tube_lamp(sec: String, pos: Vector3, yaw := 0.0, color := Color(0.85, 0.95, 0.9), energy := 1.2, rng := 8.0, flicker := false) -> OmniLight3D:
	var b := Basis(Vector3.UP, yaw)
	mesh_at(sec, MeshKit.bevel_box(Vector3(0.22, 0.08, 1.3), 0.02, 1), Transform3D(b, pos + Vector3(0, 0.04, 0)), Mats.flat(Color(0.2, 0.21, 0.2), 0.5, 0.6))
	var tube := MeshInstance3D.new()
	tube.mesh = MeshKit.cylinder(0.035, 1.15, 8)
	tube.rotation = Vector3(PI * 0.5, yaw, 0)
	tube.position = pos - Vector3(0, 0.02, 0)
	tube.material_override = Mats.emissive(color, 2.5)
	add_child(tube)
	var l := light(pos - Vector3(0, 0.3, 0), color, rng, energy)
	if flicker:
		var f := Flicker.new(); f.light = l; f.mesh = tube; f.base = energy
		add_child(f)
	return l

## Poste/luminária de sódio.
func sodium_lamp(sec: String, pos: Vector3, yaw := 0.0, height := 7.0, energy := 2.2, shadow := false) -> void:
	var steel := Mats.get_mat("steel", 1.0, Color(0.4, 0.4, 0.38))
	mesh_at(sec, MeshKit.cylinder(0.1, height, 8), Transform3D(Basis(), pos + Vector3(0, height * 0.5, 0)), steel, Vector3(0.22, height, 0.22))
	var arm := Basis(Vector3.UP, yaw)
	mesh_at(sec, MeshKit.bevel_box(Vector3(0.08, 0.08, 1.2), 0.02, 1), Transform3D(arm, pos + Vector3(0, height, 0) + arm * Vector3(0, 0, 0.55)), steel)
	var lamp_p := pos + Vector3(0, height - 0.1, 0) + arm * Vector3(0, 0, 1.1)
	var lm := MeshInstance3D.new()
	lm.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.25, 0.02), Vector2(0.28, 0.12), Vector2(0.1, 0.2), Vector2(0.0, 0.2)]), 12)
	lm.material_override = Mats.emissive(Color(1.0, 0.58, 0.22), 3.0)
	lm.position = lamp_p
	add_child(lm)
	spot(lamp_p, lamp_p + Vector3(0, -1, 0) + arm * Vector3(0, 0, 0.15), Color(1.0, 0.62, 0.3), height * 2.2, 55.0, energy, shadow)

## Cartaz/quadro texturizado (quad).
func poster(pos: Vector3, yaw: float, tex_path: String, size := Vector2(1.2, 1.7), emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	m.roughness = 0.9
	if emissive:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 1.4
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func occluder(pos: Vector3, size: Vector3) -> void:
	var o := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new(); bo.size = size
	o.occluder = bo
	o.position = pos
	add_child(o)

func reflection_probe(pos: Vector3, size: Vector3) -> void:
	if int(Settings.get_v("graphics", "shadows", 1)) < 2:
		return
	var rp := ReflectionProbe.new()
	rp.position = pos
	rp.size = size
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.intensity = 0.6
	add_child(rp)

func acoustic_zone(pos: Vector3, size: Vector3, room_size: float, wet: float, ambience := "", amb_vol := -10.0) -> void:
	Interactables.trigger(self, pos, size, func():
		AudioBus.set_room(room_size, wet)
		if ambience != "":
			AudioBus.play_ambience(ambience, "", amb_vol), false)

# ---------------- entidades ----------------
## Iniciar um capítulo direto pelo menu (sem o estado do capítulo anterior): garante o arsenal
## mínimo que o jogador teria naquele ponto da campanha.
func ensure_loadout(ids: Array) -> void:
	if not is_instance_valid(player) or not player.weapons.owned.is_empty():
		return
	for id in ids:
		player.weapons.give(id)
	for t in ["9mm", "12", "762", "grenade"]:
		player.weapons.add_ammo(t, {"9mm": 72, "12": 12, "762": 60, "grenade": 1}[t])
	if not ids.is_empty():
		player.weapons.equip(ids[mini(1, ids.size() - 1)])

func prop(kind: String, pos: Vector3, yaw := 0.0) -> PhysicsProp:
	var p := PhysicsProp.make(kind)
	add_child(p)
	p.global_position = pos
	p.rotation.y = yaw
	return p

func cover(pos: Vector3) -> void:
	var n := Marker3D.new()
	n.add_to_group("cover")
	n.position = pos
	add_child(n)

func enemy(id: String, kind: String, pos: Vector3, yaw := 0.0, patrol: Array[Vector3] = []) -> EnemyAI:
	if state["killed"].has(id):
		return null
	var e := EnemyAI.make(kind, id.hash())
	e.name = id
	e.patrol = patrol
	add_child(e)
	e.global_position = pos
	e.rotation.y = yaw
	e.died_signal.connect(func(_n): state["killed"].append(id))
	return e

func pickup(id: String, pos: Vector3, item: String, amount := 0) -> Interactables.Pickup:
	if state["picked"].has(id):
		return null
	var p := Interactables.pickup(self, pos, item, amount)
	p.on_pick = func(): state["picked"].append(id)
	return p

func checkpoint(id: String, trig_pos: Vector3, trig_size: Vector3, spawn: Vector3, yaw: float) -> void:
	checkpoints[id] = [spawn, yaw]
	Interactables.trigger(self, trig_pos, trig_size, func(): Game.reach_checkpoint(id))

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var cp: Array = checkpoints.get(Game.checkpoint, checkpoints.get("start", [Vector3.ZERO, 0.0]))
	player.global_position = cp[0]
	player.rotation.y = cp[1]
	var st: Dictionary = Game.pending_player_state
	if not st.is_empty():
		var clean := st.duplicate()
		clean.erase("_level_state")
		player.set_state(clean, false)
	Game.pending_player_state = {}

## Luz cintilante (lâmpada defeituosa) — processada a baixa frequência.
class Flicker extends Node:
	var light: Light3D
	var mesh: MeshInstance3D
	var base := 1.0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = randf_range(0.04, 0.4)
		var on := randf() > 0.25
		light.light_energy = base * (1.0 if on else 0.08)
		if mesh: mesh.visible = on

# ---------------- helpers de arquitetura (cap. 2+) ----------------
## Colisor invisível em rampa (escadas sem "degrau preso" no CharacterBody).
func ramp(sec: String, a: Vector3, b: Vector3, width: float, surface := "concrete") -> void:
	var d := b - a
	var horiz := Vector2(d.x, d.z).length()
	var len := d.length()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(width, 0.1, len)
	cs.shape = bs
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, horiz)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	cs.transform = Transform3D(basis, (a + b) * 0.5 + basis.y * -0.05)
	_body(sec, surface).add_child(cs)

## Escada: degraus visuais + rampa de colisão. base = pé da escada; sobe na direção yaw (0 = -Z).
func stair(sec: String, base: Vector3, yaw: float, width: float, rise: float, mat: Material, step_h := 0.2) -> Vector3:
	var steps := int(round(rise / step_h))
	var sh := rise / steps
	var sd := 0.3
	var b := Basis(Vector3.UP, yaw)
	mesh_at(sec, MeshKit.stairs(width, steps, sh, sd), Transform3D(b, base), mat)
	var top := base + b * Vector3(0, rise, -sd * steps)
	ramp(sec, base + b * Vector3(0, 0.0, 0.15), top + b * Vector3(0, 0, -0.05), width)
	# corrimão
	var steel := Mats.get_mat("steel", 1.0, Color(0.4, 0.4, 0.38))
	mesh_at(sec, MeshKit.pipe(PackedVector3Array([base + b * Vector3(width * 0.5 - 0.05, 0.9, 0), top + b * Vector3(width * 0.5 - 0.05, 0.9, 0)]), 0.025, 6), Transform3D(), steel)
	return top

## Fachada de prédio residencial: bloco com janelas (vidro escuro/iluminado), parapeito e varandas.
func facade_block(sec: String, pos: Vector3, size: Vector3, mat: Material, seed_v := 0, face_dirs := ["n", "s", "e", "w"], start_floor := 0) -> void:
	if size.x > 0.05 and size.z > 0.05:
		box(sec, pos + Vector3(0, size.y * 0.5, 0), size, mat)
		box(sec, pos + Vector3(0, size.y - 0.5, 0), Vector3(size.x + 0.3, 0.3, size.z + 0.3), Mats.get_mat("concrete", 0.4, Color(0.5, 0.5, 0.48)), Vector3.ZERO, false, 0.05)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var lit := Mats.emissive(Color(0.95, 0.75, 0.45), 1.3)
	var dark := Mats.flat(Color(0.05, 0.06, 0.07), 0.15, 0.3)
	var frame := Mats.get_mat("concrete", 0.4, Color(0.42, 0.42, 0.4))
	var lit_parts := []; var dark_parts := []; var frame_parts := []
	var floors := int(size.y / 3.2)
	for side in face_dirs:
		var along := size.x if side in ["n", "s"] else size.z
		var cols := int(along / 3.0)
		for f in range(start_floor, floors):
			for c in range(cols):
				var u := -along * 0.5 + (c + 0.5) * along / cols
				var y := 1.0 + f * 3.2 + 0.75
				var p: Vector3
				var yaw := 0.0
				match side:
					"n": p = Vector3(u, y, -size.z * 0.5 - 0.02); yaw = PI
					"s": p = Vector3(u, y, size.z * 0.5 + 0.02); yaw = 0.0
					"e": p = Vector3(size.x * 0.5 + 0.02, y, u); yaw = PI * 0.5
					"w": p = Vector3(-size.x * 0.5 - 0.02, y, u); yaw = -PI * 0.5
				var xf := Transform3D(Basis(Vector3.UP, yaw), pos + p)
				var pane := [MeshKit.bevel_box(Vector3(1.3, 1.5, 0.04), 0.0, 1), xf]
				if rng.randf() < 0.18: lit_parts.append(pane)
				else: dark_parts.append(pane)
				frame_parts.append([MeshKit.bevel_box(Vector3(1.6, 0.12, 0.25), 0.02, 1), xf * Transform3D(Basis(), Vector3(0, -0.8, 0.06))])
	if lit_parts.size() > 0: mesh_at(sec, MeshKit.combine(lit_parts), Transform3D(), lit)
	if dark_parts.size() > 0: mesh_at(sec, MeshKit.combine(dark_parts), Transform3D(), dark)
	if frame_parts.size() > 0: mesh_at(sec, MeshKit.combine(frame_parts), Transform3D(), frame)

## Carcaça de carro abandonado (cobertura).
func car_wreck(sec: String, pos: Vector3, yaw: float, color: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var paint := Mats.get_mat("rusted_paint", 0.8, color)
	var parts := [[MeshKit.bevel_box(Vector3(1.7, 0.7, 4.2), 0.12, 2), Transform3D(Basis(), Vector3(0, 0.65, 0))],
		[MeshKit.bevel_box(Vector3(1.5, 0.55, 2.2), 0.15, 2), Transform3D(Basis(), Vector3(0, 1.25, 0.2))]]
	mesh_at(sec, MeshKit.combine(parts), Transform3D(b, pos), paint, Vector3(1.7, 1.5, 4.2), Vector3(0, 0.75, 0))
	var tire := Mats.get_mat("rubber", 1.0, Color(0.45, 0.45, 0.45))
	for wx: float in [-0.8, 0.8]:
		for wz: float in [-1.35, 1.35]:
			mesh_at(sec, MeshKit.cylinder(0.33, 0.22, 12, 0.03), Transform3D(b * Basis(Vector3.FORWARD, PI * 0.5), pos + b * Vector3(wx, 0.33, wz)), tire)
	mesh_at(sec, MeshKit.bevel_box(Vector3(1.4, 0.45, 0.04), 0.01, 1), Transform3D(b * Basis(Vector3.RIGHT, -0.5), pos + b * Vector3(0, 1.3, -0.95)), Mats.flat(Color(0.06, 0.07, 0.08), 0.1, 0.3))
	cover(pos + b * Vector3(1.4, 0, 0))
	cover(pos + b * Vector3(-1.4, 0, 0))

## Barricada de concreto (jersey) com cobertura.
func barrier(sec: String, pos: Vector3, yaw: float, length := 3.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	var prof := MeshKit.combine([[MeshKit.bevel_box(Vector3(0.7, 0.35, length), 0.05, 1), Transform3D(Basis(), Vector3(0, 0.175, 0))],
		[MeshKit.bevel_box(Vector3(0.3, 0.75, length), 0.05, 1), Transform3D(Basis(), Vector3(0, 0.7, 0))]])
	mesh_at(sec, prof, Transform3D(b, pos), Mats.get_mat("concrete", 0.6, Color(0.75, 0.74, 0.7)), Vector3(0.6, 1.05, length), Vector3(0, 0.525, 0))
	cover(pos + b * Vector3(0.9, 0, 0))
	cover(pos + b * Vector3(-0.9, 0, 0))
