class_name FlakTurret
extends StaticBody3D
## Canhão antiaéreo de cais (relíquia de guerra). O jogador "monta" com usar: fica preso ao
## assento, a visão gira a torre, disparar lança granadas com espoleta de proximidade (explodem
## perto do helicóptero, ao tocar algo ou após 2,4 s). Usar de novo desmonta.

var gunner: Node = null
var rate := 0.55
var enabled := true
var shots := 0
var _cool := 0.0
var _yaw_node: Node3D
var _pitch_node: Node3D
var _muzzles: Array[Node3D] = []
var _barrel_i := 0
var seat := Vector3(0, 0.9, 1.15)
var exit_offset := Vector3(0, 0.1, 2.4)
var linear_velocity := Vector3.ZERO

func _init() -> void:
	collision_layer = 1
	set_meta("surface", "metal")

func _ready() -> void:
	add_to_group("vehicle")
	var steel := Mats.prop("steel", 2.0, Color(0.42, 0.45, 0.4))
	var paint := Mats.prop("rusted_paint", 1.5, Color(0.5, 0.58, 0.45))
	var base := MeshInstance3D.new()
	base.mesh = MeshKit.lathe(PackedVector2Array([Vector2(1.3, 0.0), Vector2(1.3, 0.25), Vector2(0.9, 0.35), Vector2(0.7, 0.7), Vector2(0.0, 0.75)]), 16)
	base.material_override = paint
	add_child(base)
	var cs := CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = 1.2; cyl.height = 0.8
	cs.shape = cyl; cs.position.y = 0.4
	add_child(cs)
	_yaw_node = Node3D.new(); _yaw_node.position.y = 0.75; add_child(_yaw_node)
	for s in [-1.0, 1.0]:
		var side := MeshInstance3D.new()
		side.mesh = MeshKit.bevel_box(Vector3(0.12, 1.0, 1.1), 0.03)
		side.material_override = paint
		side.position = Vector3(s * 0.65, 0.5, 0.0)
		_yaw_node.add_child(side)
	var seat_m := MeshInstance3D.new()
	seat_m.mesh = MeshKit.bevel_box(Vector3(0.5, 0.08, 0.45), 0.03)
	seat_m.material_override = Mats.flat(Color(0.15, 0.13, 0.1), 0.9)
	seat_m.position = Vector3(0, 0.15, 1.0)
	_yaw_node.add_child(seat_m)
	_pitch_node = Node3D.new(); _pitch_node.position = Vector3(0, 0.95, 0.0); _yaw_node.add_child(_pitch_node)
	var breech := MeshInstance3D.new()
	breech.mesh = MeshKit.bevel_box(Vector3(1.0, 0.45, 0.9), 0.06)
	breech.material_override = steel
	_pitch_node.add_child(breech)
	for s in [-0.28, 0.28]:
		var b := MeshInstance3D.new()
		b.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.09, 0.0), Vector2(0.075, 0.4), Vector2(0.06, 2.3), Vector2(0.085, 2.35), Vector2(0.085, 2.6), Vector2(0.06, 2.62)]), 10)
		b.material_override = steel
		b.rotation.x = -PI * 0.5
		b.position = Vector3(s, 0.05, -0.3)
		_pitch_node.add_child(b)
		var mz := Node3D.new(); mz.position = Vector3(s, 0.05, -2.95)
		_pitch_node.add_child(mz)
		_muzzles.append(mz)
	var sight := MeshInstance3D.new()
	sight.mesh = MeshKit.pipe(PackedVector3Array([Vector3(-0.15, 0.4, -0.5), Vector3(-0.15, 0.55, -0.5), Vector3(0.15, 0.55, -0.5), Vector3(0.15, 0.4, -0.5)]), 0.012, 6)
	sight.material_override = steel
	_pitch_node.add_child(sight)

func get_hint() -> String:
	return Loc.t("hud.turret") if gunner == null and enabled else ""

func interact(by: Node) -> void:
	if gunner == null and enabled and by is Player:
		gunner = by
		by.enter_vehicle(self)
		by.weapons.holster(true)
		AudioBus.play_3d("lever", global_position, -4.0)

func exit_vehicle(_force := false) -> bool:
	if gunner == null:
		return false
	var p := gunner
	gunner = null
	p.exit_vehicle(global_transform * Transform3D(_yaw_node.transform.basis, Vector3.ZERO) * exit_offset)
	p.weapons.holster(false)
	return true

func seat_transform() -> Transform3D:
	var b := Basis(Vector3.UP, _yaw_node.rotation.y)
	return Transform3D(Basis(), global_position + b * seat)

func _physics_process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if gunner == null or not is_instance_valid(gunner):
		gunner = null
		return
	# a torre segue a visão do atirador
	var cam: Camera3D = gunner.camera
	var fwd := -cam.global_basis.z
	_yaw_node.global_rotation.y = atan2(-fwd.x, -fwd.z)
	_pitch_node.rotation.x = clampf(asin(clampf(fwd.y, -1.0, 1.0)), -0.15, 1.35)
	if gunner.input_enabled and Input.is_action_pressed("fire") and _cool <= 0.0:
		fire(cam.global_position + fwd * 3.2, fwd)

func fire(from: Vector3, dir: Vector3) -> void:
	_cool = rate
	shots += 1
	var mz: Node3D = _muzzles[_barrel_i % 2]
	_barrel_i += 1
	var sh := FlakShell.new()
	sh.dir = dir
	sh.source = gunner
	(Game.level if is_instance_valid(Game.level) else get_parent()).add_child(sh)
	sh.global_position = from
	AudioBus.play_3d("flak_fire", mz.global_position, 4.0, 0.06, 200.0)
	Effects.burst(mz.global_position, dir, Color(1.0, 0.7, 0.3), 10, true, 1.2)
	if gunner:
		gunner.shake(0.25)
		gunner.add_recoil(1.6, randf_range(-0.4, 0.4))
	InputRouter.vibrate(0.5, 0.5, 0.12)

## Granada de flak: voa reto (sem gravidade, é rápida), testa colisão por raio a cada passo
## e explode por proximidade de helicópteros.
class FlakShell extends Node3D:
	var dir := Vector3.FORWARD
	var speed := 110.0
	var life := 2.4
	var source: Node = null
	var _mesh: MeshInstance3D
	func _ready() -> void:
		_mesh = MeshInstance3D.new()
		_mesh.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0, -0.6), Vector2(0.06, -0.4), Vector2(0.06, 0.2), Vector2(0, 0.3)]), 6)
		_mesh.material_override = Mats.emissive(Color(1.0, 0.8, 0.4), 4.0)
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh)
		look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
		_mesh.rotation.x = -PI * 0.5
	func _physics_process(delta: float) -> void:
		life -= delta
		var step := dir * speed * delta
		var from := global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + step, 1 | 4 | 8)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			_boom(hit.position)
			return
		global_position = from + step
		for h in get_tree().get_nodes_in_group("heli"):
			if h.alive and h.global_position.distance_to(global_position) < 5.0:
				_boom(global_position)
				return
		if life <= 0.0:
			_boom(global_position)
	func _boom(p: Vector3) -> void:
		var near_player = is_instance_valid(Game.player) and Game.player.global_position.distance_to(p) < 9.0
		Effects.explosion(p, 6.0, 140.0 if not near_player else 40.0, source)
		queue_free()
