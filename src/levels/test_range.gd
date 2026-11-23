extends LevelBase
## SALA DE TESTES — hangar de QA acessível pelo menu principal (fora da campanha).
## Estações: A) Arsenal e painel do jogador · B) Estande de tiro (alvos com contador de dano)
## C) Arena de combate (gerador de inimigos) · D) Física (todos os objetos, barris explosivos)
## E) Circuito de movimento (escada, rampa, escada de mão, túnel agachado, saltos, queda,
##    esteira, portas, zona de dano, holofote) · F) NPCs, dublagem e áudio · G) Materiais
## H) Gráficos (predefinições ao vivo + painel de desempenho).
## Não salva progresso (Game.save_game ignora o capítulo 0).

const PROP_KINDS := ["crate", "crate_small", "barrel", "explosive", "cinder", "bucket", "bottle", "pallet", "plank", "suitcase"]
const MAT_NAMES := ["concrete", "brick", "tiles", "asphalt", "rusted_paint", "steel", "grate", "dominion", "wood", "gravel", "cracked_earth",
	"sand", "corrugated", "fabric", "camo_ow", "flak", "hazmat", "gunmetal", "polymer", "stock_wood", "leather", "rubber"]
const HUMAN_OUTFITS := ["citizen", "citizen", "vigilante", "vigilante_elite", "soldier", "conscript"]
const AMBIENCES := ["industrial_hum", "rain", "station_hall", "train_interior", "wind_city"]

var M := {}
var _props: Array[Node] = []
var _spawned: Array[Node] = []
var _targets: Array = []
var _passive := false
var _god := false
var _perf_on := true
var _perf: Label
var _perf_t := 0.0
var _irina: NpcAlly
var _amb_i := 0
var _all_lines: Array = []
var _line_i := 0
var _hazard: Area3D
var _hazard_in := false
var _hazard_t := 0.0
var _status: Label3D
var _search: Searchlight
var _plat: AnimatableBody3D
var _humans: Array[Node] = []

func _mats() -> void:
	M = {
		"conc": Mats.get_mat("concrete", 0.35, Color(0.62, 0.62, 0.6)),
		"conc_dark": Mats.get_mat("concrete", 0.35, Color(0.4, 0.41, 0.4)),
		"floor": Mats.get_mat("tiles", 0.25, Color(0.55, 0.55, 0.52)),
		"brick": Mats.get_mat("brick", 0.4, Color(0.6, 0.53, 0.48)),
		"paint": Mats.get_mat("rusted_paint", 0.5, Color(0.5, 0.62, 0.6)),
		"paint_y": Mats.get_mat("rusted_paint", 0.5, Color(0.88, 0.72, 0.3)),
		"paint_red": Mats.get_mat("rusted_paint", 0.5, Color(0.72, 0.4, 0.33)),
		"steel": Mats.get_mat("steel", 0.6, Color(0.6, 0.6, 0.58)),
		"steel_dark": Mats.get_mat("steel", 0.6, Color(0.35, 0.35, 0.34)),
		"grate": Mats.get_mat("grate", 0.6, Color(0.7, 0.7, 0.68)),
		"wood": Mats.get_mat("wood", 0.8, Color(0.72, 0.62, 0.5)),
		"rubber": Mats.get_mat("rubber", 1.0, Color(0.5, 0.5, 0.5)),
		"target": Mats.flat(Color(0.85, 0.82, 0.75), 0.7),
		"target_ring": Mats.flat(Color(0.7, 0.18, 0.12), 0.6),
		"hazard": Mats.emissive(Color(0.2, 0.7, 1.0), 1.2),
	}

func build() -> void:
	_mats()
	grid = {"hall": 16.0}
	setup_env(Color(0.1, 0.11, 0.12), Color(0.62, 0.62, 0.6), 1.2, Color(0.2, 0.2, 0.2), 0.004, 0.0, 0.4)
	env.tonemap_exposure = 1.5
	_build_hall()
	_build_arsenal()
	_build_range()
	_build_arena()
	_build_physics()
	_build_course()
	_build_npcs()
	_build_materials()
	_build_graphics()
	checkpoints["start"] = [Vector3(0, 0.05, 2.0), 0.0]
	# pontos de câmera para QA (--cp=)
	checkpoints["range"] = [Vector3(-21, 0.05, -5.0), 0.0]
	checkpoints["arena"] = [Vector3(18, 0.05, -4.5), 0.0]
	checkpoints["physics"] = [Vector3(0, 0.05, -7.5), 0.0]
	checkpoints["course"] = [Vector3(0, 0.05, -38.0), 0.0]
	checkpoints["npc"] = [Vector3(-24, 0.05, 0.0), PI * 0.5]
	checkpoints["south"] = [Vector3(8, 0.05, -2.0), PI]

func after_build() -> void:
	Game.set_objective("obj.test")
	AudioBus.play_ambience("res://assets/audio/ambience/industrial_hum.wav", "", -12.0)
	AudioBus.set_room(0.7, 0.3)
	AudioBus.start_music()
	_give_all()
	_reset_props()
	_spawn_humans()
	_make_perf_panel()
	_status_msg(Loc.t("test.welcome"))

