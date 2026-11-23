extends Node3D
## QA: estúdio de personagens. `godot -- --lineup=/tmp/shots/lu` renderiza todos os figurinos
## lado a lado (frente, 3/4, perfil e close das cabeças) sem HUD e sai.
const OUTFITS := ["vigilante", "vigilante_elite", "soldier", "conscript", "citizen", "citizen"]
var prefix := "/tmp/shots/lineup"

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.34, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.6)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-150), 0)
	fill.light_energy = 0.5
	add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	floor_mi.material_override = Mats.get_mat("concrete", 0.5, Color.WHITE, false)
	add_child(floor_mi)
	for i in OUTFITS.size():
		var h := Humanoid.new(OUTFITS[i], 900 + i * 7 if i != 5 else 3)
		add_child(h)
		h.position = Vector3(-3.0 + i * 1.2, 0, 0)
		if OUTFITS[i] == "soldier": h.attach_weapon("rifle")
		elif OUTFITS[i] == "vigilante": h.attach_weapon("baton")
		elif OUTFITS[i] == "vigilante_elite": h.attach_weapon("pistol")
	# fileira de props físicos (auditoria de textura em todas as faces)
	var kinds := ["crate", "crate_small", "barrel", "explosive", "pallet", "suitcase", "battery", "engine", "tire", "bucket", "cinder", "plank", "sawblade"]
	for i in kinds.size():
		var pr := PhysicsProp.make(kinds[i])
		pr.freeze = true
		add_child(pr)
		pr.position = Vector3(-4.0 + (i % 7) * 1.3, 0.5, 4.0 + (i / 7) * 1.6)
		pr.rotation.y = 0.5
	# fileira de armas novas (modelos de primeira pessoa vistos de lado)
	var wids := ["crowbar", "magnum", "ar2", "crossbow", "rpg", "bugbait", "gravitygun", "physgun"]
	for i in wids.size():
		var w := ViewModels.build(wids[i])
		add_child(w)
		w.position = Vector3(-3.5 + (i % 4) * 1.6, 1.3 - (i / 4) * 0.7, -8.0)
		w.rotation.y = -PI * 0.5
		w.scale = Vector3.ONE * 1.6
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.make_current()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lineup="): prefix = a.substr(9)
	await _settle()
	var shots := [
		["front", Vector3(0, 1.1, 7.0), Vector3(0, 0.95, 0)],
		["threeq", Vector3(5.0, 1.4, 5.0), Vector3(0, 0.95, 0)],
		["vig", Vector3(-2.0, 1.65, 1.6), Vector3(-2.4, 1.5, 0)],
		["sold", Vector3(-0.2, 1.65, 1.6), Vector3(-0.6, 1.5, 0)],
		["side", Vector3(-6.5, 1.5, 0.8), Vector3(-1.8, 1.35, 0)],
		["back", Vector3(-1.8, 1.6, -3.0), Vector3(-1.8, 1.2, 0)],
		["props", Vector3(0, 2.4, 9.5), Vector3(0, 0.3, 4.8)],
		["props_top", Vector3(-1.5, 3.2, 6.0), Vector3(-1.5, 0.4, 4.2)],
		["crate_a", Vector3(-2.6, 1.4, 5.6), Vector3(-4.0, 0.5, 4.0)],
		["crate_b", Vector3(-5.6, 1.0, 2.6), Vector3(-4.0, 0.5, 4.0)],
		["barrel_top", Vector3(-1.4, 2.0, 4.6), Vector3(-1.4, 0.5, 4.0)],
		["weapons", Vector3(-1.2, 1.0, -3.6), Vector3(-1.2, 0.95, -8.0)],
		["weapons_q", Vector3(2.5, 1.5, -5.0), Vector3(0.5, 0.95, -8.0)],
		["props_low", Vector3(-1.6, 0.9, 7.2), Vector3(-1.6, 0.5, 4.0)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		await _settle(6)
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [prefix, s[0]])
		print("LINEUP %s_%s.png" % [prefix, s[0]])
	get_tree().quit()

func _settle(n := 20) -> void:
	for i in n:
		await get_tree().process_frame
