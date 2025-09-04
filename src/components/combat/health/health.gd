extends Node
class_name Health

@export var max_health: int = 10
var current_health: int
var declared_dead: bool = false

signal health_changed(new_value: int, max_value: int)

func _ready() -> void:
	current_health = max_health

func take_damage(damage_data: AttackData, source: Node) -> void:
	if !declared_dead:
		current_health = clamp(current_health - damage_data.damage, 0, max_health)
		print(name, " took ", damage_data.damage, " damage. HP: ", current_health, "/", max_health)
		health_changed.emit(current_health, max_health)
		if current_health == 0:
			_notify_death(source)

func _notify_death(source: Node) -> void:
	var target := get_parent()
	if target and target.has_method("_death"):
		target.call_deferred("_death", source)
		declared_dead = true
