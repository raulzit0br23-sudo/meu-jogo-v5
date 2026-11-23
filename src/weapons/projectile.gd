class_name Projectile
extends Node3D
## Projéteis do arsenal: sinalizador, míssil guiado a laser, virote incendiário e granada de 20 mm.
## Movimento por raycast a cada quadro físico (sem túnel em alta velocidade, barato no mobile).
## Também contém Throwable (granada, molotov, hopwire, S.L.A.M.).

var kind := "flare"
var vel := Vector3.ZERO
var gravity := 0.0
var life := 6.0
var source: Node
var guided := false
var _trail: CPUParticles3D
var _light: OmniLight3D
var _snd: AudioStreamPlayer3D
var _bounces := 0
var _passed: Array = []

const MASK := 1 | 4 | 8

static func spawn(p_kind: String, from: Vector3, dir: Vector3, by: Node) -> Projectile:
	var p := Projectile.new()
	p.kind = p_kind
	p.source = by
	match p_kind:
		"flare": p.vel = dir * 40.0; p.gravity = 5.0; p.life = 4.0
		"rocket": p.vel = dir * 20.0; p.life = 9.0
		"bolt_inc": p.vel = dir * 75.0; p.gravity = 1.5; p.life = 3.0
		"gren20": p.vel = dir * 42.0 + Vector3.UP * 2.0; p.gravity = 9.8; p.life = 5.0
		"xbolt": p.vel = dir * 110.0; p.gravity = 0.6; p.life = 4.0
		"cball": p.vel = dir * 24.0; p.life = 4.5
	Effects._world().add_child(p)
	p.global_position = from
	p.look_at(from + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	return p

func _ready() -> void:
	var mi := MeshInstance3D.new()
	match kind:
		"flare":
			mi.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.015, -0.04), Vector2(0.015, 0.04), Vector2(0.0, 0.05)]), 8)
			mi.material_override = Mats.emissive(Color(1.0, 0.25, 0.15), 4.0)
			_light = _mk_light(Color(1.0, 0.3, 0.2), 7.0, 2.5)
			_trail = _mk_trail(Color(1.0, 0.35, 0.2, 0.8), 0.25)
		"rocket":
			mi.mesh = MeshKit.combine([[MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.3), Vector2(0.045, -0.28), Vector2(0.045, 0.2), Vector2(0.0, 0.32)]), 10), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)]])
			mi.material_override = Mats.prop("gunmetal", 6.0, Color(0.7, 0.72, 0.68))
			_light = _mk_light(Color(1.0, 0.7, 0.4), 6.0, 2.0)
			_trail = _mk_trail(Color(0.75, 0.72, 0.68, 0.6), 0.9)
			_snd = Fire.loop_player(self, "rocket_loop", 0.0, 60.0)
		"bolt_inc":
			mi.mesh = MeshKit.combine([[MeshKit.cylinder(0.008, 0.4, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)]])
			mi.material_override = Mats.emissive(Color(1.0, 0.55, 0.2), 3.0)
			_trail = _mk_trail(Color(1.0, 0.5, 0.2, 0.7), 0.2)
		"xbolt":
			# vergalhão aquecido ao rubro (besta)
			mi.mesh = MeshKit.combine([[MeshKit.cylinder(0.007, 0.5, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)]])
			mi.material_override = Mats.emissive(Color(1.0, 0.45, 0.12), 2.2)
			_light = _mk_light(Color(1.0, 0.45, 0.15), 3.0, 0.8)
			_trail = _mk_trail(Color(1.0, 0.6, 0.3, 0.35), 0.08)
		"cball":
			var sm := SphereMesh.new(); sm.radius = 0.22; sm.height = 0.44; sm.radial_segments = 12; sm.rings = 6
			mi.mesh = sm
			var cm := Mats.emissive(Color(0.75, 0.9, 1.0), 6.0)
			mi.material_override = cm
			_light = _mk_light(Color(0.6, 0.85, 1.0), 6.0, 3.0)
			_trail = _mk_trail(Color(0.6, 0.85, 1.0, 0.5), 0.4)
			_snd = Fire.loop_player(self, "ar2_ball_loop", -4.0, 40.0)
		"gren20":
			mi.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.03), Vector2(0.02, -0.025), Vector2(0.02, 0.02), Vector2(0.0, 0.035)]), 8)
			mi.material_override = Mats.flat(Color(0.3, 0.32, 0.22), 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _mk_light(c: Color, r: float, e: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c; l.omni_range = r; l.light_energy = e
	add_child(l)
	return l

func _mk_trail(c: Color, sz: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24; p.lifetime = 0.6; p.local_coords = false
	p.gravity = Vector3(0, 0.4, 0); p.initial_velocity_min = 0.1; p.initial_velocity_max = 0.4
	p.scale_amount_min = sz * 0.6; p.scale_amount_max = sz
	var q := QuadMesh.new(); q.size = Vector2.ONE * 0.5
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/textures/fx_smoke.png"):
		m.albedo_texture = load("res://assets/textures/fx_smoke.png")
	p.material_override = m
	var g := Gradient.new(); g.set_color(0, c); g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	p.color_ramp = g
	add_child(p)
	return p

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_detonate(global_position, Vector3.UP, null)
		return
	if kind == "rocket":
		var spd := minf(vel.length() + delta * 30.0, 38.0)
		var dir := vel.normalized()
		if guided and is_instance_valid(source) and source is Player and source.alive:
			var cam: Camera3D = source.camera
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 300.0, MASK)
			q.exclude = [source.get_rid()]
			var h := get_world_3d().direct_space_state.intersect_ray(q)
			var aim: Vector3 = h["position"] if not h.is_empty() else cam.global_position - cam.global_basis.z * 300.0
			dir = dir.slerp((aim - global_position).normalized(), clampf(delta * 3.5, 0.0, 1.0))
		vel = dir * spd
	vel.y -= gravity * delta
	var to := global_position + vel * delta
	var q2 := PhysicsRayQueryParameters3D.create(global_position, to, MASK)
	if is_instance_valid(source) and source is CollisionObject3D:
		q2.exclude = [source.get_rid()]
	if kind == "cball":
		q2.exclude = q2.exclude + _passed
	var hit := get_world_3d().direct_space_state.intersect_ray(q2)
	if not hit.is_empty() and kind == "cball" and _cball_hit(hit):
		return
	if not hit.is_empty():
		_detonate(hit["position"], hit["normal"], hit["collider"])
		return
	global_position = to
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.FORWARD)

func _detonate(pos: Vector3, normal: Vector3, col: Object) -> void:
	set_physics_process(false)
	match kind:
		"flare":
			if col and col is Node and (col.is_in_group("enemy") or col is Player):
				Fire.ignite(col, 8.0, source, 9.0)
				Combat.apply_hit(col, 12.0, pos, vel.normalized(), source, "fire")
			else:
				Combat.apply_hit(col, 6.0, pos, vel.normalized(), source, "fire")
				_leave_flare(pos + normal * 0.05)
		"rocket":
			Effects.explosion(pos + normal * 0.2, 4.5, 140.0, source)
		"bolt_inc":
			Combat.apply_hit(col, 30.0, pos, vel.normalized(), source, "bullet")
			if col and col is Node and col.is_in_group("enemy"):
				Fire.ignite(col, 6.0, source, 10.0)
			else:
				Fire.area(pos + normal * 0.05, 1.2, 3.5, source, 10.0)
			Effects.burst(pos, normal, Color(1.0, 0.55, 0.2), 10, true, 0.8)
		"gren20":
			Effects.explosion(pos + normal * 0.15, 3.6, 90.0, source)
		"xbolt":
			Combat.apply_hit(col, 100.0, pos, vel.normalized() * 9.0, source, "bullet")
			AudioBus.play_3d("crossbow_hit", pos, -2.0, 0.1)
			if col is RigidBody3D:
				(col as RigidBody3D).apply_impulse(vel.normalized() * 25.0, pos - (col as RigidBody3D).global_position)
			Effects.impact(pos, normal, Mats.surface_of(col), vel.normalized())
			if col is StaticBody3D or col == null:
				_leave_bolt(pos, vel.normalized())
		"cball":
			Effects.burst(pos, normal, Color(0.75, 0.9, 1.0), 24, true, 1.4)
			AudioBus.play_3d("ar2_ball_bounce", pos, 4.0)
			for b in get_tree().get_nodes_in_group("enemy"):
				if b is Node3D and b.global_position.distance_to(pos) < 2.0:
					Combat.apply_hit(b, 120.0, pos, Vector3.UP * 4.0, source, "explosion")
	queue_free()

## O vergalhão fica cravado na parede por alguns segundos, ainda quente.
func _leave_bolt(pos: Vector3, dir: Vector3) -> void:
	var n := MeshInstance3D.new()
	n.mesh = MeshKit.combine([[MeshKit.cylinder(0.007, 0.5, 6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.18))]])
	var m := Mats.emissive(Color(1.0, 0.45, 0.12), 1.6)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Effects._world().add_child(n)
	n.global_position = pos
	n.look_at(pos + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	var tw := n.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func(): n.material_override = Mats.prop("steel", 6.0, Color(0.35, 0.3, 0.28)))
	tw.tween_interval(12.0)
	tw.tween_callback(n.queue_free)

