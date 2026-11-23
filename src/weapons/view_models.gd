class_name ViewModels
extends RefCounted
## Modelos em primeira pessoa construídos com MeshKit: braços com luvas e mangas,
## e armas com peças móveis nomeadas (Slide, Mag, Pump, Muzzle) usadas pela animação procedural.

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, name := "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name != "": m.name = name
	parent.add_child(m)
	return m

static func _node(parent: Node3D, name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.name = name; n.position = pos
	n.set_meta("rest", pos)
	parent.add_child(n)
	return n

static func _arm(weapon_root: Node3D, hand_pos: Vector3, elbow_back: Vector3, right := true) -> void:
	var parent: Node3D = weapon_root.get_node_or_null("Arms")
	if parent == null:
		parent = Node3D.new(); parent.name = "Arms"; weapon_root.add_child(parent)
	var sleeve := Mats.prop("fabric", 3.0, Color(0.34, 0.37, 0.3))
	var glove := Mats.prop("leather", 4.0, Color(0.42, 0.38, 0.34))
	# Antebraço: perfil afunilado ao longo de -Z, apontado da mão para o cotovelo.
	var fore := MeshKit.lathe(PackedVector2Array([Vector2(0.032, 0.0), Vector2(0.04, 0.05), Vector2(0.047, 0.2), Vector2(0.05, 0.3)]), 12)
	var dir := (elbow_back - hand_pos).normalized()
	var arm := Node3D.new()
	parent.add_child(arm)
	arm.position = hand_pos
	arm.look_at_from_position(hand_pos, hand_pos + dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.FORWARD)
	var mi := _mi(arm, fore, sleeve)
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	mi.position = Vector3(0, 0, -0.04)
	var cuff := MeshKit.lathe(PackedVector2Array([Vector2(0.048, 0.0), Vector2(0.054, 0.02), Vector2(0.054, 0.05), Vector2(0.048, 0.07)]), 12)
	var cm := _mi(arm, cuff, Mats.prop("rubber", 4.0, Color(0.5, 0.52, 0.5)))
	cm.rotation = Vector3(-PI * 0.5, 0, 0); cm.position = Vector3(0, 0, -0.05)
	# Mão: palma chanfrada + dedos
	var palm := _mi(parent, MeshKit.bevel_box(Vector3(0.075, 0.035, 0.09), 0.014), glove, hand_pos)
	palm.rotation = Vector3(0.2, 0, 0.15 if right else -0.15)
	for i in 4:
		var f := MeshKit.bevel_box(Vector3(0.016, 0.018, 0.06), 0.007, 1)
		_mi(parent, f, glove, hand_pos + Vector3(-0.026 + i * 0.017, -0.02, -0.04), Vector3(1.1, 0, 0))
	_mi(parent, MeshKit.bevel_box(Vector3(0.018, 0.02, 0.055), 0.008, 1), glove, hand_pos + Vector3(0.04 * (1 if right else -1), 0.01, -0.03), Vector3(0.3, 0.6 * (-1 if right else 1), 0))

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	match id:
		"wrench": _wrench(root)
		"pistol": _pistol(root)
		"smg": _smg(root)
		"shotgun": _shotgun(root)
		"manipulator": _manipulator(root)
		"iceaxe": _iceaxe(root)
		"stunbaton": _stunbaton(root)
		"flaregun": _flaregun(root)
		"smg1": _smg1(root)
		"ar1": _ar1(root)
		"oicw": _oicw(root)
		"hmg": _hmg(root)
		"sniper": _sniper(root)
		"missile": _missile(root)
		"immolator": _immolator(root)
		"irifle": _irifle(root)
		"guardgun": _guardgun(root)
		"grenade", "molotov", "hopwire", "slam", "brickbat": _throwable(root, id)
		"binoculars": _binoculars(root)
		"crowbar": _crowbar(root)
		"magnum": _magnum(root)
		"ar2": _ar2(root)
		"crossbow": _crossbow(root)
		"rpg": _rpg(root)
		"bugbait": _bugbait(root)
		"gravitygun": _gravitygun(root)
		"physgun": _physgun(root)
	_merge(root)
	var arms: Node3D = root.get_node_or_null("Arms")
	if arms: _merge(arms, true)
	return root

const _MOVING := ["Slide", "Mag", "Pump", "Bolt", "Spin", "Muzzle", "Arms", "Core", "Claw0", "Claw1", "Claw2"]

## Junta as malhas estáticas da arma por material (menos draw calls no mobile).
static func _merge(container: Node3D, all := false) -> void:
	var groups := {}
	var victims := []
	var stack: Array = [[container, Transform3D()]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		for c in n.get_children():
			if not all and c.name in _MOVING:
				continue
			if not (c is Node3D):
				continue
			var xf: Transform3D = it[1] * (c as Node3D).transform
			if c is MeshInstance3D and c.get_child_count() == 0 and c.mesh:
				var mat: Material = c.material_override
				if not groups.has(mat): groups[mat] = []
				groups[mat].append([c.mesh, xf])
				victims.append(c)
			elif c.get_class() == "Node3D" and c.get_child_count() > 0:
				stack.append([c, xf])
	if victims.size() < 3:
		return
	for v in victims:
		v.get_parent().remove_child(v)
		v.free()
	# remove nós vazios restantes
	for c in container.get_children():
		if c.get_class() == "Node3D" and c.get_child_count() == 0 and not (c.name in _MOVING) and not c.has_meta("rest"):
			c.free()
	for mat in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.combine(groups[mat])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(mi)

static func _wrench(r: Node3D) -> void:
	var steel := Mats.prop("steel", 4.0, Color(0.75, 0.75, 0.78))
	var rust := Mats.prop("gunmetal", 5.0, Color(0.8, 0.55, 0.4))
	var handle := MeshKit.lathe(PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.016, 0.02), Vector2(0.014, 0.33), Vector2(0.018, 0.36)]), 10)
	_mi(r, handle, steel, Vector3(0, -0.05, 0), Vector3(-1.2, 0, 0))
	var head := Node3D.new(); r.add_child(head)
	head.position = Vector3(0, 0.07, -0.31)
	head.rotation = Vector3(-1.2, 0, 0)
	_mi(head, MeshKit.bevel_box(Vector3(0.08, 0.035, 0.03), 0.008), steel, Vector3(0, 0.02, 0))
	_mi(head, MeshKit.bevel_box(Vector3(0.02, 0.06, 0.03), 0.006), steel, Vector3(0.03, 0.06, 0))
	_mi(head, MeshKit.bevel_box(Vector3(0.02, 0.05, 0.028), 0.006), rust, Vector3(-0.025, 0.055, 0))
	_mi(head, MeshKit.cylinder(0.012, 0.05, 10, 0.003), steel, Vector3(0, 0.0, 0), Vector3(0, 0, PI * 0.5))
	var grip := MeshKit.lathe(PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.022, 0.03), Vector2(0.022, 0.1), Vector2(0.02, 0.12)]), 10)
	_mi(r, grip, Mats.flat(Color(0.35, 0.08, 0.05), 0.9), Vector3(0, -0.06, 0.02), Vector3(-1.2, 0, 0))
	_arm(r, Vector3(0.0, -0.08, 0.04), Vector3(0.1, -0.25, 0.45))
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))

