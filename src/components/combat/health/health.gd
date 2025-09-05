extends Node
class_name Health

@export var max_health: int = 10
@export var overwrite_data: Resource
@export var tint_on_damage: bool = false

@export var apply_knockback_on_damage: bool = true
@export var knockback_resistance: float = 0.0
@export var only_knockback_if_alive: bool = true

var current_health: int
var declared_dead: bool = false

signal health_changed(new_value: int, max_value: int)
signal damaged(damage_data, source)

func _ready() -> void:
	if overwrite_data and "max_health" in overwrite_data:
		max_health = overwrite_data.max_health
	current_health = max_health

func take_damage(damage_data: AttackData, source: Node) -> void:
	if declared_dead:
		return

	var target := get_parent()

	current_health = clamp(current_health - damage_data.damage, 0, max_health)
	health_changed.emit(current_health, max_health)
	damaged.emit(damage_data, source)
	print(name, " took ", damage_data.damage, " damage. HP: ", current_health, "/", max_health)

	if tint_on_damage and target and target.has_node("Animator"):
		target.get_node("Animator").modulate = Color.RED
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(target) and target.has_node("Animator"):
			target.get_node("Animator").modulate = Color.WHITE

	if apply_knockback_on_damage and target and target.has_method("apply_knockback"):
		if current_health > 0 or not only_knockback_if_alive:
			var kb_mag = _extract_knockback(damage_data)
			if kb_mag != Vector2.ZERO:
				var attacker = _resolve_attacker_node2d(source)
				var tgt2d = target as Node2D
				var dir_x = 1.0
				if attacker and tgt2d:
					dir_x = _compute_dir_x(attacker, tgt2d)
				var final_kb = Vector2(dir_x * kb_mag.x, -kb_mag.y)
				var resist = 1.0 - clamp(knockback_resistance, 0.0, 1.0)
				target.apply_knockback(attacker if attacker else source, final_kb * resist)

	if target and target.has_method("enter_hitstun") and "hitstun" in damage_data and damage_data.hitstun > 0.0:
		target.enter_hitstun(damage_data.hitstun)

	if current_health == 0 and source:
		_notify_death(source)

func _extract_knockback(damage_data: AttackData) -> Vector2:
	var horiz = 0.0
	var up = 0.0
	if "knockback" in damage_data:
		var kbv = damage_data.knockback
		if typeof(kbv) == TYPE_VECTOR2:
			horiz = float(kbv.x)
			up = float(kbv.y)
		else:
			horiz = float(kbv)
	if "knockup" in damage_data:
		up = float(damage_data.knockup)
	return Vector2(max(0.0, horiz), max(0.0, up))

func _compute_dir_x(attacker: Node2D, target: Node2D) -> float:
	var dx = target.global_position.x - attacker.global_position.x
	if dx > 0.0:
		return 1.0
	if dx < 0.0:
		return -1.0
	var facing_x = sign(attacker.global_transform.x.x)
	return facing_x if facing_x != 0.0 else 1.0

func _resolve_attacker_node2d(src: Node) -> Node2D:
	var n = src
	while n and not (n is Node2D):
		n = n.get_parent()
	return n as Node2D

func _notify_death(source: Node) -> void:
	var target = get_parent()
	if target and target.has_method("_death"):
		target.call_deferred("_death", source)
		declared_dead = true