# =====================================================================
# Utilidades
# =====================================================================
func sign3d(pos: Vector3, yaw: float, text: String, size := 64, color := Color(0.95, 0.85, 0.55), width_px := 900.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.shaded = false
	l.double_sided = false
	l.width = width_px
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	l.global_position = pos
	l.rotation.y = yaw
	return l

## Botão reutilizável com placa acima. yaw = direção para onde o botão olha.
func panel_button(pos: Vector3, yaw: float, label_key: String, cb: Callable) -> Interactables.Switch:
	var s := Interactables.button(self, pos, yaw)
	s.once = false
	s.hint_key = label_key
	s.activated.connect(func():
		s.used = false
		cb.call())
	var pb := Basis(Vector3.UP, yaw)
	# pedestal
	box("hall", pos + pb * Vector3(0, -0.6, -0.12), Vector3(0.5, 1.0, 0.2), M["steel_dark"], Vector3(0, yaw, 0))
	var lb := sign3d(pos + pb * Vector3(0, 0.25, 0.02), yaw, Loc.t(label_key), 26, Color(0.95, 0.88, 0.6), 190.0)
	lb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return s

func _status_msg(t: String) -> void:
	if is_instance_valid(_status):
		_status.text = t
	get_tree().call_group("hud", "flash_pickup", t)

# =====================================================================
# Hangar (x -32..32, z 6..-72)
# =====================================================================
func _build_hall() -> void:
	var sec := "hall"
	sector(sec)
	room(sec, Vector3(0, 0, -33), Vector3(64, 12, 78), M["brick"], M["floor"], M["conc_dark"])
	# faixas de piso por estação
	for z in [-6.0, -40.0]:
		box(sec, Vector3(0, 0.005, z), Vector3(64, 0.01, 0.25), M["paint_y"], Vector3.ZERO, false)
	for x in [-10.0, 10.0]:
		box(sec, Vector3(x, 0.005, -23), Vector3(0.25, 0.01, 34), M["paint_y"], Vector3.ZERO, false)
	# treliças de teto e pilares
	for z in range(0, 9):
		var zz := 4.0 - z * 9.0
		box(sec, Vector3(0, 11.4, zz), Vector3(64, 0.5, 0.3), M["steel_dark"], Vector3.ZERO, false)
	for x in [-31.4, 31.4]:
		for z in range(0, 9):
			box(sec, Vector3(x, 6, 4.0 - z * 9.0), Vector3(0.6, 12, 0.6), M["conc"])
	# luzes (grade 16 m, compatível com o limite de luzes por malha do Mobile)
	for x in [-24.0, -8.0, 8.0, 24.0]:
		for z in [0.0, -16.0, -32.0, -48.0, -64.0]:
			# luminária pendurada na treliça
			mesh_at(sec, MeshKit.cylinder(0.01, 3.6, 4), Transform3D(Basis(), Vector3(x, 9.4, z)), M["steel_dark"])
			tube_lamp(sec, Vector3(x, 7.5, z), 0.0, Color(0.95, 0.95, 0.9), 3.0, 17.0)
	sign3d(Vector3(0, 7.5, -71.6), 0.0, Loc.t("test.title"), 160, Color(0.95, 0.9, 0.75))
	acoustic_zone(Vector3(0, 6, -33), Vector3(64, 12, 78), 0.7, 0.3)

# =====================================================================
# A) Arsenal + painel do jogador (z 6..-6, centro)
# =====================================================================
func _build_arsenal() -> void:
	var sec := "hall"
	# bancada
	box(sec, Vector3(0, 0.45, -3.0), Vector3(7.0, 0.9, 1.0), M["wood"])
	box(sec, Vector3(0, 0.93, -3.0), Vector3(7.2, 0.06, 1.1), M["steel_dark"])
	var items := [["wrench", 0], ["pistol", 0], ["smg", 0], ["shotgun", 0], ["ammo_9mm", 60], ["ammo_12", 12], ["medkit", 0], ["filter", 0], ["mask", 0]]
	for i in items.size():
		var x := -3.0 + i * 0.75
		Interactables.pickup(self, Vector3(x, 1.15, -3.0), items[i][0], items[i][1])
	sign3d(Vector3(0, 2.3, -3.6), 0.0, Loc.t("test.arsenal"), 72)
	# segunda bancada: arsenal ampliado (todas as armas inspiradas nas armas cortadas do beta)
	box(sec, Vector3(0, 0.45, 0.6), Vector3(17.0, 0.9, 1.0), M["wood"])
	box(sec, Vector3(0, 0.93, 0.6), Vector3(17.2, 0.06, 1.1), M["steel_dark"])
	var ext := ["iceaxe", "stunbaton", "flaregun", "smg1", "ar1", "oicw", "hmg", "sniper", "missile", "manipulator",
		"immolator", "irifle", "guardgun", "grenade", "molotov", "hopwire", "slam", "brickbat", "binoculars",
		"ammo_762", "ammo_556", "ammo_20mm", "ammo_338", "ammo_rocket"]
	for i in ext.size():
		var amt := 0
		if String(ext[i]).begins_with("ammo_"):
			amt = {"ammo_762": 60, "ammo_556": 60, "ammo_20mm": 3, "ammo_338": 10, "ammo_rocket": 2}[ext[i]]
		Interactables.pickup(self, Vector3(-8.0 + i * 0.69, 1.15, 0.6), ext[i], amt)
	# painel do jogador (lado leste da bancada, voltado para +Z)
	var bx := 5.0
	panel_button(Vector3(bx, 1.2, -3.2), 0.0, "test.btn.all_weapons", _give_all)
	panel_button(Vector3(bx + 1.2, 1.2, -3.2), 0.0, "test.btn.heal", func():
		player.health = player.max_health; player.filter = 100.0
		player.health_changed.emit(player.health, player.filter)
		_status_msg(Loc.t("test.msg.healed")))
	panel_button(Vector3(bx + 2.4, 1.2, -3.2), 0.0, "test.btn.god", func():
		_god = not _god; player.god = _god
		_status_msg(Loc.t("test.msg.god_on") if _god else Loc.t("test.msg.god_off")))
	panel_button(Vector3(bx + 3.6, 1.2, -3.2), 0.0, "test.btn.hurt", func():
		var was := player.god
		player.god = false
		player.take_damage(20.0, player.global_position + Vector3(2, 0, 0))
		player.god = was)
	panel_button(Vector3(bx + 4.8, 1.2, -3.2), 0.0, "test.btn.save_test", func():
		_status_msg(Loc.t("test.msg.no_save")))
	_status = sign3d(Vector3(0, 3.2, -3.6), 0.0, "", 44, Color(0.7, 0.95, 0.85))

func _give_all() -> void:
	if not is_instance_valid(player):
		return
	for w in WeaponManager.DEFS:
		player.weapons.give(w, true)
	for a in WeaponManager.MAX_AMMO:
		player.weapons.add_ammo(a, 999)
	player.set_mask(true)
	player.weapons.equip("smg")
	_status_msg(Loc.t("test.msg.armed"))

# =====================================================================
# B) Estande de tiro (oeste: x -32..-10, z -6..-40)
# =====================================================================
class Target extends StaticBody3D:
	var label: Label3D
	var total := 0.0
	var hits := 0
	var plate: MeshInstance3D
	var dist := 0.0
	func take_hit(damage: float, _pos: Vector3, _dir: Vector3, _src: Node = null, _type := "bullet") -> void:
		total += damage
		hits += 1
		_refresh()
		AudioBus.play_3d("impact_metal", global_position, -6.0)
		var tw := create_tween()
		plate.rotation.x = -0.35
		tw.tween_property(plate, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC)
	func take_damage(amount: float, pos: Vector3 = Vector3.ZERO, type := "bullet") -> void:
		take_hit(amount, pos, Vector3.ZERO, null, type)
	func reset() -> void:
		total = 0.0; hits = 0; _refresh()
	func _refresh() -> void:
		label.text = "%d m\n%s: %d  ·  %s: %d" % [int(dist), Loc.t("test.hits"), hits, Loc.t("test.dmg"), int(total)]

func _target(pos: Vector3, dist: float) -> void:
	var t := Target.new()
	t.dist = dist
	t.set_meta("surface", "metal")
	add_child(t)
	t.global_position = pos
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.0, 1.7, 0.12); cs.shape = bs
	cs.position = Vector3(0, 1.15, 0)
	t.add_child(cs)
	# poste + placa silhueta (cabeça + tronco) com anéis
	var post := MeshInstance3D.new()
	post.mesh = MeshKit.cylinder(0.04, 0.3, 8)
	post.material_override = M["steel_dark"]
	post.position = Vector3(0, 0.15, 0)
	t.add_child(post)
	var plate := MeshInstance3D.new()
	plate.mesh = MeshKit.combine([
		[MeshKit.bevel_box(Vector3(0.9, 1.15, 0.05), 0.04), Transform3D(Basis(), Vector3(0, 0.6, 0))],
		[MeshKit.lathe(PackedVector2Array([Vector2(0, -0.2), Vector2(0.18, -0.18), Vector2(0.2, 0.0), Vector2(0.18, 0.18), Vector2(0, 0.2)]), 12), Transform3D(Basis().scaled(Vector3(1, 1, 0.25)), Vector3(0, 1.4, 0))]])
	plate.material_override = M["target"]
	plate.position = Vector3(0, 0.3, 0)
	t.add_child(plate)
	for r: float in [0.32, 0.18]:
		var ring := MeshInstance3D.new()
		ring.mesh = MeshKit.cylinder(r, 0.012, 20)
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(0, 0.75, 0.03 + (0.32 - r) * 0.05)
		ring.material_override = M["target_ring"] if r > 0.2 else M["target"]
		plate.add_child(ring)
	t.plate = plate
	var l := Label3D.new()
	l.font_size = 40; l.pixel_size = 0.006; l.outline_size = 8; l.shaded = false
	l.modulate = Color(0.9, 0.95, 0.85)
	l.position = Vector3(0, 2.3, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	t.add_child(l)
	t.label = l
	t._refresh()
	_targets.append(t)

func _build_range() -> void:
	var sec := "hall"
	# linha de tiro com balcão
	box(sec, Vector3(-21, 0.55, -7.0), Vector3(20, 1.1, 0.6), M["conc"])
	box(sec, Vector3(-21, 1.13, -7.0), Vector3(20.2, 0.06, 0.8), M["steel_dark"])
	# divisórias de raia
	for x in [-27.0, -21.0, -15.0]:
		box(sec, Vector3(x, 1.0, -9.5), Vector3(0.1, 2.0, 4.0), M["steel"])
	# alvos 10/20/30 m em três raias + fundo de proteção
	var lanes := [-24.0, -18.0, -12.5]
	var dists := [10.0, 20.0, 30.0]
	for i in 3:
		_target(Vector3(lanes[i], 0.0, -7.0 - dists[i]), dists[i])
	_target(Vector3(-29.0, 0.0, -17.0), 10.0)
	box(sec, Vector3(-21, 2.5, -39.5), Vector3(22, 5, 0.6), M["conc_dark"])
	sign3d(Vector3(-21, 2.8, -6.6), 0.0, Loc.t("test.range"), 72)
	panel_button(Vector3(-11.8, 1.45, -6.6), 0.0, "test.btn.reset_targets", func():
		for t in _targets: t.reset()
		_status_msg(Loc.t("test.msg.targets")))

# =====================================================================
# C) Arena de combate (leste: x 10..32, z -6..-40)
# =====================================================================
func _build_arena() -> void:
	var sec := "hall"
	# mureta de separação com vão
	box(sec, Vector3(21, 0.6, -7.0), Vector3(20, 1.2, 0.4), M["conc"])
	# coberturas
	for c: Vector3 in [Vector3(14, 0.6, -16), Vector3(22, 0.6, -14), Vector3(28, 0.6, -20), Vector3(16, 0.6, -26), Vector3(25, 0.6, -30)]:
		box(sec, c, Vector3(2.6, 1.2, 0.6), M["conc_dark"])
		cover(c + Vector3(0, -0.55, 0.7))
		cover(c + Vector3(0, -0.55, -0.7))
	barrier(sec, Vector3(20, 0, -21), 0.3)
	barrier(sec, Vector3(12.5, 0, -33), -0.4)
	sign3d(Vector3(21, 2.8, -6.6), 0.0, Loc.t("test.arena"), 72)
	var bx := 12.0
	var kinds := [["test.btn.spawn_baton", "vigilante_baton"], ["test.btn.spawn_pistol", "vigilante_pistol"], ["test.btn.spawn_soldier", "soldier"]]
	for i in kinds.size():
		var k: String = kinds[i][1]
		panel_button(Vector3(bx + i * 1.3, 1.6, -6.6), 0.0, kinds[i][0], func(): _spawn_enemy(k))
	panel_button(Vector3(bx + 3.9, 1.6, -6.6), 0.0, "test.btn.spawn_squad", func():
		for k in ["vigilante_baton", "vigilante_pistol", "vigilante_pistol", "soldier"]: _spawn_enemy(k))
	panel_button(Vector3(bx + 5.2, 1.6, -6.6), 0.0, "test.btn.passive", func():
		_passive = not _passive
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.get("passive") != null: e.passive = _passive
		_status_msg(Loc.t("test.msg.passive_on") if _passive else Loc.t("test.msg.passive_off")))
	panel_button(Vector3(bx + 6.5, 1.6, -6.6), 0.0, "test.btn.kill_all", func():
		var n := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.has_method("take_hit") and e.get("health") != null and e.health > 0.0:
				e.take_hit(9999.0, e.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD, player, "bullet"); n += 1
		_status_msg(Loc.t("test.msg.killed") % n))
	panel_button(Vector3(bx + 7.8, 1.6, -6.6), 0.0, "test.btn.clear_bodies", func():
		for e in _spawned:
			if is_instance_valid(e): e.queue_free()
		_spawned.clear()
		_status_msg(Loc.t("test.msg.cleared")))

func _spawn_enemy(kind: String) -> void:
	var alive := 0
	for e in _spawned:
		if is_instance_valid(e) and e.health > 0.0: alive += 1
	if alive >= 8:
		_status_msg(Loc.t("test.msg.limit"))
		return
	var e := EnemyAI.make(kind, randi())
	e.passive = _passive
	add_child(e)
	e.global_position = Vector3(randf_range(13.0, 29.0), 0.05, randf_range(-34.0, -37.0))
	e.rotation.y = 0.0
	_spawned.append(e)
	_status_msg(Loc.t("test.msg.spawned") % Loc.t("test.enemy." + kind))

# =====================================================================
# D) Física (centro: x -10..10, z -6..-40)
# =====================================================================
func _build_physics() -> void:
	sign3d(Vector3(0, 3.2, -9.0), 0.0, Loc.t("test.physics"), 72)
	panel_button(Vector3(-1.5, 1.2, -8.6), 0.0, "test.btn.reset_props", _reset_props)
	panel_button(Vector3(1.5, 1.2, -8.6), 0.0, "test.btn.rain_props", func():
		for i in 10:
			var p := PhysicsProp.make(PROP_KINDS[randi() % PROP_KINDS.size()] if i % 4 != 0 else "crate_small")
			add_child(p)
			p.global_position = Vector3(randf_range(-6, 6), 7.0 + i * 0.6, randf_range(-20, -28))
			_props.append(p))
	panel_button(Vector3(4.5, 1.2, -8.6), 0.0, "test.respawn", _spawn_humans)
	sign3d(Vector3(0, 3.3, -26.0), 0.0, Loc.t("test.targets"), 22, Color(0.9, 0.9, 0.8), 1400.0)
	# rampa de lançamento para física
	box("hall", Vector3(-6, 0.5, -34), Vector3(3, 0.15, 6), M["steel"], Vector3(0.35, 0, 0))
	box("hall", Vector3(6, 0.75, -34), Vector3(3, 1.5, 3), M["conc"])

func _reset_props() -> void:
	for p in _props:
		if is_instance_valid(p): p.queue_free()
	_props.clear()
	var i := 0
	for k in PROP_KINDS:
		var row := i % 5
		var col := i / 5
		var p := prop(k, Vector3(-6.0 + row * 3.0, 0.6, -14.0 - col * 4.0), randf() * PI)
		_props.append(p)
		i += 1
	# fileira de barris explosivos (reação em cadeia)
	for j in 4:
		_props.append(prop("explosive", Vector3(-4.5 + j * 1.0, 0.5, -26.0)))
	# pilha de caixas
	for y in 3:
		for x in 3 - y:
			_props.append(prop("crate", Vector3(3.0 + x * 1.05 + y * 0.52, 0.5 + y * 1.0, -30.0)))
	_status_msg(Loc.t("test.msg.props"))

## Alvo humano para testes: personagem completo (mesmo corpo dos NPCs da campanha) que não revida.
## Recebe dano por região (tiro na cabeça x2), queima, é empurrado pelo Manipulador e vira ragdoll.
class HumanTarget extends NpcBase:
	var home := Vector3.ZERO
	var walker := false
	var _t := 0.0
	func _ready() -> void:
		add_to_group("enemy")
		home = global_position
		health = 60.0
	func _physics_process(delta: float) -> void:
		if not alive:
			return
		_t += delta
		if walker and has_arrived():
			go_to(home + Vector3(0, 0, -3.0 if int(_t / 4.0) % 2 == 0 else 0.0), 1.2)
		if Game.player and is_instance_valid(Game.player):
			body.look_target = Game.player.global_position + Vector3.UP * 1.6
		_nav_step(delta)
	func _on_hurt(_d: float, _s: Node, _type: String) -> void:
		body.crouch = 0.5
		AudioBus.play_3d("enemy_pain", global_position + Vector3.UP * 1.5, -4.0, 0.15)

func _spawn_humans() -> void:
	for h in _humans:
		if is_instance_valid(h):
			if h.body: h.body.free_ragdoll()
			h.queue_free()
	_humans.clear()
	for i in HUMAN_OUTFITS.size():
		var h := HumanTarget.new()
		h.name = "Human%d" % i
		h.setup_body(HUMAN_OUTFITS[i], 900 + i * 7 if i != 1 else 3)
		if HUMAN_OUTFITS[i] == "soldier": h.body.attach_weapon("rifle")
		elif HUMAN_OUTFITS[i].begins_with("vigilante"): h.body.attach_weapon("baton" if i == 2 else "pistol")
		h.walker = i == 4
		add_child(h)
		h.global_position = Vector3(-6.5 + i * 2.6, 0.05, -23.0)
		h.home = h.global_position
		h.rotation.y = 0.0
		_humans.append(h)
	_status_msg(Loc.t("test.respawn"))

# =====================================================================
# E) Circuito de movimento (norte: z -40..-72)
# =====================================================================
func _build_course() -> void:
	var sec := "hall"
	sign3d(Vector3(0, 4.6, -41.0), 0.0, Loc.t("test.course"), 72)
	# 1) escada até plataforma (oeste)
	var top := stair(sec, Vector3(-27, 0, -44), 0.0, 2.0, 3.0, M["conc"])
	box(sec, Vector3(-27, 2.85, top.z - 3.0), Vector3(4.0, 0.3, 6.0), M["grate"])
	sign3d(Vector3(-27, 1.5, -43.6), 0.0, Loc.t("test.c.stairs"), 36)
	# 2) saltos entre blocos a partir da plataforma (para leste)
	var z_j := top.z - 3.0
	for i in 4:
		box(sec, Vector3(-22.0 + i * 3.2, 1.5 + i * 0.25, z_j), Vector3(1.6, 3.0 + i * 0.5, 1.6), M["paint"])
	sign3d(Vector3(-17, 4.8, z_j + 1.0), 0.0, Loc.t("test.c.jumps"), 36)
	# 3) túnel agachado
	box(sec, Vector3(-6, 0.65, -50), Vector3(2.2, 0.1, 6), M["steel_dark"])  # teto baixo (1.2 m)
	for s: float in [-1.0, 1.0]:
		box(sec, Vector3(-6 + s * 1.15, 0.6, -50), Vector3(0.1, 1.2, 6), M["steel_dark"])
	box(sec, Vector3(-6, 1.95, -50), Vector3(2.4, 2.5, 6.0), M["conc_dark"])
	sign3d(Vector3(-6, 3.6, -46.8), 0.0, Loc.t("test.c.crouch"), 36)
	# 4) rampa
	box(sec, Vector3(3, 1.0, -50), Vector3(3, 0.2, 8.4), M["conc"], Vector3(0.245, 0, 0))
	box(sec, Vector3(3, 1.0, -56.5), Vector3(3, 2.0, 4.6), M["conc"])
	sign3d(Vector3(3, 2.4, -45.4), 0.0, Loc.t("test.c.ramp"), 36)
	# 5) escada de mão até torre de queda (6 m)
	box(sec, Vector3(11, 3.0, -60), Vector3(3, 6.0, 3), M["conc_dark"])
	Interactables.ladder(self, Vector3(11, 0, -58.35), 0.0, 6.2)
	box(sec, Vector3(11, 6.05, -60), Vector3(3.2, 0.1, 3.2), M["grate"])
	sign3d(Vector3(11, 2.4, -58.2), 0.0, Loc.t("test.c.ladder"), 36)
	# 6) esteira
	_conveyor(Vector3(18, 0, -50), 10.0, Vector3(0, 0, 2.5))
	sign3d(Vector3(18, 2.2, -44.6), 0.0, Loc.t("test.c.conveyor"), 36)
	# 7) plataforma móvel (elevador)
	_plat = AnimatableBody3D.new()
	_plat.sync_to_physics = true
	_plat.set_meta("surface", "metal")
	var pcs := CollisionShape3D.new(); var pbs := BoxShape3D.new(); pbs.size = Vector3(2.4, 0.2, 2.4); pcs.shape = pbs
	_plat.add_child(pcs)
	var pmi := MeshInstance3D.new(); pmi.mesh = MeshKit.bevel_box(Vector3(2.4, 0.2, 2.4), 0.03); pmi.material_override = M["paint_y"]
	_plat.add_child(pmi)
	add_child(_plat)
	_plat.position = Vector3(25, 0.1, -50)
	box(sec, Vector3(25, 2.9, -53.0), Vector3(3, 0.2, 3), M["grate"])
	var tw := create_tween().set_loops()
	tw.tween_interval(2.0)
	tw.tween_property(_plat, "position:y", 3.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.0)
	tw.tween_property(_plat, "position:y", 0.1, 3.0).set_trans(Tween.TRANS_SINE)
	sign3d(Vector3(25, 4.2, -48.6), 0.0, Loc.t("test.c.lift"), 36)
	# 8) portas: física (livre) e trancada (+ botão destrancar)
	for seg: Vector2 in [Vector2(-24.0, -22.55), Vector2(-21.45, -18.55), Vector2(-17.45, -16.0)]:
		box(sec, Vector3((seg.x + seg.y) * 0.5, 1.6, -64), Vector3(seg.y - seg.x, 3.2, 0.3), M["brick"])
	box(sec, Vector3(-20, 2.7, -64), Vector3(8, 1.0, 0.3), M["brick"])
	Interactables.door(self, Vector3(-22.5, 0.0, -64.0), 0.0, Vector3(1.0, 2.15, 0.07), false, Mats.sheet("door_wood"))
	var d2 := Interactables.door(self, Vector3(-18.5, 0.0, -64.0), 0.0, Vector3(1.0, 2.15, 0.07), true, Mats.sheet("door_metal_red"))
	sign3d(Vector3(-20, 3.6, -63.6), 0.0, Loc.t("test.c.doors"), 36)
	panel_button(Vector3(-15.4, 1.2, -63.6), 0.0, "test.btn.unlock", func():
		if is_instance_valid(d2): d2.set_locked(not d2.locked)
		_status_msg(Loc.t("test.msg.unlocked") if not d2.locked else Loc.t("test.msg.locked")))
	# 9) zona de dano (cabo energizado)
	_hazard = Area3D.new()
	_hazard.collision_layer = 0; _hazard.collision_mask = 2
	var hcs := CollisionShape3D.new(); var hbs := BoxShape3D.new(); hbs.size = Vector3(3, 2, 3); hcs.shape = hbs
	_hazard.add_child(hcs)
	add_child(_hazard)
	_hazard.position = Vector3(-6, 1.0, -64)
	_hazard.body_entered.connect(func(b): if b is Player: _hazard_in = true)
	_hazard.body_exited.connect(func(b): if b is Player: _hazard_in = false)
	box(sec, Vector3(-6, 0.02, -64), Vector3(3, 0.04, 3), M["hazard"], Vector3.ZERO, false)
	light(Vector3(-6, 1.0, -64), Color(0.3, 0.7, 1.0), 5.0, 1.2)
	sign3d(Vector3(-6, 2.6, -62.4), 0.0, Loc.t("test.c.hazard"), 36)
	# 10) holofote de vigilância
	var tp := Vector3(29, 0, -68)
	box(sec, tp + Vector3(0, 3.5, 0), Vector3(1.2, 7.0, 1.2), M["steel_dark"])
	_search = Searchlight.new()
	add_child(_search)
	_search.position = tp + Vector3(0, 7.4, 0)
	_search.sweep_center = atan2(-12.0, 14.0)
	_search.sweep_arc = 0.6
	_search.pitch = -0.4
	_search.range_m = 30.0
	_search.spotted.connect(func(_p): _status_msg(Loc.t("test.msg.spotted")))
	sign3d(Vector3(26.5, 2.4, -66.0), 0.0, Loc.t("test.c.searchlight"), 36)

func _conveyor(c: Vector3, length: float, vel: Vector3) -> void:
	var sec := "hall"
	var h := 0.85
	box(sec, c + Vector3(0, h * 0.5 - 0.05, 0), Vector3(1.3, h - 0.1, length), M["steel_dark"], Vector3.ZERO, false)
	for i in int(length / 2.0):
		var z := c.z - length * 0.5 + 1.0 + i * 2.0
		mesh_at(sec, MeshKit.cylinder(0.07, 1.4, 8), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(c.x, h - 0.02, z)), M["steel"])
	box(sec, c + Vector3(0, h + 0.01, 0), Vector3(1.2, 0.04, length), M["rubber"], Vector3.ZERO, false)
	var b := StaticBody3D.new()
	b.set_meta("surface", "metal")
	b.constant_linear_velocity = vel
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.3, h, length); cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.position = c + Vector3(0, h * 0.5, 0)

