class_name Crawler
extends CharacterBody3D
## "Rastejador": criatura original do Ermo (seis patas, carapaça segmentada). Inspirada nas
## criaturas de areia/costa do conceito do HL2 beta, mas com design próprio.
## Comportamento: vagueia perto do ninho; ao perceber o jogador (visão 25 m ou ruído) corre até
## ele (7 m/s, NavigationAgent3D com fallback em linha reta) e dá um bote (salto) que causa dano.
## Frágil (35 de vida); atropelável; lâminas de serra arremessadas o cortam ao meio.

signal died_signal(n: Node)

var health := 35.0
var alive := true
var speed := 7.0
var view_dist := 25.0
var leap_damage := 10.0
var bite_damage := 6.0
var home := Vector3.INF
var agent: NavigationAgent3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var aware := false
var _legs: Array[Node3D] = []
var _body: Node3D
var _gait := 0.0
var _think := 0.0
var _leap_cd := 1.0
var _leaping := false
var _leap_hit := false
var _bite_cd := 0.0
var _idle_snd := 2.0
var _wander := Vector3.INF
var _dead_t := 0.0
var _seed := 0

static func make(seed_v := 0) -> Crawler:
	var c := Crawler.new()
	c._seed = seed_v
	return c

func _init() -> void:
	collision_layer = 8
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("crawler")
	set_meta("surface", "flesh")
	if home == Vector3.INF:
		home = global_position
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new(); sh.radius = 0.38; sh.height = 1.3
	cs.shape = sh; cs.rotation.x = PI * 0.5; cs.position.y = 0.42
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.radius = 0.4; agent.height = 0.8
	agent.path_desired_distance = 0.8; agent.target_desired_distance = 0.8
	add_child(agent)
	_build()
	Game.noise_emitted.connect(_on_noise)
	_think = randf() * 0.3
	_idle_snd = randf_range(1.0, 6.0)

func _build() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = _seed
	var shell := Mats.prop("cracked_earth", 1.5, Color(0.75, 0.62, 0.5).lerp(Color(0.55, 0.5, 0.42), rng.randf()))
	var flesh := Mats.flat(Color(0.45, 0.25, 0.2), 0.5)
	var dark := Mats.flat(Color(0.12, 0.1, 0.08), 0.6)
	_body = Node3D.new(); _body.position.y = 0.45; add_child(_body)
	# carapaça: 4 segmentos sobrepostos (lathe achatado), cabeça com mandíbulas
	for i in 4:
		var m := MeshInstance3D.new()
		var r := 0.36 - i * 0.05
		m.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(r, 0.0), Vector2(r * 0.9, 0.12), Vector2(r * 0.4, 0.2), Vector2(0.0, 0.21)]), 10)
		m.material_override = shell
		m.scale = Vector3(1.0, 1.0, 0.8)
		m.position = Vector3(0, 0.02 - i * 0.02, 0.05 + i * 0.26)
		_body.add_child(m)
	var belly := MeshInstance3D.new()
	belly.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.2, -0.35), Vector2(0.24, 0.3), Vector2(0.1, 0.65), Vector2(0.0, 0.7)]), 8)
	belly.material_override = flesh
	belly.rotation.x = PI * 0.5
	belly.position = Vector3(0, -0.05, 0.3)
	belly.scale = Vector3(1.0, 1.0, 0.6)
	_body.add_child(belly)
	var head := MeshInstance3D.new()
	head.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.2, 0.05), Vector2(0.22, 0.2), Vector2(0.12, 0.34), Vector2(0.0, 0.36)]), 8)
	head.material_override = shell
	head.rotation.x = -PI * 0.5
	head.position = Vector3(0, 0.0, -0.12)
	_body.add_child(head)
	for s in [-1.0, 1.0]:
		var mand := MeshInstance3D.new()
		mand.mesh = MeshKit.pipe(PackedVector3Array([Vector3(s * 0.1, -0.02, -0.4), Vector3(s * 0.16, -0.04, -0.58), Vector3(s * 0.05, -0.05, -0.7)]), 0.025, 5)
		mand.material_override = dark
		_body.add_child(mand)
		var eye := MeshInstance3D.new()
		eye.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0.01), Vector2(0, 0.04)]), 6)
		eye.material_override = Mats.emissive(Color(0.9, 0.7, 0.2), 1.5)
		eye.position = Vector3(s * 0.09, 0.1, -0.38)
		_body.add_child(eye)
	# seis patas articuladas (fêmur + tíbia), animadas por marcha trípode
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.22, 0.0, -0.05 + row * 0.32)
		hip.rotation.y = side * (0.35 - row * 0.35) + (PI if side < 0 else 0.0)
		_body.add_child(hip)
		var femur := MeshInstance3D.new()
		femur.mesh = MeshKit.pipe(PackedVector3Array([Vector3.ZERO, Vector3(0.38, 0.22, 0)]), 0.035, 5)
		femur.material_override = shell
		hip.add_child(femur)
		var knee := Node3D.new(); knee.name = "Knee"; knee.position = Vector3(0.38, 0.22, 0)
		hip.add_child(knee)
		var tibia := MeshInstance3D.new()
		tibia.mesh = MeshKit.pipe(PackedVector3Array([Vector3.ZERO, Vector3(0.22, -0.4, 0), Vector3(0.26, -0.66, 0)]), 0.025, 5)
		tibia.material_override = dark
		knee.add_child(tibia)
		hip.set_meta("phase", 0.0 if i in [0, 3, 4] else PI)
		_legs.append(hip)

func aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.45

