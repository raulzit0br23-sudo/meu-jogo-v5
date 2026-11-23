class_name Humanoid
extends Node3D
## Corpo humanoide articulado (hierarquia de articulações) com malhas modeladas por torno/chanfro,
## figurinos (cidadão, vigilante, soldado, conscrito), animação procedural com blending
## (idle/respiração, caminhada, corrida, agachado, mira, fala com gestos, reação a impacto, sentado)
## e conversão para ragdoll físico com articulações cone-twist.

var outfit := "citizen"
var palette := {}
var joints := {}            # nome -> Node3D (pivô)
var _targets := {}          # nome -> Vector3 rotação alvo
var _phase := 0.0
var _breath := 0.0
var _flinch := Vector3.ZERO
var speed := 0.0            # m/s
var aim := 0.0              # 0..1
var crouch := 0.0           # 0..1
var sit := 0.0              # 0..1
var talk := 0.0             # energia de fala 0..1
var look_target: Vector3 = Vector3.INF
var weapon_kind := ""
var ragdolled := false
var _rag_bodies: Array[RigidBody3D] = []
var muzzle: Node3D

const SEG := 10   # segmentos de torno (baixo para mobile)

func _init(p_outfit := "citizen", seed := 0) -> void:
	outfit = p_outfit
	var r := RandomNumberGenerator.new(); r.seed = seed
	var coats := [Color(0.24, 0.27, 0.25), Color(0.3, 0.26, 0.2), Color(0.18, 0.21, 0.26), Color(0.33, 0.33, 0.3)]
	var skins := [Color(0.78, 0.62, 0.52), Color(0.62, 0.45, 0.35), Color(0.45, 0.32, 0.24), Color(0.85, 0.7, 0.6)]
	palette = {
		"coat": coats[r.randi() % coats.size()], "skin": skins[r.randi() % skins.size()],
		"pants": Color(0.16, 0.17, 0.18).lerp(Color(0.25, 0.22, 0.18), r.randf()),
		"hair": Color(0.1, 0.08, 0.06).lerp(Color(0.5, 0.45, 0.4), r.randf() * r.randf()),
		"mask": r.randf() < 0.75,
	}
	if outfit == "vigilante":
		palette["coat"] = Color(0.12, 0.14, 0.15); palette["pants"] = Color(0.1, 0.11, 0.12); palette["mask"] = true
	elif outfit == "vigilante_elite":
		palette["mask"] = true
	elif outfit == "soldier":
		palette["coat"] = Color(0.2, 0.24, 0.27); palette["pants"] = Color(0.16, 0.18, 0.2); palette["mask"] = true
	elif outfit == "conscript":
		palette["coat"] = Color(0.3, 0.32, 0.22); palette["pants"] = Color(0.26, 0.27, 0.2)

var _pending_weapon := ""

func _ready() -> void:
	_build()
	if _pending_weapon != "":
		var k := _pending_weapon
		_pending_weapon = ""
		attach_weapon(k)

func _mat(c: Color, rough := 0.85) -> Material:
	return Mats.flat(c, rough)

func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	parent.add_child(j)
	joints[name] = j
	_targets[name] = Vector3.ZERO
	return j

func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = scl
	m.rotation = rot
	m.visibility_range_end = Settings.get_v("graphics", "view_distance", 120.0) * 0.8
	parent.add_child(m)
	return m

## Membro afunilado ao longo de -Y (de cima para baixo), comprimento L.
func _limb(r0: float, r1: float, l: float, bulge := 0.1) -> ArrayMesh:
	return MeshKit.lathe(PackedVector2Array([Vector2(r0 * 0.7, 0.0), Vector2(r0, -l * 0.08), Vector2(lerpf(r0, r1, 0.35) * (1.0 + bulge), -l * 0.4),
		Vector2(r1, -l * 0.92), Vector2(r1 * 0.75, -l)]), SEG)

## Figurinos ORIGINAIS inspirados nas eras de desenvolvimento do HL2 Beta (ver docs/06_ARSENAL_E_PERSONAGENS.md):
##  citizen    — cidadão comum (sobretudo longo) OU variante "Air Exchange" (traje hazmat verde, avental,
##               capuz de gás com lentes redondas, braçadeira de identificação vermelha no braço esquerdo).
##  vigilante  — guarda urbano no espírito do conceito de 2001–02: sobretudo cinza-esverdeado longo, quepe,
##               máscara pálida de lentes redondas com filtro no queixo, braçadeira vermelha no braço direito.
##  vigilante_elite — mesma base com ombreiras e emblema vermelhos e lentes amarelas.
##  soldier    — soldado da Supervisão no espírito de 2002–03: camuflado azul-cinza, capacete-máscara integral
##               com lentes amarelas, número "314" no peito, joelheiras cinzas, calça verde-escura.
##  conscript  — recruta humano: colete antiestilhaço oliva, capacete de aço, cantil, rosto descoberto.
var variant := ""

func _tex_mat(name: String, tint: Color, scale := 3.0) -> Material:
	return Mats.prop(name, scale, Color(minf(tint.r, 1.0), minf(tint.g, 1.0), minf(tint.b, 1.0)))

func _sheet_mat(path: String) -> Material:
	var key := "hm_sheet_" + path
	if Mats._cache.has(key):
		return Mats._cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path) if ResourceLoader.exists(path) else null
	m.roughness = 0.8
	Mats._cache[key] = m
	return m

