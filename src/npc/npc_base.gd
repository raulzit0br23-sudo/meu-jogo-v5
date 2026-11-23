class_name NpcBase
extends CharacterBody3D
## Base comum de personagens: corpo Humanoid, navegação (NavigationAgent3D), locomoção com
## aceleração, orientação suave, dano, morte com ragdoll e fala posicional com lip-sync gestual.

signal died_signal(npc: Node)

var body: Humanoid
var agent: NavigationAgent3D
var voice: AudioStreamPlayer3D
var health := 60.0
var alive := true
var move_speed := 0.0
var face_dir := Vector3.ZERO     # direção desejada do olhar (horizontal)
var _goal := Vector3.INF
var _goal_speed := 0.0
var _arrive_cb: Callable
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var npc_id := ""
var _talk_env := 0.0

func setup_body(outfit: String, seed_v: int) -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.32; cap.height = 1.8
	cs.shape = cap; cs.position.y = 0.9
	add_child(cs)
	body = Humanoid.new(outfit, seed_v)
	body.name = "Body"
	add_child(body)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.5
	agent.radius = 0.35
	agent.height = 1.8
	agent.avoidance_enabled = false
	add_child(agent)
	voice = AudioStreamPlayer3D.new()
	voice.bus = "Voice"
	voice.unit_size = 6.0
	voice.max_distance = 40.0
	voice.position.y = 1.6
	add_child(voice)
	floor_snap_length = 0.4

func go_to(p: Vector3, spd := 1.6, cb := Callable()) -> void:
	_goal = p
	_goal_speed = spd
	_arrive_cb = cb
	agent.target_position = p

func stop_moving() -> void:
	_goal = Vector3.INF
	_goal_speed = 0.0

func has_arrived() -> bool:
	return _goal == Vector3.INF

func _nav_step(delta: float) -> void:
	var desired := Vector3.ZERO
	if _goal != Vector3.INF:
		var flat := Vector3(_goal.x - global_position.x, 0, _goal.z - global_position.z)
		if flat.length() < 0.55:
			stop_moving()
			if _arrive_cb.is_valid():
				var cb := _arrive_cb
				_arrive_cb = Callable()
				cb.call()
		else:
			var nxt := agent.get_next_path_position()
			var d := nxt - global_position
			d.y = 0
			# Se a malha de navegação não tiver rota, segue em linha reta (fallback).
			if d.length() < 0.05 or agent.is_navigation_finished():
				d = flat
			desired = d.normalized() * _goal_speed
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(desired, clampf(delta * 6.0, 0, 1))
	velocity.x = hv.x; velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	move_speed = hv.length()
	var look := face_dir if face_dir != Vector3.ZERO else hv
	look.y = 0
	if look.length() > 0.1:
		var target_yaw := atan2(look.x, look.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 6.0, 0, 1))
	if body:
		body.speed = move_speed
		# energia de fala: envelope do barramento de voz quando este NPC está falando
		var e := AudioBus.voice_energy() if voice.playing else 0.0
		_talk_env = lerpf(_talk_env, e, clampf(delta * 14.0, 0, 1))
		body.talk = clampf(_talk_env * 3.0, 0.0, 1.0) if voice.playing else move_toward(body.talk, 0.0, delta * 3.0)
		body.animate(delta)

func speak(stream: AudioStream) -> void:
	voice.stream = stream
	voice.play()

func stop_voice() -> void:
	voice.stop()

func take_hit(damage: float, pos: Vector3, dir: Vector3, source: Node = null, type := "bullet") -> void:
	if not alive:
		return
	if type == "bullet" and pos.y > global_position.y + 1.5:
		damage *= 2.0     # tiro na cabeça
	health -= damage
	if body:
		body.flinch(dir)
	Effects.burst(pos, -dir, Color(0.35, 0.03, 0.02), 8, false, 0.6)
	_on_hurt(damage, source, type)
	if health <= 0.0:
		die(dir * clampf(damage * 0.9, 20.0, 160.0), pos)

func _on_hurt(_dmg: float, _src: Node, _type: String) -> void:
	pass

func die(impulse: Vector3, pos: Vector3) -> void:
	if not alive:
		return
	alive = false
	voice.stop()
	collision_layer = 0
	collision_mask = 1
	set_physics_process(false)
	died_signal.emit(self)
	_on_died()
	body.ragdoll(impulse, pos, velocity)

func _on_died() -> void:
	pass

func aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.3