## Esfera de energia: desintegra inimigos (atravessa), empurra objetos e ricocheteia em superfícies.
## Retorna true se o projétil continua voando.
func _cball_hit(hit: Dictionary) -> bool:
	var col: Object = hit["collider"]
	var pos: Vector3 = hit["position"]
	if col is CollisionObject3D:
		_passed.append(col.get_rid())
	if col and col is Node and (col.is_in_group("enemy") or col.has_method("take_hit")) and not (col is StaticBody3D):
		Combat.apply_hit(col, 400.0, pos, vel.normalized() * 12.0, source, "explosion")
		Effects.burst(pos, -vel.normalized(), Color(0.7, 0.9, 1.0), 16, true, 1.0)
		AudioBus.play_3d("ar2_ball_bounce", pos, 0.0)
		global_position = pos
		return true
	if col is RigidBody3D:
		(col as RigidBody3D).apply_central_impulse(vel.normalized() * minf((col as RigidBody3D).mass * 14.0, 900.0))
	_bounces += 1
	if _bounces > 7:
		return false
	vel = vel.bounce(hit["normal"])
	global_position = pos + hit["normal"] * 0.25
	AudioBus.play_3d("ar2_ball_bounce", pos, -4.0, 0.15)
	Effects.burst(pos, hit["normal"], Color(0.6, 0.85, 1.0), 6, true, 0.5)
	return true