func _build() -> void:
	var r := RandomNumberGenerator.new(); r.seed = hash(str(palette))
	if outfit == "citizen":
		variant = "airex" if r.randf() < 0.4 else "plain"
	var skin := _mat(palette["skin"], 0.6)
	var boots := _tex_mat("leather", Color(0.14, 0.14, 0.15) if outfit in ["vigilante", "vigilante_elite", "soldier"] else Color(0.32, 0.27, 0.23), 4.0)
	var glove := _tex_mat("leather", Color(0.25, 0.23, 0.21), 4.0)
	var rubber := _tex_mat("rubber", Color(0.5, 0.52, 0.5), 4.0)
	var belt := _tex_mat("leather", Color(0.2, 0.17, 0.14), 4.0)
	var coat: Material
	var pants: Material
	var sleeve: Material
	var long_coat := false
	match outfit:
		"vigilante", "vigilante_elite":
			coat = _tex_mat("fabric", Color(0.3, 0.34, 0.4) if outfit == "vigilante" else Color(0.22, 0.23, 0.26), 2.5)
			pants = _tex_mat("fabric", Color(0.2, 0.22, 0.26), 3.0); long_coat = true
		"soldier":
			coat = _tex_mat("camo_ow", Color(1, 1, 1), 2.0); pants = _tex_mat("fabric", Color(0.38, 0.45, 0.36))
		"conscript":
			coat = _tex_mat("fabric", Color(0.48, 0.5, 0.36)); pants = _tex_mat("fabric", Color(0.4, 0.4, 0.3))
		_:
			if variant == "airex":
				coat = _tex_mat("hazmat", Color(0.62, 0.64, 0.5), 2.5); pants = coat
			else:
				coat = _tex_mat("fabric", palette["coat"] * 2.2); pants = _tex_mat("fabric", palette["pants"] * 2.4); long_coat = true
	sleeve = coat
	var pelvis := _joint("pelvis", self, Vector3(0, 0.98, 0))
	_mesh(pelvis, MeshKit.lathe(PackedVector2Array([Vector2(0.12, -0.12), Vector2(0.17, -0.05), Vector2(0.17, 0.06), Vector2(0.15, 0.1)]), SEG), pants, Vector3.ZERO, Vector3(1.0, 1, 0.7))
	_mesh(pelvis, MeshKit.lathe(PackedVector2Array([Vector2(0.172, 0.0), Vector2(0.176, 0.02), Vector2(0.176, 0.05), Vector2(0.172, 0.07)]), SEG, false, false), belt, Vector3(0, 0.02, 0), Vector3(1.0, 1, 0.72))
	var spine := _joint("spine", pelvis, Vector3(0, 0.1, 0))
	_mesh(spine, MeshKit.lathe(PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.16, 0.12), Vector2(0.17, 0.2)]), SEG), coat, Vector3.ZERO, Vector3(1.0, 1, 0.68))
	var chest := _joint("chest", spine, Vector3(0, 0.2, 0))
	var broad := 1.1 if outfit in ["vigilante", "vigilante_elite", "soldier"] else 1.0
	_mesh(chest, MeshKit.lathe(PackedVector2Array([Vector2(0.17, 0.0), Vector2(0.2, 0.12), Vector2(0.2, 0.24), Vector2(0.13, 0.31), Vector2(0.06, 0.33)]), SEG), coat, Vector3.ZERO, Vector3(broad, 1, 0.66))
	if long_coat and outfit.begins_with("vigilante"):
		pass  # sobretudo dos Vigilantes é feito em _combine_body
	elif long_coat:
		# sobretudo longo até os joelhos, com abertura frontal sugerida por uma faixa mais escura
		var skirt := MeshKit.lathe(PackedVector2Array([Vector2(0.19, 0.0), Vector2(0.2, -0.25), Vector2(0.23, -0.55), Vector2(0.25, -0.74)]), SEG, false, false)
		_mesh(spine, skirt, coat, Vector3(0, 0.12, 0), Vector3(1.0, 1, 0.75))
		_mesh(chest, MeshKit.lathe(PackedVector2Array([Vector2(0.11, 0.0), Vector2(0.14, 0.05), Vector2(0.12, 0.11)]), SEG), coat, Vector3(0, 0.28, -0.01))  # gola alta
		_mesh(spine, MeshKit.bevel_box(Vector3(0.03, 0.62, 0.02), 0.008, 1), belt, Vector3(0, -0.2, 0.17), Vector3.ONE, Vector3(-0.12, 0, 0))
		for i in 3:
			_mesh(chest, MeshKit.cylinder(0.012, 0.01, 6), _tex_mat("gunmetal", Color(0.7, 0.7, 0.65), 6.0), Vector3(0.05, 0.05 + i * 0.07, 0.135), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	match outfit:
		"vigilante", "vigilante_elite", "soldier":
			_combine_body(pelvis, spine, chest, coat, belt, rubber)
		"conscript":
			var flak := _tex_mat("flak", Color(0.85, 0.85, 0.7), 3.0)
			_mesh(chest, MeshKit.lathe(PackedVector2Array([Vector2(0.19, 0.0), Vector2(0.215, 0.1), Vector2(0.205, 0.24), Vector2(0.14, 0.3)]), SEG, false, false), flak, Vector3(0, 0.0, 0), Vector3(1.0, 1, 0.72))
			_mesh(spine, MeshKit.lathe(PackedVector2Array([Vector2(0.17, -0.02), Vector2(0.175, 0.2)]), SEG, false, false), flak, Vector3.ZERO, Vector3(1.0, 1, 0.72))
			# cantil no quadril
			_mesh(pelvis, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.07), Vector2(0.05, -0.06), Vector2(0.055, 0.04), Vector2(0.02, 0.07), Vector2(0.0, 0.08)]), 10), _tex_mat("gunmetal", Color(0.6, 0.65, 0.45), 6.0), Vector3(-0.19, -0.03, -0.04), Vector3(1, 1, 0.55))
			_mesh(pelvis, MeshKit.bevel_box(Vector3(0.07, 0.08, 0.05), 0.01, 1), belt, Vector3(0.12, 0.0, 0.13))
		_:
			if variant == "airex":
				# avental de borracha da Troca de Ar
				var apron := _tex_mat("rubber", Color(0.55, 0.5, 0.42), 3.0)
				_mesh(chest, MeshKit.bevel_box(Vector3(0.27, 0.3, 0.015), 0.01, 1), apron, Vector3(0, 0.1, 0.15), Vector3.ONE, Vector3(0.08, 0, 0))
				_mesh(spine, MeshKit.bevel_box(Vector3(0.3, 0.5, 0.015), 0.01, 1), apron, Vector3(0, -0.12, 0.155), Vector3.ONE, Vector3(-0.06, 0, 0))
				_mesh(chest, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.06, -0.11), Vector2(0.065, 0.1), Vector2(0.0, 0.12)]), 8), _tex_mat("gunmetal", Color(0.7, 0.7, 0.62), 4.0), Vector3(0.0, 0.14, -0.17), Vector3(1, 1, 0.7))
	var neck := _joint("neck", chest, Vector3(0, 0.32, 0))
	_mesh(neck, MeshKit.cylinder(0.055, 0.1, SEG), coat if outfit in ["soldier", "vigilante", "vigilante_elite"] or variant == "airex" else skin, Vector3(0, 0.04, 0))
	var head := _joint("head", neck, Vector3(0, 0.09, 0))
	var skull := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.07, 0.0), Vector2(0.095, 0.06), Vector2(0.1, 0.13), Vector2(0.085, 0.2), Vector2(0.04, 0.235), Vector2(0.0, 0.24)]), 14)
	match outfit:
		"vigilante", "vigilante_elite", "soldier":
			_combine_head(head, chest, skull, rubber, belt)
		_:
			_mesh(head, skull, skin, Vector3.ZERO, Vector3(0.92, 1, 1.05))
			if variant == "airex":
				# capuz de gás com visor e lentes redondas
				var hood := _tex_mat("hazmat", Color(0.62, 0.64, 0.5), 2.5)
				_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.1, -0.03), Vector2(0.115, 0.08), Vector2(0.115, 0.17), Vector2(0.095, 0.24), Vector2(0.0, 0.27)]), 14), hood, Vector3.ZERO, Vector3(0.98, 1, 1.08))
				for s in [-1.0, 1.0]:
					_mesh(head, MeshKit.cylinder(0.032, 0.012, 12), Mats.glass(), Vector3(0.045 * s, 0.13, 0.115), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
					_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.034, 0.0), Vector2(0.038, 0.012)]), 12, false, false), rubber, Vector3(0.045 * s, 0.13, 0.11), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
				_mesh(head, MeshKit.cylinder(0.035, 0.05, 12, 0.008), _tex_mat("gunmetal", Color(0.6, 0.62, 0.55), 6.0), Vector3(0, 0.04, 0.12), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
			else:
				_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.09, 0.12), Vector2(0.1, 0.17), Vector2(0.075, 0.23), Vector2(0.0, 0.25)]), 12), _mat(palette["hair"]), Vector3(0, 0, -0.01), Vector3(0.95, 1, 1.08))
				_mesh(head, MeshKit.bevel_box(Vector3(0.03, 0.04, 0.03), 0.01, 1), skin, Vector3(0, 0.11, 0.1))  # nariz
				for s in [-1.0, 1.0]:
					_mesh(head, MeshKit.bevel_box(Vector3(0.022, 0.012, 0.01), 0.004, 1), _mat(Color(0.05, 0.05, 0.05), 0.2), Vector3(0.035 * s, 0.135, 0.092))
					_mesh(head, MeshKit.bevel_box(Vector3(0.03, 0.008, 0.01), 0.003, 1), _mat(palette["hair"]), Vector3(0.035 * s, 0.155, 0.093))
				if palette["mask"] and outfit == "citizen":
					# meia-máscara de filtro (ar da cidade)
					_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.065, 0.0), Vector2(0.06, 0.04), Vector2(0.04, 0.07), Vector2(0.032, 0.08)]), 12), rubber, Vector3(0, 0.07, 0.07), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
					_mesh(head, MeshKit.cylinder(0.035, 0.05, 12, 0.008), _tex_mat("gunmetal", Color(0.6, 0.62, 0.55), 6.0), Vector3(0.05, 0.05, 0.12), Vector3.ONE, Vector3(PI * 0.5, 0.5, 0))
			if outfit == "conscript":
				var steel := _tex_mat("gunmetal", Color(0.75, 0.8, 0.6), 4.0)
				_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.14, 0.12), Vector2(0.135, 0.14), Vector2(0.11, 0.24), Vector2(0.0, 0.275)]), 14), steel, Vector3.ZERO)
				_mesh(head, MeshKit.bevel_box(Vector3(0.012, 0.12, 0.012), 0.004, 1), belt, Vector3(0.09, 0.07, 0.03))
	# braços
	for s in [-1.0, 1.0]:
		var side := "l" if s < 0 else "r"
		var sh := _joint("shoulder_" + side, chest, Vector3((0.215 if outfit in ["vigilante", "vigilante_elite", "soldier"] else 0.2) * s, 0.26, 0))
		_mesh(sh, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.06), Vector2(0.07, 0.03), Vector2(0.075, -0.04)]), SEG), sleeve)
		_mesh(sh, _limb(0.062, 0.05, 0.29), sleeve)
		if outfit == "vigilante_elite" or outfit == "soldier":
			# ombreira em camadas (placas sobrepostas)
			var pad := _tex_mat("polymer", Color(0.75, 0.16, 0.12), 4.0) if outfit == "vigilante_elite" else _tex_mat("polymer", Color(0.34, 0.38, 0.44), 4.0)
			_mesh(sh, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.085), Vector2(0.07, 0.07), Vector2(0.098, 0.01), Vector2(0.1, -0.06)]), 12, false, false), pad, Vector3(0.012 * s, 0, 0), Vector3(1, 1, 1.05))
			_mesh(sh, MeshKit.lathe(PackedVector2Array([Vector2(0.09, -0.03), Vector2(0.1, -0.07), Vector2(0.098, -0.11)]), 12, false, false), pad, Vector3(0.012 * s, -0.01, 0), Vector3(1, 1, 1.05))
		elif outfit == "vigilante":
			# dragona do sobretudo
			_mesh(sh, MeshKit.bevel_box(Vector3(0.1, 0.018, 0.06), 0.006, 1), belt, Vector3(-0.01 * s, 0.07, 0), Vector3.ONE, Vector3(0, 0, -0.35 * s))
		if outfit == "soldier":
			# protetor de antebraço
			pass
		# braçadeiras: vermelha no braço direito (guarda urbano) / identificação no esquerdo (Troca de Ar)
		var band := (outfit in ["vigilante", "vigilante_elite"] and side == "r") or (variant == "airex" and side == "l")
		if band:
			var bm := _tex_mat("fabric", Color(0.95, 0.18, 0.12), 4.0)
			_mesh(sh, MeshKit.lathe(PackedVector2Array([Vector2(0.064, 0.0), Vector2(0.066, 0.06)]), SEG, false, false), bm, Vector3(0, -0.14, 0))
		var el := _joint("elbow_" + side, sh, Vector3(0, -0.29, 0))
		_mesh(el, _limb(0.05, 0.04, 0.26), sleeve)
		if outfit == "soldier":
			_mesh(el, MeshKit.lathe(PackedVector2Array([Vector2(0.056, -0.04), Vector2(0.06, -0.1), Vector2(0.052, -0.2)]), 10, false, false), _tex_mat("polymer", Color(0.3, 0.33, 0.38), 4.0), Vector3(0, 0, 0.004), Vector3(1, 1, 1.1))
		elif outfit.begins_with("vigilante"):
			_mesh(el, MeshKit.lathe(PackedVector2Array([Vector2(0.046, -0.2), Vector2(0.052, -0.215), Vector2(0.052, -0.25)]), 10, false, false), sleeve)  # punho do sobretudo
		var hand := _joint("hand_" + side, el, Vector3(0, -0.26, 0))
		var hm: Material = skin if (outfit == "citizen" and variant != "airex") or outfit == "conscript" else glove
		_mesh(hand, MeshKit.bevel_box(Vector3(0.06, 0.1, 0.035), 0.015), hm, Vector3(0, -0.05, 0))
		_mesh(hand, MeshKit.bevel_box(Vector3(0.02, 0.05, 0.02), 0.007, 1), hm, Vector3(0.035 * s, -0.035, 0.015), Vector3.ONE, Vector3(0, 0, -0.4 * s))
	# pernas
	for s in [-1.0, 1.0]:
		var side := "l" if s < 0 else "r"
		var hp := _joint("hip_" + side, pelvis, Vector3(0.095 * s, -0.06, 0))
		_mesh(hp, _limb(0.085, 0.06, 0.44, 0.05), pants)
		if outfit == "soldier":
			var tp := _tex_mat("polymer", Color(0.3, 0.33, 0.38), 4.0)
			_mesh(hp, MeshKit.bevel_box(Vector3(0.12, 0.2, 0.05), 0.02, 2), tp, Vector3(0.0, -0.14, 0.075), Vector3.ONE, Vector3(0.05, 0, 0))
			_mesh(hp, MeshKit.bevel_box(Vector3(0.05, 0.09, 0.05), 0.01, 1), belt, Vector3(0.085 * s, -0.24, 0.0))
		var kn := _joint("knee_" + side, hp, Vector3(0, -0.44, 0))
		_mesh(kn, _limb(0.06, 0.045, 0.42), pants)
		if outfit in ["soldier", "conscript"]:
			_mesh(kn, MeshKit.bevel_box(Vector3(0.09, 0.1, 0.05), 0.02), _tex_mat("rubber", Color(0.7, 0.72, 0.72), 4.0), Vector3(0, -0.02, 0.05))
		var ft := _joint("foot_" + side, kn, Vector3(0, -0.42, 0))
		_mesh(ft, MeshKit.bevel_box(Vector3(0.1, 0.08, 0.26), 0.03), boots, Vector3(0, -0.03, 0.06))
		_mesh(ft, MeshKit.lathe(PackedVector2Array([Vector2(0.055, -0.0), Vector2(0.06, 0.3 if outfit.begins_with("vigilante") else (0.2 if outfit == "soldier" else (0.14 if outfit != "citizen" else 0.1)))]), SEG), boots, Vector3(0, -0.02, 0))
		_mesh(ft, MeshKit.bevel_box(Vector3(0.105, 0.02, 0.27), 0.006, 1), rubber, Vector3(0, -0.07, 0.06))
	_merge_joints()

