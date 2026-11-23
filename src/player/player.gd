class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa: caminhar/correr/agachar/pular, escadas de mão, balanço de câmera,
## passos por material, saúde/filtro da máscara, lanterna, interação e transporte físico de objetos.

signal health_changed(hp: float, filter: float)
signal interact_hint(text: String)
signal died

const WALK := 4.2
const RUN := 6.8
const CROUCH := 2.2
const ACCEL := 12.0
const AIR_ACCEL := 2.5
const JUMP_V := 4.6
const STAND_H := 1.75
const CROUCH_H := 1.05
const EYE_STAND := 1.62
const EYE_CROUCH := 0.95
const USE_DIST := 2.2
const CARRY_MAX_MASS := 45.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 100.0
var max_health := 100.0
var filter := 0.0           # proteção extra (equivalente a armadura)
var alive := true
var god := false   # usado apenas pelos testes automatizados
var input_enabled := true
var look_enabled := true
var crouching := false
var on_ladder: Area3D = null
var has_mask := false

var head: Node3D
var camera: Camera3D
var weapons: WeaponManager
var flashlight: SpotLight3D
var _shape: CapsuleShape3D
var _collider: CollisionShape3D
var _pitch := 0.0
var _bob_t := 0.0
var _step_acc := 0.0
var _land_kick := 0.0
var _recoil := Vector2.ZERO
var _shake := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _hold: RigidBody3D = null
var _hold_dist := 1.6
var _hold_prev_damp := 0.0
var _hold_manip := false
var _focus: Object = null
var _last_hint := ""
var _heart: AudioStreamPlayer
var vehicle = null   # Vehicle ou FlakTurret (interface: seat_transform, exit_vehicle, linear_velocity)
var _veh_yaw := 0.0
var in_shelter := false   # tempestade de partículas (cap. 6)
var _breath: AudioStreamPlayer

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_max_angle = deg_to_rad(46)
	floor_snap_length = 0.35
	_shape = CapsuleShape3D.new()
	_shape.radius = 0.36
	_shape.height = STAND_H
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	_collider.position.y = STAND_H * 0.5
	add_child(_collider)
	head = Node3D.new(); head.name = "Head"; head.position.y = EYE_STAND
	add_child(head)
	camera = Camera3D.new(); camera.name = "Camera"
	camera.fov = Settings.get_v("graphics", "fov", 80.0)
	camera.near = 0.04
	camera.far = Settings.get_v("graphics", "view_distance", 120.0)
	head.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 22.0; flashlight.spot_angle = 26.0; flashlight.light_energy = 2.2
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = Settings.get_v("graphics", "shadows", 1) >= 2
	flashlight.position = Vector3(0.18, -0.12, 0.0)
	flashlight.visible = false
	camera.add_child(flashlight)
	weapons = WeaponManager.new()
	weapons.name = "Weapons"
	camera.add_child(weapons)
	weapons.setup(self)
	_heart = AudioStreamPlayer.new(); _heart.bus = "SFX"; _heart.stream = AudioBus.get_stream("heartbeat"); add_child(_heart)
	_breath = AudioStreamPlayer.new(); _breath.bus = "SFX"; _breath.volume_db = -20.0
	var bs := AudioBus.get_stream("mask_breath")
	if bs is AudioStreamWAV:
		bs = bs.duplicate(); bs.loop_mode = AudioStreamWAV.LOOP_FORWARD; bs.loop_end = int(bs.get_length() * bs.mix_rate)
	_breath.stream = bs
	add_child(_breath)
	Settings.changed.connect(_on_settings)
	Game.player = self

func _on_settings(section: String) -> void:
	if section == "graphics":
		camera.fov = Settings.get_v("graphics", "fov", 80.0)
		camera.far = Settings.get_v("graphics", "view_distance", 120.0)

func set_mask(on: bool) -> void:
	has_mask = on
	if on and not _breath.playing: _breath.play()
	elif not on: _breath.stop()

