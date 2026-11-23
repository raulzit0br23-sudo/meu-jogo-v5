class_name MeshKit
extends RefCounted
## Kit de modelagem procedural. Gera geometria real (chanfros, perfis de torno, tubos curvos,
## arcos, escadas) e combina várias peças num único ArrayMesh por material (menos draw calls).
## Também gera LODs automáticos via ImporterMesh quando disponível.

# ---------------- primitivas com detalhe ----------------

## Caixa com arestas chanfradas/arredondadas (normais suaves nas bordas).
static func bevel_box(size: Vector3, r := 0.04, seg := 2) -> ArrayMesh:
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.95)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := h - Vector3.ONE * r
	var coords := func(half: float) -> PackedFloat32Array:
		var c := PackedFloat32Array([-half])
		for i in range(1, seg + 1):
			c.append(-half + r * (1.0 - cos(PI * 0.5 * float(i) / float(seg + 1))) )
		c.append(-half + r)
		c.append(half - r)
		for i in range(seg, 0, -1):
			c.append(half - r * (1.0 - cos(PI * 0.5 * float(i) / float(seg + 1))))
		c.append(half)
		return c
	var cx: PackedFloat32Array = coords.call(h.x)
	var cy: PackedFloat32Array = coords.call(h.y)
	var cz: PackedFloat32Array = coords.call(h.z)
	# 6 faces: eixo normal, sinal, eixos u/v
	var faces := [[0, 1, 2, 1], [0, -1, 1, 2], [1, 1, 0, 2], [1, -1, 2, 0], [2, 1, 1, 0], [2, -1, 0, 1]]
	var ax := [cx, cy, cz]
	var hh := [h.x, h.y, h.z]
	for f in faces:
		var n_ax: int = f[0]; var sgn: float = f[1]; var u_ax: int = f[2]; var v_ax: int = f[3]
		if sgn < 0:
			var tmp := u_ax; u_ax = v_ax; v_ax = tmp
		var cu: PackedFloat32Array = ax[u_ax]
		var cv: PackedFloat32Array = ax[v_ax]
		for i in cu.size() - 1:
			for j in cv.size() - 1:
				var quad := []
				for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
					var p := Vector3.ZERO
					p[n_ax] = hh[n_ax] * sgn
					p[u_ax] = cu[i + d[0]]
					p[v_ax] = cv[j + d[1]]
					var ip := p.clamp(-inner, inner)
					var dir := p - ip
					var nrm := dir.normalized() if dir.length() > 1e-5 else Vector3.ZERO
					if nrm == Vector3.ZERO:
						nrm[n_ax] = sgn
					var v := ip + nrm * r
					quad.append([v, nrm])
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(quad[idx][1])
					st.set_uv(Vector2(quad[idx][0][u_ax], quad[idx][0][v_ax]))
					st.add_vertex(quad[idx][0])
	st.generate_tangents()
	return st.commit()

## Caixa simples (24 vértices) com UVs em metros (mesma convenção do bevel_box). Substitui o
## BoxMesh, cujos UVs ficam num atlas 0..1 por face e esticavam a textura em paredes grandes.
static func box_uv(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[0, 1, 2, 1], [0, -1, 1, 2], [1, 1, 0, 2], [1, -1, 2, 0], [2, 1, 1, 0], [2, -1, 0, 1]]
	var hh := [h.x, h.y, h.z]
	for f in faces:
		var n_ax: int = f[0]; var sgn: float = f[1]; var u_ax: int = f[2]; var v_ax: int = f[3]
		if sgn < 0:
			var tmp := u_ax; u_ax = v_ax; v_ax = tmp
		var nrm := Vector3.ZERO; nrm[n_ax] = sgn
		var quad := []
		for d in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var p := Vector3.ZERO
			p[n_ax] = hh[n_ax] * sgn
			p[u_ax] = hh[u_ax] * d[0]
			p[v_ax] = hh[v_ax] * d[1]
			quad.append(p)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(Vector2(quad[idx][u_ax], quad[idx][v_ax]))
			st.add_vertex(quad[idx])
	st.generate_tangents()
	return st.commit()