# =====================================================================
# F) NPCs, dublagem e áudio (sudoeste: x -32..-10, z 6..-6)
# =====================================================================
func _build_npcs() -> void:
	sign3d(Vector3(-31.5, 3.2, -0.5), PI * 0.5, Loc.t("test.npc"), 72)
	_irina = NpcAlly.make("irina", "conscript", 77, "rifle")
	_irina.body.palette["mask"] = false
	add_child(_irina)
	_irina.global_position = Vector3(-16, 0.05, 2)
	_irina.rotation.y = -PI * 0.5
	_irina.set_mode(NpcAlly.Mode.IDLE)
	_irina.on_use = _irina_toggle
	_irina.use_hint = "hud.talk"
	for k in 3:
		var outfit: String = ["citizen", "citizen", "conscript"][k]
		var c := NpcAlly.make("", outfit, 500 + k)
		add_child(c)
		c.global_position = Vector3(-28.0 + k * 1.6, 0.05, 4.0)
		c.rotation.y = PI
		if k == 1: c.set_mode(NpcAlly.Mode.SIT)
	# dublagem: todas as falas dos capítulos 1–3
	for ch in [1, 2, 3]:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch%d.json" % ch))
		if typeof(d) == TYPE_DICTIONARY:
			for seq in d:
				for ln in d[seq]:
					_all_lines.append(ln)
	panel_button(Vector3(-31.0, 1.2, 2.60), PI * 0.5, "test.btn.voice", func():
		if _all_lines.is_empty(): return
		var ln: Dictionary = _all_lines[_line_i % _all_lines.size()]
		_line_i += 1
		say("test_voice", [ln], true)
		_status_msg("%s  (%d/%d)" % [ln.get("id", ""), (_line_i - 1) % _all_lines.size() + 1, _all_lines.size()]))
	panel_button(Vector3(-31.0, 1.2, 1.35), PI * 0.5, "test.btn.voice_lang", func():
		var cur: String = Settings.get_v("access", "voice_lang", "pt")
		Settings.set_v("access", "voice_lang", "en" if cur == "pt" else "pt")
		_status_msg(Loc.t("test.msg.voice_lang") % Settings.get_v("access", "voice_lang", "pt").to_upper()))
	panel_button(Vector3(-31.0, 1.2, 0.10), PI * 0.5, "test.btn.ui_lang", func():
		var cur: String = Settings.get_v("access", "language", "pt")
		Settings.set_v("access", "language", "en" if cur == "pt" else "pt")
		_status_msg(Loc.t("test.msg.ui_lang")))
	panel_button(Vector3(-31.0, 1.2, -1.15), PI * 0.5, "test.btn.ambience", func():
		_amb_i = (_amb_i + 1) % AMBIENCES.size()
		AudioBus.play_ambience("res://assets/audio/ambience/%s.wav" % AMBIENCES[_amb_i], "", -10.0)
		_status_msg(Loc.t("test.msg.ambience") % AMBIENCES[_amb_i]))
	panel_button(Vector3(-31.0, 1.2, -2.40), PI * 0.5, "test.btn.sfx", _sfx_test)
	panel_button(Vector3(-31.0, 1.2, -3.65), PI * 0.5, "test.btn.explosion", func():
		Effects.explosion(Vector3(-1.0, 0.5, -24.5), 5.0, 60.0, null)
		_status_msg(Loc.t("test.msg.boom")))

