class_name EnemyAI
extends NpcBase
## Inimigo humanoide (Vigilante / Soldado do Domínio).
## Percepção: cone de visão + linha de visada (raycast), audição via Game.noise_emitted, alerta de esquadrão.
## Estados: IDLE, PATROL, INVESTIGATE, COMBAT, COVER, SEARCH, DEAD.
## Raciocínio escalonado (6–10 Hz, com deslocamento aleatório) para distribuir custo de CPU.

enum S { IDLE, PATROL, INVESTIGATE, COMBAT, COVER, SEARCH, DEAD }
const STATE_NAMES := ["idle", "patrol", "investigate", "combat", "cover", "search", "dead"]

var state := S.IDLE
var kind := "vigilante_pistol"
var patrol: Array[Vector3] = []
var _patrol_i := 0
var view_dist := 26.0
var fov_cos := cos(deg_to_rad(60))
var damage := 6.0
var fire_interval := 0.55
var burst := 3
var accuracy := 0.8
var melee := false
var _think_t := 0.0
var _think_rate := 0.12
var _fire_t := 0.0
var _burst_left := 0
var _sees := false
var _last_seen := Vector3.INF
var _last_seen_t := 999.0
var _state_t := 0.0
var _cover_pt: Vector3 = Vector3.INF
var _hurt_recent := 0.0
var _awareness := 0.0
var _chatter_t := 0.0
var _flash: OmniLight3D
var target_override: Node3D = null
var passive := false     # roteiro: ignora percepção até ser ativado
var drops := {}           # {"ammo_pistol": 12}

static func make(p_kind := "vigilante_pistol", seed_v := 0) -> EnemyAI:
	var e := EnemyAI.new()
	e.kind = p_kind
	e.name = "Enemy"
	match p_kind:
		"vigilante_baton":
			e.setup_body("vigilante", seed_v); e.body.attach_weapon("baton")
			e.health = 45.0; e.melee = true; e.damage = 14.0; e.fire_interval = 1.0; e.burst = 1
		"vigilante_pistol":
			e.setup_body("vigilante", seed_v); e.body.attach_weapon("pistol")
			e.health = 50.0; e.damage = 5.0; e.fire_interval = 0.45; e.burst = 3; e.accuracy = 0.65
			e.drops = {"ammo_9mm": 9}
		"vigilante_elite":
			e.setup_body("vigilante_elite", seed_v); e.body.attach_weapon("rifle")
			e.health = 70.0; e.damage = 5.0; e.fire_interval = 0.1; e.burst = 5; e.accuracy = 0.7; e.view_dist = 30.0
			e.drops = {"ammo_9mm": 20}
		"conscript_hostile":
			e.setup_body("conscript", seed_v); e.body.attach_weapon("rifle")
			e.health = 60.0; e.damage = 6.0; e.fire_interval = 0.12; e.burst = 4; e.accuracy = 0.6
			e.drops = {"ammo_762": 15}
		"soldier":
			e.setup_body("soldier", seed_v); e.body.attach_weapon("rifle")
			e.health = 80.0; e.damage = 6.0; e.fire_interval = 0.11; e.burst = 6; e.accuracy = 0.7; e.view_dist = 34.0
			e.drops = {"ammo_9mm": 20}
	return e

func _ready() -> void:
	add_to_group("enemy")
	Game.noise_emitted.connect(_on_noise)
	_think_t = randf() * _think_rate
	_think_rate = randf_range(0.1, 0.16)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_flash.omni_range = 4.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)
	_flash.position = Vector3(0, 1.4, 0.6)
	if patrol.size() > 1:
		_set_state(S.PATROL)

func state_name() -> String:
	return STATE_NAMES[state]

func _target() -> Node3D:
	if is_instance_valid(target_override):
		return target_override
	if is_instance_valid(Game.player) and Game.player.alive:
		return Game.player
	return null

func _set_state(s: S) -> void:
	if state == s:
		return
	state = s
	_state_t = 0.0
	Game.set_alerted(self, s in [S.COMBAT, S.COVER, S.SEARCH])
	match s:
		S.COMBAT:
			if _chatter_t <= 0.0:
				AudioBus.play_3d("enemy_alert", global_position + Vector3.UP * 1.6, -2.0)
				_chatter_t = 4.0
			_alert_squad()
		S.SEARCH, S.INVESTIGATE:
			_radio()

func _radio() -> void:
	if _chatter_t <= 0.0:
		AudioBus.play_3d("radio_chatter_%d" % (randi() % 6), global_position + Vector3.UP * 1.6, -8.0, 0.05, 25.0)
		_chatter_t = 5.0

func _alert_squad() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e.has_method("hear_alert") and e.alive and e.global_position.distance_to(global_position) < 18.0:
			e.hear_alert(_last_seen if _last_seen != Vector3.INF else global_position)