static func _pistol(r: Node3D) -> void:
	var dark := Mats.prop("steel", 6.0, Color(0.25, 0.26, 0.28))
	var poly := Mats.flat(Color(0.08, 0.085, 0.09), 0.75)
	var slide := _node(r, "Slide", Vector3(0, 0.035, -0.09))
	_mi(slide, MeshKit.bevel_box(Vector3(0.032, 0.034, 0.19), 0.006), dark)
	for i in 5:
		_mi(slide, MeshKit.bevel_box(Vector3(0.034, 0.026, 0.004), 0.001, 1), poly, Vector3(0, 0.0, 0.06 + i * 0.008))
	_mi(slide, MeshKit.bevel_box(Vector3(0.008, 0.008, 0.012), 0.002, 1), dark, Vector3(0, 0.021, -0.085))
	_mi(slide, MeshKit.bevel_box(Vector3(0.022, 0.008, 0.01), 0.002, 1), dark, Vector3(0, 0.021, 0.085))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.022, 0.17), 0.006), poly, Vector3(0, 0.008, -0.085))
	var grip := _mi(r, MeshKit.bevel_box(Vector3(0.03, 0.11, 0.045), 0.01), poly, Vector3(0, -0.045, -0.005), Vector3(-0.28, 0, 0))
	grip.name = "Grip"
	var mag := _node(r, "Mag", Vector3(0, -0.1, 0.005))
	_mi(mag, MeshKit.bevel_box(Vector3(0.024, 0.03, 0.036), 0.004), dark, Vector3.ZERO, Vector3(-0.28, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.006, 0), Vector2(0.006, 0.03)]), 8), dark, Vector3(0, 0.033, -0.19), Vector3(-PI * 0.5, 0, 0))
	var tg := MeshKit.pipe(PackedVector3Array([Vector3(0, -0.005, -0.06), Vector3(0, -0.03, -0.055), Vector3(0, -0.03, -0.02), Vector3(0, -0.01, -0.01)]), 0.004, 6)
	_mi(r, tg, poly)
	_node(r, "Muzzle", Vector3(0, 0.035, -0.21))
	_arm(r, Vector3(0.0, -0.06, 0.0), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.035, -0.07, -0.01), Vector3(-0.22, -0.28, 0.35), false)
	r.set_meta("ads", Vector3(0.0, -0.068, -0.3))

static func _smg(r: Node3D) -> void:
	var dark := Mats.prop("steel", 5.0, Color(0.3, 0.31, 0.32))
	var poly := Mats.flat(Color(0.1, 0.1, 0.1), 0.7)
	var paint := Mats.prop("polymer", 4.0, Color(0.55, 0.6, 0.5))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.065, 0.3), 0.01), paint, Vector3(0, 0.02, -0.12))
	_mi(r, MeshKit.cylinder(0.022, 0.16, 12, 0.004), dark, Vector3(0, 0.03, -0.33), Vector3(PI * 0.5, 0, 0))
	for i in 6:
		_mi(r, MeshKit.bevel_box(Vector3(0.052, 0.01, 0.018), 0.003, 1), poly, Vector3(0, 0.055, -0.27 - i * 0.025))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.008, 0), Vector2(0.009, 0.05)]), 8), dark, Vector3(0, 0.03, -0.41), Vector3(-PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.05), 0.01), poly, Vector3(0, -0.05, -0.02), Vector3(-0.25, 0, 0))
	var mag := _node(r, "Mag", Vector3(0, -0.1, -0.13))
	_mi(mag, MeshKit.bevel_box(Vector3(0.028, 0.16, 0.04), 0.006), dark, Vector3.ZERO, Vector3(0.1, 0, 0))
	var stock := MeshKit.pipe(PackedVector3Array([Vector3(0, 0.02, 0.03), Vector3(0, 0.02, 0.18), Vector3(0, -0.04, 0.2), Vector3(0, -0.04, 0.12)]), 0.008, 8)
	_mi(r, stock, dark)
	_mi(r, MeshKit.bevel_box(Vector3(0.014, 0.03, 0.08), 0.004), dark, Vector3(0, 0.068, -0.06))
	_node(r, "Muzzle", Vector3(0, 0.03, -0.44))
	_arm(r, Vector3(0.0, -0.06, -0.01), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.01, -0.03, -0.26), Vector3(-0.22, -0.3, 0.2), false)
	r.set_meta("ads", Vector3(0.0, -0.083, -0.26))

static func _shotgun(r: Node3D) -> void:
	var dark := Mats.prop("steel", 5.0, Color(0.22, 0.22, 0.24))
	var wood := Mats.prop("wood", 6.0)
	_mi(r, MeshKit.bevel_box(Vector3(0.048, 0.06, 0.2), 0.008), dark, Vector3(0, 0.02, -0.08))
	_mi(r, MeshKit.cylinder(0.014, 0.5, 12, 0.002), dark, Vector3(0, 0.04, -0.4), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.cylinder(0.013, 0.42, 12, 0.002), dark, Vector3(0, 0.012, -0.36), Vector3(PI * 0.5, 0, 0))
	var pump := _node(r, "Pump", Vector3(0, 0.012, -0.3))
	var pr := MeshKit.lathe(PackedVector2Array([Vector2(0.018, -0.07), Vector2(0.024, -0.06), Vector2(0.025, 0.06), Vector2(0.019, 0.07)]), 12)
	_mi(pump, pr, wood, Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	var stock := MeshKit.bevel_box(Vector3(0.04, 0.07, 0.26), 0.014)
	_mi(r, stock, wood, Vector3(0, -0.02, 0.13), Vector3(0.14, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.034, 0.09, 0.045), 0.01), wood, Vector3(0, -0.04, 0.0), Vector3(-0.35, 0, 0))
	var bead := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.003, 0.003), Vector2(0.0, 0.006)]), 6)
	_mi(r, bead, Mats.flat(Color(0.8, 0.75, 0.6)), Vector3(0, 0.056, -0.64))
	_node(r, "Muzzle", Vector3(0, 0.04, -0.66))
	_arm(r, Vector3(0.0, -0.05, 0.0), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.01, -0.01, -0.3), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.092, -0.3))

## Manipulador: emissor ressonante com três garras, bobinas expostas e núcleo azul-pálido
## (design próprio; cumpre o papel do conceito de "manipulador de objetos" do beta).
static func _manipulator(r: Node3D) -> void:
	var body := Mats.prop("polymer", 3.0, Color(0.85, 0.7, 0.45))
	var steel := Mats.prop("steel", 4.0, Color(0.55, 0.55, 0.56))
	var dark := Mats.flat(Color(0.08, 0.08, 0.09), 0.7)
	var copper := Mats.flat(Color(0.62, 0.36, 0.2), 0.45, 0.8)
	_mi(r, MeshKit.bevel_box(Vector3(0.12, 0.11, 0.3), 0.025), body, Vector3(0, 0.0, -0.08))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.075, 0.03), Vector2(0.08, 0.12), Vector2(0.06, 0.16)]), 12), steel, Vector3(0, 0.0, -0.22), Vector3(-PI * 0.5, 0, 0))
	for i in 3:
		_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.066, 0.0), Vector2(0.072, 0.008), Vector2(0.072, 0.02), Vector2(0.066, 0.028)]), 12, false, false), copper, Vector3(0, 0.0, -0.06 - i * 0.045), Vector3(-PI * 0.5, 0, 0))
	var core := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.035, 0.01), Vector2(0.03, 0.05), Vector2(0.0, 0.06)]), 10), Mats.emissive(Color(0.55, 0.85, 1.0), 3.0), Vector3(0, 0.0, -0.36), Vector3(-PI * 0.5, 0, 0))
	core.name = "Core"
	for i in 3:
		var a := i * TAU / 3.0 + PI * 0.5
		var claw := Node3D.new(); claw.name = "Claw%d" % i
		claw.position = Vector3(cos(a) * 0.07, sin(a) * 0.07, -0.34)
		claw.rotation.z = a - PI * 0.5
		claw.rotation.x = 0.0
		claw.set_meta("rest_rx", 0.0)
		r.add_child(claw)
		_mi(claw, MeshKit.pipe(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.05, -0.08), Vector3(0, 0.03, -0.17), Vector3(0, -0.01, -0.2)]), 0.011, 6), dark)
	_mi(r, MeshKit.bevel_box(Vector3(0.035, 0.11, 0.05), 0.01), dark, Vector3(0, -0.1, 0.02), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0.06, 0.03, 0.05), Vector3(0.09, 0.02, -0.1), Vector3(0.06, 0.04, -0.2)]), 0.01, 6), copper)
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.03, 0.1), 0.01), dark, Vector3(0, 0.07, -0.02))
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.55, 0.85, 1.0); gl.omni_range = 2.0; gl.light_energy = 0.3
	gl.position = Vector3(0, 0, -0.42)
	r.add_child(gl)
	r.set_meta("glow_light", gl)
	_node(r, "Muzzle", Vector3(0, 0, -0.45))
	_arm(r, Vector3(0.0, -0.1, 0.03), Vector3(0.12, -0.28, 0.42))
	_arm(r, Vector3(-0.07, -0.04, -0.12), Vector3(-0.25, -0.3, 0.25), false)
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))