var _sfx_i := 0
const SFX_LIST := ["pistol_fire", "smg_fire", "shotgun_fire", "rifle_fire", "pulse_fire", "reload_pistol", "reload_smg", "shotgun_pump",
	"impact_metal", "impact_wood", "impact_glass", "glass_break", "wood_break", "door_creak", "door_slam", "gate_motor", "alarm",
	"enemy_alert", "enemy_pain", "enemy_death", "radio_chatter_0", "crawler_idle", "crawler_attack", "heartbeat", "mask_breath",
	"pickup_health", "pickup_item", "lever", "button_press", "explosion",
	"ar1_fire", "oicw_fire", "smg1_fire", "hmg_fire", "sniper_fire", "oicw_grenade", "flare_fire", "rocket_fire", "irifle_fire",
	"guard_charge", "guard_fire", "stun_hit", "swing", "molotov_break", "hopwire_deploy", "hopwire_wire", "slam_place", "slam_beep",
	"fire_ignite", "reload_rifle", "reload_hmg", "sniper_bolt", "firemode"]

func _sfx_test() -> void:
	var n: String = SFX_LIST[_sfx_i % SFX_LIST.size()]
	_sfx_i += 1
	AudioBus.play_3d(n, player.global_position + Vector3(0, 1.5, -2), -4.0, 0.0)
	_status_msg("SFX: %s (%d/%d)" % [n, (_sfx_i - 1) % SFX_LIST.size() + 1, SFX_LIST.size()])

