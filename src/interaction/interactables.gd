class_name Interactables
extends RefCounted
## Fábrica de elementos interativos: portas físicas com dobradiça, alavancas, botões, escadas de mão,
## gatilhos de área, itens coletáveis e tábuas quebráveis.

# ---------------- Porta física (RigidBody3D + HingeJoint3D) ----------------
class PhysDoor extends RigidBody3D:
	signal opened
	var locked := false
	var hinge: HingeJoint3D
	var _creak_cd := 0.0
	var _was_open := false
	var _frame: StaticBody3D
	func _init() -> void:
		collision_layer = 4
		collision_mask = 1 | 2 | 4 | 8
		mass = 22.0
		angular_damp = 3.0
		can_sleep = true
		set_meta("surface", "wood")
		set_meta("no_carry", true)
	func get_hint() -> String:
		return Loc.t("hud.use") if not locked else Loc.t("hud.locked")
	func interact(by: Node) -> void:
		if locked:
			AudioBus.play_3d("lever", global_position, -6.0)
			return
		freeze = false
		var away: Vector3 = (global_position - by.global_position).normalized()
		apply_impulse(away * 40.0, global_basis.x * 0.6)
		AudioBus.play_3d("door_creak", global_position, -6.0)
	func set_locked(v: bool) -> void:
		locked = v
		freeze = v
	func _physics_process(delta: float) -> void:
		_creak_cd -= delta
		if angular_velocity.length() > 0.8 and _creak_cd <= 0.0:
			_creak_cd = 1.5
			AudioBus.play_3d("door_creak", global_position, -10.0)
		var ang := absf(rotation.y - get_meta("rest_yaw", rotation.y))
		if ang > 0.6 and not _was_open:
			_was_open = true
			opened.emit()

static func door(parent: Node3D, pos: Vector3, yaw: float, size := Vector3(1.0, 2.1, 0.07), locked := false, mat: Material = null) -> PhysDoor:
	var frame := StaticBody3D.new()
	frame.collision_layer = 1
	parent.add_child(frame)
	frame.global_position = pos
	frame.rotation.y = yaw
	var d := PhysDoor.new()
	d._frame = frame
	parent.add_child(d)
	# A dobradiça fica na borda esquerda; o corpo da porta é deslocado meia largura.
	d.global_position = pos + Basis(Vector3.UP, yaw) * Vector3(size.x * 0.5, size.y * 0.5, 0)
	d.rotation.y = yaw
	d.set_meta("rest_yaw", yaw)
	var mi := MeshInstance3D.new()
	# Folha com UV 0..1: painéis, rebites, chapa de chute e desgaste vêm da textura da porta.
	mi.mesh = MeshKit.box_sheet(size)
	mi.material_override = mat if mat else Mats.sheet("door_metal_grey")
	d.add_child(mi)
	var knob := MeshInstance3D.new()
	knob.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.02, 0), Vector2(0.02, 0.05), Vector2(0.035, 0.06), Vector2(0.03, 0.08), Vector2(0.0, 0.085)]), 10)
	knob.material_override = Mats.prop("steel", 4.0)
	for s in [1.0, -1.0]:
		var k := knob.duplicate() as MeshInstance3D
		k.position = Vector3(size.x * 0.38, 0, size.z * 0.5 * s)
		k.rotation = Vector3(PI * 0.5 * s, 0, 0)
		d.add_child(k)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs
	d.add_child(cs)
	var h := HingeJoint3D.new()
	parent.add_child(h)
	h.global_position = pos + Vector3(0, size.y * 0.5, 0)
	h.global_basis = Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, yaw)  # eixo Z local -> vertical
	h.node_a = h.get_path_to(frame)
	h.node_b = h.get_path_to(d)
	h.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	h.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-100))
	h.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(100))
	d.hinge = h
	d.set_locked(locked)
	return d

# ---------------- Alavanca / botão ----------------
class Switch extends StaticBody3D:
	signal activated
	var once := true
	var used := false
	var enabled := true
	var handle: Node3D
	var hint_key := "hud.use"
	var sound := "lever"
	func get_hint() -> String:
		return "" if (used and once) or not enabled else Loc.t(hint_key)
	func interact(_by: Node) -> void:
		if (used and once) or not enabled:
			return
		used = true
		AudioBus.play_3d(sound, global_position, -2.0)
		if handle:
			var tw := create_tween()
			tw.tween_property(handle, "rotation:x", -handle.rotation.x, 0.35).set_trans(Tween.TRANS_BACK)
		activated.emit()