# ---------------- estado (salvamento) ----------------
func get_state() -> Dictionary:
	return {"health": health, "filter": filter, "mask": has_mask, "weapons": weapons.get_state(),
		"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "pitch": _pitch}

func set_state(d: Dictionary, restore_pos := false) -> void:
	if d.is_empty():
		return
	health = float(d.get("health", 100.0))
	filter = float(d.get("filter", 0.0))
	set_mask(bool(d.get("mask", false)))
	weapons.set_state(d.get("weapons", {}))
	if restore_pos and d.has("pos"):
		global_position = Vector3(d["pos"][0], d["pos"][1], d["pos"][2])
		rotation.y = float(d.get("yaw", 0.0))
	health_changed.emit(health, filter)

# ---------------- dano / cura ----------------
func take_damage(amount: float, from: Vector3 = Vector3.ZERO, _type := "bullet") -> void:
	if not alive or god:
		return
	var absorbed := minf(filter, amount * 0.7)
	filter -= absorbed
	health -= amount - absorbed
	_shake = minf(_shake + amount * 0.02, 0.6)
	if from != Vector3.ZERO:
		var dir := (from - global_position).normalized()
		_recoil += Vector2(randf_range(-1.5, 1.5), 1.5) * clampf(amount / 15.0, 0.3, 1.5)
		get_tree().call_group("hud", "show_damage_dir", dir)
	AudioBus.play_3d("player_hurt", global_position + Vector3.UP, -4.0)
	InputRouter.vibrate(0.4, 0.6, 0.18)
	health_changed.emit(health, filter)
	if health <= 0.0:
		_die()

func heal(amount: float) -> bool:
	if health >= max_health:
		return false
	health = minf(max_health, health + amount)
	health_changed.emit(health, filter)
	return true

func add_filter(amount: float) -> bool:
	if filter >= 100.0:
		return false
	filter = minf(100.0, filter + amount)
	health_changed.emit(health, filter)
	return true

func _die() -> void:
	alive = false
	health = 0.0
	_release_hold(false)
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.25, 0.8).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(head, "rotation:z", 0.6, 0.8)
	died.emit()
	Game.on_player_died()

# ---------------- entrada ----------------
func _unhandled_input(event: InputEvent) -> void:
	if not alive or not input_enabled:
		return
	if event.is_action_pressed("use"):
		if vehicle:
			if not vehicle.exit_vehicle():
				AudioBus.play_3d("manip_deny", global_position, -14.0)
			get_viewport().set_input_as_handled()
			return
		_use()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		AudioBus.play_3d("button_press", global_position, -14.0)
	elif event.is_action_pressed("crouch"):
		if not InputRouter.device == InputRouter.Device.KBM:
			_toggle_crouch_requested = not _toggle_crouch_requested
	elif _hold and _hold_manip:
		pass  # o Manipulador trata disparo/mira enquanto segura
	elif _hold and event.is_action_pressed("fire"):
		_throw_hold()
		get_viewport().set_input_as_handled()
	elif _hold and event.is_action_pressed("aim"):
		_release_hold(true)
		get_viewport().set_input_as_handled()

var _toggle_crouch_requested := false

func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, delta * 8); velocity.z = move_toward(velocity.z, 0, delta * 8)
		move_and_slide()
		return
	_look(delta)
	if vehicle:
		_ride(delta)
	else:
		_move(delta)
	_update_hold(delta)
	_update_focus()
	_update_camera_fx(delta)
	if health < 25.0 and not _heart.playing:
		_heart.play()

func _look(delta: float) -> void:
	if not look_enabled:
		return
	var d := InputRouter.consume_look(delta)
	if weapons.is_aiming():
		d *= weapons.look_mult()
	rotate_y(deg_to_rad(-d.x))
	_pitch = clampf(_pitch - d.y, -88.0, 88.0)
	head.rotation_degrees.x = _pitch + _recoil.y
	head.rotation_degrees.y = _recoil.x * 0.3

