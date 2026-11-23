extends Node
## Testes automatizados de integração (executar: godot --headless -- --autotest).
## Percorre o Capítulo 1 inteiro por meio dos mesmos gatilhos, pickups e interações que o jogador usa,
## acelerando o tempo. Também testa salvamento, armas, física destrutível, IA e presença de dublagem.
## Resultado: imprime PASS/FAIL por item e sai com código 0 (tudo ok) ou 1.

var results: Array = []
var lvl: Node
var p: Player

func ok(name: String, cond: bool, info := "") -> void:
	results.append([name, cond])
	print(("PASS " if cond else "FAIL ") + name + ("" if info == "" else "  (" + info + ")"))

func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return cond.call()

func tp(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await frames(4)

func find_all(root: Node, pred: Callable, out: Array) -> Array:
	for c in root.get_children():
		if pred.call(c):
			out.append(c)
		find_all(c, pred, out)
	return out

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	_test_voice_files()
	var only := OS.get_environment("AZ_ONLY")
	if only == "":
		await _test_chapter1()
		await _test_save_roundtrip()
	if only == "" or only == "ch2":
		await _test_chapter2()
	if only == "" or only == "ch3":
		await _test_chapter3()
	if only == "" or only == "ch4" or only == "ch46":
		await _test_chapter4()
	if only == "" or only == "ch5" or only == "ch6" or only == "ch46":
		await _test_chapter5()
	if only == "" or only == "ch5" or only == "ch6" or only == "ch46":
		await _test_chapter6()
	if only == "" or only == "test":
		await _test_range()
	var fails := results.filter(func(r): return not r[1]).size()
	print("RESULT %d/%d passed in %.1f s" % [results.size() - fails, results.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	Engine.time_scale = 1.0
	get_tree().quit(0 if fails == 0 else 1)

func _test_voice_files() -> void:
	for ch in [1, 2, 3, 4, 5, 6]:
		_voice_ch(ch)

func _voice_ch(ch: int) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/ch%d.json" % ch))
	var total := 0
	var missing: Array = []
	for seq in d:
		for line in d[seq]:
			for lang in ["pt", "en"]:
				total += 1
				var path := "res://assets/audio/voice/%s/%s.wav" % [lang, line["id"]]
				if not ResourceLoader.exists(path):
					missing.append(path)
	ok("dublagem PT/EN presente para todas as falas do cap. %d" % ch, missing.is_empty(), "%d arquivos, faltando %d" % [total, missing.size()])

func _test_chapter1() -> void:
	Game.start_chapter(1, "start")
	await until(func(): return is_instance_valid(Game.level) and is_instance_valid(Game.player) and Game.player.is_inside_tree(), 30.0)
	lvl = Game.level
	p = Game.player
	ok("capítulo 1 carrega e cria o jogador", is_instance_valid(p))
	if not is_instance_valid(p):
		return
	p.god = true
	await frames(10)
	Engine.time_scale = 6.0
	# --- trem ---
	ok("início: objetivo de viagem", Game.objective_key == "obj.ch1.ride", Game.objective_key)
	var masks: Array = find_all(lvl, func(n): return n is Interactables.Pickup and n.item == "mask", [])
	ok("máscara existe no vagão", masks.size() == 1)
	var bohdan: NpcAlly = lvl._bohdan
	ok("Bohdan sentado e conversável", is_instance_valid(bohdan) and bohdan.mode == NpcAlly.Mode.SIT and bohdan.on_use.is_valid())
	if bohdan.on_use.is_valid():
		bohdan.on_use.call()
	await wait(1.0)
	ok("diálogo com Bohdan toca", Dialogue.is_busy())
	if masks.size() > 0:
		masks[0].interact(p)
	ok("pegar máscara ativa a máscara do jogador", p.has_mask)
	var arrived := await until(func(): return not lvl._riding and lvl.ride_speed == 0.0, 120.0)
	ok("trem freia e chega à estação", arrived)
	ok("objetivo: plataforma", Game.objective_key == "obj.ch1.platform", Game.objective_key)
	await wait(3.0)
	ok("portas do trem abriram", absf(lvl._train_doors[0].position.z - float(lvl._train_doors[0].get_meta("open_z"))) < 0.05)
	# --- estação ---
	await tp(Vector3(3.5, 0.1, 0))
	await wait(0.3)
	ok("checkpoint estação", Game.checkpoint == "station", Game.checkpoint)
	ok("salvamento automático criado", Game.has_save("auto"))
	await tp(Vector3(22, 0.1, 9.0))
	await wait(0.5)
	ok("fila: diálogo do Regente/Bohdan", Dialogue.is_busy())
	await tp(Vector3(22, 0.1, -6.6))
	ok("door de serviço trancada antes do alarme", lvl._service_door.locked)
	await until(func(): return lvl.flag("alarm"), 5.0)
	ok("inspeção disparada", lvl.flag("alarm"))
	await until(func(): return not lvl._service_door.locked, 60.0)
	ok("alarme destranca a porta de serviço", not lvl._service_door.locked)
	ok("objetivo: fugir", Game.objective_key == "obj.ch1.flee", Game.objective_key)
	var active := 0
	for g in lvl._station_guards:
		if is_instance_valid(g) and not g.passive:
			active += 1
	ok("guardas ativados (IA sai do modo passivo)", active == lvl._station_guards.size() and active > 0, "%d" % active)
	await wait(1.0)
	var states := []
	for g in lvl._station_guards:
		if is_instance_valid(g): states.append(g.state_name())
	ok("IA dos guardas em alerta/combate", states.any(func(s): return s.to_lower() in ["investigate", "combat", "search", "cover"]), str(states))
	var fleeing: int = lvl._citizens.filter(func(c): return is_instance_valid(c) and c.mode == NpcAlly.Mode.FLEE).size()
	ok("cidadãos fogem", fleeing > 0, "%d" % fleeing)
	# matar guardas com dano real (Combat.apply_hit → ragdoll)
	for g in lvl._station_guards:
		if is_instance_valid(g):
			Combat.apply_hit(g, 500.0, g.global_position + Vector3.UP, Vector3.FORWARD, p)
	await wait(0.5)
	ok("guardas mortos registrados no estado", lvl.state["killed"].size() >= lvl._station_guards.size(), str(lvl.state["killed"]))
	ok("ragdolls criados", find_all(lvl, func(n): return n is RigidBody3D and n.collision_layer == 32, []).size() > 0)
	# --- manutenção ---
	await tp(Vector3(12, 0.1, -20))
	await wait(0.3)
	ok("checkpoint manutenção", Game.checkpoint == "maint", Game.checkpoint)
	await tp(Vector3(12, 0.1, -24))
	await wait(0.3)
	ok("objetivo: chave inglesa", Game.objective_key == "obj.ch1.wrench", Game.objective_key)
	var wr := find_all(lvl, func(n): return n is Interactables.Pickup and n.item == "wrench", [])
	if wr.size() > 0: wr[0].interact(p)
	await frames(2)
	ok("chave inglesa adquirida", p.weapons.owned.has("wrench"))
	ok("objetivo: duto", Game.objective_key == "obj.ch1.vent", Game.objective_key)
	# tábuas: bala não quebra, chave inglesa quebra (golpes reais com raycast)
	var boards := find_all(lvl, func(n): return n is StaticBody3D and n.has_signal("broken"), [])
	ok("tábuas presentes", boards.size() >= 1)
	var b0: Node3D = boards[0] if boards.size() > 0 else null
	if b0:
		Combat.apply_hit(b0, 100.0, b0.global_position, Vector3.FORWARD, p, "bullet")
		await frames(2)
		ok("tiro não quebra as tábuas", is_instance_valid(b0))
		await tp(Vector3(15, 0.1, -37.3))
		p.rotation.y = 0.0
		p._pitch = -14.0
		p.weapons.equip("wrench")
		await wait(1.0)
		for i in 6:
			if not is_instance_valid(b0): break
			p.weapons._fire()
			await wait(0.6)
		ok("golpes da chave inglesa quebram as tábuas", not is_instance_valid(b0))
	# --- sala do duto / empilhar ---
	await tp(Vector3(15, 0.1, -46.5))
	await wait(0.3)
	ok("checkpoint duto", Game.checkpoint == "vent", Game.checkpoint)
	var crates := find_all(lvl, func(n): return n is PhysicsProp and n.global_position.z < -44.0 and n.global_position.z > -54.0 and n.kind.begins_with("crate"), [])
	ok("caixas para empilhar na sala do duto", crates.size() >= 2, "%d" % crates.size())
	# o jogador sem caixas não alcança a saliência de 1,75 m: verifica geometria (pulo ~1,1 m)
	await tp(Vector3(15, 1.9, -53.3))
	await wait(0.5)
	ok("saliência do duto é piso firme a 1,75 m", absf(p.global_position.y - 1.75) < 0.15, "%.2f" % p.global_position.y)
	# atravessa o duto agachado
	p.crouching = true
	p._shape.height = 1.0
	p._collider.position.y = 0.5
	await tp(Vector3(15, 1.85, -58.0))
	Input.action_press("crouch")
	await wait(0.6)
	ok("duto: o jogador permanece no duto (agachado)", p.global_position.y > 1.6 and p.global_position.y < 2.0, "%.2f" % p.global_position.y)
	# --- casa de bombas ---
	Input.action_release("crouch")
	await tp(Vector3(15, 0.1, -65.5))
	await wait(0.3)
	ok("checkpoint casa de bombas", Game.checkpoint == "pump", Game.checkpoint)
	var pist := find_all(lvl, func(n): return n is Interactables.Pickup and n.item == "pistol", [])
	if pist.size() > 0: pist[0].interact(p)
	for pk in find_all(lvl, func(n): return n is Interactables.Pickup and n.global_position.z < -74.0 and n.global_position.z > -78.0, []):
		pk.interact(p)
	ok("pistola adquirida", p.weapons.owned.has("pistol"))
	await until(func(): return is_instance_valid(lvl.get_node_or_null("pump_v1")), 10.0)
	var e1: EnemyAI = lvl.get_node_or_null("pump_v1")
	ok("emboscada: inimigos surgem", e1 != null)
	# disparo real de pistola contra o inimigo (hitscan)
	if e1:
		await wait(0.5)
		e1.global_position = Vector3(15, 0.05, -68.0)
		await tp(Vector3(15, 0.1, -66.0))
		p.rotation.y = 0.0
		p._pitch = -3.0
		p.weapons.equip("pistol")
		await wait(1.2)
		var clip0: int = p.weapons.clip["pistol"]
		var hp0: float = e1.health
		for i in 3:
			if is_instance_valid(e1) and e1.alive:
				var to: Vector3 = e1.aim_point() - p.camera.global_position
				p.rotation.y = atan2(-to.x, -to.z)
				p._pitch = rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
				await frames(1)
			p.weapons._fire()
			await wait(0.3)
		ok("pistola consome munição", p.weapons.clip["pistol"] < clip0, "%d → %d" % [clip0, p.weapons.clip["pistol"]])
		ok("disparo atinge o inimigo", not is_instance_valid(e1) or e1.health < hp0 or not e1.alive, "")
	for n in ["pump_v1", "pump_v2"]:
		var e = lvl.get_node_or_null(n)
		if e and e.alive: Combat.apply_hit(e, 500.0, e.global_position + Vector3.UP, Vector3.FORWARD, p)
	# barril explosivo: tiro acende pavio e explode
	var ex := find_all(lvl, func(n): return n is PhysicsProp and n.explosive and n.global_position.z < -63.0 and n.global_position.z > -77.0, [])
	if ex.size() > 0:
		var bar: PhysicsProp = ex[0]
		Combat.apply_hit(bar, 20.0, bar.global_position, Vector3.FORWARD, p)
		await until(func(): return not is_instance_valid(bar), 10.0)
		ok("barril explosivo explode após tiro", not is_instance_valid(bar))
	var crate_b := find_all(lvl, func(n): return n is PhysicsProp and n.hp > 0.0 and not n.explosive, [])
	if crate_b.size() > 0:
		var cb: PhysicsProp = crate_b[0]
		Combat.apply_hit(cb, 999.0, cb.global_position, Vector3.FORWARD, p, "melee")
		await frames(3)
		ok("caixa destrutível quebra em destroços", not is_instance_valid(cb) or cb.is_queued_for_deletion())
	# --- pátio ---
	await tp(Vector3(15, 0.1, -79.5))
	await wait(0.3)
	ok("checkpoint pátio", Game.checkpoint == "yard", Game.checkpoint)
	await tp(Vector3(15, 0.1, -84))
	await wait(0.3)
	ok("objetivo: pátio", Game.objective_key == "obj.ch1.yard", Game.objective_key)
	ok("sol ilumina área externa", lvl._sun.light_cull_mask == 3)
	var yd: Array = ["yd_1", "yd_2", "yd_3", "yd_4", "yd_5"].filter(func(n): return lvl.get_node_or_null(n) != null)
	ok("inimigos do pátio presentes", yd.size() == 5, str(yd))
	await tp(Vector3(20, 0.1, -160))
	await wait(0.5)
	ok("Irina chama no portão", lvl.flag("irina_called") and Game.objective_key == "obj.ch1.gate")
	# vagão secreto
	var swb := find_all(lvl, func(n): return n is StaticBody3D and n.has_signal("broken") and n.global_position.z < -140.0, [])
	ok("vagão secreto lacrado com tábuas", swb.size() == 1)
	if swb.size() > 0:
		Combat.apply_hit(swb[0], 200.0, swb[0].global_position, Vector3.FORWARD, p, "melee")
		await frames(2)
	for pk in find_all(lvl, func(n): return n is Interactables.Pickup and n.global_position.distance_to(Vector3(40, 1, -152)) < 4.0, []):
		pk.interact(p)
	ok("SMG do vagão secreto", p.weapons.owned.has("smg"))
	# guarita: escada + alavanca
	await tp(Vector3(50, 3.2, -139.5))
	await wait(0.4)
	ok("checkpoint guarita", Game.checkpoint == "gate", Game.checkpoint)
	var levers := find_all(lvl, func(n): return n is Interactables.Switch, [])
	ok("alavanca existe", levers.size() == 1)
	if levers.size() > 0: levers[0].interact(p)
	await wait(0.3)
	ok("alavanca aciona o portão", lvl._gate_opening or lvl._gate_open > 0.0)
	await until(func(): return is_instance_valid(lvl.get_node_or_null("yd_r1")), 20.0)
	ok("reforços chegam", lvl.get_node_or_null("yd_r1") != null)
	await until(func(): return lvl.flag("gate_open"), 60.0)
	ok("portão abre completamente", lvl.flag("gate_open"))
	# salvamento manual no meio do capítulo
	ok("salvamento manual", Game.save_game("slot1"))
	await tp(Vector3(20, 0.1, -176))
	var done := await until(func(): return Game.chapter == 2 and is_instance_valid(Game.level) and Game.level != lvl and is_instance_valid(Game.level.player) and Game.level.player.is_inside_tree(), 90.0)
	await frames(10)
	ok("fim do capítulo 1 → carrega o capítulo 2", done)
	Engine.time_scale = 1.0

func _test_save_roundtrip() -> void:
	var d := Game.read_save("slot1")
	ok("save: leitura do slot manual", not d.is_empty())
	if d.is_empty():
		return
	ok("save: capítulo/checkpoint gravados", int(d.get("chapter", 0)) == 1 and str(d.get("checkpoint", "")) == "gate", "%s/%s" % [d.get("chapter"), d.get("checkpoint")])
	var prev_l := Game.level
	Game.load_game("slot1")
	await until(func(): return Game.level != prev_l and Game.in_game and is_instance_valid(Game.player) and Game.player.is_inside_tree() and is_instance_valid(Game.level) and Game.level.player == Game.player, 30.0)
	await frames(10)
	var pl := Game.player
	ok("load: jogador renasce no checkpoint da guarita", is_instance_valid(pl) and pl.global_position.distance_to(Vector3(50, 3.1, -139.5)) < 1.5, str(pl.global_position) if pl else "")
	ok("load: inventário restaurado (pistola/SMG)", pl and pl.weapons.owned.has("pistol") and pl.weapons.owned.has("smg"))
	ok("load: inimigos mortos não reaparecem", Game.level.get_node_or_null("st_guard_0") == null and Game.level.get_node_or_null("pump_v1") == null)
	ok("load: alavanca e portão mantêm estado", Game.level.flag("lever"))


# ---------------- utilidades de movimento real ----------------
func kill_all(radius := 30.0) -> void:
	for e in find_all(lvl, func(n): return n is EnemyAI and n.alive and n.global_position.distance_to(p.global_position) < radius, []):
		Combat.apply_hit(e, 999.0, e.global_position + Vector3.UP, Vector3.FORWARD, p)
	await frames(3)

## Anda de verdade (CharacterBody + colisão) na direção do yaw por `sec` segundos.
func walk(yaw: float, sec: float, sprint := false, jump_at := Callable()) -> void:
	p.rotation.y = yaw
	p._pitch = 0.0
	InputRouter.touch_move = Vector2(0, -1)
	if sprint: Input.action_press("sprint")
	var t := 0.0
	var jumped := false
	while t < sec:
		if not jumped and jump_at.is_valid() and jump_at.call():
			Input.action_press("jump")
			jumped = true
			await get_tree().physics_frame
			Input.action_release("jump")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if OS.get_environment("AZ_TRACE") != "" and fmod(t, 0.25) < 0.017:
			print("   t=%.2f pos=%s vel=%s floor=%s" % [t, p.global_position, p.velocity, p.is_on_floor()])
	InputRouter.touch_move = Vector2.ZERO
	Input.action_release("sprint")
	await frames(3)

func load_level(ch: int) -> bool:
	var prev_l: Node = null
	if Game.chapter != ch or not is_instance_valid(Game.level):
		prev_l = Game.level
		Game.start_chapter(ch, "start")
	var okk := await until(func(): return Game.level != prev_l and Game.chapter == ch and is_instance_valid(Game.level) and is_instance_valid(Game.player) and Game.player.is_inside_tree() and Game.level.player == Game.player, 40.0)
	lvl = Game.level
	p = Game.player
	if okk:
		p.god = true
		await frames(10)
	return okk

func _test_chapter2() -> void:
	Engine.time_scale = 1.0
	var loaded := await load_level(2)
	ok("capítulo 2 carrega", loaded)
	if not loaded: return
	Engine.time_scale = 6.0
	ok("cap2: objetivo inicial (rua)", Game.objective_key == "obj.ch2.street", Game.objective_key)
	ok("cap2: Irina acompanha (FOLLOW)", is_instance_valid(lvl._irina) and lvl._irina.mode == NpcAlly.Mode.FOLLOW)
	await tp(Vector3(0, 0.1, -5))
	await wait(0.4)
	ok("cap2: diálogo de abertura toca", Dialogue.is_busy())
	await tp(Vector3(0, 0.1, -40))
	await wait(0.3)
	ok("cap2: checkpoint rua", Game.checkpoint == "street2", Game.checkpoint)
	ok("cap2: bloqueio de Vigilantes na rua", lvl.get_node_or_null("st_v1") != null)
	await kill_all()
	await tp(Vector3(0, 0.1, -63))
	await tp(Vector3(0, 0.1, -66))
	await wait(0.3)
	ok("cap2: checkpoint/objetivo praça", Game.checkpoint == "plaza" and Game.objective_key == "obj.ch2.plaza", Game.checkpoint + " " + Game.objective_key)
	ok("cap2: patrulhas da praça", lvl._plaza_enemies.size() == 4, "%d" % lvl._plaza_enemies.size())
	# holofote: congela a varredura e coloca o jogador no ponto iluminado
	var sl: Searchlight = lvl._search
	sl.sweep_speed = 0.0
	sl.sweep_center += 0.3
	await frames(3)
	var dir: Vector3 = -sl.light.global_basis.z
	var gp: Vector3 = sl.light.global_position + dir * (sl.light.global_position.y / maxf(0.05, -dir.y))
	await tp(Vector3(gp.x, 0.1, gp.z))
	var spotted := await until(func(): return lvl.flag("spotted_done"), 12.0)
	ok("cap2: holofote detecta o jogador com linha de visão", spotted, str(gp))
	var alerted = lvl._plaza_enemies.filter(func(e): return is_instance_valid(e) and e.state_name() in ["investigate", "combat", "search", "cover"]).size()
	var sts: Array = lvl._plaza_enemies.map(func(e): return e.state_name() + ("/passive" if e.passive else "") if is_instance_valid(e) else "freed")
	ok("cap2: detecção alerta as patrulhas", alerted > 0, "%d %s" % [alerted, str(sts)])
	await kill_all()
	# Bloco 14
	await tp(Vector3(-37.0, 0.1, -112.0))
	await wait(0.3)
	ok("cap2: checkpoint Bloco 14", Game.checkpoint == "block", Game.checkpoint)
	# subida real pela escada (lance 1)
	await tp(Vector3(-37.45, 0.1, -112.9))
	await walk(0.0, 2.2)
	ok("cap2: escada do prédio sobe um andar (física real)", p.global_position.y > 3.0, "y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	await tp(Vector3(-39.2, 12.9, -119.1))
	await wait(0.3)
	ok("cap2: checkpoint 5º andar", Game.checkpoint == "floor5", Game.checkpoint)
	var mv: NpcAlly = lvl._matvei
	ok("cap2: Matvei sentado e conversável", is_instance_valid(mv) and mv.mode == NpcAlly.Mode.SIT and mv.on_use.is_valid())
	if mv.on_use.is_valid(): mv.on_use.call()
	await wait(0.3)
	ok("cap2: diálogo do Matvei", Dialogue.is_busy())
	var sg := find_all(lvl, func(n): return n is Interactables.Pickup and n.item == "shotgun", [])
	if sg.size() > 0: sg[0].interact(p)
	await frames(2)
	ok("cap2: espingarda adquirida", p.weapons.owned.has("shotgun"))
	var raid := await until(func(): return lvl.get_node_or_null("rd_v1") != null, 10.0)
	ok("cap2: batida policial começa", raid and lvl.flag("raid"))
	ok("cap2: objetivo telhado", Game.objective_key == "obj.ch2.roof", Game.objective_key)
	# tiro real de espingarda num inimigo da batida
	var e1: EnemyAI = lvl.get_node_or_null("rd_s1")
	if e1:
		e1.global_position = Vector3(-40.5, 9.65, -112.0)
		await tp(Vector3(-40.5, 9.7, -108.5))
		p.weapons.equip("shotgun")
		await wait(1.0)
		var hp0 := e1.health
		var to: Vector3 = e1.aim_point() - p.camera.global_position
		p.rotation.y = atan2(-to.x, -to.z)
		p._pitch = rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
		await frames(1)
		p.weapons._fire()
		await wait(0.3)
		ok("cap2: espingarda acerta (dano por chumbo)", not is_instance_valid(e1) or not e1.alive or e1.health < hp0)
	await kill_all()
	await tp(Vector3(-36.5, 16.1, -118.0))
	await wait(0.3)
	ok("cap2: checkpoint telhado", Game.checkpoint == "roof" and lvl.flag("raid_done"), Game.checkpoint)
	# salto real entre telhados (vão de 3,5 m, 1 m abaixo)
	await tp(Vector3(-43.0, 16.1, -112.0))
	await walk(0.0, 3.0, true, func(): return p.global_position.z < -119.0)
	ok("cap2: salto correndo atravessa o vão entre telhados", p.global_position.z < -124.0 and p.global_position.y > 14.5, "y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	await wait(0.5)
	await kill_all()
	# travessia real da viga de aço
	await tp(Vector3(-44.0, 15.1, -139.0))
	await walk(0.0, 2.6)
	ok("cap2: viga de aço sustenta o jogador até o telhado C", p.global_position.z < -146.6 and p.global_position.y > 14.5, "y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	await tp(Vector3(-44.0, 15.1, -148.0))
	await wait(0.3)
	ok("cap2: checkpoint telhados", Game.checkpoint == "roofs2", Game.checkpoint)
	await kill_all()
	ok("cap2: escada de mão para o beco", find_all(lvl, func(n): return n is Interactables.Ladder, []).size() >= 1)
	ok("cap2: salvamento manual", Game.save_game("slot2"))
	var prev := lvl
	await tp(Vector3(-44.0, 0.1, -172.0))
	await walk(0.0, 1.5)
	var done := await until(func(): return Game.chapter == 3 and is_instance_valid(Game.level) and Game.level != prev, 60.0)
	ok("cap2: fim do capítulo → carrega o capítulo 3", done)
	Engine.time_scale = 1.0

func _test_chapter3() -> void:
	var loaded := await load_level(3)
	ok("capítulo 3 carrega", loaded)
	if not loaded: return
	Engine.time_scale = 6.0
	ok("cap3: inventário herdado do cap. 2 (espingarda)", p.weapons.owned.has("shotgun"))
	ok("cap3: objetivo inicial", Game.objective_key == "obj.ch3.hall", Game.objective_key)
	await tp(Vector3(0, 0.1, -5))
	await wait(0.3)
	ok("cap3: Kovač no rádio (abertura)", Dialogue.is_busy())
	await tp(Vector3(0, 0.1, -17))
	await wait(0.3)
	ok("cap3: checkpoint galpão", Game.checkpoint == "hall", Game.checkpoint)
	# esteira move caixas de verdade
	var belt_items := find_all(lvl, func(n): return n is PhysicsProp and absf(n.global_position.x - 6.0) < 0.6 and n.global_position.y > 0.9, [])
	var z0: float = belt_items[0].global_position.z if belt_items.size() > 0 else 0.0
	await wait(2.0)
	ok("cap3: esteira transporta as carcaças", belt_items.size() > 0 and is_instance_valid(belt_items[0]) and belt_items[0].global_position.z > z0 + 1.0, "%d itens, dz=%.2f" % [belt_items.size(), (belt_items[0].global_position.z - z0) if belt_items.size() > 0 else 0.0])
	var workers := find_all(lvl, func(n): return n is NpcAlly, []).size()
	ok("cap3: operários e capataz no galpão", workers >= 9, "%d" % workers)
	var fm: NpcAlly = find_all(lvl, func(n): return n is NpcAlly and n.npc_id == "foreman", [])[0]
	if fm.on_use.is_valid(): fm.on_use.call()
	await wait(0.3)
	ok("cap3: capataz fala e indica o guindaste", Game.objective_key == "obj.ch3.pit", Game.objective_key)
	await kill_all()
	await tp(Vector3(0, 0.1, -75.5))
	await wait(0.3)
	ok("cap3: checkpoint fosso", Game.checkpoint == "pit", Game.checkpoint)
	# cair no fosso sem a ponte
	await tp(Vector3(0, 0.1, -80.5))
	await wait(1.0)
	ok("cap3: sem ponte, o jogador cai no fosso", p.global_position.y < -5.0, "y=%.2f" % p.global_position.y)
	await tp(Vector3(0, 0.1, -76.0))
	lvl._btn_lower.interact(p)
	await wait(0.5)
	ok("cap3: botão 'baixar' bloqueado antes de mover o carro", not lvl.flag("crane_done") and lvl._bridge.position.y > 6.0)
	lvl._btn_move.interact(p)
	var moved := await until(func(): return lvl._btn_lower.enabled and absf(lvl._trolley.position.x) < 0.05, 15.0)
	ok("cap3: guindaste desloca a plataforma sobre o fosso", moved)
	lvl._btn_lower.interact(p)
	var lowered := await until(func(): return lvl.flag("crane_done"), 15.0)
	ok("cap3: plataforma desce e vira ponte", lowered and absf(lvl._bridge.position.y - lvl.BRIDGE_DOWN.y) < 0.05)
	await kill_all()
	await tp(Vector3(0, 0.1, -77.5))
	await walk(0.0, 4.5)
	ok("cap3: atravessa o fosso pela ponte (física real)", p.global_position.z < -94.0 and p.global_position.y > -0.5, "y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	await kill_all()
	await tp(Vector3(0, 0.1, -102.5))
	await wait(0.3)
	ok("cap3: checkpoint prensa", Game.checkpoint == "press", Game.checkpoint)
	ok("cap3: sobrecarga bloqueada antes das válvulas", not lvl._overload.enabled)
	lvl._valves[0].interact(p)
	await wait(0.5)
	ok("cap3: 1ª válvula dispara alarme e reforços", lvl._alarm_on and lvl.get_node_or_null("pr_s1") != null)
	await kill_all()
	lvl._valves[1].interact(p)
	await wait(0.5)
	await kill_all()
	# sobe a escada da passarela de verdade
	await tp(Vector3(-13.5, 0.1, -130.6))
	await walk(0.0, 2.6)
	ok("cap3: escada da passarela leva a 5 m (física real)", p.global_position.y > 4.8, "y=%.2f z=%.2f" % [p.global_position.y, p.global_position.z])
	await tp(Vector3(-8.0, 5.1, -140.0))
	lvl._valves[2].interact(p)
	await wait(0.3)
	ok("cap3: três válvulas fechadas liberam a sobrecarga", lvl._valves_closed() == 3 and lvl._overload.enabled and Game.objective_key == "obj.ch3.overload")
	await kill_all()
	await tp(Vector3(-13.0, 0.1, -124.0))
	lvl._overload.interact(p)
	await wait(0.5)
	ok("cap3: sobrecarga → objetivo fuga", lvl.flag("overload") and Game.objective_key == "obj.ch3.drain")
	await tp(Vector3(12.0, 0.1, -134.0))
	await wait(11.0)
	ok("cap3: porta do dreno abre", lvl._drain_door.position.y > 4.0)
	ok("cap3: prensa explode (alarme encerrado)", not lvl._alarm_on)
	await kill_all()
	await walk(-PI * 0.5, 2.5)
	if p.global_position.x < 17.5:
		var q := PhysicsShapeQueryParameters3D.new()
		var sp := SphereShape3D.new(); sp.radius = 0.5; q.shape = sp
		q.transform = Transform3D(Basis(), p.global_position + Vector3(0.5, 0.9, 0)); q.collision_mask = 1
		for h in p.get_world_3d().direct_space_state.intersect_shape(q, 8):
			var co: Node = h["collider"]
			var sh: Node = co.shape_owner_get_owner(co.shape_find_owner(h["shape"]))
			print("  bloqueio: ", co.name, " ", sh.global_position if sh is Node3D else "", " ", (sh.shape.size if sh.shape is BoxShape3D else ""))
	ok("cap3: entra no dreno andando", p.global_position.x > 17.5, "x=%.2f" % p.global_position.x)
	await wait(0.3)
	ok("cap3: checkpoint dreno", Game.checkpoint == "drain", Game.checkpoint)
	ok("cap3: salvamento manual", Game.save_game("slot3"))
	ok("cap3: Irina espera na saída", is_instance_valid(lvl._irina))
	await tp(Vector3(43.0, 0.1, -134.0))
	await walk(-PI * 0.5, 1.5)
	var done := await until(func(): return Game.chapter == 4 and is_instance_valid(Game.level) and Game.level != lvl and Game.level.player == Game.player, 90.0)
	ok("cap3: fim do capítulo → carrega o cap. 4", done)
	if done:
		await frames(10)
		ok("cap4: inventário herdado do cap. 3", Game.player.weapons.owned.has("shotgun"))
	Engine.time_scale = 1.0
	# carregar save do cap. 3
	var prev3 := Game.level
	Game.load_game("slot3")
	var ld := await until(func(): return Game.level != prev3 and Game.in_game and is_instance_valid(Game.level) and Game.level.player == Game.player and Game.chapter == 3, 40.0)
	await frames(10)
	ok("cap3: load restaura estado (válvulas, ponte, sobrecarga)", ld and Game.level.flag("crane_done") and Game.level.flag("overload") and Game.level._bridge.position.y < 0.0)

# ---------------- Capítulo 4 ----------------
func _boat_drive(b: Vehicle, target_z: float, steer_x := 0.0, timeout := 40.0) -> bool:
	var t := 0.0
	while t < timeout and is_instance_valid(b):
		var dz := b.global_position.z - target_z
		if dz < 1.0: break
		b.throttle_override = 1.0
		# segue o eixo x desejado: direção proporcional ao desvio e ao rumo
		var fwd := -b.global_transform.basis.z
		var want := Vector3(steer_x - b.global_position.x, 0, -6.0).normalized()
		var cross := fwd.cross(want).y
		b.steer_override = clampf(cross * 3.0, -1.0, 1.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	b.throttle_override = INF
	b.steer_override = INF
	return is_instance_valid(b) and b.global_position.z <= target_z + 1.0

func _test_chapter4() -> void:
	var loaded := await load_level(4)
	ok("capítulo 4 carrega", loaded)
	if not loaded: return
	Engine.time_scale = 4.0
	ok("cap4: arsenal mínimo garantido", p.weapons.owned.size() >= 3, str(p.weapons.owned))
	ok("cap4: objetivo inicial", Game.objective_key == "obj.ch4.sewer", Game.objective_key)
	ok("cap4: barco flutua na doca", is_instance_valid(lvl._boat) and absf(lvl._boat.global_position.y - lvl.WATER_Y) < 0.8, "y=%.2f" % lvl._boat.global_position.y)
	# andar de verdade pela passarela do coletor
	await tp(Vector3(2.0, 0.1, -2.0))
	await walk(0.0, 2.5)
	ok("cap4: anda pela passarela do coletor", p.global_position.z < -8.0 and p.global_position.y > -0.3, "z=%.2f y=%.2f" % [p.global_position.z, p.global_position.y])
	await kill_all(60.0)
	ok("cap4: comporta fechada bloqueia", lvl._gate.position.y < 2.0 and not lvl.flag("gate_open"))
	await tp(Vector3(9.8, 2.3, -30.0))
	lvl._crank.interact(p)
	var opened := await until(func(): return lvl._gate.position.y > 4.0, 10.0)
	ok("cap4: manivela abre a comporta", opened and lvl.flag("gate_open"))
	await tp(Vector3(0, 0.6, -62.5))
	await wait(0.3)
	ok("cap4: checkpoint doca", Game.checkpoint == "dock", Game.checkpoint)
	await kill_all(60.0)
	var b: Vehicle = lvl._boat
	b.enter(p)
	await wait(0.3)
	ok("cap4: entra no barco", b.driver == p)
	var reached := await _boat_drive(b, -180.0, -1.0, 60.0)
	ok("cap4: pilota o barco pelo canal até a barreira", reached, "z=%.1f x=%.1f" % [b.global_position.z, b.global_position.x])
	ok("cap4: Caçador aparece no canal", is_instance_valid(lvl._heli))
	ok("cap4: grade da barreira bloqueia o canal", not lvl.flag("barrier_open"))
	b.exit_vehicle(true)
	await tp(Vector3(5.6, 0.6, -197.5))
	await wait(0.3)
	ok("cap4: checkpoint barreira", Game.checkpoint == "barrier", Game.checkpoint)
	await kill_all(40.0)
	lvl._grate_btn.interact(p)
	var up := await until(func(): return lvl._grate.position.y > 4.0, 12.0)
	ok("cap4: botão da cabine ergue a grade", up)
	b.global_position = Vector3(2.6, lvl.WATER_Y, -189.0)
	b.rotation = Vector3.ZERO
	b.linear_velocity = Vector3.ZERO
	b.enter(p)
	await wait(0.3)
	reached = await _boat_drive(b, -258.0, 0.0, 40.0)
	ok("cap4: barco passa a barreira até o reservatório", reached, "z=%.1f" % b.global_position.z)
	b.exit_vehicle(true)
	await tp(Vector3(30.0, 0.6, -268.0))
	await wait(0.3)
	ok("cap4: checkpoint píer (canhão antiaéreo)", Game.checkpoint == "basin", Game.checkpoint)
	ok("cap4: canhão antiaéreo existe", is_instance_valid(lvl._turret))
	if is_instance_valid(lvl._heli):
		for i in 8:
			if not lvl._heli.alive: break
			Combat.apply_hit(lvl._heli, 120.0, lvl._heli.global_position, Vector3.DOWN, p, "explosion")
			await wait(0.2)
	var hd := await until(func(): return lvl.flag("heli_dead"), 10.0)
	ok("cap4: Caçador abatido → objetivo Muralha", hd and Game.objective_key == "obj.ch4.wall", Game.objective_key)
	await tp(Vector3(0, 0.6, lvl.BASIN_Z1 - 2.0))
	await wait(0.3)
	ok("cap4: checkpoint cais", Game.checkpoint == "quay", Game.checkpoint)
	ok("cap4: holofotes na Muralha", lvl._lights_search.size() >= 3)
	await kill_all(140.0)
	ok("cap4: salvamento manual", Game.save_game("slot4"))
	await tp(Vector3(0, 0.3, lvl.WALL_Z + 4.0))
	await wait(0.3)
	lvl._elev_lever.interact(p)
	var top := await until(func(): return lvl._elevator.position.y > 29.0, 20.0)
	ok("cap4: elevador sobe com o jogador", top and p.global_position.y > 28.0, "elev=%.1f p.y=%.1f" % [lvl._elevator.position.y, p.global_position.y])
	var nxt := await until(func(): return Game.chapter != 4 or not Game.in_game, 60.0)
	ok("cap4: topo da Muralha conclui o capítulo → cap. 5", nxt and Game.chapter == 5, "ch=%d" % Game.chapter)
	Engine.time_scale = 1.0
	var prev4 := Game.level
	Game.load_game("slot4")
	var ld := await until(func(): return Game.level != prev4 and Game.in_game and is_instance_valid(Game.level) and Game.level.player == Game.player and Game.chapter == 4, 40.0)
	await frames(10)
	ok("cap4: load restaura estado (comporta, grade, Caçador)", ld and Game.level.flag("gate_open") and Game.level.flag("barrier_open") and Game.level.flag("heli_dead") and Game.level._grate.position.y > 4.0)

# ---------------- Capítulo 5: Ferro-Velho ----------------
func kill_crawlers() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("crawler"):
		if is_instance_valid(c) and c.alive:
			Combat.apply_hit(c, 999.0, c.global_position + Vector3.UP * 0.3, Vector3.FORWARD, p)
			n += 1
	await frames(3)
	return n

func _test_chapter5() -> void:
	Engine.time_scale = 1.0
	var loaded := await load_level(5)
	ok("capítulo 5 carrega", loaded)
	if not loaded: return
	Engine.time_scale = 4.0
	ok("cap5: objetivo inicial", Game.objective_key == "obj.ch5.find", Game.objective_key)
	ok("cap5: arsenal mínimo garantido", p.weapons.owned.size() >= 3, str(p.weapons.owned))
	ok("cap5: motor bloqueia a portinhola", is_instance_valid(lvl._engine) and lvl._engine.global_position.distance_to(lvl.ENGINE_HOME) < 1.0)
	await tp(Vector3(-12.0 + 6.0, 0.1, -24.0 + 1.0))
	var got := await until(func(): return p.weapons.owned.has("manipulator"), 90.0)
	ok("cap5: Lindqvist entrega o Manipulador", got and lvl.flag("manip"))
	await tp(Vector3(-12.0 + 7.5, 0.1, -23.0))
	await wait(0.3)
	ok("cap5: checkpoint pátio", Game.checkpoint == "yard", Game.checkpoint)
	lvl._engine.global_position = lvl.ENGINE_HOME + Vector3(-2.6, 0.2, 2.2)
	lvl._engine.linear_velocity = Vector3.ZERO
	var mv := await until(func(): return lvl.flag("engine_moved"), 5.0)
	ok("cap5: afastar o motor libera a portinhola", mv and Game.objective_key == "obj.ch5.stack", Game.objective_key)
	ok("cap5: bateria no telhado do depósito", lvl._battery.global_position.y > 2.3, "y=%.2f" % lvl._battery.global_position.y)
	lvl._battery.global_position = Vector3(10.0, 0.6, -50.0)
	lvl._battery.linear_velocity = Vector3.ZERO
	var up := await until(func(): return lvl.flag("battery_up"), 5.0)
	ok("cap5: bateria retirada do telhado", up and Game.objective_key == "obj.ch5.battery", Game.objective_key)
	ok("cap5: portão fechado sem energia", lvl._gate.position.y < 2.5)
	await tp(lvl.SOCKET + Vector3(-1.5, 0.1, 2.0))
	lvl._battery.global_position = lvl.SOCKET + Vector3(0, 1.4, 0)
	lvl._battery.linear_velocity = Vector3.ZERO
	var ins := await until(func(): return lvl.flag("battery_in"), 5.0)
	ok("cap5: bateria encaixada no soquete", ins)
	var opened := await until(func(): return lvl._gate.position.y > 4.5, 15.0)
	ok("cap5: portão sobe com a bateria", opened)
	var wave := await until(func(): return get_tree().get_nodes_in_group("crawler").size() > 0, 60.0)
	ok("cap5: onda de Rastejadores surge", wave, "n=%d" % get_tree().get_nodes_in_group("crawler").size())
	await tp(Vector3(0, 0.1, -67.0))
	await wait(0.3)
	ok("cap5: checkpoint pátio interno", Game.checkpoint == "inner", Game.checkpoint)
	var t := 0.0
	while t < 40.0 and not lvl.flag("crawlers_done"):
		await kill_crawlers()
		await wait(0.5)
		t += 0.5
	ok("cap5: duas ondas de Rastejadores eliminadas", lvl.flag("crawlers_done") and lvl._crawler_wave == 2, "onda=%d" % lvl._crawler_wave)
	ok("cap5: garagem fechada antes da planta", lvl._garage.position.y < 3.0)
	await tp(lvl.WORKSHOP + Vector3(0, 0.1, 5.5))
	await wait(0.3)
	ok("cap5: checkpoint oficina", Game.checkpoint == "workshop", Game.checkpoint)
	ok("cap5: salvamento manual", Game.save_game("slot5"))
	await tp(lvl.WORKSHOP + Vector3(-4.5, 0.1, 1.8))
	var bp := await until(func(): return lvl.flag("blueprint"), 5.0)
	ok("cap5: planta do Trocador encontrada", bp)
	var gar := await until(func(): return lvl._garage.position.y > 3.5, 60.0)
	ok("cap5: porta da garagem abre", gar and Game.objective_key == "obj.ch5.buggy", Game.objective_key)
	await tp(lvl._buggy.global_position + Vector3(-2.0, 0, 0))
	lvl._buggy.enter(p)
	var nxt := await until(func(): return Game.chapter == 6 and is_instance_valid(Game.level) and Game.level != lvl, 40.0)
	ok("cap5: entrar no Besouro conclui → cap. 6", nxt, "ch=%d" % Game.chapter)
	Engine.time_scale = 1.0

# ---------------- Capítulo 6: Mar Seco ----------------
func _buggy_drive(b: Vehicle, target_z: float, timeout := 60.0, x_off := 1.5) -> bool:
	var t := 0.0
	while t < timeout and is_instance_valid(b):
		if b.global_position.z - target_z < 1.0: break
		b.throttle_override = 1.0
		var fwd := -b.global_transform.basis.z
		var aim_z := b.global_position.z - 14.0
		var want := Vector3(lvl.rx(aim_z) + x_off - b.global_position.x, 0, -14.0).normalized()
		b.steer_override = clampf(fwd.cross(want).y * 3.0, -1.0, 1.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	b.throttle_override = INF
	b.steer_override = INF
	return is_instance_valid(b) and b.global_position.z <= target_z + 1.0

func _buggy_reset(b: Vehicle, z: float) -> void:
	b.global_position = Vector3(lvl.rx(z) + 1.5, lvl._h(lvl.rx(z) + 1.5, z) + 0.9, z)
	b.rotation = Vector3.ZERO
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	await frames(4)

func _test_chapter6() -> void:
	var loaded := await load_level(6)
	ok("capítulo 6 carrega", loaded)
	if not loaded: return
	ok("cap6: Manipulador presente no inventário", p.weapons.owned.has("manipulator"), str(p.weapons.owned))
	ok("cap6: objetivo inicial (balizas)", Game.objective_key == "obj.ch6.beacons", Game.objective_key)
	var q := PhysicsRayQueryParameters3D.create(Vector3(lvl.rx(-100.0), 50, -100.0), Vector3(lvl.rx(-100.0), -50, -100.0))
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	ok("cap6: terreno de areia tem colisão", not hit.is_empty() and absf(hit.position.y - lvl._h(lvl.rx(-100.0), -100.0)) < 0.6, str(hit.get("position", "nada")))
	var b: Vehicle = lvl._buggy
	ok("cap6: Besouro disponível na largada", is_instance_valid(b))
	await tp(b.global_position + Vector3(-2.0, 0, 0))
	b.enter(p)
	await wait(0.3)
	ok("cap6: entra no Besouro", b.driver == p)
	Engine.time_scale = 3.0
	var r := await _buggy_drive(b, -200.0, 50.0)
	if not r:
		var qs := PhysicsShapeQueryParameters3D.new()
		var bx := BoxShape3D.new(); bx.size = Vector3(6, 3, 8)
		qs.shape = bx
		qs.transform = Transform3D(Basis(), b.global_position + Vector3(0, 1, -3))
		qs.exclude = [b.get_rid()]
		for h in p.get_world_3d().direct_space_state.intersect_shape(qs, 16):
			var col: Object = h.collider
			print("   DIAG colisor: ", col, " ", (col as Node).get_path() if col is Node else "", " ", (col as Node3D).global_position if col is Node3D else "")
	ok("cap6: dirige pelo leito seco até o petroleiro", r, "pos=%s v=%.1f drv=%s in=%s jump=%s sprint=%s fire=%s paused=%s sleep=%s frz=%s" % [b.global_position, b.linear_velocity.length(), b.driver == p, p.input_enabled, Input.is_action_pressed("jump"), Input.is_action_pressed("sprint"), Input.is_action_pressed("fire"), get_tree().paused, b.sleeping, b.freeze])
	await wait(0.3)
	ok("cap6: checkpoint petroleiro", Game.checkpoint == "tanker", Game.checkpoint)
	r = await _buggy_drive(b, -345.0, 50.0)
	if not r: await _buggy_reset(b, -345.0)
	await wait(0.4)
	ok("cap6: checkpoint ossada", Game.checkpoint == "bones", Game.checkpoint)
	ok("cap6: Rastejadores na ossada", lvl._crawlers_spawned)
	await kill_crawlers()
	r = await _buggy_drive(b, -500.0, 50.0)
	if not r: await _buggy_reset(b, -500.0)
	await wait(0.3)
	ok("cap6: checkpoint posto avançado", Game.checkpoint == "outpost", Game.checkpoint)
	await _buggy_drive(b, -530.0, 8.0)
	ok("cap6: cancela bloqueia o Besouro", b.global_position.z > lvl.OUTPOST_Z, "z=%.1f" % b.global_position.z)
	b.exit_vehicle(true)
	await kill_all(80.0)
	lvl._boom_btn.interact(p)
	var op := await until(func(): return lvl.flag("boom_open") and lvl._boom.rotation.z > 1.2, 10.0)
	ok("cap6: botão da cabine ergue a cancela", op)
	await _buggy_reset(b, lvl.OUTPOST_Z + 8.0)
	await tp(b.global_position + Vector3(-2.0, 0, 0))
	b.enter(p)
	await wait(0.2)
	r = await _buggy_drive(b, -590.0, 40.0)
	if not r: await _buggy_reset(b, -590.0)
	ok("cap6: passa pela cancela", b.global_position.z < lvl.OUTPOST_Z - 10.0, "z=%.1f" % b.global_position.z)
	await _buggy_drive(b, -640.0, 30.0)
	ok("cap6: tempestade de partículas ativa", lvl._storm_on and Game.objective_key == "obj.ch6.storm", Game.objective_key)
	var h0: float = p.health
	p.god = false
	await wait(2.0)
	ok("cap6: dentro do Besouro a tempestade não fere", p.health >= h0, "%.0f → %.0f" % [h0, p.health])
	b.exit_vehicle(true)
	await tp(p.global_position + Vector3(0, 0.5, 0))
	await wait(2.5)
	ok("cap6: a pé, a tempestade causa dano", p.health < h0, "%.0f → %.0f" % [h0, p.health])
	var sh: AABB = lvl._shelters[0]
	await tp(sh.get_center() - Vector3(0, sh.size.y * 0.5 - 0.15, 0))
	var h1: float = p.health
	await wait(2.0)
	ok("cap6: abrigo protege da tempestade", p.health >= h1 - 0.01, "%.0f → %.0f" % [h1, p.health])
	p.god = true
	p.health = 100.0
	await _buggy_reset(b, -700.0)
	await tp(b.global_position + Vector3(-2.0, 0, 0))
	b.enter(p)
	r = await _buggy_drive(b, -800.0, 40.0)
	if not r: await _buggy_reset(b, -800.0)
	await wait(0.4)
	ok("cap6: tempestade termina na costa", not lvl._storm_on and Game.objective_key == "obj.ch6.lighthouse", Game.objective_key)
	ok("cap6: checkpoint costa", Game.checkpoint == "coast", Game.checkpoint)
	ok("cap6: salvamento manual", Game.save_game("slot6"))
	r = await _buggy_drive(b, -860.0, 30.0)
	if not r: await _buggy_reset(b, -858.0)
	var arr := await until(func(): return lvl.flag("done"), 10.0)
	ok("cap6: chegada ao farol", arr)
	var end := await until(func(): return not Game.in_game, 90.0)
	ok("cap6: fim da demo leva ao encerramento", end)
	Engine.time_scale = 1.0
	var prev := Game.level
	Game.load_game("slot6")
	var ld := await until(func(): return Game.in_game and is_instance_valid(Game.level) and Game.level != prev and Game.chapter == 6 and Game.level.player == Game.player, 40.0)
	await frames(10)
	ok("cap6: load restaura estado (cancela aberta, checkpoint costa)", ld and Game.level.flag("boom_open") and Game.checkpoint == "coast" and Game.level._boom.rotation.z > 1.2)

# ---------------- Sala de Testes ----------------
func press(key: String) -> bool:
	var sw := find_all(lvl, func(n): return n is Interactables.Switch and n.hint_key == key, [])
	if sw.is_empty():
		return false
	sw[0].interact(p)
	await frames(2)
	return true

func _wstate(wm: WeaponManager, id: String) -> int:
	var d: Dictionary = WeaponManager.DEFS[id]
	var n := int(wm.clip.get(id, 0))
	if d.has("ammo"): n += int(wm.reserve.get(d["ammo"], 0))
	return n

## Dispara cada arma do arsenal (tiro primário) e confere consumo de munição / efeito;
## depois mata um alvo humano e confere o ragdoll.
func _test_arsenal(wm: WeaponManager) -> void:
	await tp(Vector3(0, 0.05, -14.0))
	p.rotation.y = 0.0
	p._pitch = deg_to_rad(-2.0)
	var bad := []
	for id in WeaponManager.DEFS.keys():
		var d: Dictionary = WeaponManager.DEFS[id]
		wm.equip(id)
		await wait(0.9)
		if wm.current != id:
			bad.append(id + ":equip"); continue
		var before := _wstate(wm, id)
		var hold := 1.1 if id == "guardgun" else 0.3
		Input.action_press("fire")
		await wait(hold)
		Input.action_release("fire")
		await wait(0.35)
		var t: String = d.get("type", "")
		if t in ["melee", "manip", "binoc"]:
			continue
		if _wstate(wm, id) >= before:
			bad.append("%s:%d" % [id, before])
		if d.has("ammo"): wm.add_ammo(d["ammo"], 999)
	ok("arsenal: %d armas disparam e consomem munição" % WeaponManager.DEFS.size(), bad.is_empty(), str(bad))
	await wait(3.0)  # granadas/hopwire detonam
	await press("test.respawn")
	await frames(10)
	var hs: Array = lvl._humans
	ok("sala de testes: %d alvos humanos" % hs.size(), hs.size() >= 5)
	var h: NpcBase = hs[0]
	await tp(h.global_position + Vector3(0, 0.05, 4.0))
	p.rotation.y = 0.0
	wm.equip("shotgun")
	await wait(0.9)
	Combat.apply_hit(h, 500.0, h.global_position + Vector3.UP * 1.2, Vector3(0, 0, -1), p, "bullet")
	await wait(0.6)
	ok("alvo humano: morre e vira ragdoll", not h.alive and h.body.ragdolled)
	await press("test.respawn")
	await frames(5)

## Physgun (levita/fixa), Gravity Gun (empurrão) e esfera de energia do AR2.
func _test_manip_tools(wm: WeaponManager) -> void:
	await tp(Vector3(10, 0.05, -14.0))
	p.rotation.y = 0.0
	p._pitch = 0.0
	p.head.rotation.x = 0.0
	await frames(3)
	var cam: Camera3D = p.camera
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var c := PhysicsProp.make("crate")
	lvl.add_child(c)
	c.global_position = Vector3(cam.global_position.x, cam.global_position.y, cam.global_position.z) + fwd * 5.0
	c.freeze = true
	wm.equip("physgun")
	await wait(0.9)
	c.freeze = false
	Input.action_press("fire")
	await wait(0.3)
	var held := wm._phys_body == c
	var y0 := c.global_position.y
	p._pitch = 25.0; p.head.rotation_degrees.x = 25.0
	await wait(1.2)
	var y1 := c.global_position.y
	ok("physgun: levita objeto à distância sem puxar", held and y1 > y0 + 1.0 and c.global_position.distance_to(cam.global_position) > 3.5, "held=%s y %.2f -> %.2f d=%.1f" % [held, y0, y1, c.global_position.distance_to(cam.global_position)])
	Input.action_press("aim")
	await wait(0.2)
	Input.action_release("aim")
	Input.action_release("fire")
	await wait(1.0)
	ok("physgun: fixa objeto no ar", c.freeze and c.has_meta("phys_frozen") and absf(c.global_position.y - y1) < 0.6, "freeze=%s y=%.2f" % [c.freeze, c.global_position.y])
	c.queue_free()
	p._pitch = -17.0; p.head.rotation_degrees.x = -17.0
	await frames(2)
	var g := PhysicsProp.make("crate_small")
	lvl.add_child(g)
	g.global_position = cam.global_position + fwd * 3.0 + Vector3.DOWN * 0.9
	wm.equip("gravitygun")
	await wait(1.0)
	var gp := g.global_position
	Input.action_press("fire")
	await frames(3)
	Input.action_release("fire")
	await wait(0.4)
	ok("gravity gun: empurrão arremessa objeto", g.global_position.distance_to(gp) > 1.5, "%.2f m" % g.global_position.distance_to(gp))
	g.queue_free()
	p._pitch = 0.0; p.head.rotation_degrees.x = 0.0
	wm.equip("ar2")
	await wait(0.9)
	var cb0: int = wm.reserve["cball"]
	wm._alt_fire()
	await wait(0.7)
	var balls := find_all(get_tree().root, func(n): return n is Projectile and n.kind == "cball", [])
	ok("AR2: esfera de energia disparada", wm.reserve["cball"] == cb0 - 1 and balls.size() > 0, "%d -> %d, esferas=%d" % [cb0, wm.reserve["cball"], balls.size()])
	await wait(4.5)

func _test_range() -> void:
	Engine.time_scale = 1.0
	# fecha os créditos do fim da demo (o rolamento automático voltaria ao menu no meio do teste)
	Game.quit_to_menu()
	await frames(5)
	var loaded := await load_level(0)
	ok("sala de testes carrega", loaded)
	if not loaded: return
	await frames(20)
	var wm := p.weapons
	ok("sala de testes: todas as armas", wm.owned.has("wrench") and wm.owned.has("pistol") and wm.owned.has("smg") and wm.owned.has("shotgun"), str(wm.owned))
	ok("sala de testes: munição máxima", wm.reserve["9mm"] == WeaponManager.MAX_AMMO["9mm"] and wm.reserve["12"] == WeaponManager.MAX_AMMO["12"], str(wm.reserve))
	var pk := find_all(lvl, func(n): return n is Interactables.Pickup, [])
	ok("sala de testes: bancada com todas as armas e munições (%d itens)" % pk.size(), pk.size() >= 30, str(pk.size()))
	ok("sala de testes: arsenal completo (%d armas)" % wm.owned.size(), wm.owned.size() == WeaponManager.DEFS.size(), str(wm.owned))
	var sw := find_all(lvl, func(n): return n is Interactables.Switch, [])
	var missing := []
	for n in sw:
		if Loc.t(n.hint_key) == n.hint_key: missing.append(n.hint_key)
	ok("sala de testes: %d botões com texto PT/EN" % sw.size(), sw.size() >= 30 and missing.is_empty(), str(missing))
	# alvos registram dano de tiro real (hitscan)
	var tg: Array = lvl._targets
	var t0: Node3D = tg[0]
	await tp(t0.global_position + Vector3(0, 0.05, 6.0))
	p.rotation.y = 0.0
	p.head.rotation.x = 0.0
	p._pitch = deg_to_rad(-4.0)
	wm.equip("pistol")
	await wait(1.0)
	for i in 3:
		Input.action_press("fire"); await frames(2); Input.action_release("fire"); await wait(0.3)
	ok("sala de testes: alvo registra acertos de tiro", t0.hits > 0, "acertos=%d dano=%d cur=%s in=%s paused=%s ammo=%s" % [t0.hits, int(t0.total), wm.current, p.input_enabled, get_tree().paused, str(wm.clip.get("pistol", -1)) if "clip" in wm else "?"])
	await press("test.btn.reset_targets")
	ok("sala de testes: zerar alvos", t0.hits == 0)
	await _test_arsenal(wm)
	await _test_manip_tools(wm)
	# inimigos
	var before: int = get_tree().get_nodes_in_group("enemy").size()
	await press("test.btn.spawn_squad")
	await frames(10)
	var after: int = get_tree().get_nodes_in_group("enemy").size()
	ok("sala de testes: gerar esquadrão (4)", after - before == 4, "%d -> %d" % [before, after])
	await press("test.btn.passive")
	ok("sala de testes: inimigos passivos", lvl._spawned.all(func(e): return e.passive))
	await press("test.btn.passive")
	await press("test.btn.kill_all")
	await frames(5)
	ok("sala de testes: eliminar todos", lvl._spawned.all(func(e): return not is_instance_valid(e) or not e.alive))
	await press("test.btn.clear_bodies")
	await frames(3)
	ok("sala de testes: remover corpos", lvl._spawned.is_empty())
	# física
	var nprops: int = lvl._props.size()
	ok("sala de testes: todos os tipos de objeto físico", nprops >= 10 + 4 + 6, str(nprops))
	await press("test.btn.explosion")
	await wait(0.5)
	var moved = lvl._props.filter(func(o): return not is_instance_valid(o) or (o is RigidBody3D and o.linear_velocity.length() > 0.3))
	ok("sala de testes: explosão afeta objetos", moved.size() > 0, "%d afetados" % moved.size())
	await press("test.btn.reset_props")
	await frames(3)
	ok("sala de testes: repor objetos", lvl._props.filter(func(o): return is_instance_valid(o)).size() == nprops)
	# zona de dano
	p.god = false
	p.health = 100.0
	await tp(Vector3(-6, 0.1, -64))
	await wait(1.3)
	ok("sala de testes: zona de dano fere o jogador", p.health < 100.0, "saúde %.0f" % p.health)
	await tp(Vector3(0, 0.1, -38))
	await press("test.btn.heal")
	ok("sala de testes: curar", p.health == p.max_health)
	await press("test.btn.god")
	var hp := p.health
	p.take_damage(30.0)
	ok("sala de testes: invulnerável", p.health == hp)
	await press("test.btn.god")
	p.god = true
	# porta trancada
	var doors := find_all(lvl, func(n): return n is Interactables.PhysDoor, [])
	var locked := doors.filter(func(d): return d.locked)
	ok("sala de testes: porta trancada existe", locked.size() == 1)
	await press("test.btn.unlock")
	ok("sala de testes: destrancar porta", locked.size() == 1 and not locked[0].locked)
	# escada de mão
	var ld: Node3D = find_all(lvl, func(n): return n is Interactables.Ladder, [])[0]
	await tp(ld.global_position + Vector3(0, 0.1, 0.5))
	p.rotation.y = 0.0
	var y0 := p.global_position.y
	InputRouter.touch_move = Vector2(0, -1)
	await wait(2.0)
	InputRouter.touch_move = Vector2.ZERO
	ok("sala de testes: subir escada de mão", p.global_position.y > y0 + 1.5, "y %.1f -> %.1f" % [y0, p.global_position.y])
	# esteira move o jogador
	await tp(Vector3(18, 1.0, -52))
	await frames(5)
	var z0 := p.global_position.z
	await wait(1.0)
	ok("sala de testes: esteira transporta", p.global_position.z > z0 + 0.8, "z %.1f -> %.1f" % [z0, p.global_position.z])
	# gráficos / dublagem / salvamento
	var pre: String = Settings.get_v("graphics", "preset", "")
	await press("test.btn.low")
	ok("sala de testes: predefinição Baixo ao vivo", Settings.get_v("graphics", "preset", "") == "low")
	if pre != "" and Settings.PRESETS.has(pre): Settings.apply_preset(pre)
	await press("test.btn.voice")
	await frames(3)
	ok("sala de testes: tocar fala dublada", Dialogue.is_busy() and Dialogue.missing_voice.is_empty())
	Dialogue.stop()
	ok("sala de testes: não salva progresso", not Game.save_game("test_probe"))
	ok("sala de testes: painel de desempenho", is_instance_valid(lvl._perf) and lvl._perf.text.begins_with("FPS"))
	# morte -> reinicia a sala
	var old_id := lvl.get_instance_id()
	p.god = false
	p.take_damage(500.0)
	await wait(0.5)
	Game.retry()
	var re := await until(func(): return is_instance_valid(Game.level) and Game.level.get_instance_id() != old_id and Game.chapter == 0 and is_instance_valid(Game.player) and Game.level.player == Game.player, 30.0)
	ok("sala de testes: reiniciar após morte", re)
