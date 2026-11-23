class_name Fire
extends RefCounted
## Fogo: queima contínua em alvos (Burn) e áreas de chamas no chão (Area). Usado pelo Imolador,
## coquetel molotov, pistola sinalizadora e rifle incendiário. Partículas CPU leves (mobile).

const FLAME_COL := Color(1.0, 0.55, 0.18)

static func _flames(parent: Node3D, radius: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 2.5, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var q := QuadMesh.new(); q.size = Vector2(0.45, 0.45)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/textures/fx_smoke.png"):
		m.albedo_texture = load("res://assets/textures/fx_smoke.png")
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.35, 0.9))
	g.add_point(0.5, Color(1.0, 0.4, 0.1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.2, 0.15, 0.1, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	return p

## Incendeia um alvo (inimigo, jogador, prop). Renova a duração se já estiver queimando.
static func ignite(target: Node, secs := 5.0, source: Node = null, dps := 7.0) -> void:
	if target == null or not is_instance_valid(target) or not (target is Node3D):
		return
	if target.has_meta("no_burn"):
		return
	for c in target.get_children():
		if c is Burn:
			c.time_left = maxf(c.time_left, secs)
			return
	var b := Burn.new()
	b.time_left = secs
	b.source = source
	b.dps = dps
	target.add_child(b)

class Burn extends Node3D:
	var time_left := 5.0
	var dps := 7.0
	var source: Node
	var _tick := 0.0
	var _fx: CPUParticles3D
	var _light: OmniLight3D
	func _ready() -> void:
		position = Vector3(0, 1.0, 0) if get_parent() is CharacterBody3D else Vector3.ZERO
		if not (get_parent() is Player):
			_fx = Fire._flames(self, 0.35, 14)
			_light = OmniLight3D.new()
			_light.light_color = Fire.FLAME_COL; _light.omni_range = 4.0; _light.light_energy = 1.2
			add_child(_light)
		AudioBus.play_3d("fire_ignite", global_position, -4.0, 0.1, 30.0)
	func _physics_process(delta: float) -> void:
		time_left -= delta
		_tick -= delta
		var host := get_parent()
		if _light:
			_light.light_energy = 1.0 + randf() * 0.5
		if host == null or not is_instance_valid(host) or time_left <= 0.0 or (host.get("alive") == false):
			queue_free()
			return
		# entrar na água apaga
		if host is Node3D and host.get("in_water") == true:
			queue_free()
			return
		if _tick <= 0.0:
			_tick = 0.5
			Combat.apply_hit(host, dps * 0.5, (host as Node3D).global_position + Vector3.UP, Vector3.UP * 0.01, source, "fire")
			if host is Player:
				host.shake(0.05)

## Som em loop próprio (não usa o pool do AudioBus, que recicla vozes).
static func loop_player(parent: Node3D, name: String, vol := 0.0, max_dist := 40.0) -> AudioStreamPlayer3D:
	var st = AudioBus.get_stream(name)
	if st == null:
		return null
	if st is AudioStreamWAV and st.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		st = st.duplicate()
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * st.mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol
	p.max_distance = max_dist
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.autoplay = true
	parent.add_child(p)
	return p

## Área de chamas no chão: queima quem estiver dentro e incendeia.
static func area(pos: Vector3, radius: float, secs: float, source: Node = null, dps := 14.0) -> Node3D:
	var a := FireArea.new()
	a.radius = radius
	a.life = secs
	a.source = source
	a.dps = dps
	Effects._world().add_child(a)
	a.global_position = pos
	return a

class FireArea extends Node3D:
	var radius := 2.0
	var life := 6.0
	var dps := 14.0
	var source: Node
	var _tick := 0.0
	var _light: OmniLight3D
	var _snd: AudioStreamPlayer3D
	func _ready() -> void:
		add_to_group("fire_area")
		set_meta("no_carry", true)
		var fx := Fire._flames(self, radius * 0.7, clampi(int(radius * 10), 10, 30))
		fx.position.y = 0.2
		_light = OmniLight3D.new()
		_light.light_color = Fire.FLAME_COL; _light.omni_range = radius * 3.0; _light.light_energy = 2.0
		_light.position.y = 0.6
		add_child(_light)
		_snd = Fire.loop_player(self, "fire_loop", -4.0, 30.0)
	func _physics_process(delta: float) -> void:
		life -= delta
		_light.light_energy = clampf(life, 0.0, 1.0) * (1.6 + randf() * 0.6)
		if life <= 0.0:
			queue_free()
			return
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = 0.33
		var space := get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new(); s.radius = radius
		q.shape = s
		q.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.5)
		q.collision_mask = 2 | 4 | 8
		var seen := {}
		for r in space.intersect_shape(q, 24):
			var c: Object = instance_from_id(int(r["collider_id"]))
			if c == null or not is_instance_valid(c) or seen.has(c):
				continue
			seen[c] = true
			Combat.apply_hit(c, dps * 0.33, (c as Node3D).global_position, Vector3.UP * 0.01, source, "fire")
			if c is Node and (c.is_in_group("enemy") or c is Player):
				Fire.ignite(c, 3.0, source)