# ---------------- veículos ----------------
func enter_vehicle(v: Node3D) -> void:
	_release_hold(true)
	vehicle = v
	_collider.disabled = true
	_set_crouch(false, 1.0)
	head.position.y = 1.08
	_prev_vyaw = v.global_rotation.y
	velocity = Vector3.ZERO
	interact_hint.emit(Loc.t("hud.exit_vehicle"))
	_last_hint = Loc.t("hud.exit_vehicle")

func exit_vehicle(at: Vector3) -> void:
	vehicle = null
	_collider.disabled = false
	global_position = at
	velocity = Vector3.ZERO
	_last_hint = ""

## Acompanha o assento; a guinada do veículo é somada à visão do jogador (câmera livre).
func _ride(_delta: float) -> void:
	if not is_instance_valid(vehicle):
		vehicle = null; _collider.disabled = false
		return
	var vy: float = vehicle.global_rotation.y
	rotation.y += wrapf(vy - _prev_vyaw, -PI, PI)
	_prev_vyaw = vy
	var st: Transform3D = vehicle.seat_transform()
	global_position = st.origin - Vector3.UP * 0.0
	velocity = vehicle.linear_velocity
	if _last_hint != Loc.t("hud.exit_vehicle") and _hold == null:
		_last_hint = Loc.t("hud.exit_vehicle")
		interact_hint.emit(_last_hint)

var _prev_vyaw := 0.0

func _move(delta: float) -> void:
	var move := InputRouter.get_move() if input_enabled else Vector2.ZERO
	var want_crouch := (Input.is_action_pressed("crouch") if InputRouter.device == InputRouter.Device.KBM else _toggle_crouch_requested) and input_enabled
	_set_crouch(want_crouch, delta)
	var sprint := Input.is_action_pressed("sprint") and move.y < -0.3 and not crouching and input_enabled
	var speed := CROUCH if crouching else (RUN if sprint else WALK)
	if weapons.is_aiming(): speed *= 0.6
	speed *= weapons.speed_mult()
	if _hold: speed *= clampf(1.0 - _hold.mass / 120.0, 0.55, 1.0)
	var dir := (transform.basis * Vector3(move.x, 0, move.y))
	dir.y = 0
	if on_ladder:
		_ladder_move(move, delta)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
		_fall_speed = minf(_fall_speed, velocity.y)
	var target := dir * speed
	var acc := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = lerpf(velocity.x, target.x, clampf(acc * delta, 0, 1))
	velocity.z = lerpf(velocity.z, target.z, clampf(acc * delta, 0, 1))
	if is_on_floor() and Input.is_action_just_pressed("jump") and input_enabled and not crouching:
		velocity.y = JUMP_V
		_footstep(0.0)
	move_and_slide()
	_push_bodies()
	if is_on_floor() and not _was_on_floor:
		_land(-_fall_speed)
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.9
		_step_acc += hspeed * delta
		var stride := 2.2 if sprint else 1.7
		if _step_acc > stride:
			_step_acc = 0.0
			_footstep(hspeed)

func _ladder_move(move: Vector2, delta: float) -> void:
	var look_up := -_pitch / 90.0
	var climb := -move.y * (1.0 if look_up > -0.3 else -1.0)
	velocity = Vector3.ZERO
	velocity.y = climb * 2.6
	velocity += transform.basis.x * move.x * 1.5
	if Input.is_action_just_pressed("jump"):
		velocity = -transform.basis.z * -3.0 + Vector3.UP * 2.0
		on_ladder = null
	move_and_slide()
	_step_acc += absf(velocity.y) * delta
	if _step_acc > 0.6:
		_step_acc = 0.0
		AudioBus.play_3d("step_metal_%d" % randi_range(0, 3), global_position, -8.0)