## Junta as malhas de cada articulação por material: de ~60 nós para ~25 por personagem.
# =====================================================================
# Combine (Vigilantes e Soldados) — designs ORIGINAIS que seguem a linguagem visual
# documentada das concept arts de Half-Life 2 (Raising the Bar / beta 2001–03):
#  - Vigilante: sobretudo longo de inspiração militar dos anos 40 (cinturão, talabarte, dragonas,
#    botas de cano alto), capuz escuro e máscara de gás frontal pálida com duas lentes redondas,
#    focinho de filtro, cantil lateral e mangueira até o cartucho do peito.
#  - Elite: sobretudo preto, quepe de oficial com faixa vermelha, máscara escura, lentes âmbar.
#  - Soldado: capacete integral liso com visor escuro e duas lentes grandes brilhantes, respiradores
#    nas bochechas, mangueira até a mochila, placas de armadura em camadas sobre camuflado azul-cinza.
# =====================================================================
func _combine_body(pelvis: Node3D, spine: Node3D, chest: Node3D, coat: Material, belt: Material, rubber: Material) -> void:
	var metal := _tex_mat("gunmetal", Color(0.62, 0.63, 0.6), 6.0)
	if outfit.begins_with("vigilante"):
		# saia do sobretudo até abaixo do joelho, com abertura frontal e aba traseira
		var skirt := MeshKit.lathe(PackedVector2Array([Vector2(0.185, 0.0), Vector2(0.2, -0.2), Vector2(0.235, -0.5), Vector2(0.27, -0.78), Vector2(0.275, -0.8)]), 14, false, false)
		_mesh(spine, skirt, coat, Vector3(0, 0.12, 0), Vector3(1.08, 1, 0.78))
		_mesh(spine, MeshKit.bevel_box(Vector3(0.025, 0.78, 0.03), 0.008, 1), belt, Vector3(0.0, -0.27, 0.2), Vector3.ONE, Vector3(-0.15, 0, 0))
		# gola alta
		_mesh(chest, MeshKit.lathe(PackedVector2Array([Vector2(0.11, 0.0), Vector2(0.135, 0.06), Vector2(0.125, 0.13)]), 12, false, false), coat, Vector3(0, 0.27, -0.005), Vector3(1.0, 1, 1.0))
		# duas fileiras de botões
		for i in 4:
			for sx in [-1.0, 1.0]:
				_mesh(spine if i < 2 else chest, MeshKit.cylinder(0.011, 0.01, 6), metal, Vector3(0.065 * sx, (0.02 + i * 0.08) if i < 2 else (0.0 + (i - 2) * 0.08), 0.14 if i < 2 else 0.15), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		# cinturão largo com fivela + talabarte diagonal
		_mesh(spine, MeshKit.lathe(PackedVector2Array([Vector2(0.178, 0.0), Vector2(0.182, 0.015), Vector2(0.182, 0.055), Vector2(0.178, 0.07)]), 14, false, false), belt, Vector3(0, -0.02, 0), Vector3(1.1, 1, 0.8))
		_mesh(spine, MeshKit.bevel_box(Vector3(0.07, 0.055, 0.015), 0.006, 1), metal, Vector3(0, 0.015, 0.15))
		_mesh(chest, MeshKit.bevel_box(Vector3(0.035, 0.5, 0.012), 0.005, 1), belt, Vector3(0.0, 0.08, 0.145), Vector3.ONE, Vector3(-0.05, 0, 0.62))
		_mesh(chest, MeshKit.bevel_box(Vector3(0.035, 0.42, 0.012), 0.005, 1), belt, Vector3(0.0, 0.1, -0.14), Vector3.ONE, Vector3(0.05, 0, -0.62))
		# coldre e bolsa de carregadores no cinturão
		_mesh(pelvis, MeshKit.bevel_box(Vector3(0.06, 0.12, 0.05), 0.012, 1), belt, Vector3(0.2, -0.04, 0.05))
		_mesh(pelvis, MeshKit.bevel_box(Vector3(0.09, 0.06, 0.045), 0.01, 1), belt, Vector3(-0.12, 0.02, 0.15))
		# cartucho de filtro no peito + mangueira até o focinho da máscara
		_mesh(chest, MeshKit.cylinder(0.034, 0.09, 12, 0.006), metal, Vector3(0.1, 0.14, 0.15), Vector3.ONE, Vector3(0.0, 0, 0.0))
		_mesh(chest, MeshKit.pipe(PackedVector3Array([Vector3(0.1, 0.19, 0.155), Vector3(0.09, 0.27, 0.19), Vector3(0.04, 0.36, 0.19), Vector3(0.0, 0.41, 0.17)]), 0.016, 8), rubber)
		# insígnia no peito
		var patch := "res://assets/textures/patch_elite.png" if outfit == "vigilante_elite" else "res://assets/textures/patch_cp.png"
		_mesh(chest, MeshKit.bevel_box(Vector3(0.07, 0.04, 0.008), 0.003, 1), _sheet_mat(patch), Vector3(-0.1, 0.2, 0.15), Vector3.ONE, Vector3(-0.15, 0, 0))
	else:
		# Soldado: peitoral e costeiro em camadas, abdômen segmentado, colar, mochila com mangueira
		var plate := _tex_mat("polymer", Color(0.34, 0.38, 0.44), 4.0)
		var dark := _tex_mat("polymer", Color(0.18, 0.19, 0.22), 4.0)
		_mesh(chest, MeshKit.bevel_box(Vector3(0.34, 0.2, 0.08), 0.035, 2), plate, Vector3(0, 0.18, 0.105), Vector3.ONE, Vector3(-0.08, 0, 0))
		_mesh(chest, MeshKit.bevel_box(Vector3(0.3, 0.08, 0.07), 0.025, 2), dark, Vector3(0, 0.05, 0.11))
		for i in 2:
			_mesh(spine, MeshKit.bevel_box(Vector3(0.27 - i * 0.02, 0.07, 0.06), 0.02, 2), plate, Vector3(0, 0.16 - i * 0.08, 0.1))
		_mesh(chest, MeshKit.bevel_box(Vector3(0.32, 0.26, 0.07), 0.03, 2), plate, Vector3(0, 0.14, -0.11))
		_mesh(chest, MeshKit.lathe(PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.125, 0.03), Vector2(0.12, 0.08)]), 12, false, false), dark, Vector3(0, 0.29, 0), Vector3(1.05, 1, 1.0))
		_mesh(chest, MeshKit.bevel_box(Vector3(0.09, 0.045, 0.01), 0.004, 1), _sheet_mat("res://assets/textures/patch_314.png"), Vector3(-0.09, 0.24, 0.15), Vector3.ONE, Vector3(-0.08, 0, 0))
		# mochila (tanque/rádio) e mangueira para o capacete
		_mesh(chest, MeshKit.bevel_box(Vector3(0.24, 0.26, 0.1), 0.03, 2), dark, Vector3(0, 0.13, -0.19))
		_mesh(chest, MeshKit.cylinder(0.045, 0.22, 12, 0.01), metal, Vector3(0.0, 0.13, -0.25))
		_mesh(chest, MeshKit.pipe(PackedVector3Array([Vector3(0.09, 0.22, -0.2), Vector3(0.16, 0.32, -0.08), Vector3(0.12, 0.4, 0.04), Vector3(0.09, 0.43, 0.07)]), 0.018, 8), rubber)
		# cinto de munição com bolsas
		for i in 4:
			_mesh(pelvis, MeshKit.bevel_box(Vector3(0.06, 0.08, 0.045), 0.01, 1), belt, Vector3(-0.15 + i * 0.1, 0.02, 0.14))
		_mesh(pelvis, MeshKit.bevel_box(Vector3(0.16, 0.14, 0.04), 0.02, 2), plate, Vector3(0, -0.08, 0.13))

