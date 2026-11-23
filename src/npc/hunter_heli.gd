class_name HunterHeli
extends AnimatableBody3D
## Helicóptero "Caçador" do Domínio (original; inspirado no conceito de aeronave de patrulha
## dos canais do HL2 beta). Malha procedural: fuselagem torneada, lança de cauda, rotores girando.
## Comportamento: acompanha o jogador a uma altitude, dentro de uma área (bounds), e dispara
## rajadas de metralhadora com aviso sonoro. Só é seriamente ferido por explosões (flak, barris);
## balas causam 10% do dano. Ao morrer: cai girando e explode.

signal died_signal(n: Node)

var health := 600.0
var max_health := 600.0
var alive := true
var altitude := 16.0
var follow_dist := 22.0
var bounds_min := Vector3(-INF, -INF, -INF)
var bounds_max := Vector3(INF, INF, INF)
var aggressive := true
var damage := 4.0
var burst_n := 14
var target: Node3D = null
var hold_point := Vector3.INF     # se definido, paira neste ponto (sequências)
var _vel := Vector3.ZERO
var _rotor: Node3D
var _tail_rotor: Node3D
var _gun: Node3D
var _snd: AudioStreamPlayer3D
var _fire_t := 3.0
var _burst_left := 0
var _shot_t := 0.0
var _orbit := 0.0
var _crash_t := 0.0
var _smoke_t := 0.0
var _flash: OmniLight3D

func _init() -> void:
	collision_layer = 8
	collision_mask = 0
	sync_to_physics = false
	set_meta("surface", "metal")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("heli")
	_build()
	_snd = AudioStreamPlayer3D.new()
	_snd.bus = "SFX"
	var st := AudioBus.get_stream("heli_rotor")
	if st is AudioStreamWAV:
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * st.mix_rate)
	_snd.stream = st
	_snd.unit_size = 30.0
	_snd.max_distance = 220.0
	_snd.volume_db = 2.0
	add_child(_snd)
	_snd.play()
	_flash = OmniLight3D.new(); _flash.omni_range = 6.0; _flash.light_energy = 0.0
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_gun.add_child(_flash)

func _mi(parent: Node3D, mesh: Mesh, mat: Material, xf := Transform3D()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh; m.material_override = mat; m.transform = xf
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _build() -> void:
	var hull := Mats.prop("dominion", 1.0, Color(0.55, 0.58, 0.6))
	var dark := Mats.prop("steel", 2.0, Color(0.2, 0.21, 0.22))
	var glass := Mats.emissive(Color(0.25, 0.55, 0.7), 0.6)
	var body := Node3D.new(); body.name = "Body"; add_child(body)
	# fuselagem: gota alongada (lathe no eixo Z)
	var prof := PackedVector2Array()
	for i in 15:
		var t := float(i) / 14.0
		var r := 1.25 * pow(sin(t * PI), 0.7) * (1.0 - 0.35 * t)
		prof.append(Vector2(maxf(r, 0.05), -3.0 + t * 6.0))
	_mi(body, MeshKit.with_lods(MeshKit.lathe(prof, 14)), hull, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.9, 0.85, 1.0)), Vector3(0, 0, 0)))
	# cabine (vidro escuro emissivo leve)
	_mi(body, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.65, 0.05), Vector2(0.7, 0.45), Vector2(0.4, 0.85), Vector2(0.0, 0.9)]), 12), glass, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 0.7, 1.0)), Vector3(0, 0.2, -2.0)))
	# lança de cauda, deriva e estabilizadores
	_mi(body, MeshKit.lathe(PackedVector2Array([Vector2(0.45, 0.0), Vector2(0.3, 2.0), Vector2(0.18, 4.6)]), 10), hull, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.25, 2.4)))
	_mi(body, MeshKit.bevel_box(Vector3(0.12, 1.5, 0.9), 0.04), hull, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.9, 6.7)))
	_mi(body, MeshKit.bevel_box(Vector3(2.0, 0.08, 0.6), 0.03), hull, Transform3D(Basis(), Vector3(0, 0.3, 6.2)))
	# casulos laterais (turbinas) e esquis
	for s in [-1.0, 1.0]:
		_mi(body, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -1.0), Vector2(0.32, -0.8), Vector2(0.36, 0.6), Vector2(0.24, 1.0), Vector2(0.0, 1.05)]), 10), dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.75, 1.0, 0.3)))
		_mi(body, MeshKit.pipe(PackedVector3Array([Vector3(s * 0.9, -1.35, -1.8), Vector3(s * 0.95, -1.4, 1.6), Vector3(s * 0.95, -1.2, 2.0)]), 0.06, 6), dark)
		for z in [-0.8, 0.8]:
			_mi(body, MeshKit.pipe(PackedVector3Array([Vector3(s * 0.55, -0.7, z), Vector3(s * 0.93, -1.38, z)]), 0.05, 6), dark)
		# luz de navegação
		_mi(body, MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.08, 0.04), Vector2(0, 0.1)]), 6), Mats.emissive(Color(1, 0.2, 0.1) if s < 0 else Color(0.2, 1, 0.3), 3.0), Transform3D(Basis(), Vector3(s * 1.0, 0.1, 0.0)))
	# mastro + rotor principal (4 pás)
	_mi(body, MeshKit.cylinder(0.14, 0.6, 10), dark, Transform3D(Basis(), Vector3(0, 1.35, 0.0)))
	_rotor = Node3D.new(); _rotor.position = Vector3(0, 1.7, 0.0); body.add_child(_rotor)
	var blades := []
	for i in 4:
		blades.append([MeshKit.bevel_box(Vector3(0.35, 0.04, 5.6), 0.01, 1), Transform3D(Basis(Vector3.UP, i * PI * 0.5), Vector3(0, 0, 0)).translated_local(Vector3(0, 0, 2.8))])
	blades.append([MeshKit.cylinder(0.3, 0.18, 10), Transform3D()])
	_mi(_rotor, MeshKit.combine(blades), dark)
	# disco borrado (transparência aditiva barata) para sugerir movimento
	var disc := MeshInstance3D.new()
	disc.mesh = MeshKit.cylinder(5.6, 0.01, 24)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.1, 0.1, 0.1, 0.18)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0, 1.72, 0)
	body.add_child(disc)
	_tail_rotor = Node3D.new(); _tail_rotor.position = Vector3(0.16, 1.1, 7.0); body.add_child(_tail_rotor)
	var tb := []
	for i in 3:
		tb.append([MeshKit.bevel_box(Vector3(0.04, 1.3, 0.16), 0.01, 1), Transform3D(Basis(Vector3.RIGHT, i * TAU / 3.0), Vector3.ZERO).translated_local(Vector3(0, 0.6, 0))])
	_mi(_tail_rotor, MeshKit.combine(tb), dark)
	# canhão sob o nariz
	_gun = Node3D.new(); _gun.position = Vector3(0, -0.85, -2.2); body.add_child(_gun)
	_mi(_gun, MeshKit.lathe(PackedVector2Array([Vector2(0, -0.3), Vector2(0.28, -0.25), Vector2(0.3, 0.2), Vector2(0, 0.3)]), 10), dark)
	for i in 3:
		var a := i * TAU / 3.0
		_mi(_gun, MeshKit.cylinder(0.04, 1.1, 6), dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(cos(a) * 0.08, sin(a) * 0.08, -0.6)))
	# colisão
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 1.2; cap.height = 6.2
	cs.shape = cap; cs.rotation.x = PI * 0.5
	add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bx := BoxShape3D.new(); bx.size = Vector3(0.7, 0.9, 4.5)
	cs2.shape = bx; cs2.position = Vector3(0, 0.3, 4.6)
	add_child(cs2)

