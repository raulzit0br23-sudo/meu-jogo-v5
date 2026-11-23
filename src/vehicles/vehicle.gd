class_name Vehicle
extends RigidBody3D
## Veículos dirigíveis com física arcade (RigidBody3D + forças):
##  - "boat": barco de canal. Empuxo em 4 pontos sobre um plano d'água (water_y), arrasto e deriva.
##  - "buggy": o "Besouro". 4 molas por raycast (suspensão), tração, atrito lateral, direção.
## O jogador entra/sai com "usar". Dirigindo: colisão do jogador desligada, ele acompanha o assento,
## move.y = acelerador, move.x = direção, câmera livre (o jogador pode atirar), pular = freio de mão,
## correr = turbo. O motor é um loop 3D com pitch proporcional à velocidade.

signal entered(by: Node)
signal exited(by: Node)

var mode := "buggy"
var driver: Node = null
var max_speed := 16.0
var boost_speed := 22.0
var accel := 5.0
var turn_rate := 1.6
var grip := 4.0
var water_y := 0.0
var locked := false            # true = jogador não pode sair (sequências roteirizadas)
var can_enter := true
var health := 500.0
var throttle_override := INF   # usado pelos testes automatizados
var steer_override := INF
var seat := Vector3(0, 0.55, 0.2)
var exit_offset := Vector3(-1.8, 0.3, 0)
var _wheels: Array[Vector3] = []
var _wheel_nodes: Array[Node3D] = []
var _spin := 0.0
var _engine: AudioStreamPlayer3D
var _splash_cd := 0.0
var _upside_t := 0.0
var _rest := 0.55
var _spring_k := 0.0
var _damp_c := 0.0
var _hull: Node3D
var _prev_yaw := 0.0
var speed := 0.0

func _init() -> void:
	collision_layer = 4
	collision_mask = 1 | 4 | 8
	can_sleep = false
	continuous_cd = true
	set_meta("no_carry", true)
	set_meta("surface", "metal")

static func make(kind: String) -> Vehicle:
	var v := Vehicle.new()
	v.mode = kind
	v.name = "Boat" if kind == "boat" else "Buggy"
	if kind == "boat":
		v._build_boat()
	else:
		v._build_buggy()
	return v

func _ready() -> void:
	add_to_group("vehicle")
	_engine = AudioStreamPlayer3D.new()
	_engine.bus = "SFX"
	var st := AudioBus.get_stream("engine_boat" if mode == "boat" else "engine_buggy")
	if st is AudioStreamWAV:
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * st.mix_rate)
	_engine.stream = st
	_engine.volume_db = -14.0
	_engine.unit_size = 8.0
	_engine.max_distance = 70.0
	add_child(_engine)
	_prev_yaw = global_rotation.y

