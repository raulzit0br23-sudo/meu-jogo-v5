class_name NpcAlly
extends NpcBase
## Personagem aliado/civil: segue o jogador, vai até pontos roteirizados, olha para quem fala,
## permanece sentado/encostado, fala com voz posicional. Civis podem fugir de tiros.

enum Mode { IDLE, FOLLOW, SCRIPT, FLEE, SIT }
var mode := Mode.IDLE
var follow_dist := 2.6
var invulnerable := true
var _think := 0.0
var _flee_from := Vector3.ZERO
var on_use: Callable
var use_hint := "hud.use"

func get_hint() -> String:
	return Loc.t(use_hint) if on_use.is_valid() else ""

func interact(_by: Node) -> void:
	if on_use.is_valid():
		var cb := on_use
		on_use = Callable()
		cb.call()

static func make(id: String, outfit := "citizen", seed_v := 0, weapon := "") -> NpcAlly:
	var n := NpcAlly.new()
	n.npc_id = id
	n.name = id.capitalize() if id != "" else "Citizen"
	n.setup_body(outfit, seed_v)
	if weapon != "":
		n.body.attach_weapon(weapon)
	return n

func _ready() -> void:
	add_to_group("npc")
	if npc_id != "":
		Dialogue.register_speaker(npc_id, self)
	Game.noise_emitted.connect(_on_noise)
	_think = randf() * 0.2

func set_mode(m: Mode) -> void:
	mode = m
	if body:
		body.sit = 1.0 if m == Mode.SIT else 0.0

func _physics_process(delta: float) -> void:
	_think -= delta
	var p: Node3D = Game.player if is_instance_valid(Game.player) else null
	if _think <= 0.0:
		_think = 0.2
		match mode:
			Mode.FOLLOW:
				if p:
					var d := global_position.distance_to(p.global_position)
					if d > follow_dist + 1.0:
						go_to(p.global_position, 4.5 if d > 7.0 else 2.0)
					elif d < follow_dist:
						stop_moving()
			Mode.FLEE:
				var away := (global_position - _flee_from)
				away.y = 0
				go_to(global_position + away.normalized() * 6.0, 5.0)
	# olha o jogador quando próximo ou quando fala
	if p and global_position.distance_to(p.global_position) < 6.0:
		body.look_target = p.global_position + Vector3.UP * 1.55
		if has_arrived() and mode != Mode.SIT:
			face_dir = (p.global_position - global_position)
	else:
		body.look_target = Vector3.INF
		face_dir = Vector3.ZERO
	if mode == Mode.SIT:
		velocity = Vector3.ZERO
		body.speed = 0.0
		body.talk = clampf(AudioBus.voice_energy() * 3.0, 0, 1) if voice.playing else 0.0
		body.animate(delta)
		return
	_nav_step(delta)

func _on_noise(pos: Vector3, radius: float, _src: Node) -> void:
	if npc_id == "" and radius > 15.0 and global_position.distance_to(pos) < radius and mode == Mode.IDLE:
		_flee_from = pos
		mode = Mode.FLEE

func take_hit(damage: float, pos: Vector3, dir: Vector3, source: Node = null, type := "bullet") -> void:
	if invulnerable:
		if body: body.flinch(dir)
		return
	super.take_hit(damage, pos, dir, source, type)