func _irina_toggle() -> void:
	if _irina.mode == NpcAlly.Mode.FOLLOW:
		_irina.set_mode(NpcAlly.Mode.IDLE)
		_status_msg(Loc.t("test.msg.irina_stay"))
	else:
		_irina.set_mode(NpcAlly.Mode.FOLLOW)
		_status_msg(Loc.t("test.msg.irina_follow"))
	_irina.on_use = _irina_toggle

# =====================================================================
# G) Parede de materiais (sul, voltada para o norte)
# =====================================================================
func _build_materials() -> void:
	for i in MAT_NAMES.size():
		var x := 14.0 + (i % 6) * 2.8
		var y := 1.4 + (i / 6) * 2.6
		box("hall", Vector3(x, y, 5.75), Vector3(2.4, 2.2, 0.3), Mats.get_mat(MAT_NAMES[i], 0.5))
		# diagnóstico: verde = textura carregada pelo importador; vermelho = arquivo ausente/não importado
		var tex_ok := Mats.get_mat(MAT_NAMES[i], 0.5).albedo_texture != null
		sign3d(Vector3(x, y - 1.25, 5.55), PI, MAT_NAMES[i] + ("  OK" if tex_ok else "  ERRO"), 28,
			Color(0.55, 0.95, 0.55) if tex_ok else Color(1.0, 0.35, 0.3))
	sign3d(Vector3(21, 6.0, 5.5), PI, Loc.t("test.materials"), 64)
	poster(Vector3(-4.0, 2.2, 5.58), PI, "res://assets/textures/poster_0.png")
	poster(Vector3(-6.0, 2.2, 5.58), PI, "res://assets/textures/poster_1.png")
	poster(Vector3(-8.0, 2.2, 5.58), PI, "res://assets/textures/poster_2.png")