static func lever(parent: Node3D, pos: Vector3, yaw: float) -> Switch:
	var s := Switch.new()
	parent.add_child(s)
	s.global_position = pos
	s.rotation.y = yaw
	var box := MeshInstance3D.new()
	box.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.4, 0.6, 0.18), 0.02), Transform3D()],
		[MeshKit.bevel_box(Vector3(0.3, 0.08, 0.05), 0.01, 1), Transform3D(Basis(), Vector3(0, 0.18, 0.1))]])
	box.material_override = Mats.prop("rusted_paint", 2.0, Color(0.9, 0.75, 0.4))
	s.add_child(box)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.45, 0.9, 0.4); cs.shape = bs
	cs.position = Vector3(0, 0.1, 0.1)
	s.add_child(cs)
	var h := Node3D.new(); h.position = Vector3(0, 0, 0.1); h.rotation.x = 0.7
	s.add_child(h)
	var arm := MeshInstance3D.new()
	arm.mesh = MeshKit.combine([[MeshKit.cylinder(0.018, 0.4, 8), Transform3D(Basis(), Vector3(0, 0.2, 0))],
		[MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.035, 0.01), Vector2(0.04, 0.1), Vector2(0.0, 0.12)]), 10), Transform3D(Basis(), Vector3(0, 0.38, 0))]])
	arm.material_override = Mats.flat(Color(0.55, 0.1, 0.08), 0.6)
	h.add_child(arm)
	s.handle = h
	return s

static func button(parent: Node3D, pos: Vector3, yaw: float) -> Switch:
	var s := Switch.new()
	s.sound = "button_press"
	parent.add_child(s)
	s.global_position = pos
	s.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.bevel_box(Vector3(0.22, 0.3, 0.08), 0.015)
	mi.material_override = Mats.prop("steel", 3.0)
	s.add_child(mi)
	var b := MeshInstance3D.new()
	b.mesh = MeshKit.cylinder(0.045, 0.05, 14, 0.01)
	b.rotation.x = PI * 0.5
	b.position = Vector3(0, 0.03, 0.05)
	b.material_override = Mats.emissive(Color(0.9, 0.3, 0.1), 1.2)
	s.add_child(b)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.25, 0.32, 0.15); cs.shape = bs
	s.add_child(cs)
	return s

# ---------------- Escada de mão ----------------
class Ladder extends Area3D:
	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		body_entered.connect(func(b): if b is Player: b.on_ladder = self)
		body_exited.connect(func(b): if b is Player and b.on_ladder == self: b.on_ladder = null)

static func ladder(parent: Node3D, pos: Vector3, yaw: float, height: float) -> Ladder:
	var l := Ladder.new()
	parent.add_child(l)
	l.global_position = pos
	l.rotation.y = yaw
	var parts := []
	for x in [-0.22, 0.22]:
		parts.append([MeshKit.cylinder(0.025, height, 8), Transform3D(Basis(), Vector3(x, height * 0.5, 0))])
	var rungs := int(height / 0.3)
	for i in rungs:
		parts.append([MeshKit.cylinder(0.016, 0.44, 6), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.2 + i * 0.3, 0))])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.combine(parts)
	mi.material_override = Mats.prop("rusted_paint", 3.0)
	l.add_child(mi)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.7, height + 0.4, 0.9)
	cs.shape = bs; cs.position = Vector3(0, height * 0.5 + 0.2, 0.25)
	l.add_child(cs)
	return l

# ---------------- Gatilho de área ----------------
static func trigger(parent: Node3D, pos: Vector3, size: Vector3, callback: Callable, once := true) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2 | 4   # jogador a pé ou veículo pilotado por ele
	parent.add_child(a)
	a.global_position = pos
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs
	a.add_child(cs)
	var fired := [false]
	a.body_entered.connect(func(b):
		var is_p: bool = b is Player or (b is Vehicle and b.driver is Player)
		if is_p and not (once and fired[0]):
			fired[0] = true
			callback.call())
	return a

# ---------------- Item coletável ----------------
class Pickup extends StaticBody3D:
	var item := ""
	var amount := 0
	var on_pick: Callable
	func _init() -> void:
		collision_layer = 16
		collision_mask = 0
	func get_hint() -> String:
		return Loc.t("hud.pick") + ": " + Loc.t("item." + item)
	func interact(by: Node) -> void:
		var ok := false
		match item:
			"medkit": ok = by.heal(25.0)
			"filter": ok = by.add_filter(25.0)
			"mask":
				by.set_mask(true); ok = true
			_:
				if item.begins_with("ammo_"):
					ok = by.weapons.add_ammo(item.substr(5), amount)
				else:
					ok = by.weapons.give(item)
		if ok:
			AudioBus.play_3d("pickup_health" if item in ["medkit", "filter"] else "pickup_item", global_position, -4.0)
			get_tree().call_group("hud", "flash_pickup", Loc.t("item." + item))
			if on_pick.is_valid(): on_pick.call()
			queue_free()
		else:
			AudioBus.play_3d("manip_deny", global_position, -14.0)
	func _process(delta: float) -> void:
		if get_child_count() > 0:
			get_child(0).rotation.y += delta * 0.8

