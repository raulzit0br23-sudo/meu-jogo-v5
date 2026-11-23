class_name MenuBackdrop
extends Node3D
## Cenário 3D do menu principal: pátio ferroviário sob névoa ao anoitecer, com a silhueta de um
## Trocador Atmosférico ao fundo (luzes piscando) e a câmera em lento travelling.

var _cam: Camera3D
var _t := 0.0
var _blink: Array[OmniLight3D] = []

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.17, 0.19, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.33, 0.34)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.22, 0.23)
	env.fog_density = 0.022
	env.fog_height = 6.0
	env.fog_height_density = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, 140, 0)
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.light_energy = 0.6
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = MeshKit.terrain(Vector2(220, 220), 40, func(x: float, z: float) -> float: return (sin(x * 0.05) * 0.4 + cos(z * 0.07) * 0.3 + 0.3) * clampf((absf(x - (-1.0)) - 9.0) / 10.0, 0.0, 1.0))
	ground.material_override = Mats.get_mat("cracked_earth", 0.08, Color(0.7, 0.68, 0.62))
	add_child(ground)
	var steel := Mats.get_mat("steel", 1.0, Color(0.55, 0.5, 0.45))
	var wood := Mats.get_mat("wood", 1.0, Color(0.5, 0.42, 0.35))
	for track in 3:
		var x := -6.0 + track * 5.0
		for side in [-0.75, 0.75]:
			var r := MeshInstance3D.new()
			r.mesh = MeshKit.bevel_box(Vector3(0.12, 0.16, 200), 0.02, 1)
			r.material_override = steel
			r.position = Vector3(x + side, 0.25, -60)
			add_child(r)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = MeshKit.bevel_box(Vector3(2.4, 0.16, 0.26), 0.03, 1)
		mm.instance_count = 140
		for i in 140:
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf_range(-0.04, 0.04)), Vector3(x, 0.12, 40 - i * 1.4)))
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = wood
		add_child(mmi)
	# vagões abandonados
	var rust := Mats.get_mat("rusted_paint", 0.6, Color(0.6, 0.5, 0.42))
	for i in 4:
		var w := MeshInstance3D.new()
		w.mesh = MeshKit.bevel_box(Vector3(2.9, 3.2, 13.0), 0.12)
		w.material_override = rust
		w.position = Vector3(4.0 if i % 2 == 0 else -6.0, 2.0, -18.0 - i * 16.0)
		w.rotation.y = randf_range(-0.02, 0.02)
		add_child(w)
	# postes de sódio
	for i in 6:
		var p := Node3D.new()
		p.position = Vector3(-1.5, 0, -4 - i * 18)
		var pole := MeshInstance3D.new(); pole.mesh = MeshKit.cylinder(0.09, 7.0, 8); pole.position.y = 3.5; pole.material_override = steel
		p.add_child(pole)
		var lamp := MeshInstance3D.new(); lamp.mesh = MeshKit.bevel_box(Vector3(0.5, 0.15, 0.3), 0.04, 1); lamp.position = Vector3(0.3, 7.0, 0)
		lamp.material_override = Mats.emissive(Color(1.0, 0.6, 0.25), 3.0)
		p.add_child(lamp)
		var l := OmniLight3D.new(); l.position = Vector3(0.3, 6.6, 0); l.light_color = Color(1.0, 0.62, 0.3); l.omni_range = 11.0; l.light_energy = 1.6
		p.add_child(l)
		add_child(p)
	# Trocador Atmosférico: torre colossal com nervuras e chaminés
	var tower := Node3D.new()
	tower.position = Vector3(30, 0, -150)
	add_child(tower)
	var dark := Mats.flat(Color(0.12, 0.13, 0.14), 0.6, 0.5)
	var body := MeshInstance3D.new()
	body.mesh = MeshKit.lathe(PackedVector2Array([Vector2(26, 0), Vector2(22, 20), Vector2(15, 60), Vector2(12, 95), Vector2(16, 102), Vector2(9, 112), Vector2(4, 130)]), 24)
	body.material_override = dark
	tower.add_child(body)
	for i in 8:
		var a := TAU * i / 8.0
		var rib := MeshInstance3D.new()
		rib.mesh = MeshKit.bevel_box(Vector3(2.0, 105, 3.0), 0.3)
		rib.material_override = dark
		rib.position = Vector3(cos(a) * 17.0, 50, sin(a) * 17.0)
		rib.rotation = Vector3(0, -a, 0.12 * (1 if i % 2 == 0 else -1))
		tower.add_child(rib)
		var bl := OmniLight3D.new()
		bl.light_color = Color(1.0, 0.2, 0.1); bl.omni_range = 18.0; bl.light_energy = 0.0
		bl.position = Vector3(cos(a) * 13.5, 96, sin(a) * 13.5)
		tower.add_child(bl)
		var bm := MeshInstance3D.new(); bm.mesh = MeshKit.bevel_box(Vector3(1, 1, 1), 0.2, 1); bm.position = bl.position
		bm.material_override = Mats.emissive(Color(1.0, 0.25, 0.1), 4.0)
		tower.add_child(bm)
		_blink.append(bl)
	_cam = Camera3D.new()
	_cam.fov = 62
	_cam.far = 400
	add_child(_cam)
	_cam.current = true

func _process(delta: float) -> void:
	_t += delta
	_cam.position = Vector3(1.5 + sin(_t * 0.05) * 2.0, 1.7, 14.0 - fmod(_t * 0.6, 40.0) * 0.0)
	_cam.look_at(Vector3(18, 22 + sin(_t * 0.08) * 2.0, -150))
	for i in _blink.size():
		_blink[i].light_energy = 3.0 if fmod(_t + i * 0.25, 2.0) < 0.15 else 0.0
