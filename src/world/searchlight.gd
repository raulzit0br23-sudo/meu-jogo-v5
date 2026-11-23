class_name Searchlight
extends Node3D
## Holofote giratório: varre um arco; se o jogador ficar dentro do cone com linha de visão
## por tempo suficiente, emite "spotted". Checagem a 6 Hz para economizar CPU no celular.

signal spotted(pos: Vector3)
var light: SpotLight3D
var beam: MeshInstance3D
var sweep_center := 0.0
var sweep_arc := 1.2
var sweep_speed := 0.32
var pitch := -0.55
var range_m := 46.0
var angle_deg := 9.0
var enabled := true
var _t := 0.0
var _check := 0.0
var _exposure := 0.0

func _ready() -> void:
	light = SpotLight3D.new()
	light.spot_range = range_m
	light.spot_angle = angle_deg
	light.light_energy = 9.0
	light.light_color = Color(0.85, 0.95, 1.0)
	light.spot_attenuation = 0.6
	add_child(light)
	# feixe volumétrico falso (cone aditivo, barato)
	beam = MeshInstance3D.new()
	var r := tan(deg_to_rad(angle_deg)) * range_m * 0.7
	beam.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(r, range_m * 0.7), Vector2(0.0, range_m * 0.7)]), 14, false, false)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.5, 0.6, 0.7, 0.06)
	beam.material_override = m
	beam.rotation.x = -PI * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(beam)
	var head := MeshInstance3D.new()
	head.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.5), Vector2(0.45, -0.45), Vector2(0.5, 0.2), Vector2(0.42, 0.25), Vector2(0.0, 0.25)]), 14)
	head.material_override = Mats.flat(Color(0.18, 0.19, 0.2), 0.5, 0.7)
	head.rotation.x = -PI * 0.5
	light.add_child(head)

func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	var yaw := sweep_center + sin(_t * sweep_speed * TAU / (sweep_arc * 2.0 + 0.001)) * sweep_arc
	light.rotation = Vector3(pitch, yaw, 0)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.16
	var p: Node3D = Game.player if is_instance_valid(Game.player) else null
	if p == null:
		return
	var eye: Vector3 = p.global_position + Vector3.UP * 1.0
	var to := eye - light.global_position
	var dist := to.length()
	var fwd := -light.global_basis.z
	var inside := dist < range_m and fwd.dot(to / dist) > cos(deg_to_rad(angle_deg * 1.15))
	if inside:
		var q := PhysicsRayQueryParameters3D.create(light.global_position, eye, 1)
		inside = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_exposure = clampf(_exposure + (0.16 if inside else -0.08), 0.0, 1.0)
	if inside:
		light.light_color = Color(1.0, 0.55, 0.4).lerp(Color(0.85, 0.95, 1.0), 1.0 - _exposure)
	if _exposure >= 0.5:
		_exposure = 0.0
		spotted.emit(p.global_position)