func _leave_flare(pos: Vector3) -> void:
	var n := Node3D.new()
	Effects._world().add_child(n)
	n.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.25, 0.15); l.omni_range = 9.0; l.light_energy = 2.5
	n.add_child(l)
	var fx := Fire._flames(n, 0.05, 8)
	fx.scale_amount_min = 0.2; fx.scale_amount_max = 0.4
	var tw := n.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(l, "light_energy", 0.0, 1.5)
	tw.tween_callback(n.queue_free)

# ======================================================================================
## Arremessáveis com física (RigidBody3D).
class Throwable extends RigidBody3D:
	var kind := "grenade"
	var source: Node
	var fuse := 2.6
	var _armed_t := 0.0
	var _stuck := false
	var _wires: Array = []          # [[a, b], ...] (hopwire)
	var _wire_root: Node3D
	var _hop_state := 0
	var _beam: MeshInstance3D       # S.L.A.M. em modo mina
	var _beam_len := 0.0
	var _tick := 0.0
	var _blink: OmniLight3D
	var _dead := false

	static func throw(p_kind: String, from: Vector3, v: Vector3, by: Node) -> Throwable:
		var t := Throwable.new()
		t.kind = p_kind
		t.source = by
		Effects._world().add_child(t)
		t.global_position = from
		t.linear_velocity = v
		t.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		return t

	func _init() -> void:
		collision_layer = 4
		collision_mask = 1 | 4 | 8
		contact_monitor = true
		max_contacts_reported = 2
		continuous_cd = true
		set_meta("no_carry", true)

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new(); sp.radius = 0.06
		match kind:
			"grenade":
				mi.mesh = MeshKit.combine([[MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.06), Vector2(0.04, -0.05), Vector2(0.045, 0.02), Vector2(0.03, 0.06), Vector2(0.0, 0.065)]), 10), Transform3D()],
					[MeshKit.cylinder(0.012, 0.03, 6), Transform3D(Basis(), Vector3(0, 0.075, 0))]])
				mi.material_override = Mats.prop("gunmetal", 8.0, Color(0.55, 0.6, 0.45))
				mass = 0.5
				_blink = OmniLight3D.new(); _blink.light_color = Color(1, 0.2, 0.1); _blink.omni_range = 2.0; _blink.light_energy = 0.0
				add_child(_blink)
			"molotov":
				mi.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.1), Vector2(0.04, -0.1), Vector2(0.042, 0.02), Vector2(0.015, 0.07), Vector2(0.013, 0.12), Vector2(0.0, 0.12)]), 10)
				mi.material_override = Mats.glass()
				var rag := MeshInstance3D.new()
				rag.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.11), Vector2(0.02, 0.12), Vector2(0.01, 0.17), Vector2(0.0, 0.18)]), 6)
				rag.material_override = Mats.flat(Color(0.6, 0.55, 0.45), 0.95)
				add_child(rag)
				var fl := Fire._flames(rag, 0.02, 6); fl.position.y = 0.17
				fl.scale_amount_min = 0.15; fl.scale_amount_max = 0.3
				mass = 0.7
			"hopwire":
				mi.mesh = MeshKit.combine([[MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.05, -0.03), Vector2(0.055, 0.0), Vector2(0.05, 0.03), Vector2(0.0, 0.05)]), 12), Transform3D()],
					[MeshKit.cylinder(0.058, 0.012, 12), Transform3D()]])
				mi.material_override = Mats.prop("steel", 10.0, Color(0.6, 0.62, 0.66))
				mass = 0.6
				fuse = 1.1
			"bugbait":
				mi.mesh = _bugbait_mesh()
				mi.material_override = Mats.prop("rubber", 6.0, Color(0.55, 0.6, 0.3))
				mass = 0.3
			"slam":
				mi.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.12, 0.05, 0.16), 0.01), Transform3D()],
					[MeshKit.bevel_box(Vector3(0.05, 0.02, 0.05), 0.005, 1), Transform3D(Basis(), Vector3(0, 0.03, 0.03))]])
				mi.material_override = Mats.prop("polymer", 8.0, Color(0.5, 0.55, 0.45))
				sp.radius = 0.07
				mass = 0.8
				_blink = OmniLight3D.new(); _blink.light_color = Color(0.2, 1.0, 0.3); _blink.omni_range = 1.5; _blink.light_energy = 0.0
				add_child(_blink)
				add_to_group("slam_remote")
		cs.shape = sp
		add_child(cs)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		body_entered.connect(_on_body)

	func _on_body(other: Node) -> void:
		if _dead:
			return
		var spd := linear_velocity.length()
		match kind:
			"grenade", "hopwire":
				if spd > 1.5:
					AudioBus.play_3d("grenade_bounce", global_position, -6.0, 0.15)
			"molotov":
				if spd > 2.0 or other.is_in_group("enemy"):
					_dead = true
					AudioBus.play_3d("molotov_break", global_position, 2.0, 0.1)
					Fire.area(global_position, 2.8, 7.0, source, 16.0)
					if other.is_in_group("enemy"):
						Fire.ignite(other, 7.0, source)
					Effects.burst(global_position, Vector3.UP, Color(1.0, 0.6, 0.2), 20, false, 1.4)
					queue_free()
			"bugbait":
				if spd > 1.0 or other.is_in_group("enemy"):
					_dead = true
					AudioBus.play_3d("bugbait_splat", global_position, 0.0, 0.1)
					Effects.burst(global_position, Vector3.UP, Color(0.6, 0.75, 0.25), 22, false, 1.2)
					# feromônio: atrai inimigos ao ponto do impacto e marca o atingido como alvo
					Game.emit_noise(global_position, 35.0, null)
					if other.is_in_group("enemy"):
						other.set_meta("pheromone_t", Time.get_ticks_msec() + 12000)
					queue_free()
			"slam":
				if not _stuck and other is StaticBody3D:
					_stick()

	static func _bugbait_mesh() -> Mesh:
		# casulo orgânico com lóbulos (isca de feromônio)
		var parts := [[MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.06), Vector2(0.04, -0.045), Vector2(0.05, 0.0), Vector2(0.038, 0.045), Vector2(0.0, 0.065)]), 10), Transform3D()]]
		for i in 5:
			var a := TAU * i / 5.0
			parts.append([MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.018, -0.01), Vector2(0.016, 0.015), Vector2(0.0, 0.025)]), 6), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.04, 0.01 * (i % 2), sin(a) * 0.04))])
		return MeshKit.combine(parts)

	## S.L.A.M.: gruda na superfície; se foi colocado à mão (fixado com mira à parede), vira mina de laser.
	func _stick() -> void:
		_stuck = true
		freeze = true
		AudioBus.play_3d("slam_place", global_position, -4.0)

	func place_as_tripmine(pos: Vector3, normal: Vector3) -> void:
		_stuck = true
		freeze = true
		remove_from_group("slam_remote")
		global_position = pos + normal * 0.03
		look_at(global_position + normal, Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD)
		rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		AudioBus.play_3d("slam_place", global_position, -4.0)
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + normal * 10.0, 1)
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		_beam_len = (h["position"] - global_position).length() if not h.is_empty() else 10.0
		_beam = MeshInstance3D.new()
		_beam.mesh = MeshKit.cylinder(0.004, _beam_len, 4)
		_beam.material_override = Mats.emissive(Color(0.2, 0.6, 1.0), 2.5)
		_beam.position = Vector3(0, _beam_len * 0.5, 0)
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam)
		set_meta("normal", normal)
		_armed_t = 1.2

	func detonate_remote() -> void:
		if not _dead and kind == "slam" and _beam == null:
			_explode(4.5, 150.0)

	func _physics_process(delta: float) -> void:
		if _dead:
			return
		fuse -= delta
		_tick -= delta
		match kind:
			"grenade":
				if _blink:
					_blink.light_energy = 1.5 if fmod(fuse, 0.5 if fuse > 1.0 else 0.2) < 0.08 else 0.0
				if fuse <= 0.0:
					_explode(5.0, 110.0)
			"hopwire":
				_hopwire(delta)
			"slam":
				if _blink:
					_blink.light_energy = 0.8 if fmod(Time.get_ticks_msec() * 0.001, 1.0) < 0.1 else 0.0
				if _beam:
					_armed_t -= delta
					if _armed_t <= 0.0 and _tick <= 0.0:
						_tick = 0.05
						var nrm: Vector3 = get_meta("normal")
						var q := PhysicsRayQueryParameters3D.create(global_position + nrm * 0.05, global_position + nrm * _beam_len, 2 | 4 | 8)
						q.exclude = [get_rid()]
						var h := get_world_3d().direct_space_state.intersect_ray(q)
						if not h.is_empty():
							_explode(4.5, 150.0)

	## Hopwire: quica, salta ~1,6 m e dispara 7 cabos que se prendem às superfícies próximas.
	## Quem cruzar um cabo detona a carga (com os cabos).
	func _hopwire(_delta: float) -> void:
		if _hop_state == 0 and fuse <= 0.0 and linear_velocity.length() < 2.0:
			_hop_state = 1
			freeze = true
			AudioBus.play_3d("hopwire_deploy", global_position, 0.0)
			var tw := create_tween()
			tw.tween_property(self, "global_position", global_position + Vector3.UP * 1.4, 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_shoot_wires)
		elif _hop_state == 2 and _tick <= 0.0:
			_tick = 0.08
			var bodies: Array = get_tree().get_nodes_in_group("enemy").duplicate()
			if is_instance_valid(Game.player) and _armed_t <= 0.0:
				bodies.append(Game.player)
			for e in bodies:
				if not (e is Node3D) or e.get("alive") == false:
					continue
				var p: Vector3 = e.global_position + Vector3.UP * 0.9
				if p.distance_to(global_position) > 9.0:
					continue
				for w in _wires:
					if _seg_dist(p, w[0], w[1]) < 0.45:
						AudioBus.play_3d("hopwire_wire", global_position, 2.0)
						_explode(4.5, 160.0)
						return
		if _hop_state == 2:
			_armed_t -= _delta

	func _shoot_wires() -> void:
		_hop_state = 2
		_armed_t = 2.0     # o jogador tem 2 s para sair de perto antes dos cabos o considerarem
		_wire_root = Node3D.new()
		Effects._world().add_child(_wire_root)
		var space := get_world_3d().direct_space_state
		var parts := []
		for i in 7:
			var a := TAU * float(i) / 7.0 + randf() * 0.3
			var d := Vector3(cos(a), randf_range(-0.55, 0.25), sin(a)).normalized()
			var q := PhysicsRayQueryParameters3D.create(global_position, global_position + d * 7.0, 1)
			var h := space.intersect_ray(q)
			var end: Vector3 = h["position"] if not h.is_empty() else global_position + d * 7.0
			_wires.append([global_position, end])
			var len := global_position.distance_to(end)
			var b := Basis.looking_at((end - global_position).normalized(), Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
			parts.append([MeshKit.cylinder(0.006, len, 4), Transform3D(b, (global_position + end) * 0.5)])
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.combine(parts)
		mi.material_override = Mats.emissive(Color(0.7, 0.8, 1.0), 1.4)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wire_root.add_child(mi)
		AudioBus.play_3d("hopwire_wire", global_position, -2.0)

	static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return p.distance_to(a + ab * t)

	func _explode(r: float, dmg: float) -> void:
		if _dead:
			return
		_dead = true
		Effects.explosion(global_position, r, dmg, source if kind != "slam" else null)
		if is_instance_valid(_wire_root):
			_wire_root.queue_free()
		queue_free()

	## Explosões próximas detonam granadas/S.L.A.M. em cadeia.
	func take_hit(_d: float, _p: Vector3, _dir: Vector3, _s: Node = null, type := "bullet") -> void:
		if type in ["explosion", "bullet"] and kind in ["grenade", "slam", "hopwire"]:
			call_deferred("_explode", 4.5, 120.0)