# ======================================================================================
# Arsenal ampliado (v0.4). Formas originais construídas peça a peça, inspiradas nas
# descrições das armas cortadas do HL2 Beta (ver docs/06_ARSENAL_E_PERSONAGENS.md).

static func _gm(tint := Color(0.42, 0.43, 0.45)) -> StandardMaterial3D:
	return Mats.prop("gunmetal", 6.0, tint)

static func _poly(tint := Color(0.3, 0.31, 0.3)) -> StandardMaterial3D:
	return Mats.prop("polymer", 6.0, tint)

static func _wood() -> StandardMaterial3D:
	return Mats.prop("stock_wood", 4.0)

static func _bar(r: Node3D, mat: Material, len: float, rad: float, pos: Vector3, seg := 10) -> void:
	_mi(r, MeshKit.cylinder(rad, len, seg, rad * 0.15), mat, pos, Vector3(PI * 0.5, 0, 0))

## Picareta de gelo: cabo de madeira com empunhadura de borracha e cabeça de aço (ataque pesado no ALT).
static func _iceaxe(r: Node3D) -> void:
	var steel := Mats.prop("steel", 4.0, Color(0.8, 0.8, 0.82))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.014, 0.0), Vector2(0.017, 0.05), Vector2(0.016, 0.38), Vector2(0.013, 0.42)]), 10), _wood(), Vector3(0, -0.05, 0), Vector3(-1.2, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.022, 0.02), Vector2(0.022, 0.11), Vector2(0.019, 0.13)]), 10), Mats.prop("rubber", 4.0, Color(0.6, 0.3, 0.2)), Vector3(0, -0.06, 0.02), Vector3(-1.2, 0, 0))
	var head := Node3D.new(); r.add_child(head)
	head.position = Vector3(0, 0.09, -0.36); head.rotation = Vector3(-1.2, 0, 0)
	_mi(head, MeshKit.bevel_box(Vector3(0.03, 0.045, 0.035), 0.006), steel, Vector3(0, 0.03, 0))
	_mi(head, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.04, 0), Vector3(0, 0.05, 0.08), Vector3(0, 0.02, 0.16), Vector3(0, -0.01, 0.19)]), 0.009, 6), steel)
	_mi(head, MeshKit.bevel_box(Vector3(0.05, 0.012, 0.07), 0.004, 1), steel, Vector3(0, 0.045, -0.05))
	_arm(r, Vector3(0.0, -0.08, 0.04), Vector3(0.1, -0.25, 0.45))
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))

## Bastão de choque: cassetete com punho e ponteira emissiva azul (ferramenta da Proteção Civil).
static func _stunbaton(r: Node3D) -> void:
	var dark := _poly(Color(0.22, 0.22, 0.24))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.017, 0.0), Vector2(0.02, 0.03), Vector2(0.018, 0.36), Vector2(0.015, 0.4)]), 12), dark, Vector3(0, -0.05, 0), Vector3(-1.25, 0, 0))
	_mi(r, MeshKit.cylinder(0.025, 0.012, 12, 0.003), _gm(), Vector3(0, -0.04, -0.03), Vector3(-1.25 + PI * 0.5, 0, 0))
	var tip := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.018, 0.01), Vector2(0.016, 0.06), Vector2(0.0, 0.07)]), 10), Mats.emissive(Color(0.5, 0.8, 1.0), 2.5), Vector3(0, 0.08, -0.36), Vector3(-1.25, 0, 0))
	tip.name = "Core"
	var gl := OmniLight3D.new(); gl.light_color = Color(0.5, 0.8, 1.0); gl.omni_range = 1.4; gl.light_energy = 0.5
	gl.position = Vector3(0, 0.1, -0.4); r.add_child(gl)
	_arm(r, Vector3(0.0, -0.08, 0.04), Vector3(0.1, -0.25, 0.45))
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))

## Pistola sinalizadora: cano largo laranja, basculante, cão externo.
static func _flaregun(r: Node3D) -> void:
	var orange := _poly(Color(1.0, 0.45, 0.15))
	var dark := _gm(Color(0.3, 0.3, 0.32))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.11), Vector2(0.024, -0.11), Vector2(0.026, -0.1), Vector2(0.024, 0.08), Vector2(0.0, 0.08)]), 14), orange, Vector3(0, 0.03, -0.11), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.016, 0.0), Vector2(0.016, 0.01)]), 12, false, false), dark, Vector3(0, 0.03, -0.22), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.032, 0.11, 0.05), 0.012), orange, Vector3(0, -0.04, 0.0), Vector3(-0.3, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.04, 0.06), 0.008), dark, Vector3(0, 0.02, -0.0))
	_mi(r, MeshKit.bevel_box(Vector3(0.01, 0.03, 0.015), 0.003, 1), dark, Vector3(0, 0.05, 0.03), Vector3(-0.5, 0, 0))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0, -0.005, -0.05), Vector3(0, -0.03, -0.045), Vector3(0, -0.03, -0.01), Vector3(0, -0.01, 0.0)]), 0.004, 6), dark)
	_node(r, "Muzzle", Vector3(0, 0.03, -0.23))
	_arm(r, Vector3(0.0, -0.06, 0.0), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.035, -0.07, -0.01), Vector3(-0.22, -0.28, 0.35), false)
	r.set_meta("ads", Vector3(0.0, -0.07, -0.3))

## SM-1: submetralhadora compacta de 30 tiros (papel da SMG1 de 2001), empunhadura dianteira.
static func _smg1(r: Node3D) -> void:
	var g := _gm(Color(0.3, 0.31, 0.33))
	var p := _poly(Color(0.14, 0.14, 0.15))
	_mi(r, MeshKit.bevel_box(Vector3(0.045, 0.06, 0.24), 0.01), g, Vector3(0, 0.02, -0.1))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.045, 0.11), 0.012), p, Vector3(0, -0.005, -0.25))
	_bar(r, g, 0.06, 0.012, Vector3(0, 0.025, -0.33))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.06, 0.03), 0.008), p, Vector3(0, -0.055, -0.26), Vector3(0.15, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.034, 0.1, 0.045), 0.01), p, Vector3(0, -0.05, -0.0), Vector3(-0.25, 0, 0))
	var mag := _node(r, "Mag", Vector3(0, -0.085, -0.12))
	_mi(mag, MeshKit.bevel_box(Vector3(0.024, 0.12, 0.034), 0.005), g, Vector3.ZERO, Vector3(0.05, 0, 0))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.035, 0.02), Vector3(0.0, 0.05, -0.04), Vector3(0, 0.035, -0.08)]), 0.006, 6), g)
	_mi(r, MeshKit.bevel_box(Vector3(0.012, 0.022, 0.016), 0.003, 1), g, Vector3(0, 0.058, -0.2))
	_node(r, "Muzzle", Vector3(0, 0.025, -0.37))
	_arm(r, Vector3(0.0, -0.06, -0.0), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.005, -0.08, -0.26), Vector3(-0.22, -0.3, 0.2), false)
	r.set_meta("ads", Vector3(0.0, -0.085, -0.24))

