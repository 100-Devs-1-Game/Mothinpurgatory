extends CharacterBody2D

@export var enemy_data: EnemyData
@export var speed: float = 180.0

var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	if enemy_data:
		speed = enemy_data.speed

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	var dir = (player.global_position - global_position).normalized()
	
	velocity = dir * speed
	move_and_slide()

func get_faction() -> int:
	return enemy_data.interactable_faction

func _death(source: Node) -> void:
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	queue_free()
