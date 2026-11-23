class_name Effects
extends RefCounted
## Efeitos visuais: decals de impacto (pool limitado pela qualidade), partículas por material,
## explosões com dano radial e impulso físico. Partículas em CPU (compatível com GPUs móveis fracas).

static var _decals: Array[Decal] = []
static var _bullet_tex: Texture2D
static var _scorch_tex: Texture2D
static var _smoke_tex: Texture2D
static var _particle_mats := {}

static func _world() -> Node:
	var lvl = Game.level
	return lvl if is_instance_valid(lvl) else Engine.get_main_loop().root

static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

static func impact(pos: Vector3, normal: Vector3, surface: String, dir: Vector3, with_sound := true) -> void:
	var w := _world()
	if with_sound:
		var snd = {"metal": "impact_metal", "wood": "impact_wood", "flesh": "impact_flesh", "glass": "impact_glass"}.get(surface, "impact_concrete")
		AudioBus.play_3d(snd, pos, -6.0, 0.15, 40.0)
	if surface != "flesh":
		_decal(w, pos, normal, false)
	var color = {"metal": Color(1.0, 0.75, 0.35), "wood": Color(0.45, 0.32, 0.2), "flesh": Color(0.25, 0.04, 0.03),
		"glass": Color(0.7, 0.8, 0.8)}.get(surface, Color(0.55, 0.53, 0.5))
	var sparks := surface == "metal"
	burst(pos + normal * 0.02, normal.lerp(-dir, 0.3).normalized(), color, 10 if sparks else 8, sparks)

static func _decal(w: Node, pos: Vector3, normal: Vector3, scorch: bool) -> void:
	var limit: int = Settings.get_v("graphics", "decals", 32)
	if limit <= 0:
		return
	if _bullet_tex == null:
		_bullet_tex = _tex("res://assets/textures/fx_bullet_hole.png")
		_scorch_tex = _tex("res://assets/textures/fx_scorch.png")
	var d: Decal
	if _decals.size() >= limit:
		var old = _decals.pop_front()
		d = old if is_instance_valid(old) else Decal.new()
	else:
		d = Decal.new()
	if d.get_parent() != w:
		if d.get_parent(): d.get_parent().remove_child(d)
		w.add_child(d)
	var s := 1.6 if scorch else 0.09
	d.size = Vector3(s, 0.12 if not scorch else 0.6, s)
	d.texture_albedo = _scorch_tex if scorch else _bullet_tex
	d.modulate = Color(1, 1, 1, 0.9)
	d.cull_mask = 1
	d.global_position = pos
	var up := normal
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	d.global_basis = Basis(x, up, z).rotated(up, randf() * TAU)
	_decals.append(d)

static func _pmat(color: Color, additive: bool) -> StandardMaterial3D:
	var key := color.to_html() + str(additive)
	if _particle_mats.has(key):
		return _particle_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if _smoke_tex == null:
		_smoke_tex = _tex("res://assets/textures/fx_smoke.png")
	if not additive and _smoke_tex:
		m.albedo_texture = _smoke_tex
	m.albedo_color = color
	_particle_mats[key] = m
	return m

static func burst(pos: Vector3, dir: Vector3, color: Color, amount: int, sparks: bool, scale := 1.0) -> CPUParticles3D:
	var mult: float = Settings.get_v("graphics", "particles", 1.0)
	var n := int(amount * mult)
	if n <= 0:
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n
	p.lifetime = 0.35 if sparks else 0.9
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = 35.0 if sparks else 25.0
	p.initial_velocity_min = 3.0 * scale if sparks else 0.6 * scale
	p.initial_velocity_max = 7.0 * scale if sparks else 2.0 * scale
	p.gravity = Vector3(0, -9.8, 0) if sparks else Vector3(0, -0.6, 0)
	p.scale_amount_min = 0.03 * scale if sparks else 0.12 * scale
	p.scale_amount_max = 0.05 * scale if sparks else 0.3 * scale
	var curve := Curve.new(); curve.add_point(Vector2(0, 0.6)); curve.add_point(Vector2(1, 1.4 if not sparks else 0.1))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(color, 1.0)); g.set_color(1, Color(color, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new(); q.size = Vector2.ONE
	q.material = _pmat(Color.WHITE, sparks)
	p.mesh = q
	_world().add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

static func explosion(pos: Vector3, radius: float, damage: float, source: Node = null) -> void:
	var w := _world()
	AudioBus.play_3d("explosion", pos, 4.0, 0.1, 150.0)
	Game.emit_noise(pos, 60.0, source)
	burst(pos, Vector3.UP, Color(1.0, 0.6, 0.25), 30, true, 1.6)
	burst(pos, Vector3.UP, Color(0.18, 0.17, 0.16), 18, false, 4.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3); light.omni_range = radius * 3.0; light.light_energy = 8.0
	w.add_child(light)
	light.global_position = pos + Vector3.UP * 0.5
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5)
	tw.tween_callback(light.queue_free)
	_decal(w, pos + Vector3.UP * 0.1, Vector3.UP, true)
	var space := (w as Node3D).get_world_3d().direct_space_state if w is Node3D else null
	if space == null:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new(); s.radius = radius
	q.shape = s
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = 2 | 4 | 8
	for r in space.intersect_shape(q, 48):
		var c: Object = instance_from_id(int(r["collider_id"]))
		if c == null or not is_instance_valid(c) or c == source:
			continue
		var cpos: Vector3 = c.global_position
		var dist := cpos.distance_to(pos)
		var fall := clampf(1.0 - dist / radius, 0.0, 1.0)
		# Linha de visão: paredes protegem.
		var lq := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, cpos + Vector3.UP * 0.5, 1)
		if not space.intersect_ray(lq).is_empty():
			fall *= 0.25
		var dir := (cpos - pos + Vector3.UP * 0.5).normalized()
		if c is RigidBody3D:
			c.apply_central_impulse(dir * 18.0 * fall * sqrt(maxf(c.mass, 1.0)))
		Combat.apply_hit(c, damage * fall, cpos, dir * 4.0 * fall, source, "explosion")
	var pl = Game.player
	if is_instance_valid(pl):
		var d2: float = pl.global_position.distance_to(pos)
		pl.shake(clampf(1.0 - d2 / (radius * 4.0), 0.0, 0.8))