# ---------------- construção ----------------
func _mi(mesh: Mesh, mat: Material, xf := Transform3D()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.transform = xf
	_hull.add_child(m)
	return m

func _col(shape: Shape3D, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)

func _build_boat() -> void:
	mass = 380.0
	max_speed = 15.0; boost_speed = 20.0; accel = 3.5; turn_rate = 1.25; grip = 1.6
	seat = Vector3(0, 0.47, 1.2)
	exit_offset = Vector3(0, 0.6, -2.6)
	linear_damp = 0.0
	angular_damp = 1.5
	_hull = Node3D.new(); _hull.name = "Hull"; add_child(_hull)
	var hull_mat := Mats.prop("rusted_paint", 1.5, Color(0.55, 0.62, 0.58))
	var wood := Mats.prop("wood", 1.5, Color(0.75, 0.65, 0.5))
	var steel := Mats.prop("steel", 2.0, Color(0.45, 0.45, 0.44))
	# Casco: perfil em "V" extrudado por seções (proa afinando), feito por lathe achatado
	var prof := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		var r := 0.95 * (0.86 + 0.14 * sin(clampf(t * 2.0, 0.0, 1.0) * PI * 0.5)) * (1.0 - pow(maxf(0.0, t - 0.6) / 0.4, 2.0) * 0.92)
		prof.append(Vector2(maxf(r, 0.05), -2.3 + t * 4.6))
	var hull := MeshKit.lathe(prof, 16)
	_mi(hull, hull_mat, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(1.0, 0.45, 1.0)), Vector3(0, 0.0, 0)))
	# convés, bancos, borda
	_mi(MeshKit.bevel_box(Vector3(1.5, 0.06, 3.0), 0.02), wood, Transform3D(Basis(), Vector3(0, 0.44, 0.3)))
	_mi(MeshKit.bevel_box(Vector3(1.4, 0.08, 0.35), 0.02), wood, Transform3D(Basis(), Vector3(0, 0.72, -0.4)))
	_mi(MeshKit.bevel_box(Vector3(1.3, 0.3, 0.06), 0.02), wood, Transform3D(Basis(), Vector3(0, 0.6, -0.4)))
	for s in [-1.0, 1.0]:
		_mi(MeshKit.pipe(PackedVector3Array([Vector3(s * 0.82, 0.62, 1.9), Vector3(s * 0.88, 0.62, 0.0), Vector3(s * 0.6, 0.62, -1.6), Vector3(0, 0.62, -2.2)]), 0.035, 6), steel)
		_mi(MeshKit.cylinder(0.14, 0.5, 10, 0.02), Mats.flat(Color(0.12, 0.12, 0.12), 0.9), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(s * 0.94, 0.3, 0.6)))
	# motor de popa
	_mi(MeshKit.bevel_box(Vector3(0.4, 0.5, 0.45), 0.05), steel, Transform3D(Basis(), Vector3(0, 0.7, 2.25)))
	_mi(MeshKit.cylinder(0.06, 0.9, 8), steel, Transform3D(Basis(), Vector3(0, -0.15, 2.35)))
	_mi(MeshKit.pipe(PackedVector3Array([Vector3(0, 0.85, 2.2), Vector3(0, 1.0, 1.75), Vector3(0, 0.85, 1.5)]), 0.025, 6), Mats.flat(Color(0.5, 0.1, 0.08), 0.6))
	# luz de proa
	_mi(MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0.02), Vector2(0.12, 0.12), Vector2(0, 0.14)]), 10), Mats.emissive(Color(1.0, 0.9, 0.7), 2.0), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.62, -1.95)))
	var lamp := SpotLight3D.new()
	lamp.spot_range = 26.0; lamp.spot_angle = 30.0; lamp.light_energy = 2.5; lamp.light_color = Color(1.0, 0.92, 0.75)
	lamp.position = Vector3(0, 0.6, -2.1); lamp.rotation.x = -0.12
	lamp.add_to_group("az_lights")
	add_child(lamp)
	var bs := BoxShape3D.new(); bs.size = Vector3(1.8, 0.6, 4.4)
	_col(bs, Vector3(0, 0.1, 0))
	_wheels = [Vector3(-0.7, -0.15, -1.6), Vector3(0.7, -0.15, -1.6), Vector3(-0.75, -0.15, 1.6), Vector3(0.75, -0.15, 1.6)]
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.25, 0.2)

