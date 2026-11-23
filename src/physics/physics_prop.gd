class_name PhysicsProp
extends RigidBody3D
## Objeto físico genérico: massa/atrito por material, sons de impacto proporcionais à velocidade,
## quebra em destroços físicos, explosão com pavio, dano por impacto ao ser arremessado.
## Usa "sleep" agressivo e destroços temporários para manter desempenho em celulares.

var kind := "crate"
var surface := "wood"
var hp := 0.0               # 0 = indestrutível
var explosive := false
var _fuse := -1.0
var _impact_cd := 0.0
var _thrown_by: Node = null
var _thrown_t := 0.0
var debris_parts: Array = []
var sharp := false          # lâmina de serra: dano de arremesso multiplicado  # [[mesh, material, size]]
var _mesh_node: MeshInstance3D

func _init() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	contact_monitor = true
	max_contacts_reported = 2
	can_sleep = true
	continuous_cd = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_meta("surface", surface)

func on_thrown(by: Node) -> void:
	_thrown_by = by
	_thrown_t = 1.5

func _physics_process(delta: float) -> void:
	_impact_cd = maxf(0.0, _impact_cd - delta)
	_thrown_t = maxf(0.0, _thrown_t - delta)
	if _fuse > 0.0:
		_fuse -= delta
		if _mesh_node:
			_mesh_node.material_overlay = _burn_mat() if fmod(_fuse, 0.25) < 0.12 else null
		if _fuse <= 0.0:
			_explode()

func _on_body_entered(other: Node) -> void:
	var v := linear_velocity.length()
	if v < 1.2 or _impact_cd > 0.0:
		return
	_impact_cd = 0.12
	var snd = {"metal": "impact_metal_heavy" if mass > 15.0 else "impact_metal", "wood": "impact_wood", "glass": "impact_glass"}.get(surface, "impact_concrete")
	if kind == "barrel" or kind == "explosive":
		snd = "barrel_hit"
	AudioBus.play_3d(snd, global_position, clampf(-22.0 + v * 3.0, -22.0, 2.0), 0.12, 45.0)
	if v > 4.0:
		Game.emit_noise(global_position, v * 2.5, self)
	# Objeto arremessado causa dano a quem atinge.
	if _thrown_t > 0.0 and other != _thrown_by and other.has_method("take_hit"):
		other.take_hit(v * mass * (1.2 if sharp else 0.35), global_position, linear_velocity, _thrown_by, "physics")
		if sharp: _thrown_t = 0.0
	if hp > 0.0 and v > 7.0:
		take_damage(v * mass * 0.08, global_position, "impact")

func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO, type := "bullet") -> void:
	if explosive:
		if type == "explosion" and amount > 10.0:
			_fuse = randf_range(0.1, 0.35)
		elif _fuse < 0.0 and amount > 3.0:
			_fuse = 2.2  # começa a queimar
			AudioBus.play_3d("manip_hold_loop", global_position, -10.0)
		return
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		_break()

func _burn_mat() -> Material:
	return Mats.emissive(Color(1.0, 0.4, 0.1), 1.5)

func _explode() -> void:
	var p := global_position
	_spawn_debris(6, Mats.prop("rusted_paint", 2.0, Color(0.7, 0.2, 0.1)), 0.12, 8.0)
	queue_free()
	Effects.explosion(p, 5.5, 110.0, self)

func _break() -> void:
	var snd = {"wood": "wood_break", "glass": "glass_break"}.get(surface, "impact_metal_heavy")
	AudioBus.play_3d(snd, global_position, 0.0)
	var mat: Material = _mesh_node.material_override if _mesh_node else null
	if mat == null and _mesh_node and _mesh_node.mesh and _mesh_node.mesh.get_surface_count() > 0:
		mat = _mesh_node.mesh.surface_get_material(_mesh_node.mesh.get_surface_count() - 1)
	_spawn_debris(7, mat, 0.18, 3.0)
	if has_meta("drop"):
		var d: Callable = get_meta("drop")
		d.call(global_position)
	queue_free()