func _set_crouch(want: bool, delta: float) -> void:
	if not want and crouching:
		# Só levanta se houver espaço acima.
		var q := PhysicsShapeQueryParameters3D.new()
		var s := CapsuleShape3D.new(); s.radius = 0.3; s.height = STAND_H - 0.1
		q.shape = s
		q.transform = Transform3D(Basis(), global_position + Vector3.UP * (STAND_H * 0.5 + 0.06))
		q.exclude = [get_rid()]
		q.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(q, 1).size() > 0:
			want = true
	crouching = want
	var h := CROUCH_H if crouching else STAND_H
	_shape.height = move_toward(_shape.height, h, delta * 6.0)
	_collider.position.y = _shape.height * 0.5
	var eye := EYE_CROUCH if crouching else EYE_STAND
	head.position.y = move_toward(head.position.y, eye, delta * 5.0)

func _push_bodies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var b := c.get_collider()
		if b is RigidBody3D and b != _hold:
			var n := -c.get_normal()
			n.y = 0
			b.apply_central_impulse(n.normalized() * clampf(4.0 / maxf(b.mass, 1.0), 0.05, 1.5) * 0.6)

func _footstep(speed: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.6, 1 | 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var surf := Mats.surface_of(hit.get("collider")) if hit else "concrete"
	if surf == "glass": surf = "concrete"
	var vol := -10.0 if crouching else (-3.0 if speed > 6.0 else -6.0)
	AudioBus.play_3d("step_%s_%d" % [surf, randi_range(0, 3)], global_position, vol, 0.1, 30.0)
	if speed > 5.5:
		Game.emit_noise(global_position, 9.0, self)

func _land(fall_v: float) -> void:
	_land_kick = clampf(fall_v * 0.025, 0.0, 0.25)
	AudioBus.play_3d("jump_land", global_position, -4.0)
	if fall_v > 9.0:
		take_damage((fall_v - 9.0) * 9.0, Vector3.ZERO, "fall")

func add_recoil(pitch: float, yaw: float) -> void:
	_recoil += Vector2(yaw, pitch)

func shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)