func _build_buggy() -> void:
	mass = 600.0
	max_speed = 18.0; boost_speed = 25.0; accel = 5.5; turn_rate = 1.7; grip = 6.0
	seat = Vector3(0, 0.55, 0.15)
	exit_offset = Vector3(-2.0, 0.3, 0.0)
	angular_damp = 1.2
	linear_damp = 0.05
	_rest = 0.6
	_spring_k = mass * 9.8 / 4.0 / 0.28
	_damp_c = 2.0 * sqrt(_spring_k * mass / 4.0) * 0.55
	_hull = Node3D.new(); _hull.name = "Hull"; add_child(_hull)
	var paint := Mats.prop("rusted_paint", 1.5, Color(0.85, 0.72, 0.45))
	var steel := Mats.prop("steel", 2.0, Color(0.38, 0.38, 0.37))
	var dark := Mats.flat(Color(0.1, 0.1, 0.1), 0.85)
	# Chassi tubular (gaiola) + carenagem frontal de ambulância + motor de trator exposto atrás
	_mi(MeshKit.bevel_box(Vector3(1.6, 0.18, 3.4), 0.05), steel, Transform3D(Basis(), Vector3(0, 0.15, 0)))
	_mi(MeshKit.bevel_box(Vector3(1.5, 0.45, 1.2), 0.12), paint, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.45, -1.15)))
	_mi(MeshKit.bevel_box(Vector3(0.9, 0.06, 0.5), 0.02), Mats.glass(), Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, 0.85, -0.55)))
	var cage := []
	for s in [-1.0, 1.0]:
		cage.append([MeshKit.pipe(PackedVector3Array([Vector3(s * 0.72, 0.25, -0.6), Vector3(s * 0.68, 1.35, -0.2), Vector3(s * 0.68, 1.35, 0.7), Vector3(s * 0.72, 0.25, 1.1)]), 0.04, 6), Transform3D()])
	cage.append([MeshKit.pipe(PackedVector3Array([Vector3(-0.68, 1.35, -0.2), Vector3(0.68, 1.35, -0.2)]), 0.04, 6), Transform3D()])
	cage.append([MeshKit.pipe(PackedVector3Array([Vector3(-0.68, 1.35, 0.7), Vector3(0.68, 1.35, 0.7)]), 0.04, 6), Transform3D()])
	_mi(MeshKit.combine(cage), steel)
	_mi(MeshKit.bevel_box(Vector3(0.5, 0.12, 0.5), 0.04), dark, Transform3D(Basis(), Vector3(0, 0.36, 0.25)))
	_mi(MeshKit.bevel_box(Vector3(0.5, 0.5, 0.1), 0.04), dark, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 0.62, 0.5)))
	_mi(MeshKit.bevel_box(Vector3(0.8, 0.5, 0.7), 0.06), steel, Transform3D(Basis(), Vector3(0, 0.5, 1.35)))
	for i in 4:
		_mi(MeshKit.cylinder(0.05, 0.2, 8), steel, Transform3D(Basis(), Vector3(-0.3 + i * 0.2, 0.85, 1.35)))
	_mi(MeshKit.pipe(PackedVector3Array([Vector3(0.35, 0.7, 1.6), Vector3(0.45, 1.3, 1.75)]), 0.05, 8), Mats.flat(Color(0.2, 0.15, 0.1), 0.6, 0.5))
	# volante
	_mi(MeshKit.pipe(PackedVector3Array([Vector3(-0.16, 0.85, -0.25), Vector3(0, 0.9, -0.28), Vector3(0.16, 0.85, -0.25), Vector3(0, 0.8, -0.22), Vector3(-0.16, 0.85, -0.25)]), 0.018, 6), dark)
	# faróis
	for s in [-0.5, 0.5]:
		_mi(MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0.02), Vector2(0.11, 0.08), Vector2(0, 0.09)]), 10), Mats.emissive(Color(1.0, 0.9, 0.7), 2.0), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s, 0.6, -1.78)))
	var lamp := SpotLight3D.new()
	lamp.spot_range = 30.0; lamp.spot_angle = 34.0; lamp.light_energy = 3.0; lamp.light_color = Color(1.0, 0.92, 0.75)
	lamp.position = Vector3(0, 0.7, -1.9); lamp.rotation.x = -0.1
	lamp.add_to_group("az_lights")
	add_child(lamp)
	# rodas (visuais); a física usa raycasts
	_wheels = [Vector3(-0.85, 0.3, -1.15), Vector3(0.85, 0.3, -1.15), Vector3(-0.85, 0.3, 1.15), Vector3(0.85, 0.3, 1.15)]
	var tire := MeshKit.lathe(PackedVector2Array([Vector2(0.18, -0.16), Vector2(0.38, -0.17), Vector2(0.42, -0.1), Vector2(0.42, 0.1), Vector2(0.38, 0.17), Vector2(0.18, 0.16)]), 16)
	var rim := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.2, -0.13), Vector2(0.2, 0.13), Vector2(0.0, 0.12)]), 8)
	for w in _wheels:
		var n := Node3D.new()
		n.position = w - Vector3(0, _rest - 0.15, 0)
		add_child(n)
		var spin := Node3D.new(); spin.name = "Spin"; n.add_child(spin)
		for pair in [[tire, dark], [rim, steel]]:
			var m := MeshInstance3D.new()
			m.mesh = pair[0]; m.material_override = pair[1]
			m.rotation.z = PI * 0.5
			spin.add_child(m)
		_wheel_nodes.append(n)
	var bs := BoxShape3D.new(); bs.size = Vector3(1.6, 0.7, 3.6)
	_col(bs, Vector3(0, 0.55, 0))
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.1, 0.1)