func hear_alert(pos: Vector3) -> void:
	if passive:
		return
	if state in [S.IDLE, S.PATROL, S.INVESTIGATE]:
		_last_seen = pos
		_last_seen_t = 0.5
		_awareness = 1.0
		_set_state(S.COMBAT)

func _on_noise(pos: Vector3, radius: float, src: Node) -> void:
	if not alive or passive or src == self or src is EnemyAI:
		return
	if global_position.distance_to(pos) > radius:
		return
	if state in [S.IDLE, S.PATROL, S.SEARCH]:
		_last_seen = pos
		_set_state(S.INVESTIGATE)
		go_to(pos, 2.4)

func _can_see(t: Node3D) -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var tp: Vector3 = t.eye_position() if t.has_method("eye_position") else t.global_position + Vector3.UP
	var to := tp - eye
	var dist := to.length()
	var vd := view_dist * (0.6 if (t is Player and t.crouching) else 1.0)
	if dist > vd:
		return false
	var fwd := global_basis.z
	var close := dist < 2.5
	if not close and fwd.dot(to / dist) < (fov_cos if state < S.COMBAT else -0.2):
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, tp, 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_state_t += delta
	_last_seen_t += delta
	_chatter_t -= delta
	_hurt_recent = maxf(0.0, _hurt_recent - delta)
	_fire_t -= delta
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, delta * 30.0)
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = _think_rate
		_think()
	var t := _target()
	if state in [S.COMBAT, S.COVER] and t:
		face_dir = t.global_position - global_position
		body.look_target = t.global_position + Vector3.UP * 1.4
		body.aim = move_toward(body.aim, 1.0, delta * 4.0)
		if _sees:
			_try_fire(t)
	else:
		face_dir = Vector3.ZERO
		body.look_target = Vector3.INF if state != S.INVESTIGATE else _last_seen + Vector3.UP
		body.aim = move_toward(body.aim, 0.25 if state == S.SEARCH else 0.0, delta * 2.0)
	body.crouch = move_toward(body.crouch, 1.0 if (state == S.COVER and not _peeking()) else 0.0, delta * 4.0)
	_nav_step(delta)

func _peeking() -> bool:
	return fmod(_state_t, 3.2) > 1.9

func activate(alert_pos := Vector3.INF) -> void:
	passive = false
	if alert_pos != Vector3.INF:
		hear_alert(alert_pos)

func _think() -> void:
	if passive:
		_sees = false
		return
	var t := _target()
	_sees = t != null and _can_see(t)
	if _sees:
		_awareness = minf(1.0, _awareness + (0.6 if state >= S.INVESTIGATE else 0.35))
		if _awareness >= 1.0:
			_last_seen = t.global_position
			_last_seen_t = 0.0
	else:
		_awareness = maxf(0.0, _awareness - 0.04)
	match state:
		S.IDLE:
			if _awareness >= 1.0: _set_state(S.COMBAT)
		S.PATROL:
			if _awareness >= 1.0:
				_set_state(S.COMBAT)
			elif has_arrived() and patrol.size() > 0:
				_patrol_i = (_patrol_i + 1) % patrol.size()
				go_to(patrol[_patrol_i], 1.3)
		S.INVESTIGATE:
			if _awareness >= 1.0:
				_set_state(S.COMBAT)
			elif has_arrived() and _state_t > 4.0:
				_set_state(S.PATROL if patrol.size() > 1 else S.IDLE)
				if patrol.size() > 0: go_to(patrol[_patrol_i], 1.3)
		S.COMBAT:
			_combat_think(t)
		S.COVER:
			if t == null:
				_set_state(S.SEARCH)
			elif _state_t > 6.0 or (t.global_position.distance_to(global_position) < 4.0):
				_set_state(S.COMBAT)
		S.SEARCH:
			if _awareness >= 1.0:
				_set_state(S.COMBAT)
			elif has_arrived():
				if _state_t > 12.0:
					_set_state(S.PATROL if patrol.size() > 1 else S.IDLE)
				else:
					var r := Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
					go_to(_last_seen + r, 1.8)

func _combat_think(t: Node3D) -> void:
	if t == null:
		_set_state(S.SEARCH)
		return
	if _last_seen_t > 5.0:
		_set_state(S.SEARCH)
		go_to(_last_seen, 2.8)
		return
	var d := global_position.distance_to(t.global_position)
	if melee:
		go_to(t.global_position, 5.2 if d > 2.0 else 0.0)
		return
	if not _sees:
		# flanqueia em direção à última posição vista
		if has_arrived() or _state_t > 2.0:
			_state_t = 0.0
			var side := Vector3(t.global_position - global_position).cross(Vector3.UP).normalized() * randf_range(-5, 5)
			go_to(_last_seen + side, 3.2)
		return
	# ferido recentemente → procura cobertura
	if _hurt_recent > 0.0 and _cover_pt == Vector3.INF:
		var c := _find_cover(t)
		if c != Vector3.INF:
			_cover_pt = c
			go_to(c, 4.5, func(): _set_state(S.COVER))
			return
	if d > 18.0:
		go_to(t.global_position, 3.0)
	elif d < 6.0:
		go_to(global_position + (global_position - t.global_position).normalized() * 3.0, 2.2)
	elif has_arrived() and randf() < 0.15:
		var strafe := (t.global_position - global_position).cross(Vector3.UP).normalized() * randf_range(-3, 3)
		go_to(global_position + strafe, 2.0)