func _combine_head(head: Node3D, chest: Node3D, skull: Mesh, rubber: Material, belt: Material) -> void:
	var metal := _tex_mat("gunmetal", Color(0.6, 0.61, 0.58), 6.0)
	var dark_rubber := _tex_mat("rubber", Color(0.32, 0.33, 0.34), 4.0)
	if outfit.begins_with("vigilante"):
		var elite := outfit == "vigilante_elite"
		# capuz justo (balaclava de borracha) cobrindo crânio e nuca
		_mesh(head, skull, dark_rubber, Vector3(0, 0, -0.005), Vector3(1.0, 1.02, 1.08))
		# máscara frontal: casca oval que avança sobre o rosto
		var face := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.04), Vector2(0.06, -0.03), Vector2(0.088, 0.03), Vector2(0.092, 0.1), Vector2(0.08, 0.16), Vector2(0.05, 0.195), Vector2(0.0, 0.205)]), 14)
		var mask_mat := _tex_mat("polymer", Color(0.2, 0.21, 0.23), 4.0) if elite else _tex_mat("polymer", Color(0.82, 0.83, 0.8), 4.0)
		_mesh(head, face, mask_mat, Vector3(0, 0.0, 0.045), Vector3(1.0, 1.0, 0.72))
		# lentes redondas inclinadas para fora, com aro grosso
		var eye := Mats.emissive(Color(1.0, 0.62, 0.15) if elite else Color(0.45, 0.75, 1.0), 1.8)
		for sx in [-1.0, 1.0]:
			var lp := Vector3(0.042 * sx, 0.125, 0.098)
			var b := Basis(Vector3.UP, 0.32 * sx) * Basis(Vector3.FORWARD, -0.2 * sx) * Basis(Vector3.RIGHT, PI * 0.5)
			_mesh_t(head, MeshKit.lathe(PackedVector2Array([Vector2(0.026, 0.0), Vector2(0.036, 0.004), Vector2(0.036, 0.022), Vector2(0.028, 0.03)]), 14, false, false), dark_rubber, Transform3D(b, lp))
			_mesh_t(head, MeshKit.cylinder(0.027, 0.006, 14), eye, Transform3D(b, lp + b.y * 0.022))
		# focinho do filtro + grade + cantil lateral
		var sn := Basis(Vector3.RIGHT, PI * 0.5 + 0.35)
		_mesh_t(head, MeshKit.lathe(PackedVector2Array([Vector2(0.042, 0.0), Vector2(0.038, 0.025), Vector2(0.03, 0.045), Vector2(0.028, 0.05)]), 12), dark_rubber, Transform3D(sn, Vector3(0, 0.045, 0.1)))
		_mesh_t(head, MeshKit.cylinder(0.031, 0.016, 12, 0.004), metal, Transform3D(sn, Vector3(0, 0.045, 0.1) + sn.y * 0.054))
		_mesh_t(head, MeshKit.cylinder(0.026, 0.055, 12, 0.006), metal, Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, 0.4), Vector3(-0.095, 0.05, 0.06)))
		# tiras da máscara
		_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.104, 0.0), Vector2(0.106, 0.018)]), 14, false, false), belt, Vector3(0, 0.11, -0.01), Vector3(1.0, 1, 1.08), Vector3(-0.35, 0, 0))
		if elite:
			# quepe de oficial com faixa vermelha e aba
			var cap := _tex_mat("fabric", Color(0.16, 0.17, 0.19), 4.0)
			_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.106, 0.15), Vector2(0.11, 0.2), Vector2(0.15, 0.26), Vector2(0.145, 0.285), Vector2(0.0, 0.29)]), 16), cap, Vector3(0, 0, -0.01), Vector3(1.0, 1, 1.1))
			_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.11, 0.17), Vector2(0.116, 0.21)]), 16, false, false), _tex_mat("fabric", Color(0.8, 0.14, 0.1), 4.0), Vector3(0, 0, -0.01), Vector3(1.0, 1, 1.1))
			_mesh(head, MeshKit.bevel_box(Vector3(0.17, 0.012, 0.075), 0.005, 1), _tex_mat("leather", Color(0.15, 0.13, 0.12), 4.0), Vector3(0, 0.185, 0.115), Vector3.ONE, Vector3(-0.28, 0, 0))
			_mesh(head, MeshKit.bevel_box(Vector3(0.04, 0.03, 0.008), 0.003, 1), metal, Vector3(0, 0.235, 0.13), Vector3.ONE, Vector3(-0.3, 0, 0))
		else:
			# capacete de patrulha de aba curta sobre o capuz
			var helm := _tex_mat("polymer", Color(0.26, 0.29, 0.34), 4.0)
			_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.132, 0.12), Vector2(0.125, 0.135), Vector2(0.118, 0.19), Vector2(0.095, 0.245), Vector2(0.05, 0.272), Vector2(0.0, 0.28)]), 16, false, true), helm, Vector3(0, 0.005, -0.012), Vector3(1.0, 1, 1.1), Vector3(-0.22, 0, 0))
			_mesh(head, MeshKit.bevel_box(Vector3(0.12, 0.03, 0.01), 0.004, 1), metal, Vector3(0, 0.245, 0.06), Vector3.ONE, Vector3(-0.9, 0, 0))
	else:
		# Soldado: capacete integral liso
		var helm := _tex_mat("polymer", Color(0.32, 0.36, 0.42), 4.0)
		var visor := _tex_mat("polymer", Color(0.1, 0.1, 0.12), 4.0)
		_mesh(head, MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.045), Vector2(0.085, -0.035), Vector2(0.115, 0.04), Vector2(0.122, 0.13), Vector2(0.11, 0.21), Vector2(0.07, 0.262), Vector2(0.0, 0.28)]), 16), helm, Vector3(0, 0, -0.008), Vector3(0.98, 1, 1.12))
		# crista central e bordas laterais
		# visor escuro frontal com as duas lentes grandes
		var face := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.07), Vector2(0.06, 0.075), Vector2(0.085, 0.12), Vector2(0.07, 0.17), Vector2(0.0, 0.18)]), 14)
		_mesh(head, face, visor, Vector3(0, 0.0, 0.06), Vector3(1.05, 1, 0.75))
		var eye := Mats.emissive(Color(1.0, 0.72, 0.2), 2.4)
		for sx in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, 0.28 * sx) * Basis(Vector3.RIGHT, PI * 0.5)
			var lp := Vector3(0.046 * sx, 0.128, 0.112)
			_mesh_t(head, MeshKit.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.038, 0.004), Vector2(0.037, 0.016), Vector2(0.031, 0.02)]), 14, false, false), metal, Transform3D(b, lp))
			_mesh_t(head, MeshKit.cylinder(0.031, 0.006, 14), eye, Transform3D(b, lp + b.y * 0.014))
			# respiradores nas bochechas
			var cb := Basis(Vector3.UP, 0.6 * sx) * Basis(Vector3.RIGHT, PI * 0.5 + 0.6)
			_mesh_t(head, MeshKit.cylinder(0.03, 0.05, 12, 0.006), dark_rubber, Transform3D(cb, Vector3(0.068 * sx, 0.035, 0.085)))
			_mesh_t(head, MeshKit.cylinder(0.026, 0.012, 12), metal, Transform3D(cb, Vector3(0.068 * sx, 0.035, 0.085) + cb.y * 0.03))
		# queixeira/respirador central
		var rb := Basis(Vector3.RIGHT, PI * 0.5 + 0.5)
		_mesh_t(head, MeshKit.lathe(PackedVector2Array([Vector2(0.045, 0.0), Vector2(0.04, 0.03), Vector2(0.03, 0.045), Vector2(0.0, 0.05)]), 12), visor, Transform3D(rb, Vector3(0, 0.035, 0.09)))
		for k in 3:
			_mesh_t(head, MeshKit.bevel_box(Vector3(0.05 - k * 0.01, 0.004, 0.006), 0.001, 1), metal, Transform3D(rb, Vector3(0, 0.035, 0.09) + rb.y * 0.046 + rb.z * (k - 1) * 0.012))

