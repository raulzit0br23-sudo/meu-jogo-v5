class_name Mats
extends RefCounted
## Biblioteca de materiais PBR (albedo + normal + ORM). A geometria do MeshKit gera UVs em metros;
## o triplanar em espaço de mundo fica reservado ao preset ULTRA (custo alto em GPU de celular).
## Cada material também declara seu "tipo físico" (som de passo/impacto, decal, partícula).

static var _cache := {}

const SURFACE := {"door_metal_red": "metal", "door_metal_grey": "metal", "door_train": "metal", "door_wood": "wood", "barrel_red": "metal", "barrel_blue": "metal", "barrel_lid_red": "metal", "barrel_lid_blue": "metal", "crate": "wood", "gunmetal": "metal", "fabric": "flesh", "camo_ow": "flesh", 
	"concrete": "concrete", "rusted_paint": "metal", "steel": "metal", "tiles": "concrete", "asphalt": "concrete",
	"brick": "concrete", "dominion": "metal", "cracked_earth": "gravel", "wood": "wood", "grate": "metal", "gravel": "gravel",
	"sand": "gravel", "water": "water", "corrugated": "metal",
}

## Qualidade de material (0 = BAIXO ... 3 = ULTRA). Alterada por Settings; os materiais já criados
## são reconfigurados no lugar, então a troca vale imediatamente.
##  0: só albedo (1 leitura de textura por pixel), UV da malha.
##  1: albedo + normal (2 leituras), UV da malha.
##  2: albedo + normal + ORM (rugosidade/metal/AO), UV da malha.
##  3: tudo + triplanar em espaço de mundo (até 15 leituras por pixel — só para PCs/celulares topo de linha).
static var quality := 1

static func get_mat(name: String, scale := 0.5, tint := Color.WHITE, triplanar := true) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [name, scale, tint.to_html(), triplanar]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.set_meta("az_tex", name)
	m.set_meta("az_scale", scale)
	m.set_meta("az_tri", triplanar)
	m.set_meta("az_world", true)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.set_meta("surface", SURFACE.get(name, "concrete"))
	_configure(m)
	_cache[key] = m
	return m

static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func _configure(m: StandardMaterial3D) -> void:
	var name: String = m.get_meta("az_tex")
	var scale: float = m.get_meta("az_scale")
	var base := "res://assets/textures/%s_" % name
	var alb := _tex(base + "albedo.png")
	m.albedo_texture = alb
	var q := quality if alb != null else 0
	m.normal_enabled = q >= 1 and alb != null
	m.normal_texture = _tex(base + "normal.png") if m.normal_enabled else null
	var orm: Texture2D = _tex(base + "orm.png") if q >= 2 else null
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0 if orm else 0.82
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0 if orm else (0.35 if SURFACE.get(name, "") == "metal" else 0.0)
	m.ao_enabled = orm != null
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.6
	# Triplanar só no ULTRA. Nos demais níveis usamos os UVs gerados pelo MeshKit (em metros, mesma
	# densidade do triplanar) — 3x menos leituras e sem perda de precisão em coordenadas de mundo grandes.
	var tri: bool = m.get_meta("az_tri") and q >= 3
	m.uv1_triplanar = tri
	m.uv1_world_triplanar = tri and m.get_meta("az_world")
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale

static func set_quality(q: int) -> void:
	q = clampi(q, 0, 3)
	if q == quality:
		return
	quality = q
	for k in _cache:
		var m = _cache[k]
		if m is StandardMaterial3D:
			if m.has_meta("az_tex"):
				_configure(m)
			elif m.has_meta("az_flat"):
				_configure_flat(m)

## Material de objeto móvel (props físicos): triplanar em espaço de objeto para a textura acompanhar o objeto.
static func prop(name: String, scale := 1.0, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "prop_%s_%s_%s" % [name, scale, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D = get_mat(name, scale, tint, true).duplicate()
	m.set_meta("az_world", false)
	_configure(m)
	m.set_meta("surface", SURFACE.get(name, "concrete"))
	_cache[key] = m
	return m

## Textura-folha mapeada 0..1 (portas, barris, painéis): sem triplanar, sem escala de mundo.
static func sheet(name: String, tint := Color.WHITE) -> StandardMaterial3D:
	return get_mat(name, 1.0, tint, false)

static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "em_%s_%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_cache[key] = m
	return m

static func flat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%s_%s" % [color.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.set_meta("az_flat", true)
	_configure_flat(m)
	_cache[key] = m
	return m

## Cores lisas (roupas, props, armas) recebem uma textura de detalhe neutra (sujeira/desgaste)
## em todos os níveis, para não parecerem superfícies sem textura. Custo: 1 leitura.
static func _configure_flat(m: StandardMaterial3D) -> void:
	var det := _tex("res://assets/textures/detail_grime_albedo.png") if quality >= 0 else null
	m.albedo_texture = det
	m.uv1_scale = Vector3.ONE * 1.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.55, 0.52, 0.28)
	m.roughness = 0.08
	m.metallic = 0.3
	m.set_meta("surface", "glass")
	_cache["glass"] = m
	return m

## Água opaca e escura (canais/esgoto): sem transparência (barato no Mobile), reflexo especular
## pelo normal map; a ondulação é animada deslocando o UV (WaterAnim, 10 Hz).
static func water(tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "water_%s" % tint.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("res://assets/textures/water_albedo.png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _tex("res://assets/textures/water_normal.png")
	m.normal_scale = 0.8
	m.roughness = 0.12
	m.metallic = 0.45
	m.metallic_specular = 0.8
	m.uv1_scale = Vector3(0.08, 0.08, 0.08)
	m.uv1_triplanar = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.set_meta("surface", "water")
	_cache[key] = m
	return m

static func surface_of(collider: Object) -> String:
	if collider == null:
		return "concrete"
	if collider.has_meta("surface"):
		return collider.get_meta("surface")
	return "concrete"
