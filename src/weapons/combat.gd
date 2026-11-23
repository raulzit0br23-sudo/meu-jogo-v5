class_name Combat
extends RefCounted
## Encaminha dano para qualquer alvo (inimigos, jogador, props quebráveis/explosivos)
## e aplica impulso físico em corpos rígidos atingidos.

static func apply_hit(target: Object, damage: float, pos: Vector3, dir: Vector3, source: Node = null, type := "bullet") -> void:
	if target == null or not is_instance_valid(target):
		return
	var t: Object = target
	var dmg_ok := func(o: Object) -> bool: return o.has_method("take_damage") or o.has_method("take_hit")
	if not dmg_ok.call(t) and t is Node and t.get_parent() and dmg_ok.call(t.get_parent()):
		t = t.get_parent()
	if t is RigidBody3D and type != "explosion":
		(t as RigidBody3D).apply_impulse(dir.normalized() * clampf(damage * 0.12, 0.2, 6.0), pos - t.global_position)
	if t.has_method("take_hit"):
		t.take_hit(damage, pos, dir, source, type)
	elif t.has_method("take_damage"):
		if t is Player:
			t.take_damage(damage, source.global_position if source is Node3D else pos, type)
		else:
			t.take_damage(damage, pos, type)