# ---------------- interação ----------------
func get_hint() -> String:
	if driver or not can_enter:
		return ""
	return Loc.t("hud.drive")

func interact(by: Node) -> void:
	if driver == null and can_enter and by is Player:
		enter(by)

func enter(p: Node) -> void:
	driver = p
	p.enter_vehicle(self)
	_engine.play()
	AudioBus.play_3d("lever", global_position, -6.0)
	entered.emit(p)

func exit_vehicle(force := false) -> bool:
	if driver == null or (locked and not force):
		return false
	if not force and speed > 5.0:
		return false
	var p := driver
	driver = null
	var out := global_transform * exit_offset
	# evita sair dentro de parede: tenta o lado oposto / atrás
	for off in [exit_offset, Vector3(-exit_offset.x, exit_offset.y, exit_offset.z), Vector3(0, 0.4, 2.8), Vector3(0, 2.0, 0)]:
		var cand: Vector3 = global_transform * off
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new(); cap.radius = 0.36; cap.height = 1.75
		q.shape = cap
		q.transform = Transform3D(Basis(), cand + Vector3.UP * 0.95)
		q.collision_mask = 1 | 4
		q.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			out = cand
			break
	p.exit_vehicle(out)
	_engine.stop()
	exited.emit(p)
	return true

func seat_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(), seat)

func take_hit(damage: float, pos: Vector3, _dir: Vector3, _src: Node = null, type := "bullet") -> void:
	# O veículo protege parcialmente: parte do dano passa ao motorista.
	if driver and driver.has_method("take_damage"):
		driver.take_damage(damage * (0.5 if type == "bullet" else 0.7), pos, type)
	Effects.burst(pos, Vector3.UP, Color(1.0, 0.75, 0.35), 6, true, 0.6)

func take_damage(amount: float, pos: Vector3 = Vector3.ZERO, type := "bullet") -> void:
	take_hit(amount, pos, Vector3.ZERO, null, type)

# ---------------- física ----------------
func _controls() -> Array:
	var thr := 0.0
	var st := 0.0
	var boost := false
	var brake := false
	if driver and driver.input_enabled and driver.alive:
		var mv: Vector2 = InputRouter.get_move()
		thr = -mv.y
		st = -mv.x
		boost = Input.is_action_pressed("sprint")
		brake = Input.is_action_pressed("jump")
	if throttle_override != INF: thr = throttle_override
	if steer_override != INF: st = steer_override
	return [thr, st, boost, brake]