func _mesh_t(parent: Node3D, mesh: Mesh, mat: Material, t: Transform3D) -> MeshInstance3D:
	var m := _mesh(parent, mesh, mat)
	m.transform = t
	return m

func _merge_joints() -> void:
	for jn in joints:
		var j: Node3D = joints[jn]
		var groups := {}
		var vis := []
		for c in j.get_children():
			if c is MeshInstance3D and c.get_child_count() == 0:
				var key = c.material_override
				if not groups.has(key): groups[key] = []
				groups[key].append([c.mesh, c.transform])
				vis.append(c)
		if vis.size() < 2:
			continue
		for c in vis:
			j.remove_child(c); c.free()
		for mat in groups:
			var mi := MeshInstance3D.new()
			mi.mesh = MeshKit.combine(groups[mat])
			mi.material_override = mat
			mi.visibility_range_end = Settings.get_v("graphics", "view_distance", 120.0) * 0.8
			j.add_child(mi)

func attach_weapon(kind: String) -> void:
	weapon_kind = kind
	if not joints.has("hand_r"):
		_pending_weapon = kind
		return
	var hand: Node3D = joints["hand_r"]
	var g := Node3D.new(); g.name = "Gun"
	hand.add_child(g)
	g.position = Vector3(0, -0.08, 0.02)
	g.rotation = Vector3(-PI * 0.5, 0, 0)
	var metal := Mats.prop("gunmetal", 5.0, Color(0.45, 0.46, 0.48))
	var mi := MeshInstance3D.new()
	match kind:
		"baton":
			mi.mesh = MeshKit.combine([[MeshKit.cylinder(0.018, 0.55, 8, 0.004), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.2))],
				[MeshKit.cylinder(0.024, 0.04, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.47))]])
			mi.material_override = Mats.flat(Color(0.05, 0.05, 0.05), 0.4)
		"pistol":
			mi.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.03, 0.04, 0.18), 0.006), Transform3D(Basis(), Vector3(0, 0.03, -0.06))],
				[MeshKit.bevel_box(Vector3(0.028, 0.1, 0.04), 0.008), Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, -0.02, 0.0))]])
			mi.material_override = metal
		_:
			mi.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.05, 0.08, 0.42), 0.012), Transform3D(Basis(), Vector3(0, 0.03, -0.12))],
				[MeshKit.cylinder(0.02, 0.22, 10, 0.004), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.04, -0.42))],
				[MeshKit.bevel_box(Vector3(0.03, 0.14, 0.05), 0.008), Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(0, -0.05, -0.15))],
				[MeshKit.bevel_box(Vector3(0.045, 0.07, 0.2), 0.012), Transform3D(Basis(), Vector3(0, 0.0, 0.15))]])
			mi.material_override = metal
			if outfit == "soldier":
				# fuzil de combate volumoso com luneta (silhueta do OICW das fotos de 2002–03)
				var body2 := MeshInstance3D.new()
				body2.mesh = MeshKit.combine([[MeshKit.bevel_box(Vector3(0.07, 0.1, 0.4), 0.025), Transform3D(Basis(), Vector3(0, 0.03, -0.1))],
					[MeshKit.cylinder(0.026, 0.2, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.11, -0.1))]])
				body2.material_override = Mats.prop("polymer", 5.0, Color(0.5, 0.52, 0.44))
				g.add_child(body2)
			var glow := MeshInstance3D.new()
			glow.mesh = MeshKit.bevel_box(Vector3(0.012, 0.012, 0.12), 0.004, 1)
			glow.material_override = Mats.emissive(Color(0.3, 0.8, 1.0), 2.5)
			glow.position = Vector3(0.026, 0.05, -0.1)
			g.add_child(glow)
	g.add_child(mi)
	muzzle = Node3D.new(); muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.04, -0.55 if kind == "rifle" else -0.16)
	g.add_child(muzzle)