## AR-1: fuzil de assalto 7,62 com coronha e guarda-mão de madeira, carregador curvo (ALT alterna modo).
static func _ar1(r: Node3D) -> void:
	var g := _gm(Color(0.3, 0.3, 0.31))
	var w := _wood()
	_mi(r, MeshKit.bevel_box(Vector3(0.046, 0.065, 0.3), 0.008), g, Vector3(0, 0.02, -0.08))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.055, 0.16), 0.014), w, Vector3(0, 0.012, -0.3))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.025, 0.14), 0.008), g, Vector3(0, 0.055, -0.3))
	_bar(r, g, 0.22, 0.011, Vector3(0, 0.03, -0.47))
	_mi(r, MeshKit.bevel_box(Vector3(0.012, 0.04, 0.012), 0.003, 1), g, Vector3(0, 0.055, -0.56))
	_mi(r, MeshKit.bevel_box(Vector3(0.012, 0.02, 0.03), 0.003, 1), g, Vector3(0, 0.06, -0.12))
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.045), 0.01), w, Vector3(0, -0.05, 0.02), Vector3(-0.3, 0, 0))
	var stock := MeshKit.lathe(PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.024, 0.05), Vector2(0.03, 0.22), Vector2(0.026, 0.24)]), 8)
	_mi(r, stock, w, Vector3(0, -0.005, 0.07), Vector3(PI * 0.5 + 0.12, 0, 0))
	var mag := _node(r, "Mag", Vector3(0, -0.07, -0.14))
	_mi(mag, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.03, 0), Vector3(0, -0.05, -0.02), Vector3(0, -0.11, -0.06)]), 0.017, 6), g)
	_node(r, "Muzzle", Vector3(0, 0.03, -0.59))
	_arm(r, Vector3(0.0, -0.06, 0.01), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.01, -0.03, -0.3), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.085, -0.26))

## OW-4: fuzil de combate com corpo volumoso, luneta integrada e lançador de 20 mm sob o cano (papel do OICW).
static func _oicw(r: Node3D) -> void:
	var body := _poly(Color(0.48, 0.5, 0.42))
	var g := _gm(Color(0.25, 0.26, 0.27))
	_mi(r, MeshKit.bevel_box(Vector3(0.06, 0.09, 0.42), 0.02), body, Vector3(0, 0.01, -0.12))
	_mi(r, MeshKit.bevel_box(Vector3(0.055, 0.04, 0.12), 0.015), body, Vector3(0, -0.035, -0.37))
	_bar(r, g, 0.2, 0.012, Vector3(0, 0.03, -0.42))
	_bar(r, g, 0.12, 0.022, Vector3(0, -0.035, -0.45))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.025, -0.1), Vector2(0.027, -0.09), Vector2(0.024, 0.09), Vector2(0.027, 0.1)]), 12), g, Vector3(0, 0.085, -0.1), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.02, 0.03, 0.05), 0.005, 1), g, Vector3(0, 0.06, -0.1))
	var lens := _mi(r, MeshKit.cylinder(0.022, 0.003, 12), Mats.emissive(Color(0.9, 0.5, 0.2), 0.6), Vector3(0, 0.085, -0.2), Vector3(PI * 0.5, 0, 0))
	lens.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.045), 0.01), body, Vector3(0, -0.07, -0.02), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.08, 0.14), 0.02), body, Vector3(0, -0.0, 0.14), Vector3(0.05, 0, 0))
	var mag := _node(r, "Mag", Vector3(0, -0.06, 0.07))
	_mi(mag, MeshKit.bevel_box(Vector3(0.026, 0.1, 0.04), 0.006), g)
	_node(r, "Muzzle", Vector3(0, 0.03, -0.53))
	_arm(r, Vector3(0.0, -0.08, 0.0), Vector3(0.12, -0.27, 0.4))
	_arm(r, Vector3(-0.01, -0.06, -0.35), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.13, -0.2))

## GR-9: metralhadora pesada alimentada por cinta, caixa de munição lateral, bipé dobrado.
static func _hmg(r: Node3D) -> void:
	var g := _gm(Color(0.28, 0.29, 0.27))
	var p := _poly(Color(0.38, 0.4, 0.3))
	_mi(r, MeshKit.bevel_box(Vector3(0.07, 0.09, 0.36), 0.012), g, Vector3(0, 0.02, -0.1))
	_mi(r, MeshKit.bevel_box(Vector3(0.075, 0.03, 0.2), 0.008), g, Vector3(0, 0.075, -0.06))
	var spin := _node(r, "Spin", Vector3(0, 0.03, -0.42))
	_mi(spin, MeshKit.cylinder(0.03, 0.3, 14, 0.004), Mats.prop("steel", 6.0, Color(0.45, 0.45, 0.47)), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	for i in 6:
		var a := i * TAU / 6.0
		_mi(spin, MeshKit.bevel_box(Vector3(0.01, 0.01, 0.26), 0.002, 1), g, Vector3(cos(a) * 0.033, sin(a) * 0.033, 0))
	_bar(r, g, 0.08, 0.014, Vector3(0, 0.03, -0.6))
	var mag := _node(r, "Mag", Vector3(-0.07, -0.04, -0.08))
	_mi(mag, MeshKit.bevel_box(Vector3(0.07, 0.11, 0.14), 0.01), p)
	for i in 5:
		_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.012, 0.01), 0.002, 1), Mats.flat(Color(0.72, 0.55, 0.25), 0.35, 0.8), Vector3(-0.03, 0.02 - i * 0.012, -0.08 + i * 0.006))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.12, 0.05), 0.01), p, Vector3(0, -0.06, 0.04), Vector3(-0.2, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.08, 0.16), 0.014), p, Vector3(0, 0.0, 0.18))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.07, -0.18), Vector3(0, 0.12, -0.12), Vector3(0, 0.12, -0.02), Vector3(0, 0.08, 0.02)]), 0.008, 6), g)
	for sgn in [-1.0, 1.0]:
		_mi(r, MeshKit.bevel_box(Vector3(0.01, 0.01, 0.2), 0.003, 1), g, Vector3(0.02 * sgn, -0.015, -0.42))
	_node(r, "Muzzle", Vector3(0, 0.03, -0.65))
	_arm(r, Vector3(0.0, -0.08, 0.04), Vector3(0.14, -0.27, 0.42))
	_arm(r, Vector3(-0.02, 0.1, -0.1), Vector3(-0.25, -0.15, 0.25), false)
	r.set_meta("hip", Vector3(0.18, -0.23, -0.36))
	r.set_meta("ads", Vector3(0.06, -0.15, -0.3))