func _find_cover(t: Node3D) -> Vector3:
	var best := Vector3.INF
	var best_d := 14.0
	var space := get_world_3d().direct_space_state
	for c in get_tree().get_nodes_in_group("cover"):
		var cp: Vector3 = c.global_position
		var d := cp.distance_to(global_position)
		if d > best_d or cp.distance_to(t.global_position) < 5.0:
			continue
		if c.has_meta("taken") and is_instance_valid(c.get_meta("taken")) and c.get_meta("taken") != self:
			continue
		var q := PhysicsRayQueryParameters3D.create(cp + Vector3.UP * 0.8, t.global_position + Vector3.UP * 1.0, 1)
		if not space.intersect_ray(q).is_empty():
			best = cp; best_d = d
			c.set_meta("taken", self)
	return best

func _try_fire(t: Node3D) -> void:
	if _fire_t > 0.0 or body.aim < 0.8:
		return
	if state == S.COVER and not _peeking():
		return
	var d := global_position.distance_to(t.global_position)
	if melee:
		if d < 1.9:
			_fire_t = fire_interval
			body.flinch(-global_basis.z * 1.5)
			AudioBus.play_3d("impact_flesh", t.global_position + Vector3.UP, 0.0)
			Combat.apply_hit(t, damage, t.global_position + Vector3.UP, global_basis.z, self, "melee")
		return
	if _burst_left <= 0:
		_burst_left = burst
	_burst_left -= 1
	_fire_t = fire_interval if _burst_left > 0 else fire_interval * 2.5 + randf() * 0.8
	var from: Vector3 = body.muzzle.global_position if body.muzzle else global_position + Vector3.UP * 1.4
	var tp: Vector3 = t.global_position + Vector3.UP * randf_range(0.9, 1.6)
	# precisão: piora com distância, movimento do alvo e quando o alvo está agachado
	var tv: Vector3 = t.velocity if t is CharacterBody3D else Vector3.ZERO
	var miss := (1.0 - accuracy) * (0.4 + d * 0.06) + tv.length() * 0.05
	var diff: float = Settings.get_v("access", "difficulty", 1)
	miss *= [1.6, 1.0, 0.75][clampi(int(diff), 0, 2)]
	tp += Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * miss
	var dir := (tp - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 1 | 2 | 4 | 8)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * 60.0
	AudioBus.play_3d("smg_fire" if kind == "soldier" else "pistol_fire", from, -3.0, 0.1, 90.0)
	_flash.light_energy = 3.0
	if not hit.is_empty():
		end = hit.position
		var dmg = damage * [0.6, 1.0, 1.3][clampi(int(diff), 0, 2)]
		if hit.collider is Player:
			hit.collider.take_damage(dmg, global_position, "bullet")
		else:
			Combat.apply_hit(hit.collider, dmg, hit.position, dir, self, "bullet")
			Effects.impact(hit.position, hit.normal, Mats.surface_of(hit.collider), dir)
	_tracer(from, end)

func _tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a); im.surface_add_vertex(a.lerp(b, 0.7))
	im.surface_end()
	mi.mesh = im
	mi.material_override = Mats.emissive(Color(1.0, 0.8, 0.5), 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := Game.level if is_instance_valid(Game.level) else get_parent()
	w.add_child(mi)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)

func _on_hurt(_dmg: float, src: Node, _type: String) -> void:
	_hurt_recent = 3.0
	AudioBus.play_3d("enemy_pain", global_position + Vector3.UP * 1.5, -3.0)
	if src and src is Node3D:
		_last_seen = src.global_position
		_last_seen_t = 0.0
		_awareness = 1.0
	if state < S.COMBAT:
		_set_state(S.COMBAT)

func _on_died() -> void:
	state = S.DEAD
	Game.set_alerted(self, false)
	AudioBus.play_3d("enemy_death", global_position + Vector3.UP * 1.5, -2.0)
	if _cover_pt != Vector3.INF:
		for c in get_tree().get_nodes_in_group("cover"):
			if c.get_meta("taken", null) == self:
				c.remove_meta("taken")
	for k in drops:
		Interactables.pickup(get_parent(), global_position + Vector3(randf_range(-0.4, 0.4), 0.25, randf_range(-0.4, 0.4)), k, drops[k])