func aim_point() -> Vector3:
	return global_position

func take_hit(dmg: float, pos: Vector3, _dir: Vector3, _src: Node = null, type := "bullet") -> void:
	if not alive:
		return
	var mult := 1.0 if type == "explosion" else (0.6 if type == "physics" else 0.1)
	health -= dmg * mult
	Effects.burst(pos, Vector3.UP, Color(1.0, 0.75, 0.35), 8, true, 0.8)
	if type == "explosion":
		AudioBus.play_3d("impact_metal_heavy", pos, 2.0, 0.1, 120.0)
	if health <= 0.0:
		_die()

func take_damage(amount: float, pos: Vector3 = Vector3.ZERO, type := "bullet") -> void:
	take_hit(amount, pos, Vector3.ZERO, null, type)

func _die() -> void:
	alive = false
	remove_from_group("enemy")
	_crash_t = 0.01
	_vel = _vel * 0.5 + Vector3(0, -2.0, 0)
	AudioBus.play_3d("heli_explode", global_position, 6.0, 0.0, 250.0)
	Effects.burst(global_position, Vector3.UP, Color(1.0, 0.55, 0.2), 40, true, 3.0)
	died_signal.emit(self)

func _physics_process(delta: float) -> void:
	_rotor.rotation.y += delta * (28.0 if alive else 14.0)
	_tail_rotor.rotation.x += delta * 40.0
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 60.0)
	if _crash_t > 0.0:
		_crash(delta)
		return
	if target == null or not is_instance_valid(target):
		target = Game.player if is_instance_valid(Game.player) else null
	if target == null:
		return
	var tp: Vector3 = target.global_position
	var goal: Vector3
	if hold_point != Vector3.INF:
		goal = hold_point
	else:
		# Fica à frente/lado do alvo, orbitando lentamente; respeita a área permitida.
		_orbit += delta * 0.18
		var tv: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
		var lead := Vector3(tv.x, 0, tv.z) * 1.6
		goal = tp + lead + Vector3(sin(_orbit), 0, cos(_orbit)) * follow_dist
		goal.y = tp.y + altitude
	goal = goal.clamp(bounds_min, bounds_max)
	var to := goal - global_position
	var desired := to.limit_length(16.0) * 0.9
	_vel = _vel.lerp(desired, clampf(delta * 0.9, 0, 1))
	global_position += _vel * delta
	# orientação: nariz para o alvo, inclina na direção do movimento
	var look := tp - global_position
	look.y = 0
	if look.length() > 1.0:
		var yaw := atan2(-look.x, -look.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 1.4, 0, 1))
	var local_v := global_basis.inverse() * _vel
	rotation.x = lerpf(rotation.x, clampf(-local_v.z * 0.025, -0.3, 0.3), clampf(delta * 2.0, 0, 1))
	rotation.z = lerpf(rotation.z, clampf(-local_v.x * 0.03, -0.35, 0.35), clampf(delta * 2.0, 0, 1))
	_gun.look_at(tp + Vector3.UP, Vector3.UP)
	# fumaça quando danificado
	if health < max_health * 0.5:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = 0.25
			Effects.burst(global_position + global_basis.z * 1.5 + Vector3.UP, Vector3.UP, Color(0.15, 0.15, 0.15), 4, false, 1.5)
	if aggressive:
		_combat(delta, tp)

