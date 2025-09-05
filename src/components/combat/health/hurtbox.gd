extends Area2D

@export var health_node_path: NodePath
@export var hit: PackedScene
var health_component: Node

func _ready() -> void:
	add_to_group("hurtbox")
	health_component = get_node_or_null(health_node_path)

func apply_damage(attack_data: AttackData, source: Node) -> void:
	if source == get_parent():
		return

	if health_component:
		health_component.take_damage(attack_data, source)

	if attack_data and attack_data.damage > 0:
		if source and source.is_in_group("Player"):
			var hs = attack_data.hitstop_duration
			get_tree().call_group("game", "apply_hitstop", hs, 0.0)
			var h = hit.instantiate()
			get_tree().get_first_node_in_group("game").add_child(h)
			h.global_position = self.global_position

	var owner_node = get_parent()
	if owner_node:
		if owner_node.has_method("enter_hitstun") and attack_data.hitstun > 0.0:
			owner_node.enter_hitstun(attack_data.hitstun)