func flinch(dir: Vector3) -> void:
	var local := global_basis.inverse() * dir
	_flinch += Vector3(-local.z * 0.5, 0, local.x * 0.5).limit_length(0.8)

# ---------------- animação procedural ----------------
func animate(delta: float) -> void:
	if ragdolled:
		return
	_breath += delta * 1.6
	var run := clampf((speed - 2.5) / 3.0, 0.0, 1.0)
	var walk := clampf(speed / 1.6, 0.0, 1.0)
	_phase += delta * lerpf(5.2, 9.0, run) * walk
	var ph := _phase
	var stride := lerpf(0.45, 0.85, run) * walk * (1.0 - sit)
	var c := crouch * (1.0 - sit)
	for side in ["l", "r"]:
		var o := 0.0 if side == "l" else PI
		var sg := -1.0 if side == "l" else 1.0
		var hip_x := sin(ph + o) * stride - c * 1.2 - sit * 1.5
		var knee_x := maxf(0.0, -sin(ph + o + 0.9)) * stride * 1.6 + c * 2.0 + sit * 1.5
		_targets["hip_" + side] = Vector3(hip_x, 0, sg * 0.03)
		_targets["knee_" + side] = Vector3(knee_x, 0, 0)
		_targets["foot_" + side] = Vector3(-c * 0.8 + maxf(0.0, sin(ph + o)) * stride * 0.3, 0, 0)
		var arm_swing := -sin(ph + o) * stride * 0.7
		var sh := Vector3(arm_swing + sin(_breath) * 0.02, 0, sg * (0.08 + run * 0.05))
		var el := Vector3(-0.15 - walk * 0.3 - run * 0.6, 0, 0)
		if sit > 0.5:
			sh = Vector3(-0.5, 0, sg * 0.1); el = Vector3(-0.9, 0, 0)
		# gestos de fala
		if talk > 0.05 and side == "r" and aim < 0.5:
			sh += Vector3(-0.5 - talk * 0.5 * sin(_breath * 3.0), 0.0, 0.15)
			el += Vector3(-0.8 * talk, 0, 0)
		_targets["shoulder_" + side] = sh
		_targets["elbow_" + side] = el
	# postura de mira
	if aim > 0.01 and weapon_kind != "":
		var two_hand := weapon_kind != "baton"
		_targets["shoulder_r"] = _targets["shoulder_r"].lerp(Vector3(-1.45, -0.15, 0.0), aim)
		_targets["elbow_r"] = _targets["elbow_r"].lerp(Vector3(-0.15, 0, 0), aim)
		if two_hand:
			_targets["shoulder_l"] = _targets["shoulder_l"].lerp(Vector3(-1.35, 0.6, -0.1), aim)
			_targets["elbow_l"] = _targets["elbow_l"].lerp(Vector3(-0.6, 0, 0), aim)
	var lean := run * 0.25 + c * 0.35
	_targets["spine"] = Vector3(lean + sin(_breath) * 0.015, sin(ph) * stride * 0.12, 0) + _flinch * 0.6
	_targets["chest"] = Vector3(sin(_breath) * 0.02, -sin(ph) * stride * 0.1, 0) + _flinch * 0.4
	_targets["pelvis"] = Vector3(0, sin(ph) * stride * 0.1, 0)
	# cabeça: olhar alvo
	var hd := Vector3(talk * 0.08 * sin(_breath * 4.3), 0, 0)
	if look_target != Vector3.INF:
		var local = global_basis.inverse() * (look_target - joints["neck"].global_position)
		var yaw := clampf(atan2(local.x, local.z), -1.1, 1.1)
		var pitch := clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
		hd += Vector3(pitch, yaw, 0)
	_targets["head"] = hd
	_targets["neck"] = Vector3(-lean * 0.5, 0, 0)
	_flinch = _flinch.lerp(Vector3.ZERO, clampf(delta * 6.0, 0, 1))
	# altura da pélvis (agachar/sentar/passada)
	var pel: Node3D = joints["pelvis"]
	pel.position.y = 0.98 - c * 0.42 - sit * 0.5 - absf(sin(ph)) * stride * 0.04
	# blending suave em todas as articulações
	var k := clampf(delta * 12.0, 0.0, 1.0)
	for n in _targets:
		var j: Node3D = joints[n]
		j.rotation = j.rotation.lerp(_targets[n], k)