func _spawn_debris(n: int, mat: Material, size: float, force: float) -> void:
	var parent := get_parent()
	var aabb_size := Vector3.ONE * 0.5
	if _mesh_node and _mesh_node.mesh:
		aabb_size = _mesh_node.mesh.get_aabb().size
	var mult: float = Settings.get_v("graphics", "particles", 1.0)
	for i in maxi(2, int(n * mult)):
		var b := RigidBody3D.new()
		b.collision_layer = 0
		b.collision_mask = 1
		b.mass = maxf(0.3, mass / n)
		var s := Vector3(randf_range(0.5, 1.5), randf_range(0.2, 0.6), randf_range(0.5, 1.5)) * size * (aabb_size.length() / 0.9)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.bevel_box(s, 0.01, 1)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = s
		cs.shape = bs
		b.add_child(cs)
		parent.add_child(b)
		b.global_position = global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0, 0.6), randf_range(-0.5, 0.5)) * aabb_size
		b.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		b.linear_velocity = linear_velocity + Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)) * force
		b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tw := b.create_tween()
		tw.tween_interval(6.0 + randf() * 3.0)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(b.queue_free)

# ---------------- fábrica ----------------
static func make(kind_name: String) -> PhysicsProp:
	var p := PhysicsProp.new()
	p.kind = kind_name
	var mesh: Mesh
	var mat: Material
	var shape: Shape3D
	var pm := PhysicsMaterial.new()
	match kind_name:
		"crate":
			# caixa de suprimentos: folha 0..1 em todas as faces + cantoneiras de madeira em relevo
			var s := Vector3(0.8, 0.8, 0.8)
			var battens := []
			for ax in 3:
				for sa in [-1.0, 1.0]:
					for sb in [-1.0, 1.0]:
						var sz := Vector3.ONE * 0.075; sz[ax] = s[ax] * 0.97
						var off := Vector3(sa, sb, 0) if ax == 2 else (Vector3(sa, 0, sb) if ax == 1 else Vector3(0, sa, sb))
						battens.append([MeshKit.bevel_box(sz, 0.012, 1), Transform3D(Basis(), off * (s.x * 0.5 - 0.02))])
			mesh = MeshKit.combine_by_material({Mats.sheet("crate"): [[MeshKit.box_cube_uv(s * 0.985), Transform3D()]],
				Mats.prop("wood", 2.5, Color(0.8, 0.66, 0.5)): battens})
			mat = null
			var bs := BoxShape3D.new(); bs.size = s; shape = bs
			p.mass = 14.0; p.surface = "wood"; p.hp = 30.0; pm.friction = 0.8
		"crate_small":
			var s2 := Vector3(0.45, 0.4, 0.55)
			mesh = MeshKit.combine_by_material({Mats.sheet("crate", Color(0.9, 0.86, 0.78)): [[MeshKit.box_cube_uv(s2), Transform3D()]],
				Mats.prop("wood", 2.5, Color(0.8, 0.66, 0.5)): [[MeshKit.bevel_box(Vector3(0.47, 0.05, 0.57), 0.01, 1), Transform3D(Basis(), Vector3(0, 0.15, 0))],
				[MeshKit.bevel_box(Vector3(0.47, 0.05, 0.57), 0.01, 1), Transform3D(Basis(), Vector3(0, -0.15, 0))]]})
			mat = null
			var bs2 := BoxShape3D.new(); bs2.size = s2; shape = bs2
			p.mass = 5.0; p.surface = "wood"; p.hp = 12.0
		"barrel", "explosive":
			var prof := PackedVector2Array()
			for i in 13:
				var y := -0.44 + 0.88 * float(i) / 12.0
				var rr := 0.29 + 0.012 * sin(float(i) / 12.0 * PI)
				if i in [3, 9]: rr += 0.012
				prof.append(Vector2(rr, y))
			var body := MeshKit.lathe(prof, 18, false, false, true, true)
			var col := "red" if kind_name == "explosive" else "blue"
			p.explosive = kind_name == "explosive"
			# tampas rebaixadas com aro (chime) e textura própria de tampa (bujões, sulcos, símbolo)
			var chime := MeshKit.lathe(PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.295, 0.0), Vector2(0.3, 0.025), Vector2(0.285, 0.03), Vector2(0.27, 0.0)]), 18, false, false)
			var lid := MeshKit.disc(0.29, 18)
			mesh = MeshKit.combine_by_material({
				Mats.sheet("barrel_" + col): [[body, Transform3D()], [chime, Transform3D(Basis(), Vector3(0, 0.425, 0))], [chime, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.425, 0))]],
				Mats.sheet("barrel_lid_" + col): [[lid, Transform3D(Basis(), Vector3(0, 0.43, 0))], [lid, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.43, 0))]]})
			mat = null
			var cyl := CylinderShape3D.new(); cyl.radius = 0.3; cyl.height = 0.88; shape = cyl
			p.mass = 25.0 if kind_name == "barrel" else 30.0; p.surface = "metal"; pm.friction = 0.6; pm.bounce = 0.1
		"cinder":
			var cb := MeshKit.combine([[MeshKit.bevel_box(Vector3(0.39, 0.19, 0.19), 0.01, 1), Transform3D()]])
			mesh = cb; mat = Mats.prop("concrete", 3.0)
			var bs3 := BoxShape3D.new(); bs3.size = Vector3(0.39, 0.19, 0.19); shape = bs3
			p.mass = 8.0; p.surface = "concrete"; pm.friction = 0.9
		"brick":
			mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.21, 0.065, 0.1), 0.008, 1), Transform3D()]])
			mat = Mats.prop("brick", 4.0)
			var bsb := BoxShape3D.new(); bsb.size = Vector3(0.21, 0.065, 0.1); shape = bsb
			p.mass = 2.4; p.surface = "concrete"; pm.friction = 0.9
		"bucket":
			mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.17), Vector2(0.12, -0.17), Vector2(0.15, 0.17), Vector2(0.14, 0.17), Vector2(0.11, -0.15)]), 14, false, false)
			mat = Mats.prop("steel", 3.0, Color(0.6, 0.6, 0.55))
			var cyl2 := CylinderShape3D.new(); cyl2.radius = 0.14; cyl2.height = 0.34; shape = cyl2
			p.mass = 1.5; p.surface = "metal"
		"bottle":
			mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.035, -0.12), Vector2(0.037, 0.04), Vector2(0.013, 0.09), Vector2(0.012, 0.13), Vector2(0.0, 0.13)]), 10)
			mat = Mats.glass()
			var cyl3 := CylinderShape3D.new(); cyl3.radius = 0.036; cyl3.height = 0.25; shape = cyl3
			p.mass = 0.4; p.surface = "glass"; p.hp = 1.0
		"pallet":
			var parts2 := []
			for i in 5:
				parts2.append([MeshKit.bevel_box(Vector3(1.2, 0.025, 0.14), 0.006, 1), Transform3D(Basis(), Vector3(0, 0.06, -0.4 + i * 0.2))])
			for i in 3:
				parts2.append([MeshKit.bevel_box(Vector3(0.1, 0.09, 1.0), 0.008, 1), Transform3D(Basis(), Vector3(-0.55 + i * 0.55, 0.0, 0))])
			mesh = MeshKit.combine(parts2); mat = Mats.prop("wood", 2.0, Color(0.9, 0.8, 0.65))
			var bs4 := BoxShape3D.new(); bs4.size = Vector3(1.2, 0.15, 1.0); shape = bs4
			p.mass = 12.0; p.surface = "wood"; p.hp = 25.0
		"plank":
			mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.45, 0.06, 4.4), 0.01, 1), Transform3D()],
				[MeshKit.bevel_box(Vector3(0.47, 0.07, 0.08), 0.005, 1), Transform3D(Basis(), Vector3(0, 0.005, -1.6))],
				[MeshKit.bevel_box(Vector3(0.47, 0.07, 0.08), 0.005, 1), Transform3D(Basis(), Vector3(0, 0.005, 1.6))]])
			mat = Mats.prop("wood", 2.0, Color(0.85, 0.75, 0.6))
			var bs5 := BoxShape3D.new(); bs5.size = Vector3(0.45, 0.07, 4.4); shape = bs5
			p.mass = 14.0; p.surface = "wood"
		"suitcase":
			mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.55, 0.38, 0.17), 0.03), Transform3D()],
				[MeshKit.pipe(PackedVector3Array([Vector3(-0.08, 0.19, 0), Vector3(-0.07, 0.24, 0), Vector3(0.07, 0.24, 0), Vector3(0.08, 0.19, 0)]), 0.012, 6), Transform3D()]])
			mat = Mats.prop("leather", 2.0, Color(0.6, 0.42, 0.3))
			var bs5 := BoxShape3D.new(); bs5.size = Vector3(0.55, 0.38, 0.17); shape = bs5
			p.mass = 4.0; p.surface = "wood"
		"sawblade":
			# lâmina circular de serra industrial: disco fino com dentes
			var pts := PackedVector2Array()
			var teeth := []
			for i in 24:
				var a := float(i) / 24.0 * TAU
				teeth.append([MeshKit.bevel_box(Vector3(0.06, 0.012, 0.05), 0.003, 1), Transform3D(Basis(Vector3.UP, -a + 0.4), Vector3(cos(a) * 0.4, 0, sin(a) * 0.4))])
			teeth.append([MeshKit.cylinder(0.39, 0.012, 24), Transform3D()])
			teeth.append([MeshKit.cylinder(0.08, 0.03, 10), Transform3D()])
			var _u2 = pts
			mesh = MeshKit.combine(teeth)
			mat = Mats.prop("steel", 3.0, Color(0.8, 0.8, 0.82))
			var cyl4 := CylinderShape3D.new(); cyl4.radius = 0.42; cyl4.height = 0.03; shape = cyl4
			p.mass = 6.0; p.surface = "metal"; p.sharp = true; pm.friction = 0.3
		"battery":
			mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.52, 0.32, 0.26), 0.02), Transform3D()],
				[MeshKit.cylinder(0.035, 0.06, 8), Transform3D(Basis(), Vector3(-0.17, 0.19, 0))],
				[MeshKit.cylinder(0.035, 0.06, 8), Transform3D(Basis(), Vector3(0.17, 0.19, 0))],
				[MeshKit.bevel_box(Vector3(0.3, 0.03, 0.04), 0.01, 1), Transform3D(Basis(), Vector3(0, 0.175, 0))]])
			mat = Mats.prop("rusted_paint", 3.0, Color(0.35, 0.4, 0.75))
			var bs6 := BoxShape3D.new(); bs6.size = Vector3(0.52, 0.34, 0.26); shape = bs6
			p.mass = 22.0; p.surface = "metal"
		"engine":
			# bloco de motor de caminhão (pesado demais para as mãos; só o Manipulador move)
			var eparts := [[MeshKit.bevel_box(Vector3(0.9, 0.7, 0.7), 0.06), Transform3D()],
				[MeshKit.bevel_box(Vector3(0.95, 0.18, 0.5), 0.04), Transform3D(Basis(), Vector3(0, 0.42, 0))],
				[MeshKit.cylinder(0.25, 0.12, 14), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.52, -0.05, 0))]]
			for i in 4:
				eparts.append([MeshKit.cylinder(0.05, 0.2, 8), Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(-0.3 + i * 0.2, 0.25, 0.36))])
			mesh = MeshKit.combine(eparts)
			mat = Mats.prop("steel", 2.0, Color(0.4, 0.38, 0.35))
			var bs7 := BoxShape3D.new(); bs7.size = Vector3(1.0, 0.85, 0.75); shape = bs7
			p.mass = 110.0; p.surface = "metal"; pm.friction = 0.9
		"tire":
			mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.22, -0.13), Vector2(0.36, -0.14), Vector2(0.4, -0.08), Vector2(0.4, 0.08), Vector2(0.36, 0.14), Vector2(0.22, 0.13), Vector2(0.21, -0.13)]), 16, false, false)
			mat = Mats.prop("rubber", 2.0, Color(0.22, 0.22, 0.23))
			var cyl5 := CylinderShape3D.new(); cyl5.radius = 0.4; cyl5.height = 0.28; shape = cyl5
			p.mass = 12.0; p.surface = "wood"; pm.bounce = 0.4
		_:
			push_warning("Prop desconhecido: " + kind_name)
			mesh = MeshKit.bevel_box(Vector3.ONE * 0.5); mat = Mats.prop("concrete"); var bx := BoxShape3D.new(); shape = bx
	p.physics_material_override = pm
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.visibility_range_end = Settings.get_v("graphics", "view_distance", 120.0) * 0.6
	p._mesh_node = mi
	p.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	p.add_child(cs)
	p.angular_damp = 0.6
	p.linear_damp = 0.05
	return p