# =====================================================================
# H) Gráficos e desempenho
# =====================================================================
func _build_graphics() -> void:
	var presets := [["test.btn.low", "low"], ["test.btn.medium", "medium"], ["test.btn.high", "high"], ["test.btn.ultra", "ultra"]]
	for i in presets.size():
		var pn: String = presets[i][1]
		panel_button(Vector3(7.5 - i * 1.3, 1.2, 4.9), PI, presets[i][0], func():
			Settings.apply_preset(pn)
			_status_msg(Loc.t("test.msg.preset") % Loc.t("set." + pn)))
	var fps_opts := [30, 60, 90]
	for i in fps_opts.size():
		var f: int = fps_opts[i]
		panel_button(Vector3(2.0 - i * 1.3, 1.2, 4.9), PI, "test.btn.fps%d" % f, func():
			Settings.set_v("graphics", "fps_limit", f)
			_status_msg(Loc.t("test.msg.fps") % f))
	panel_button(Vector3(-2.0, 1.2, 4.9), PI, "test.btn.perf", func():
		_perf_on = not _perf_on
		if is_instance_valid(_perf): _perf.visible = _perf_on)
	sign3d(Vector3(2.5, 2.6, 5.4), PI, Loc.t("test.graphics"), 56)

func _make_perf_panel() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	_perf = Label.new()
	_perf.position = Vector2(12, 120)
	_perf.add_theme_font_size_override("font_size", 15)
	_perf.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_perf.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_perf.add_theme_constant_override("outline_size", 4)
	_perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_perf)