# ---------------- ragdoll ----------------
const RAG := [
	# nome, raio, comprimento, pai, limite de giro (graus)
	["pelvis", 0.15, 0.22, "", 0], ["chest", 0.17, 0.42, "pelvis", 30], ["head", 0.1, 0.22, "chest", 40],
	["shoulder_l", 0.055, 0.29, "chest", 80], ["elbow_l", 0.045, 0.26, "shoulder_l", 70],
	["shoulder_r", 0.055, 0.29, "chest", 80], ["elbow_r", 0.045, 0.26, "shoulder_r", 70],
	["hip_l", 0.07, 0.44, "pelvis", 60], ["knee_l", 0.055, 0.45, "hip_l", 70],
	["hip_r", 0.07, 0.44, "pelvis", 60], ["knee_r", 0.055, 0.45, "hip_r", 70],
]

func ragdoll(impulse: Vector3, hit_pos: Vector3, inherit_vel := Vector3.ZERO) -> void:
	if ragdolled:
		return
	ragdolled = true
	var world := get_tree().current_scene if Game.level == null else Game.level
	var bodies := {}
	for spec in RAG:
		var jn: Node3D = joints[spec[0]]
		var b := RigidBody3D.new()
		b.collision_layer = 32
		b.collision_mask = 1 | 4
		b.mass = 6.0 if spec[0] in ["pelvis", "chest"] else 2.5
		b.linear_damp = 0.1
		b.angular_damp = 1.5
		b.set_meta("surface", "flesh")
		world.add_child(b)
		b.global_transform = jn.global_transform
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = spec[1]; cap.height = maxf(spec[2], spec[1] * 2.1)
		cs.shape = cap
		var up := 1.0 if spec[0] in ["chest", "head"] else -1.0
		cs.position = Vector3(0, up * spec[2] * 0.5, 0)
		b.add_child(cs)
		# transfere as malhas (incluindo as de articulações filhas não simuladas, ex.: mãos, pés, pescoço)
		_move_meshes(jn, b)
		b.linear_velocity = inherit_vel
		bodies[spec[0]] = b
		_rag_bodies.append(b)
	for spec in RAG:
		if spec[3] == "":
			continue
		var a: RigidBody3D = bodies[spec[3]]
		var bb: RigidBody3D = bodies[spec[0]]
		a.add_collision_exception_with(bb)
		var jt := ConeTwistJoint3D.new()
		world.add_child(jt)
		jt.global_transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), bb.global_position)
		jt.node_a = jt.get_path_to(a)
		jt.node_b = jt.get_path_to(bb)
		jt.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(spec[4]))
		jt.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(spec[4] * 0.5))
		jt.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
		bb.set_meta("joint", jt)
	# impulso no segmento mais próximo do impacto
	var best: RigidBody3D = bodies["chest"]
	var bd := INF
	for k in bodies:
		var d: float = bodies[k].global_position.distance_to(hit_pos)
		if d < bd:
			bd = d; best = bodies[k]
	best.apply_impulse(impulse, hit_pos - best.global_position)
	visible = false
	# Congela após assentar (economia de CPU) e limita ragdolls ativos.
	var tw := world.create_tween()
	tw.tween_interval(7.0)
	var rb: Array[RigidBody3D] = _rag_bodies.duplicate()
	tw.tween_callback(func():
		for b in rb:
			if is_instance_valid(b):
				b.freeze = true)
	RagdollBudget.register(self)

func _move_meshes(j: Node3D, body: RigidBody3D) -> void:
	for c in j.get_children():
		if c is MeshInstance3D or (c is Node3D and c.name == "Gun"):
			var gt: Transform3D = c.global_transform
			j.remove_child(c)
			body.add_child(c)
			c.global_transform = gt
		elif c is Node3D and not _is_rag_joint(c.name):
			_move_meshes(c, body)

func _is_rag_joint(n: String) -> bool:
	for s in RAG:
		if s[0] == n:
			return true
	return false

func free_ragdoll() -> void:
	for b in _rag_bodies:
		if is_instance_valid(b):
			if b.has_meta("joint") and is_instance_valid(b.get_meta("joint")):
				b.get_meta("joint").queue_free()
			b.queue_free()
	_rag_bodies.clear()

class RagdollBudget:
	static var active: Array = []
	static func register(h: Humanoid) -> void:
		active.append(h)
		var limit := 4 if Settings.get_v("graphics", "preset", "medium") == "low" else 8
		while active.size() > limit:
			var old = active.pop_front()
			if is_instance_valid(old):
				old.free_ragdoll()
				if is_instance_valid(old.get_parent()):
					old.get_parent().queue_free()