## Urso: fuzil de precisão de ferrolho com luneta longa, cano flutuante e coronha de madeira.
static func _sniper(r: Node3D) -> void:
	var g := _gm(Color(0.22, 0.23, 0.24))
	var w := _wood()
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.07, 0.5), 0.016), w, Vector3(0, -0.0, -0.08))
	_mi(r, MeshKit.bevel_box(Vector3(0.042, 0.05, 0.22), 0.01), g, Vector3(0, 0.04, -0.08))
	_bar(r, g, 0.4, 0.013, Vector3(0, 0.035, -0.5))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.018, 0.0), Vector2(0.02, 0.06)]), 10), g, Vector3(0, 0.035, -0.7), Vector3(-PI * 0.5, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.03, -0.15), Vector2(0.032, -0.13), Vector2(0.02, -0.08), Vector2(0.02, 0.06), Vector2(0.028, 0.1), Vector2(0.03, 0.13)]), 14), g, Vector3(0, 0.1, -0.08), Vector3(PI * 0.5, 0, 0))
	for z in [-0.12, -0.03]:
		_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.04, 0.02), 0.004, 1), g, Vector3(0, 0.07, z))
	var bolt := _node(r, "Bolt", Vector3(0.03, 0.045, 0.0))
	_mi(bolt, MeshKit.cylinder(0.007, 0.05, 8), g, Vector3(0.02, 0, 0), Vector3(0, 0, PI * 0.5))
	_mi(bolt, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.012), Vector2(0.012, 0.0), Vector2(0.0, 0.012)]), 8), g, Vector3(0.05, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.045, 0.11, 0.22), 0.02), w, Vector3(0, -0.04, 0.24), Vector3(0.1, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.09, 0.045), 0.012), w, Vector3(0, -0.06, 0.06), Vector3(-0.35, 0, 0))
	var mag := _node(r, "Mag", Vector3(0, -0.05, -0.08))
	_mi(mag, MeshKit.bevel_box(Vector3(0.03, 0.05, 0.07), 0.005), g)
	_node(r, "Muzzle", Vector3(0, 0.035, -0.77))
	_arm(r, Vector3(0.0, -0.07, 0.06), Vector3(0.12, -0.26, 0.42))
	_arm(r, Vector3(-0.01, -0.04, -0.3), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.13, -0.18))

## Lança-mísseis guiado: tubo sobre o ombro com designador laser e mira frontal.
static func _missile(r: Node3D) -> void:
	var p := _poly(Color(0.42, 0.45, 0.36))
	var g := _gm(Color(0.25, 0.25, 0.26))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.06, -0.45), Vector2(0.068, -0.44), Vector2(0.065, 0.4), Vector2(0.075, 0.42), Vector2(0.06, 0.45)]), 16, false, false), p, Vector3(0, 0.07, -0.15), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.075, 0.0), Vector2(0.078, 0.03)]), 16, false, false), g, Vector3(0, 0.07, -0.58), Vector3(-PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.06, 0.06, 0.14), 0.012), g, Vector3(0.08, 0.05, -0.1))
	var dot := _mi(r, MeshKit.cylinder(0.008, 0.005, 8), Mats.emissive(Color(1.0, 0.15, 0.1), 3.0), Vector3(0.08, 0.05, -0.175), Vector3(PI * 0.5, 0, 0))
	dot.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.035, 0.11, 0.05), 0.01), g, Vector3(0, -0.05, 0.0), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.09, 0.04), 0.01), g, Vector3(0, -0.03, -0.3), Vector3(0.1, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.05, 0.03), 0.008), g, Vector3(-0.06, 0.13, -0.05))
	_node(r, "Muzzle", Vector3(0, 0.07, -0.62))
	_arm(r, Vector3(0.0, -0.08, 0.0), Vector3(0.12, -0.27, 0.4))
	_arm(r, Vector3(-0.01, -0.07, -0.3), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("hip", Vector3(0.18, -0.2, -0.35))
	r.set_meta("ads", Vector3(0.06, -0.14, -0.3))

## Imolador: tanque de combustível no dorso, mangueira e bocal com chama-piloto.
static func _immolator(r: Node3D) -> void:
	var g := _gm(Color(0.32, 0.3, 0.27))
	var tank := Mats.prop("gunmetal", 3.0, Color(0.9, 0.62, 0.2))
	_mi(r, MeshKit.bevel_box(Vector3(0.06, 0.07, 0.3), 0.014), g, Vector3(0, 0.02, -0.14))
	_bar(r, g, 0.22, 0.02, Vector3(0, 0.02, -0.4))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.02, 0.0), Vector2(0.032, 0.04), Vector2(0.034, 0.07)]), 12, false, false), g, Vector3(0, 0.02, -0.51), Vector3(-PI * 0.5, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.045, -0.1), Vector2(0.05, 0.1), Vector2(0.0, 0.13)]), 14), tank, Vector3(0, -0.06, -0.12), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0.04, -0.04, -0.02), Vector3(0.07, 0.0, -0.15), Vector3(0.04, 0.02, -0.3), Vector3(0.0, 0.03, -0.4)]), 0.009, 6), Mats.prop("rubber", 4.0))
	var pilot := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.008, 0.01), Vector2(0.0, 0.03)]), 6), Mats.emissive(Color(0.4, 0.6, 1.0), 3.0), Vector3(0, -0.01, -0.53))
	pilot.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.045), 0.01), g, Vector3(0, -0.05, 0.03), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.08, 0.04), 0.01), g, Vector3(0, -0.03, -0.32), Vector3(0.1, 0, 0))
	_node(r, "Muzzle", Vector3(0, 0.02, -0.56))
	_arm(r, Vector3(0.0, -0.07, 0.03), Vector3(0.12, -0.26, 0.42))
	_arm(r, Vector3(-0.01, -0.06, -0.32), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.15, -0.18, -0.36))

## Fuzil incendiário: arma da Aliança com carregador tubular de 5 virotes e núcleo térmico laranja.
static func _irifle(r: Node3D) -> void:
	var dark := _poly(Color(0.18, 0.2, 0.22))
	var g := _gm(Color(0.36, 0.4, 0.44))
	_mi(r, MeshKit.bevel_box(Vector3(0.06, 0.08, 0.44), 0.024), dark, Vector3(0, 0.02, -0.15))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.04, 0.2), 0.012), g, Vector3(0, 0.075, -0.2))
	_bar(r, g, 0.16, 0.014, Vector3(0, 0.02, -0.44))
	for i in 5:
		_mi(r, MeshKit.cylinder(0.006, 0.12, 6), Mats.emissive(Color(1.0, 0.5, 0.15), 1.5), Vector3(-0.034, 0.03 - i * 0.012, -0.12), Vector3(PI * 0.5, 0, 0))
	var core := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.02, 0.01), Vector2(0.02, 0.05), Vector2(0.0, 0.06)]), 10), Mats.emissive(Color(1.0, 0.55, 0.2), 2.5), Vector3(0.032, 0.03, -0.05), Vector3(0, 0, PI * 0.5))
	core.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.045), 0.01), dark, Vector3(0, -0.06, -0.0), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.09, 0.16), 0.024), dark, Vector3(0, -0.01, 0.15))
	var mag := _node(r, "Mag", Vector3(0, -0.04, -0.15))
	_mi(mag, MeshKit.bevel_box(Vector3(0.026, 0.05, 0.08), 0.006), g)
	_node(r, "Muzzle", Vector3(0, 0.02, -0.53))
	_arm(r, Vector3(0.0, -0.07, 0.01), Vector3(0.12, -0.26, 0.42))
	_arm(r, Vector3(-0.01, -0.03, -0.32), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.11, -0.26))

## Canhão de Guarda: emissor pesado de anéis com núcleo azul que carrega antes do disparo.
static func _guardgun(r: Node3D) -> void:
	var shell := _poly(Color(0.3, 0.33, 0.36))
	var g := _gm(Color(0.5, 0.52, 0.55))
	_mi(r, MeshKit.bevel_box(Vector3(0.1, 0.11, 0.36), 0.03), shell, Vector3(0, 0.0, -0.12))
	for i in 4:
		_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.05, 0.0), Vector2(0.065, 0.01), Vector2(0.065, 0.03), Vector2(0.05, 0.04)]), 16, false, false), g, Vector3(0, 0.0, -0.3 - i * 0.05), Vector3(-PI * 0.5, 0, 0))
	var core := _mi(r, MeshKit.cylinder(0.035, 0.22, 12), Mats.emissive(Color(0.5, 0.8, 1.0), 2.0), Vector3(0, 0.0, -0.4), Vector3(PI * 0.5, 0, 0))
	core.name = "Core"
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0.05, 0.05, 0.0), Vector3(0.07, 0.07, -0.15), Vector3(0.05, 0.05, -0.28)]), 0.012, 6), Mats.prop("rubber", 4.0))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.11, 0.05), 0.012), shell, Vector3(0, -0.1, 0.02), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.035, 0.035, 0.18), 0.01), shell, Vector3(0, 0.08, -0.05))
	var gl := OmniLight3D.new(); gl.light_color = Color(0.5, 0.8, 1.0); gl.omni_range = 2.2; gl.light_energy = 0.3
	gl.position = Vector3(0, 0, -0.5); r.add_child(gl)
	r.set_meta("glow_light", gl)
	_node(r, "Muzzle", Vector3(0, 0, -0.52))
	_arm(r, Vector3(0.0, -0.1, 0.03), Vector3(0.12, -0.28, 0.42))
	_arm(r, Vector3(-0.08, -0.03, -0.15), Vector3(-0.25, -0.3, 0.25), false)
	r.set_meta("ads", Vector3(0.12, -0.18, -0.36))