func _update_camera_fx(delta: float) -> void:
	_recoil = _recoil.lerp(Vector2.ZERO, clampf(delta * 9.0, 0, 1))
	_land_kick = move_toward(_land_kick, 0.0, delta * 0.8)
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	var bob := Vector3.ZERO
	if Settings.get_v("controls", "head_bob", true) and is_on_floor():
		var amp := clampf(Vector2(velocity.x, velocity.z).length() / RUN, 0, 1)
		bob = Vector3(cos(_bob_t * 0.5) * 0.035, -absf(sin(_bob_t * 0.5)) * 0.05, 0) * amp
	camera.position = bob + Vector3(0, -_land_kick, 0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.04
	weapons.set_bob(_bob_t, Vector2(velocity.x, velocity.z).length() / RUN if is_on_floor() else 0.0)

# ---------------- interação e transporte físico ----------------
func _aim_ray(dist: float, mask := 1 | 4 | 8 | 16) -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_basis.z * dist
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = [get_rid()]
	q.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(q)

func _update_focus() -> void:
	if vehicle:
		return
	if _hold:
		var ht := Loc.t("hud.throw") + " / " + Loc.t("hud.drop")
		if ht != _last_hint:
			_last_hint = ht
			interact_hint.emit(ht)
		return
	var hit := _aim_ray(USE_DIST)
	var c: Object = hit.get("collider") if hit else null
	var target: Object = _interactable_of(c)
	_focus = target
	var txt := ""
	if target and target.has_method("get_hint"):
		txt = target.get_hint()
	elif target is RigidBody3D:
		txt = Loc.t("hud.pick")
	if txt != _last_hint:
		_last_hint = txt
		interact_hint.emit(txt)

func _interactable_of(c: Object) -> Object:
	if c == null:
		return null
	if c.has_method("interact"):
		return c
	var p: Node = c.get_parent() if c is Node else null
	if p and p.has_method("interact"):
		return p
	if c is RigidBody3D and c.mass <= CARRY_MAX_MASS and not c.freeze and not c.has_meta("no_carry"):
		return c
	return null

func _use() -> void:
	if _hold:
		_release_hold(true)
		return
	var t := _focus
	if t == null:
		AudioBus.play_3d("manip_deny", global_position, -18.0)
		return
	if t.has_method("interact"):
		t.interact(self)
	elif t is RigidBody3D:
		_pick(t)

func _pick(b: RigidBody3D) -> void:
	_hold = b
	_hold_dist = clampf(camera.global_position.distance_to(b.global_position), 1.2, 2.0)
	_hold_prev_damp = b.angular_damp
	b.angular_damp = 6.0
	b.add_collision_exception_with(self)
	weapons.holster(true)
	AudioBus.play_3d("manip_pickup", b.global_position, -10.0)

func _update_hold(delta: float) -> void:
	if _hold == null:
		return
	if not is_instance_valid(_hold) or _hold.freeze:
		if not _hold_manip: weapons.holster(false)
		_hold = null; _hold_manip = false; return
	var target := camera.global_position - camera.global_basis.z * _hold_dist
	var err := target - _hold.global_position
	if err.length() > (4.0 if _hold_manip else 2.5):
		_release_hold(false)
		return
	# Controle PD: velocidade alvo proporcional ao erro; massa reduz responsividade.
	var gain := clampf(14.0 - _hold.mass * 0.15, 5.0, 14.0)
	_hold.linear_velocity = _hold.linear_velocity.lerp(err * gain + velocity, clampf(delta * 18.0, 0, 1))
	_hold.angular_velocity = _hold.angular_velocity.lerp(Vector3.ZERO, clampf(delta * 6.0, 0, 1))

func _release_hold(gentle: bool) -> void:
	if _hold == null:
		return
	if is_instance_valid(_hold):
		_hold.angular_damp = _hold_prev_damp
		_hold.remove_collision_exception_with(self)
		if gentle:
			_hold.linear_velocity = _hold.linear_velocity.limit_length(2.0)
	_hold = null
	if not _hold_manip:
		weapons.holster(false)
	_hold_manip = false

func _throw_hold() -> void:
	var b := _hold
	_release_hold(false)
	if is_instance_valid(b):
		var force := clampf(14.0 / sqrt(maxf(b.mass, 0.5)), 2.5, 14.0)
		b.linear_velocity = -camera.global_basis.z * force * 1.6 + velocity
		b.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
		if b.has_method("on_thrown"):
			b.on_thrown(self)
		AudioBus.play_3d("manip_launch", b.global_position, -12.0)
		Game.emit_noise(global_position, 6.0, self)

func grab_with_manip(b: RigidBody3D) -> void:
	if _hold:
		_release_hold(true)
	_hold = b
	_hold_manip = true
	_hold_dist = 2.6
	_hold_prev_damp = b.angular_damp
	b.angular_damp = 6.0
	b.add_collision_exception_with(self)

func release_held() -> void:
	_release_hold(true)

## Arremesso do Manipulador: muito mais forte que o arremesso com as mãos.
func throw_held(mult := 2.4) -> void:
	var b := _hold
	_release_hold(false)
	if is_instance_valid(b):
		var spd := clampf(110.0 / sqrt(maxf(b.mass, 0.5)), 8.0, 30.0) * mult / 2.4
		b.linear_velocity = -camera.global_basis.z * spd + velocity
		b.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		if b.has_method("on_thrown"):
			b.on_thrown(self)
		AudioBus.play_3d("manip_launch", b.global_position, -2.0)
		Game.emit_noise(global_position, 10.0, self)

func is_holding() -> bool:
	return _hold != null

func eye_position() -> Vector3:
	return camera.global_position
