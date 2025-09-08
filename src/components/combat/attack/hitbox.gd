extends Area2D
class_name Hitbox

@export var attack_data: AttackData
@export var lifetime: float = 0.2
@export var enable_lifetime: bool = false
var a_owner: Node

func _ready() -> void:
	add_to_group("hitbox")
	connect("area_entered", _on_area_entered)

	if a_owner == null:
		a_owner = get_parent()

	if enable_lifetime:
		await get_tree().create_timer(lifetime, false).timeout
		if is_instance_valid(self):
			queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox") and area.has_method("apply_damage"):
		var hurt_owner = area.get_parent()

		if a_owner != null and hurt_owner == a_owner:
			return

		if a_owner and hurt_owner and a_owner.has_method("get_faction") and hurt_owner.has_method("get_faction"):
			if a_owner.get_faction() == hurt_owner.get_faction():
				return

		var src = a_owner if a_owner != null else self
		area.apply_damage(attack_data, src)