## Arremessáveis em mão (granada, molotov, hopwire, S.L.A.M., tijolo).
static func _throwable(r: Node3D, id: String) -> void:
	var h := Vector3(0.0, -0.02, -0.06)
	match id:
		"grenade":
			_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.06), Vector2(0.04, -0.05), Vector2(0.045, 0.02), Vector2(0.03, 0.06), Vector2(0.0, 0.065)]), 12), Mats.prop("gunmetal", 8.0, Color(0.55, 0.6, 0.45)), h)
			_mi(r, MeshKit.cylinder(0.013, 0.03, 8), _gm(), h + Vector3(0, 0.075, 0))
			_mi(r, MeshKit.pipe(PackedVector3Array([h + Vector3(0.0, 0.08, 0), h + Vector3(0.03, 0.06, 0.0), h + Vector3(0.045, 0.0, 0.0)]), 0.005, 5), _gm(Color(0.7, 0.7, 0.7)))
		"molotov":
			_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.1), Vector2(0.04, -0.1), Vector2(0.042, 0.02), Vector2(0.015, 0.07), Vector2(0.013, 0.12), Vector2(0.0, 0.12)]), 12), Mats.glass(), h)
			_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.11), Vector2(0.02, 0.12), Vector2(0.01, 0.17), Vector2(0.0, 0.18)]), 6), Mats.prop("fabric", 3.0, Color(0.9, 0.85, 0.7)), h)
			var fl = Fire._flames(r, 0.015, 8); fl.position = h + Vector3(0, 0.18, 0)
			fl.scale_amount_min = 0.12; fl.scale_amount_max = 0.25; fl.local_coords = false
		"hopwire":
			_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.05, -0.03), Vector2(0.055, 0.0), Vector2(0.05, 0.03), Vector2(0.0, 0.05)]), 14), Mats.prop("steel", 10.0, Color(0.6, 0.62, 0.66)), h)
			_mi(r, MeshKit.cylinder(0.058, 0.012, 14), Mats.emissive(Color(0.6, 0.8, 1.0), 1.0), h)
		"slam":
			_mi(r, MeshKit.bevel_box(Vector3(0.12, 0.05, 0.16), 0.01), _poly(Color(0.5, 0.55, 0.45)), h, Vector3(0.6, 0, 0))
			_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.02, 0.04), 0.005, 1), Mats.emissive(Color(0.2, 1.0, 0.3), 1.5), h + Vector3(0, 0.03, 0.0), Vector3(0.6, 0, 0))
		"brickbat":
			_mi(r, MeshKit.bevel_box(Vector3(0.21, 0.065, 0.1), 0.008, 1), Mats.prop("brick", 4.0), h, Vector3(0, 0.3, 0.2))
	_arm(r, Vector3(0.0, -0.07, 0.0), Vector3(0.12, -0.25, 0.4))
	r.set_meta("hip", Vector3(0.18, -0.2, -0.34))
	r.set_meta("ads", Vector3(0.18, -0.2, -0.34))

## Binóculos (ampliação ~5x no ALT/mira).
static func _binoculars(r: Node3D) -> void:
	var rub := Mats.prop("rubber", 4.0, Color(0.35, 0.37, 0.33))
	for sgn in [-1.0, 1.0]:
		_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.025, -0.07), Vector2(0.03, -0.06), Vector2(0.028, 0.05), Vector2(0.034, 0.07)]), 12), rub, Vector3(0.035 * sgn, 0, -0.1), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.03, 0.06), 0.008), _gm(), Vector3(0, 0.0, -0.1))
	_arm(r, Vector3(0.06, -0.05, -0.06), Vector3(0.14, -0.25, 0.35))
	_arm(r, Vector3(-0.06, -0.05, -0.06), Vector3(-0.2, -0.28, 0.3), false)
	r.set_meta("hip", Vector3(0.0, -0.25, -0.3))
	r.set_meta("ads", Vector3(0.0, -0.0, -0.12))


# ======================================================================================
# Arsenal do HL2 final + Physgun (v0.5). Modelos originais construídos peça a peça; seguem a
# silhueta e a função das armas descritas nas wikis (sem malhas, texturas ou sons da Valve).

## Pé de cabra: barra sextavada pintada de vermelho, gancho curvo com fenda e ponta chata.
static func _crowbar(r: Node3D) -> void:
	var red := Mats.prop("rusted_paint", 5.0, Color(0.75, 0.12, 0.08))
	var steel := Mats.prop("steel", 5.0, Color(0.6, 0.6, 0.62))
	var pts := PackedVector3Array([Vector3(0, -0.06, 0.06), Vector3(0, 0.0, -0.1), Vector3(0, 0.07, -0.3), Vector3(0, 0.1, -0.4)])
	_mi(r, MeshKit.pipe(pts, 0.011, 6), red)
	# gancho
	var hook := PackedVector3Array([Vector3(0, 0.1, -0.4), Vector3(0, 0.125, -0.44), Vector3(0, 0.12, -0.48), Vector3(0, 0.09, -0.5), Vector3(0, 0.06, -0.49)])
	_mi(r, MeshKit.pipe(hook, 0.011, 6), red)
	for sx in [-1.0, 1.0]:
		_mi(r, MeshKit.bevel_box(Vector3(0.006, 0.012, 0.03), 0.002, 1), steel, Vector3(0.004 * sx, 0.055, -0.485), Vector3(-0.6, 0, 0))
	# ponta chata
	_mi(r, MeshKit.bevel_box(Vector3(0.02, 0.008, 0.05), 0.003, 1), steel, Vector3(0, -0.07, 0.08), Vector3(-0.5, 0, 0))
	_arm(r, Vector3(0.0, -0.04, 0.0), Vector3(0.1, -0.25, 0.42))
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))