func take_hit(dmg: float, pos: Vector3, dir: Vector3, src: Node = null, type := "bullet") -> void:
	if not alive:
		return
	health -= dmg
	aware = true
	Effects.burst(pos, -dir if dir.length() > 0.1 else Vector3.UP, Color(0.55, 0.5, 0.15), 8, false, 0.6)
	velocity += dir.normalized() * minf(dmg * 0.15, 6.0)
	if health <= 0.0:
		_die(dir)
	elif src == Game.player:
		AudioBus.play_3d("crawler_idle", global_position, -2.0, 0.2)

func take_damage(amount: float, pos: Vector3 = Vector3.ZERO, type := "bullet") -> void:
	take_hit(amount, pos, Vector3.UP, null, type)

func _die(dir: Vector3) -> void:
	alive = false
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 1
	AudioBus.play_3d("crawler_death", global_position, 0.0, 0.15)
	Effects.burst(global_position + Vector3.UP * 0.4, Vector3.UP, Color(0.55, 0.5, 0.15), 18, false, 1.0)
	velocity = dir.normalized() * 3.0 + Vector3.UP * 2.0
	died_signal.emit(self)

func _on_noise(pos: Vector3, radius: float, src: Node) -> void:
	if not alive or src == null or not (src is Player or src == Game.player):
		return
	if pos.distance_to(global_position) < radius * 1.2:
		aware = true

func _physics_process(delta: float) -> void:
	if not alive:
		_dead_t += delta
		velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, delta * 4); velocity.z = move_toward(velocity.z, 0, delta * 4)
		move_and_slide()
		_body.rotation.z = lerpf(_body.rotation.z, PI, clampf(delta * 5.0, 0, 1))
		for l in _legs:
			l.rotation.z = lerpf(l.rotation.z, 0.9, delta * 3.0)
		if _dead_t > 12.0:
			queue_free()
		return
	var pl: Node3D = Game.player if is_instance_valid(Game.player) else null
	_leap_cd -= delta
	_bite_cd -= delta
	_idle_snd -= delta
	if _idle_snd <= 0.0:
		_idle_snd = randf_range(3.0, 7.0) if not aware else randf_range(1.2, 2.6)
		AudioBus.play_3d("crawler_idle", global_position, -8.0 if not aware else -3.0, 0.25, 35.0)
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		if pl and pl.alive and not aware:
			var d := global_position.distance_to(pl.global_position)
			if d < view_dist and _los(pl):
				aware = true
				AudioBus.play_3d("crawler_attack", global_position, -4.0, 0.2)
		if aware and pl:
			agent.target_position = pl.global_position
		elif not aware:
			if _wander == Vector3.INF or global_position.distance_to(_wander) < 1.0 or randf() < 0.05:
				_wander = home + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			agent.target_position = _wander
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	if _leaping:
		if pl and not _leap_hit and global_position.distance_to(pl.global_position) < 1.5:
			_leap_hit = true
			_hurt_player(pl, leap_damage)
		if on_floor and velocity.y <= 0.0:
			_leaping = false
		move_and_slide()
		_animate(delta, 0.0)
		return
	var want := Vector3.ZERO
	var spd := speed if aware else 1.6
	if aware and pl:
		var to := pl.global_position - global_position
		var d := to.length()
		if d < 4.0 and d > 1.6 and _leap_cd <= 0.0 and on_floor:
			_leaping = true
			_leap_hit = false
			_leap_cd = randf_range(1.4, 2.2)
			var hd := Vector3(to.x, 0, to.z).normalized()
			velocity = hd * 9.0 + Vector3.UP * 4.2
			AudioBus.play_3d("crawler_attack", global_position, 0.0, 0.15)
			move_and_slide()
			return
		if d < 1.6:
			if _bite_cd <= 0.0:
				_bite_cd = 0.8
				_hurt_player(pl, bite_damage)
			want = Vector3.ZERO
			_face(to, delta)
		else:
			want = _nav_dir(pl.global_position)
	else:
		want = _nav_dir(agent.target_position)
	velocity.x = lerpf(velocity.x, want.x * spd, clampf(delta * 8.0, 0, 1))
	velocity.z = lerpf(velocity.z, want.z * spd, clampf(delta * 8.0, 0, 1))
	if want.length() > 0.1:
		_face(want, delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _nav_dir(goal: Vector3) -> Vector3:
	var nxt := agent.get_next_path_position()
	var dir := nxt - global_position
	dir.y = 0
	if dir.length() < 0.2 or agent.is_navigation_finished():
		dir = goal - global_position
		dir.y = 0
	return dir.normalized() if dir.length() > 0.3 else Vector3.ZERO

func _face(dir: Vector3, delta: float) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 10.0, 0, 1))

func _los(pl: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, pl.global_position + Vector3.UP * 1.2, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _hurt_player(pl: Node, dmg: float) -> void:
	if pl.get("vehicle") != null:
		var v = pl.vehicle
		if v is Vehicle and v.speed > 4.0:
			return
		dmg *= 0.5
	pl.take_damage(dmg, global_position, "melee")
	AudioBus.play_3d("impact_flesh", pl.global_position + Vector3.UP, -2.0)

func _animate(delta: float, spd: float) -> void:
	_gait += delta * (4.0 + spd * 2.6)
	var amp := clampf(spd / 3.0, 0.15, 1.0)
	for l in _legs:
		var ph: float = l.get_meta("phase")
		l.rotation.z = sin(_gait + ph) * 0.25 * amp
		l.rotation.x = cos(_gait + ph) * 0.18 * amp
	_body.position.y = 0.45 + absf(sin(_gait * 2.0)) * 0.03 * amp
	if _leaping:
		_body.rotation.x = -0.35
	else:
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, clampf(delta * 6.0, 0, 1))
