extends CharacterBody2D

@export var speed: float = 60.0
@export var gravity: float = 800.0
@export var interactable_faction = 2
@export var enemy_data: EnemyData

var player: Node2D

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta: float) -> void:
	if not player:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	var dir_x = sign(player.global_position.x - global_position.x)
	velocity.x = dir_x * speed

	move_and_slide()

func get_faction() -> int:
	return interactable_faction

func _death(source: Node) -> void:
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	queue_free()