static func pickup(parent: Node3D, pos: Vector3, item: String, amount := 0) -> Pickup:
	var p := Pickup.new()
	p.item = item
	p.amount = amount
	var mi := MeshInstance3D.new()
	match item:
		"medkit":
			mi.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.36, 0.14, 0.24), 0.02), Transform3D()],
				[MeshKit.bevel_box(Vector3(0.12, 0.02, 0.04), 0.005, 1), Transform3D(Basis(), Vector3(0, 0.075, 0))],
				[MeshKit.bevel_box(Vector3(0.04, 0.02, 0.12), 0.005, 1), Transform3D(Basis(), Vector3(0, 0.075, 0))]])
			mi.material_override = Mats.prop("polymer", 3.0, Color(0.95, 0.93, 0.88))
		"filter":
			mi.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.06), Vector2(0.07, -0.06), Vector2(0.075, 0.04), Vector2(0.03, 0.07), Vector2(0.03, 0.09), Vector2(0.0, 0.09)]), 14)
			mi.material_override = Mats.prop("gunmetal", 3.0, Color(0.5, 0.75, 0.6))
		"mask":
			# máscara de gás: viseira oval, dois filtros laterais e tiras
			var rubber := Mats.prop("rubber", 3.0, Color(0.4, 0.42, 0.4))
			mi.mesh = MeshKit.combine([
				[MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.12, 0.05), Vector2(0.09, 0.1), Vector2(0.0, 0.11)]), 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.0, 1.3)), Vector3.ZERO)],
				[MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.05, 0.07), Vector2(0.0, 0.08)]), 10), Transform3D(Basis(Vector3.FORWARD, 1.0), Vector3(0.09, -0.03, 0.06))],
				[MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.05, 0.07), Vector2(0.0, 0.08)]), 10), Transform3D(Basis(Vector3.FORWARD, -1.0), Vector3(-0.09, -0.03, 0.06))]])
			mi.material_override = rubber
			var lens := MeshInstance3D.new()
			lens.mesh = MeshKit.bevel_box(Vector3(0.16, 0.06, 0.01), 0.01, 1)
			lens.material_override = Mats.glass()
			lens.position = Vector3(0, 0.03, 0.115)
			mi.add_child(lens)
		_ when item.begins_with("ammo_"):
			# caixa de munição de chapa pintada; cor por calibre (legível de longe)
			var tints := {"9mm": Color(0.55, 0.62, 0.4), "12": Color(0.75, 0.3, 0.25), "762": Color(0.5, 0.45, 0.32),
				"556": Color(0.4, 0.48, 0.5), "20mm": Color(0.7, 0.6, 0.25), "338": Color(0.35, 0.35, 0.38),
				"flare": Color(0.85, 0.3, 0.2), "rocket": Color(0.45, 0.5, 0.35), "fuel": Color(0.8, 0.55, 0.15),
				"bolt": Color(0.75, 0.4, 0.15), "guard": Color(0.35, 0.55, 0.75)}
			var big := item in ["ammo_rocket", "ammo_fuel", "ammo_762"]
			var sz := Vector3(0.4, 0.2, 0.22) if big else Vector3(0.24, 0.12, 0.16)
			mi.mesh = MeshKit.combine([[MeshKit.bevel_box(sz, 0.01), Transform3D()],
				[MeshKit.bevel_box(Vector3(sz.x + 0.01, 0.03, sz.z + 0.01), 0.005, 1), Transform3D(Basis(), Vector3(0, sz.y * 0.42, 0))],
				[MeshKit.bevel_box(Vector3(0.08, 0.02, 0.03), 0.004, 1), Transform3D(Basis(), Vector3(0, sz.y * 0.55, 0))]])
			mi.material_override = Mats.prop("gunmetal", 4.0, tints.get(item.substr(5), Color(0.6, 0.6, 0.5)))
		_:
			var vm := ViewModels.build(item)
			p.add_child(vm)
			var arms := vm.get_node_or_null("Arms")
			if arms: arms.queue_free()
			vm.scale = Vector3.ONE * 1.6
			mi = null
	if mi:
		p.add_child(mi)
	var cs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 0.35; cs.shape = sp
	p.add_child(cs)
	parent.add_child(p)
	p.global_position = pos
	return p