## Placa (porta/painel) com UV 0..1 nas duas faces maiores — para texturas-folha (portas, placas).
## O eixo mais fino é a espessura; Y é sempre a vertical (v = 0 no topo). Bordas amostram a coluna u≈0.01.
static func box_sheet(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	var thin := 0 if size.x <= size.z else 2
	var across := 2 if thin == 0 else 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[0, 1, 2, 1], [0, -1, 1, 2], [1, 1, 0, 2], [1, -1, 2, 0], [2, 1, 1, 0], [2, -1, 0, 1]]
	var hh := [h.x, h.y, h.z]
	for f in faces:
		var n_ax: int = f[0]; var sgn: float = f[1]; var u_ax: int = f[2]; var v_ax: int = f[3]
		if sgn < 0:
			var tmp := u_ax; u_ax = v_ax; v_ax = tmp
		var nrm := Vector3.ZERO; nrm[n_ax] = sgn
		var quad := []
		for d in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var p := Vector3.ZERO
			p[n_ax] = hh[n_ax] * sgn
			p[u_ax] = hh[u_ax] * d[0]
			p[v_ax] = hh[v_ax] * d[1]
			quad.append(p)
		for idx in [0, 1, 2, 0, 2, 3]:
			var q: Vector3 = quad[idx]
			var v := 1.0 - (q.y + h.y) / size.y
			var u := 0.01
			if n_ax == thin:
				u = (q[across] + hh[across]) / size[across]
				# a face traseira espelha para a maçaneta/número lerem do mesmo lado visual
				if (sgn > 0) == (thin == 0):
					u = 1.0 - u
			st.set_normal(nrm)
			st.set_uv(Vector2(u, v))
			st.add_vertex(q)
	st.generate_tangents()
	return st.commit()

## Caixa com UV 0..1 completo em cada uma das 6 faces (caixas de suprimento: mesma folha em todos os lados).
static func box_cube_uv(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[0, 1, 2, 1], [0, -1, 1, 2], [1, 1, 0, 2], [1, -1, 2, 0], [2, 1, 1, 0], [2, -1, 0, 1]]
	var hh := [h.x, h.y, h.z]
	for f in faces:
		var n_ax: int = f[0]; var sgn: float = f[1]; var u_ax: int = f[2]; var v_ax: int = f[3]
		if sgn < 0:
			var tmp := u_ax; u_ax = v_ax; v_ax = tmp
		var nrm := Vector3.ZERO; nrm[n_ax] = sgn
		var quad := []
		for d in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var p := Vector3.ZERO
			p[n_ax] = hh[n_ax] * sgn
			p[u_ax] = hh[u_ax] * d[0]
			p[v_ax] = hh[v_ax] * d[1]
			# UV legível visto de fora: "cima" = +Y (ou -Z no topo/fundo), direita = cima × normal
			var up := Vector3.UP if n_ax != 1 else Vector3(0, 0, -sgn)
			var right := up.cross(nrm)
			quad.append([p, Vector2(p.dot(right) / size.dot(right.abs()) + 0.5, 0.5 - p.dot(up) / size.dot(up.abs()))])
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	st.generate_tangents()
	return st.commit()

## Disco plano (tampa) com UV 0..1 centrado; normal +Y.
static func disc(radius: float, segments := 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments:
		var a0 := TAU * float(s) / segments
		var a1 := TAU * float(s + 1) / segments
		var v0 := Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var v1 := Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		for v in [Vector3.ZERO, v0, v1]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(v.x, v.z) / (2.0 * radius) + Vector2(0.5, 0.5)); st.add_vertex(v)
	st.generate_tangents()
	return st.commit()

