extends CharacterBody2D

@export var enemy_data: EnemyData
@export var speed: float = 180.0
@export var death_effect: PackedScene
@export var death_sound: AudioStream

var player: Node2D
var world: Node2D

func _ready() -> void:
	$Sprite2D.play("default")
	player = get_tree().get_first_node_in_group("Player")
	world = get_tree().get_first_node_in_group("World")
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

func create_effect() -> void:
	if death_effect:
		var de = death_effect.instantiate()
		get_tree().get_first_node_in_group("game").add_child(de)
		de.play("fly")
		de.global_position = global_position
	else:
		push_warning("There is no set death effect, add one in the export.")

func create_death_sound(audio: AudioStream) -> void:
	if audio == null: return
	var ap = AudioStreamPlayer2D.new()
	ap.pitch_scale = randf_range(0.85, 1.15)
	world.add_child(ap)
	ap.global_position = self.global_position
	ap.set_stream(audio)
	ap.play()

func _death(source: Node) -> void:
	create_effect()
	create_death_sound(death_sound)
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	EventBus.emit_signal("bug_killed")
	queue_free()