## Revólver .357: armação de aço inox, tambor de 6 câmaras, cano com nervura ventilada e
## extrator, cão externo e cabo de madeira.
static func _magnum(r: Node3D) -> void:
	var inox := Mats.prop("steel", 6.0, Color(0.78, 0.78, 0.8))
	var dark := _gm(Color(0.22, 0.22, 0.24))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.05, 0.09), 0.008), inox, Vector3(0, 0.03, -0.04))
	var cyl := _node(r, "Spin", Vector3(0, 0.032, -0.065))
	_mi(cyl, MeshKit.cylinder(0.028, 0.05, 14, 0.004), inox, Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	for i in 6:
		var a := TAU * i / 6.0
		_mi(cyl, MeshKit.cylinder(0.006, 0.052, 6), dark, Vector3(cos(a) * 0.017, sin(a) * 0.017, 0), Vector3(PI * 0.5, 0, 0))
		_mi(cyl, MeshKit.bevel_box(Vector3(0.006, 0.004, 0.03), 0.001, 1), dark, Vector3(cos(a + PI / 6) * 0.028, sin(a + PI / 6) * 0.028, 0), Vector3(0, 0, a + PI / 6 + PI * 0.5))
	_bar(r, inox, 0.2, 0.011, Vector3(0, 0.045, -0.19))
	_mi(r, MeshKit.bevel_box(Vector3(0.014, 0.02, 0.19), 0.004), inox, Vector3(0, 0.026, -0.19))
	_mi(r, MeshKit.bevel_box(Vector3(0.008, 0.012, 0.2), 0.002, 1), inox, Vector3(0, 0.062, -0.19))
	for i in 5:
		_mi(r, MeshKit.bevel_box(Vector3(0.009, 0.006, 0.022), 0.001, 1), dark, Vector3(0, 0.062, -0.12 - i * 0.032))
	_mi(r, MeshKit.bevel_box(Vector3(0.008, 0.014, 0.01), 0.002, 1), inox, Vector3(0, 0.072, -0.285))
	_mi(r, MeshKit.bevel_box(Vector3(0.01, 0.025, 0.02), 0.003, 1), inox, Vector3(0, 0.065, 0.015), Vector3(-0.6, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.034, 0.1, 0.045), 0.014), _wood(), Vector3(0, -0.04, 0.015), Vector3(-0.3, 0, 0))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.005, -0.03), Vector3(0, -0.025, -0.03), Vector3(0, -0.025, 0.0), Vector3(0, 0.0, 0.005)]), 0.004, 6), inox)
	_node(r, "Muzzle", Vector3(0, 0.045, -0.3))
	_arm(r, Vector3(0.0, -0.06, 0.02), Vector3(0.12, -0.25, 0.4))
	_arm(r, Vector3(-0.035, -0.07, 0.0), Vector3(-0.22, -0.28, 0.35), false)
	r.set_meta("ads", Vector3(0.0, -0.08, -0.28))

## AR2 (fuzil de pulso da Overwatch): corpo preto anguloso, cano com anéis, depósito de energia
## azul na traseira, carregador de pulso lateral e alça superior.
static func _ar2(r: Node3D) -> void:
	var shell := _poly(Color(0.12, 0.13, 0.15))
	var g := _gm(Color(0.36, 0.38, 0.42))
	var glow := Mats.emissive(Color(0.5, 0.85, 1.0), 2.5)
	_mi(r, MeshKit.bevel_box(Vector3(0.065, 0.09, 0.38), 0.02), shell, Vector3(0, 0.02, -0.12))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.05, 0.16), 0.016), shell, Vector3(0, 0.08, -0.06))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.035, 0.12), 0.01), g, Vector3(0, 0.115, -0.04))
	_bar(r, g, 0.22, 0.016, Vector3(0, 0.03, -0.42))
	for i in 4:
		_mi(r, MeshKit.cylinder(0.024, 0.014, 12, 0.003), shell, Vector3(0, 0.03, -0.35 - i * 0.04), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.022, 0.0), Vector2(0.03, 0.03), Vector2(0.03, 0.05)]), 12, false, false), shell, Vector3(0, 0.03, -0.53), Vector3(-PI * 0.5, 0, 0))
	var core := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.035), Vector2(0.03, -0.02), Vector2(0.032, 0.02), Vector2(0.0, 0.035)]), 12), glow, Vector3(0, 0.035, 0.1), Vector3(0, 0, PI * 0.5))
	core.name = "Core"
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.036, -0.04), Vector2(0.04, -0.03), Vector2(0.04, 0.03), Vector2(0.036, 0.04)]), 12, false, false), g, Vector3(0, 0.035, 0.1), Vector3(0, 0, PI * 0.5))
	var mag := _node(r, "Mag", Vector3(0.0, -0.045, -0.06))
	_mi(mag, MeshKit.bevel_box(Vector3(0.04, 0.06, 0.07), 0.01), g)
	_mi(mag, MeshKit.bevel_box(Vector3(0.042, 0.01, 0.05), 0.003, 1), glow, Vector3(0, -0.015, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.045), 0.01), shell, Vector3(0, -0.06, 0.03), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.08, 0.14), 0.02), shell, Vector3(0, -0.01, 0.2))
	_node(r, "Muzzle", Vector3(0, 0.03, -0.56))
	_arm(r, Vector3(0.0, -0.08, 0.04), Vector3(0.12, -0.26, 0.42))
	_arm(r, Vector3(-0.01, -0.02, -0.28), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.135, -0.26))

## Besta: armação de sucata soldada, arco de aço com cabos, bateria que aquece o vergalhão
## (brilho laranja) e luneta.
static func _crossbow(r: Node3D) -> void:
	var frame := _gm(Color(0.3, 0.3, 0.3))
	var rust := Mats.prop("rusted_paint", 5.0, Color(0.55, 0.42, 0.3))
	var cable := Mats.flat(Color(0.1, 0.1, 0.1), 0.6)
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.05, 0.55), 0.01), frame, Vector3(0, 0.02, -0.2))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.03, 0.4), 0.008), rust, Vector3(0, 0.055, -0.25))
	for sx in [-1.0, 1.0]:
		_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0, 0.03, -0.44), Vector3(0.12 * sx, 0.035, -0.42), Vector3(0.22 * sx, 0.04, -0.36), Vector3(0.27 * sx, 0.045, -0.3)]), 0.01, 6), frame)
		_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(0.27 * sx, 0.045, -0.3), Vector3(0.0, 0.07, -0.08)]), 0.003, 4, false), cable)
		_mi(r, MeshKit.cylinder(0.018, 0.02, 10, 0.003), frame, Vector3(0.27 * sx, 0.045, -0.3))
	var bolt := _mi(r, MeshKit.cylinder(0.006, 0.42, 6), Mats.emissive(Color(1.0, 0.45, 0.12), 1.8), Vector3(0, 0.075, -0.25), Vector3(PI * 0.5, 0, 0))
	bolt.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.06, 0.05, 0.09), 0.01), Mats.prop("polymer", 4.0, Color(0.7, 0.55, 0.2)), Vector3(0.05, -0.01, -0.05))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.018, -0.1), Vector2(0.024, -0.09), Vector2(0.02, 0.06), Vector2(0.025, 0.08), Vector2(0.02, 0.1)]), 12), frame, Vector3(0, 0.12, -0.08), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.012, 0.04, 0.02), 0.003, 1), frame, Vector3(0, 0.095, -0.08))
	_mi(r, MeshKit.bevel_box(Vector3(0.036, 0.1, 0.045), 0.01), frame, Vector3(0, -0.05, 0.03), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.04, 0.07, 0.18), 0.015), rust, Vector3(0, -0.01, 0.16))
	_node(r, "Muzzle", Vector3(0, 0.075, -0.48))
	_arm(r, Vector3(0.0, -0.08, 0.04), Vector3(0.12, -0.26, 0.42))
	_arm(r, Vector3(-0.02, -0.0, -0.3), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("ads", Vector3(0.0, -0.12, -0.24))

## RPG: tubo verde-oliva com bocal traseiro alargado, mira laser volumosa em cima (ponto vermelho).
static func _rpg(r: Node3D) -> void:
	var olive := Mats.prop("rusted_paint", 4.0, Color(0.38, 0.42, 0.3))
	var g := _gm(Color(0.2, 0.2, 0.21))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.055, -0.5), Vector2(0.06, -0.48), Vector2(0.058, 0.32), Vector2(0.08, 0.4), Vector2(0.085, 0.46)]), 16, false, false), olive, Vector3(0, 0.07, -0.12), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.066, 0.02), Vector2(0.066, 0.05)]), 16, false, false), g, Vector3(0, 0.07, -0.62), Vector3(-PI * 0.5, 0, 0))
	for z in [-0.42, -0.1, 0.18]:
		_mi(r, MeshKit.cylinder(0.064, 0.02, 16, 0.003), g, Vector3(0, 0.07, z), Vector3(PI * 0.5, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.07, 0.07, 0.18), 0.014), g, Vector3(0, 0.165, -0.15))
	_mi(r, MeshKit.cylinder(0.02, 0.03, 10), g, Vector3(0, 0.165, -0.255), Vector3(PI * 0.5, 0, 0))
	var dot := _mi(r, MeshKit.cylinder(0.01, 0.004, 8), Mats.emissive(Color(1.0, 0.12, 0.08), 4.0), Vector3(0, 0.165, -0.272), Vector3(PI * 0.5, 0, 0))
	dot.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.035, 0.11, 0.05), 0.01), g, Vector3(0, -0.05, 0.0), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.09, 0.04), 0.01), g, Vector3(0, -0.03, -0.3), Vector3(0.1, 0, 0))
	_node(r, "Muzzle", Vector3(0, 0.07, -0.66))
	_arm(r, Vector3(0.0, -0.08, 0.0), Vector3(0.12, -0.27, 0.4))
	_arm(r, Vector3(-0.01, -0.07, -0.3), Vector3(-0.22, -0.32, 0.1), false)
	r.set_meta("hip", Vector3(0.18, -0.2, -0.35))
	r.set_meta("ads", Vector3(0.06, -0.15, -0.3))