## Sólido de revolução a partir de um perfil [(raio, y), ...] (barris, colunas, postes, membros).
static func lathe(profile: PackedVector2Array, segments := 16, cap_bottom := true, cap_top := true, smooth := true, uv_norm := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	# Normais do perfil (2D) por vértice
	var pn: Array[Vector2] = []
	for i in n:
		var a := profile[maxi(i - 1, 0)]
		var b := profile[mini(i + 1, n - 1)]
		var tng := (b - a).normalized()
		pn.append(Vector2(tng.y, -tng.x))
	var length_acc := [0.0]
	for i in range(1, n):
		length_acc.append(length_acc[i - 1] + profile[i].distance_to(profile[i - 1]))
	var rmax := 0.0
	for pp in profile:
		rmax = maxf(rmax, pp.x)
	var u_rep := maxf(1.0, roundf(TAU * rmax))
	for s in segments:
		var a0 := TAU * float(s) / segments
		var a1 := TAU * float(s + 1) / segments
		for i in n - 1:
			var p := [profile[i], profile[i + 1]]
			var nn := [pn[i], pn[i + 1]]
			if not smooth:
				var tng2 := (profile[i + 1] - profile[i]).normalized()
				nn = [Vector2(tng2.y, -tng2.x), Vector2(tng2.y, -tng2.x)]
			var verts := []
			for c in [[0, a0], [0, a1], [1, a1], [1, a0]]:
				var pr: Vector2 = p[c[0]]
				var nr: Vector2 = nn[c[0]]
				var ang: float = c[1]
				var v := Vector3(cos(ang) * pr.x, pr.y, sin(ang) * pr.x)
				var nv := Vector3(cos(ang) * nr.x, nr.y, sin(ang) * nr.x).normalized()
				var uv := Vector2(ang / TAU * u_rep, length_acc[i + c[0]])
				if uv_norm:
					# folha desdobrada: u = volta completa, v = 0 no topo do perfil
					uv = Vector2(1.0 - ang / TAU, 1.0 - length_acc[i + c[0]] / maxf(length_acc[n - 1], 0.001))
				verts.append([v, nv, uv])
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(verts[idx][1]); st.set_uv(verts[idx][2]); st.add_vertex(verts[idx][0])
	if cap_bottom and profile[0].x > 0.001:
		_cap(st, profile[0], segments, -1.0)
	if cap_top and profile[n - 1].x > 0.001:
		_cap(st, profile[n - 1], segments, 1.0)
	st.generate_tangents()
	return st.commit()

static func _cap(st: SurfaceTool, p: Vector2, segments: int, dir: float) -> void:
	var c := Vector3(0, p.y, 0)
	for s in segments:
		var a0 := TAU * float(s) / segments
		var a1 := TAU * float(s + 1) / segments
		var v0 := Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
		var v1 := Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
		var tri := [c, v0, v1] if dir > 0 else [c, v1, v0]
		for v in tri:
			st.set_normal(Vector3(0, dir, 0)); st.set_uv(Vector2(v.x, v.z)); st.add_vertex(v)

static func cylinder(radius: float, height: float, segments := 16, bevel := 0.0) -> ArrayMesh:
	var pr := PackedVector2Array()
	var hh := height * 0.5
	if bevel > 0.0:
		pr.append_array([Vector2(radius - bevel, -hh), Vector2(radius, -hh + bevel), Vector2(radius, hh - bevel), Vector2(radius - bevel, hh)])
	else:
		pr.append_array([Vector2(radius, -hh), Vector2(radius, hh)])
	return lathe(pr, segments, true, true, bevel > 0.0)

## Tubo que segue uma polilinha (tubulações, corrimãos, cabos). Cotovelos suavizados.
static func pipe(points: PackedVector3Array, radius: float, segments := 10, closed_caps := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var prev_side := Vector3.ZERO
	var along := 0.0
	var u_rep := maxf(1.0, roundf(TAU * radius * 2.0)) * 0.5
	for i in points.size():
		var fwd: Vector3
		if i == 0: fwd = (points[1] - points[0]).normalized()
		elif i == points.size() - 1: fwd = (points[i] - points[i - 1]).normalized()
		else: fwd = ((points[i] - points[i - 1]).normalized() + (points[i + 1] - points[i]).normalized()).normalized()
		if i > 0:
			along += points[i].distance_to(points[i - 1])
		var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var side := fwd.cross(up).normalized()
		if prev_side != Vector3.ZERO and side.dot(prev_side) < 0:
			side = -side
		prev_side = side
		var up2 := side.cross(fwd).normalized()
		var ring := []
		for s in segments + 1:
			var a := TAU * float(s) / segments
			var nrm := (side * cos(a) + up2 * sin(a))
			ring.append([points[i] + nrm * radius, nrm, Vector2(float(s) / segments * u_rep, along)])
		rings.append(ring)
	for i in rings.size() - 1:
		for s in segments:
			var q := [rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][1]); st.set_uv(q[idx][2]); st.add_vertex(q[idx][0])
	st.generate_tangents()
	return st.commit()

## Abóbada / arco de berço (tetos de estação, túneis). Eixo do arco = Z.
static func vault(width: float, rise: float, length: float, thickness := 0.3, segments := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hl := length * 0.5
	for side: float in [1.0, -1.0]:  # interno (normal para dentro) e externo
		var rad_off := 0.0 if side > 0 else thickness
		for s in segments:
			var a0 := PI * float(s) / segments
			var a1 := PI * float(s + 1) / segments
			var p0 := Vector3(cos(a0) * (hw + rad_off), sin(a0) * (rise + rad_off), 0)
			var p1 := Vector3(cos(a1) * (hw + rad_off), sin(a1) * (rise + rad_off), 0)
			var n0 := -Vector3(cos(a0) / hw, sin(a0) / rise, 0).normalized() * side
			var n1 := -Vector3(cos(a1) / hw, sin(a1) / rise, 0).normalized() * side
			var q := [[p0 + Vector3(0, 0, -hl), n0, a0], [p1 + Vector3(0, 0, -hl), n1, a1], [p1 + Vector3(0, 0, hl), n1, a1], [p0 + Vector3(0, 0, hl), n0, a0]]
			var order := [0, 2, 1, 0, 3, 2] if side > 0 else [0, 1, 2, 0, 2, 3]
			for idx in order:
				st.set_normal(q[idx][1]); st.set_uv(Vector2(q[idx][0].z, q[idx][2] * (hw + rise) * 0.5)); st.add_vertex(q[idx][0])
	st.generate_tangents()
	return st.commit()

static func stairs(width: float, steps: int, step_h: float, step_d: float) -> ArrayMesh:
	var parts := []
	for i in steps:
		var sz := Vector3(width, step_h * (i + 1), step_d)
		parts.append([bevel_box(sz, 0.015, 1), Transform3D(Basis(), Vector3(0, sz.y * 0.5, -step_d * (i + 0.5)))])
	return combine(parts)

## Malha plana subdividida com ruído de altura (terrenos, leito marinho).
static func terrain(size: Vector2, res: int, height_fn: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in res:
		for x in res:
			var pts := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var px := (float(x + d[0]) / res - 0.5) * size.x
				var pz := (float(z + d[1]) / res - 0.5) * size.y
				pts.append(Vector3(px, height_fn.call(px, pz), pz))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(pts[idx].x, pts[idx].z)); st.add_vertex(pts[idx])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

# ---------------- combinação e LOD ----------------

## Combina [[mesh, transform], ...] num único ArrayMesh de superfície única.
static func combine(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var m: Mesh = p[0]
		for s in m.get_surface_count():
			st.append_from(m, s, p[1])
	st.generate_tangents()
	return st.commit()

## Combina peças agrupadas por material: {material: [[mesh, xform], ...]} -> ArrayMesh multi-superfície.
static func combine_by_material(groups: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	for mat in groups:
		var m := combine(groups[mat])
		if m.get_surface_count() == 0:
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out

## Gera níveis de detalhe automáticos (simplificação por meshoptimizer interno do Godot).
static func with_lods(mesh: ArrayMesh) -> ArrayMesh:
	if not ClassDB.class_exists("ImporterMesh"):
		return mesh
	var im := ImporterMesh.new()
	for s in mesh.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s))
	im.generate_lods(25.0, 60.0, [])
	var res := im.get_mesh()
	return res if res and res.get_surface_count() > 0 else mesh