func _combat(delta: float, tp: Vector3) -> void:
	var d := global_position.distance_to(tp)
	if _burst_left > 0:
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shot_t = 0.085
			_burst_left -= 1
			_shoot(tp, d)
		return
	_fire_t -= delta
	if _fire_t <= 0.0 and d < 70.0 and _has_los(tp):
		_burst_left = burst_n
		_fire_t = randf_range(3.2, 4.8)
		AudioBus.play_3d("beacon", global_position, -2.0, 0.0, 120.0)
		_shot_t = 0.6   # atraso de aviso: dá tempo de reagir

func _has_los(tp: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(_gun.global_position, tp + Vector3.UP * 1.2, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _shoot(tp: Vector3, d: float) -> void:
	var from := _gun.global_position
	var diff: float = Settings.get_v("access", "difficulty", 1)
	var t := target
	var tv: Vector3 = t.velocity if "velocity" in t else Vector3.ZERO
	var miss := 0.8 + d * 0.035 + tv.length() * 0.09
	miss *= [1.5, 1.0, 0.8][clampi(int(diff), 0, 2)]
	var aim := tp + Vector3.UP * 1.0 + Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * miss
	var dir := (aim - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, 1 | 2 | 4 | 8)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * 120.0
	AudioBus.play_3d("heli_gun", from, 0.0, 0.08, 160.0)
	_flash.light_energy = 4.0
	if not hit.is_empty():
		end = hit.position
		var dmg = damage * [0.6, 1.0, 1.3][clampi(int(diff), 0, 2)]
		if hit.collider is Player:
			hit.collider.take_damage(dmg, global_position, "bullet")
		else:
			Combat.apply_hit(hit.collider, dmg, hit.position, dir, self, "bullet")
			Effects.impact(hit.position, hit.normal, Mats.surface_of(hit.collider), dir, randf() < 0.4)
	_tracer(from, end)

func _tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a); im.surface_add_vertex(a.lerp(b, 0.8))
	im.surface_end()
	mi.mesh = im
	mi.material_override = Mats.emissive(Color(1.0, 0.85, 0.5), 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(Game.level if is_instance_valid(Game.level) else get_parent()).add_child(mi)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)

func _crash(delta: float) -> void:
	_crash_t += delta
	_vel.y -= 9.0 * delta
	rotation.y += delta * 3.5
	rotation.z = lerpf(rotation.z, 0.6, delta)
	var from := global_position
	global_position += _vel * delta
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = 0.12
		Effects.burst(global_position, Vector3.UP, Color(0.12, 0.12, 0.12), 5, false, 2.0)
	var q := PhysicsRayQueryParameters3D.create(from, global_position + Vector3.DOWN * 1.4, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() or _crash_t > 6.0:
		var p = global_position if hit.is_empty() else hit.position
		Effects.explosion(p + Vector3.UP, 8.0, 60.0, self)
		Effects.burst(p, Vector3.UP, Color(1.0, 0.5, 0.15), 50, true, 3.0)
		AudioBus.play_3d("heli_explode", p, 6.0, 0.0, 250.0)
		_snd.stop()
		_wreck(p)
		queue_free()

func _wreck(p: Vector3) -> void:
	var w := Node3D.new()
	(Game.level if is_instance_valid(Game.level) else get_parent()).add_child(w)
	w.global_position = p
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.05, -2.5), Vector2(1.0, -1.8), Vector2(1.1, 1.0), Vector2(0.5, 2.6)]), 10)
	m.material_override = Mats.flat(Color(0.08, 0.08, 0.08), 0.9)
	m.rotation = Vector3(PI * 0.5, randf() * TAU, 0.4)
	w.add_child(m)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.5, 0.15); fire.omni_range = 10.0; fire.light_energy = 2.0
	fire.position.y = 1.5
	w.add_child(fire)
	var fl := LevelBase.Flicker.new()
	fl.light = fire; fl.base = 2.0
	w.add_child(fl)
