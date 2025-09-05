extends Node2D

@export var life_time: float = 3.0
@export var speed: float = 520.0
@export var attack_data: AttackData

var dir := Vector2.ZERO
var owner_ref: Node

func setup(owner: Node, origin: Vector2, direction: Vector2, proj_speed: float, _faction_unused := 0) -> void:
	owner_ref = owner
	global_position = origin
	dir = direction.normalized()
	speed = proj_speed

	var hb: Hitbox = get_node_or_null("Hitbox")
	if hb:
		hb.a_owner = owner_ref
		if attack_data:
			hb.attack_data = attack_data

func _ready() -> void:
	if life_time > 0.0:
		despawn_later(life_time)

func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta

func despawn_later(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(self):
		queue_free()