## Isca de feromônio: casulo orgânico pulsante na palma da mão.
static func _bugbait(r: Node3D) -> void:
	var h := Vector3(0.0, -0.02, -0.06)
	var core := _mi(r, Projectile.Throwable._bugbait_mesh(), Mats.prop("rubber", 6.0, Color(0.55, 0.6, 0.3)), h)
	core.name = "Core"
	core.scale = Vector3.ONE * 1.3
	_arm(r, Vector3(0.0, -0.07, 0.0), Vector3(0.12, -0.25, 0.4))
	r.set_meta("hip", Vector3(0.18, -0.2, -0.34))
	r.set_meta("ads", Vector3(0.18, -0.2, -0.34))

## Arma de Gravidade: corpo laranja e preto, três garras que abrem ao segurar, núcleo branco-alaranjado.
static func _gravitygun(r: Node3D) -> void:
	var orange := Mats.prop("polymer", 3.0, Color(1.0, 0.5, 0.12))
	var dark := Mats.prop("gunmetal", 5.0, Color(0.15, 0.15, 0.16))
	var steel := Mats.prop("steel", 4.0, Color(0.6, 0.6, 0.62))
	_mi(r, MeshKit.bevel_box(Vector3(0.13, 0.12, 0.26), 0.03), dark, Vector3(0, 0.0, -0.05))
	_mi(r, MeshKit.bevel_box(Vector3(0.14, 0.05, 0.2), 0.02), orange, Vector3(0, 0.07, -0.08))
	for sx in [-1.0, 1.0]:
		_mi(r, MeshKit.bevel_box(Vector3(0.03, 0.09, 0.22), 0.012), orange, Vector3(0.075 * sx, 0.0, -0.1))
	_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.08, 0.03), Vector2(0.085, 0.1), Vector2(0.07, 0.13)]), 14), steel, Vector3(0, 0.0, -0.2), Vector3(-PI * 0.5, 0, 0))
	var core := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.012), Vector2(0.035, 0.05), Vector2(0.0, 0.062)]), 12), Mats.emissive(Color(1.0, 0.75, 0.4), 3.5), Vector3(0, 0.0, -0.34), Vector3(-PI * 0.5, 0, 0))
	core.name = "Core"
	for i in 3:
		var a := i * TAU / 3.0 + PI * 0.5
		var claw := Node3D.new(); claw.name = "Claw%d" % i
		claw.position = Vector3(cos(a) * 0.08, sin(a) * 0.08, -0.32)
		claw.rotation.z = a - PI * 0.5
		claw.set_meta("rest_rx", 0.0)
		r.add_child(claw)
		_mi(claw, MeshKit.pipe(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.06, -0.07), Vector3(0, 0.045, -0.18), Vector3(0, 0.0, -0.23)]), 0.014, 6), dark)
		_mi(claw, MeshKit.bevel_box(Vector3(0.03, 0.02, 0.06), 0.006, 1), orange, Vector3(0, 0.05, -0.1), Vector3(-0.2, 0, 0))
	_mi(r, MeshKit.bevel_box(Vector3(0.035, 0.11, 0.05), 0.01), dark, Vector3(0, -0.1, 0.02), Vector3(-0.25, 0, 0))
	_mi(r, MeshKit.pipe(PackedVector3Array([Vector3(-0.07, 0.04, 0.06), Vector3(-0.09, 0.03, -0.08), Vector3(-0.06, 0.05, -0.2)]), 0.01, 6), Mats.prop("rubber", 4.0))
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.65, 0.3); gl.omni_range = 2.2; gl.light_energy = 0.3
	gl.position = Vector3(0, 0, -0.42)
	r.add_child(gl)
	r.set_meta("glow_light", gl)
	_node(r, "Muzzle", Vector3(0, 0, -0.45))
	_arm(r, Vector3(0.0, -0.1, 0.03), Vector3(0.12, -0.28, 0.42))
	_arm(r, Vector3(-0.08, -0.04, -0.1), Vector3(-0.25, -0.3, 0.25), false)
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))

## Physgun (beta): emissor de laboratório cinza-azulado com antena de anéis e lente azul;
## o feixe azul liga a arma ao objeto levitado.
static func _physgun(r: Node3D) -> void:
	var body := Mats.prop("polymer", 3.0, Color(0.55, 0.6, 0.66))
	var dark := _gm(Color(0.2, 0.21, 0.23))
	var blue := Mats.emissive(Color(0.35, 0.65, 1.0), 3.0)
	_mi(r, MeshKit.bevel_box(Vector3(0.09, 0.1, 0.3), 0.025), body, Vector3(0, 0.0, -0.08))
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.04, 0.22), 0.012), dark, Vector3(0, 0.07, -0.08))
	_bar(r, dark, 0.22, 0.018, Vector3(0, 0.0, -0.33))
	for i in 5:
		_mi(r, MeshKit.cylinder(0.034 - i * 0.003, 0.01, 14, 0.002), dark, Vector3(0, 0.0, -0.25 - i * 0.04), Vector3(PI * 0.5, 0, 0))
	for i in 3:
		_mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.026, 0.0), Vector2(0.03, 0.006), Vector2(0.03, 0.012), Vector2(0.026, 0.018)]), 12, false, false), blue, Vector3(0, 0.0, -0.27 - i * 0.04), Vector3(-PI * 0.5, 0, 0))
	var core := _mi(r, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.022, 0.01), Vector2(0.0, 0.03)]), 10), blue, Vector3(0, 0.0, -0.45), Vector3(-PI * 0.5, 0, 0))
	core.name = "Core"
	_mi(r, MeshKit.bevel_box(Vector3(0.05, 0.03, 0.04), 0.008), blue, Vector3(0.048, 0.02, 0.0))
	_mi(r, MeshKit.bevel_box(Vector3(0.035, 0.11, 0.05), 0.01), dark, Vector3(0, -0.1, 0.02), Vector3(-0.25, 0, 0))
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.35, 0.65, 1.0); gl.omni_range = 2.0; gl.light_energy = 0.3
	gl.position = Vector3(0, 0, -0.48)
	r.add_child(gl)
	r.set_meta("glow_light", gl)
	_node(r, "Muzzle", Vector3(0, 0, -0.47))
	_arm(r, Vector3(0.0, -0.1, 0.03), Vector3(0.12, -0.28, 0.42))
	_arm(r, Vector3(-0.06, -0.04, -0.15), Vector3(-0.25, -0.3, 0.25), false)
	r.set_meta("ads", Vector3(0.2, -0.2, -0.38))