func _physics_process(delta: float) -> void:
	var c := _controls()
	var thr: float = c[0]
	var st: float = c[1]
	var up := global_basis.y
	var fwd := -global_basis.z
	var right := global_basis.x
	var v := linear_velocity
	var fwd_speed := v.dot(fwd)
	speed = Vector2(v.x, v.z).length()
	var grounded := 0
	var space := get_world_3d().direct_space_state
	if mode == "boat":
		for w in _wheels:
			var wp: Vector3 = global_transform * w
			var depth := water_y - wp.y
			if depth > 0.0:
				grounded += 1
				var pv := v + angular_velocity.cross(wp - global_position)
				var f := Vector3.UP * (minf(depth, 0.8) * mass * 9.8 * 0.62 - pv.y * mass * 0.35)
				apply_force(f, wp - global_position)
		if grounded > 0:
			# arrasto da água (maior lateralmente)
			apply_central_force(-fwd * fwd_speed * mass * 0.12)
			apply_central_force(-right * v.dot(right) * mass * grip)
		_splash_cd -= delta
		if grounded > 0 and speed > 6.0 and _splash_cd <= 0.0:
			_splash_cd = randf_range(0.7, 1.4)
			AudioBus.play_3d("splash", global_position + fwd * 2.0, -14.0 + speed * 0.4, 0.2, 40.0)
	else:
		for i in _wheels.size():
			var wp: Vector3 = global_transform * _wheels[i]
			var q := PhysicsRayQueryParameters3D.create(wp, wp - up * (_rest + 0.42), 1 | 4)
			q.exclude = [get_rid()]
			if driver: q.exclude.append(driver.get_rid())
			var hit := space.intersect_ray(q)
			var wn: Node3D = _wheel_nodes[i]
			if hit:
				grounded += 1
				var dist := wp.distance_to(hit.position)
				var comp := _rest - (dist - 0.42)
				var pv := v + angular_velocity.cross(wp - global_position)
				var f := up * (comp * _spring_k - pv.dot(up) * _damp_c)
				if f.dot(up) > 0.0:
					apply_force(f, wp - global_position)
				wn.position.y = lerpf(wn.position.y, _wheels[i].y - (dist - 0.42), 0.5)
			else:
				wn.position.y = lerpf(wn.position.y, _wheels[i].y - _rest, 0.2)
			if i < 2:
				wn.rotation.y = st * 0.45
		_spin += fwd_speed * delta / 0.42
		for wn in _wheel_nodes:
			wn.get_node("Spin").rotation.x = -_spin
	if grounded > 0:
		var k := float(grounded) / 4.0
		var top: float = boost_speed if c[2] else max_speed
		if c[3]:
			apply_central_force(-fwd * fwd_speed * mass * 2.5 * k)
		elif absf(thr) > 0.05:
			var target := thr * top * (0.55 if thr < 0.0 else 1.0)
			var acc := clampf(target - fwd_speed, -accel * 1.6, accel)
			apply_central_force(fwd * acc * mass * k * (1.6 if (sign(target) != sign(fwd_speed) and absf(fwd_speed) > 1.0) else 1.0))
		else:
			apply_central_force(-fwd * fwd_speed * mass * (0.5 if mode == "buggy" else 0.2) * k)
		if mode == "buggy":
			var side := v.dot(right)
			apply_central_force(-right * side * mass * grip * k * (0.35 if c[3] else 1.0))
		# direção: taxa de guinada desejada proporcional à velocidade
		var yaw_target := st * turn_rate * clampf(fwd_speed / 5.0, -1.0, 1.0)
		if mode == "boat":
			yaw_target = st * turn_rate * clampf(absf(fwd_speed) / 4.0 + 0.25, 0.0, 1.0) * (1.0 if fwd_speed >= -0.5 else -1.0)
		var yaw_now := angular_velocity.dot(up)
		var inertia := mass * (2.2 if mode == "buggy" else 1.6)
		apply_torque(up * (yaw_target - yaw_now) * inertia * 4.0 * k)
	# estabilizador (anti-capotamento): torque para alinhar "up" ao vetor vertical
	var tilt := up.cross(Vector3.UP)
	apply_torque(tilt * mass * (9.0 if mode == "buggy" else 6.0) - angular_velocity * Vector3(1, 0, 1) * mass * 0.8)
	if up.y < 0.3:
		_upside_t += delta
		if _upside_t > 2.0:
			_upside_t = 0.0
			global_transform = Transform3D(Basis(Vector3.UP, global_rotation.y), global_position + Vector3.UP * 1.5)
			linear_velocity = Vector3.ZERO; angular_velocity = Vector3.ZERO
	else:
		_upside_t = 0.0
	if _engine.playing:
		_engine.pitch_scale = clampf(0.7 + speed / max_speed * 0.9 + absf(thr) * 0.15, 0.6, 2.0)
		_engine.volume_db = -14.0 + absf(thr) * 4.0
	if driver:
		if speed > 7.0:
			Game.emit_noise(global_position, 18.0, driver)
		_run_over(space)

func _run_over(space: PhysicsDirectSpaceState3D) -> void:
	# Atropelar inimigos/criaturas a velocidade alta causa dano (como em HL2).
	if speed < 7.0:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var sp := SphereShape3D.new(); sp.radius = 1.3
	q.shape = sp
	q.transform = Transform3D(Basis(), global_position + (-global_basis.z) * 1.6 + Vector3.UP * 0.6)
	q.collision_mask = 8
	for r in space.intersect_shape(q, 4):
		var co: Object = r["collider"]
		if co and co.has_method("take_hit") and co.get("alive"):
			co.take_hit(speed * 6.0, co.global_position + Vector3.UP, linear_velocity.normalized(), driver, "physics")
			AudioBus.play_3d("impact_flesh", co.global_position, 0.0)
