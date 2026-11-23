extends Node
## Raiz do jogo: mundo 3D, cenário do menu, HUD, controles de toque, menus, pausa e final.

var world: Node3D
var backdrop: Node3D
var ui: CanvasLayer
var hud: HUD
var touch: TouchControls
var menus: Menus
var _ending: Control
var paused := false

func _ready() -> void:
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new(); world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	ui = CanvasLayer.new(); ui.name = "UI"
	add_child(ui)
	hud = HUD.new(); hud.name = "HUD"
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	ui.add_child(hud)
	touch = TouchControls.new(); touch.name = "Touch"
	touch.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(touch)
	menus = Menus.new(); menus.name = "Menus"
	ui.add_child(menus)
	menus.request_touch_edit.connect(_on_touch_edit)
	InputRouter.device_changed.connect(_on_device)
	Game.player_died.connect(func(): touch.visible = false)
	get_tree().auto_accept_quit = true
	# Parâmetro de linha de comando para testes automatizados: --chapter=1 / --test=...
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shots(a.substr(7))
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			var t: Node = load("res://src/tests/autotest.gd").new()
			t.name = "AutoTest"
			add_child(t)
			return
		if a.begins_with("--cp="):
			Game.checkpoint = a.substr(5)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapter="):
			call_deferred("_start_from_cmd", int(a.split("=")[1]))
			return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lineup="):
			ui.visible = false; hud.visible = false; touch.visible = false
			for c in get_children():
				if c is CanvasLayer: c.visible = false
			world.add_child(load("res://src/tests/lineup.gd").new())
			return
	show_main_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu="):
			menus.open(a.substr(7))

## Captura de tela para QA: --shot=prefixo:segundos1,segundos2,...
func _shots(spec: String) -> void:
	var parts := spec.split(":")
	var prefix := parts[0]
	var times := parts[1].split(",") if parts.size() > 1 else PackedStringArray(["3"])
	var t0 := 0.0
	for ts in times:
		var t := float(ts)
		await get_tree().create_timer(t - t0, true, false, true).timeout
		t0 = t
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [prefix, ts])
		print("SHOT %s_%s.png fps=%d" % [prefix, ts, Engine.get_frames_per_second()])
	get_tree().quit()

## QA: --views=/tmp/pref;x,y,z,yaw,pitch;x,y,z,yaw,pitch;... (vários pontos de vista numa execução)
func _views(spec: String) -> void:
	var parts := spec.split(";")
	var prefix := parts[0]
	for i in 60:
		await get_tree().process_frame
		if is_instance_valid(Game.player): break
	await get_tree().create_timer(4.0, true, false, true).timeout
	for k in range(1, parts.size()):
		var v := parts[k].split(",")
		if not is_instance_valid(Game.player): break
		Game.player.god = true
		Game.player.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		Game.player.velocity = Vector3.ZERO
		Game.player.rotation.y = deg_to_rad(float(v[3])) if v.size() > 3 else 0.0
		Game.player.head.rotation.x = deg_to_rad(float(v[4])) if v.size() > 4 else 0.0
		Game.player._pitch = float(v[4]) if v.size() > 4 else 0.0
		await get_tree().create_timer(2.5, true, false, true).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [prefix, k])
		print("VIEW %s_%d.png fps=%d" % [prefix, k, Engine.get_frames_per_second()])
	get_tree().quit()

func _start_from_cmd(n: int) -> void:
	var cp := "start"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cp="):
			cp = a.substr(5)
	Game.start_chapter(n, cp)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--views="):
			_views(a.substr(8))
	# QA: --campos=x,y,z,yaw_graus,pitch_graus posiciona o jogador para capturas de tela.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--campos="):
			var v := a.substr(9).split(",")
			for i in 40:
				await get_tree().process_frame
				if is_instance_valid(Game.player):
					break
			await get_tree().create_timer(1.5).timeout
			if is_instance_valid(Game.player):
				Game.player.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
				Game.player.rotation.y = deg_to_rad(float(v[3])) if v.size() > 3 else 0.0
				if v.size() > 4:
					Game.player.head.rotation.x = deg_to_rad(float(v[4]))

func show_main_menu() -> void:
	paused = false
	get_tree().paused = false
	hud.visible = false
	if is_instance_valid(_ending):
		_ending.queue_free()
	_build_backdrop()
	menus.close()
	menus.open("main")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioBus.play_ambience("res://assets/audio/ambience/wind_city.wav", "", -12.0)
	AudioBus.play_music_track("res://assets/audio/music/main_theme.wav")