func _process(delta: float) -> void:
	_perf_t -= delta
	if _perf_t <= 0.0 and is_instance_valid(_perf) and _perf_on:
		_perf_t = 0.25
		var fps := Engine.get_frames_per_second()
		var en := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.health > 0.0: en += 1
		_perf.text = "FPS %d  (%.1f ms)\n%s: %s · %s %d%%\ndraw calls %d · %s %d\n%s %dk · %s %d\n%s %d · %s %.0f MB\n%s" % [
			fps, 1000.0 / maxf(1.0, fps),
			Loc.t("set.preset"), String(Settings.get_v("graphics", "preset", "")), Loc.t("set.render_scale"), int(float(Settings.get_v("graphics", "render_scale", 1.0)) * 100.0),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			Loc.t("test.objects"), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			Loc.t("test.primitives"), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			Loc.t("test.enemies"), en,
			Loc.t("test.nodes"), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			Loc.t("test.vram"), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
			"%s %s" % [RenderingServer.get_video_adapter_name(), ProjectSettings.get_setting("rendering/renderer/rendering_method", "")]]

func _physics_process(delta: float) -> void:
	if _hazard_in and is_instance_valid(player) and player.alive:
		_hazard_t -= delta
		if _hazard_t <= 0.0:
			_hazard_t = 0.5
			var was := player.god
			player.god = false if not _god else true
			player.take_damage(6.0, player.global_position + Vector3(0, -1, 0), "shock")
			player.god = was
			Effects.burst(player.global_position + Vector3(0, 0.3, 0), Vector3.UP, Color(0.5, 0.8, 1.0), 12, true, 0.6)
	else:
		_hazard_t = 0.0