func _build_backdrop() -> void:
	if is_instance_valid(backdrop):
		return
	backdrop = MenuBackdrop.new()
	backdrop.name = "Backdrop"
	world.add_child(backdrop)

func show_loading(on: bool) -> void:
	if on:
		hud.visible = false
		if is_instance_valid(backdrop):
			backdrop.queue_free(); backdrop = null
		AudioBus.stop_theme()
		menus.close()
		menus.open("loading")
	else:
		menus.close()
		hud.visible = true
		if is_instance_valid(Game.player):
			hud.bind_player(Game.player)
		_capture_mouse()

func on_level_loaded(_lvl: Node) -> void:
	pass

func _capture_mouse() -> void:
	if InputRouter.device == InputRouter.Device.KBM and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_device(d: int) -> void:
	if Game.in_game and not paused and not hud.inventory_open():
		_capture_mouse()
	if menus.visible and d != InputRouter.Device.TOUCH and get_viewport().gui_get_focus_owner() == null:
		UIKit.focus_first(menus)

func _unhandled_input(event: InputEvent) -> void:
	if not Game.in_game or touch.edit_mode:
		return
	if event.is_action_pressed("pause") or (paused and event.is_action_pressed("ui_cancel") and menus.current() == "pause"):
		if is_instance_valid(Game.player) and not Game.player.alive:
			return
		if hud.inventory_open():
			_toggle_inventory()
		elif paused:
			if menus.current() == "pause":
				resume()
		else:
			pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not paused:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not paused and not hud.inventory_open() and InputRouter.device == InputRouter.Device.KBM:
		_capture_mouse()

func _toggle_inventory() -> void:
	hud.toggle_inventory()
	if is_instance_valid(Game.player):
		Game.player.input_enabled = not hud.inventory_open()
	if not hud.inventory_open():
		_capture_mouse()

func _notification(what: int) -> void:
	# Android: botão voltar / app em segundo plano → pausa
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if Game.in_game and not paused and is_instance_valid(Game.player) and Game.player.alive:
			pause()

func pause() -> void:
	paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.open("pause")
	AudioBus.play_ui("ui_back")

func resume() -> void:
	paused = false
	menus.close()
	get_tree().paused = false
	_capture_mouse()

func _on_touch_edit() -> void:
	menus.visible = false
	touch.set_edit_mode(true)

func on_touch_edit_done() -> void:
	menus.visible = true
	menus.open("settings", false)

func show_ending() -> void:
	hud.visible = false
	get_tree().paused = false
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioBus.stop_music()
	AudioBus.play_music_track("res://assets/audio/music/main_theme.wav")
	_ending = ColorRect.new()
	(_ending as ColorRect).color = Color(0, 0, 0, 1)
	UIKit.full_rect(_ending)
	_ending.theme = UIKit.theme()
	var v := UIKit.centered_column(22)
	UIKit.full_rect(v)
	v.add_child(UIKit.label(Loc.t("hud.chapter_complete").to_upper(), 40, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("%s %d — %s" % [Loc.t("menu.chapter"), Game.chapter, Loc.t("ch.%d" % Game.chapter)], 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var mins := int(Game.play_time / 60.0)
	v.add_child(UIKit.label("%02d:%02d" % [mins, int(Game.play_time) % 60], 20, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(Loc.t("end.tbc"), 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(Loc.t("end.build"), 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	ui.add_child(_ending)
	_ending.modulate.a = 0.0
	var ending_level_id := Game.level.get_instance_id() if is_instance_valid(Game.level) else 0
	var ending_node_id := _ending.get_instance_id()
	var tw := create_tween()
	tw.tween_property(_ending, "modulate:a", 1.0, 1.5)
	tw.tween_interval(6.0)
	tw.tween_callback(func():
		# só age se a tela de fim ainda estiver ativa (o jogador pode ter iniciado outra fase)
		if not is_instance_valid(_ending) or _ending.get_instance_id() != ending_node_id:
			return
		if is_instance_valid(Game.level) and Game.level.get_instance_id() == ending_level_id:
			Game.level.queue_free()
			Game.level = null
		_ending.queue_free()
		menus.open("credits"))
