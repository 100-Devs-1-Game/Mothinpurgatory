extends CharacterBody2D

@export var enemy_data: EnemyData
@export var move_speed_override: float = -1.0
@export var attack_area: Area2D

@export var windup_time: float = 0.45
@export var attack_duration: float = 0.20
@export var attack_cooldown: float = 0.60
@export var lunge_speed: float = 360.0

@export var death_sound: AudioStream

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var status_label: Label = get_node_or_null("status")
@onready var attack_hitbox: Area2D = get_node_or_null("attack_hitbox")

@export var hurtbox: Area2D
@export var hitbox: Area2D
@onready var hit_shape: CollisionShape2D = null
@onready var hurt_shape: CollisionShape2D = null
@onready var range_shape: CollisionShape2D = null


var world: Node2D
var player: Node2D = null
var default_speed: float = 0.0
var speed: float = 0.0
var lunge_dir: int = 1

var player_in_range: bool = false

var can_attack: bool = true
var is_winding_up: bool = false
var is_attacking: bool = false
var in_cooldown: bool = false


var hit_base_x: float = 0.0
var hurt_base_x: float = 0.0
var range_base_x: float = 0.0

func _ready() -> void:
	if hitbox != null and hitbox.get_child_count() > 0 and hitbox.get_child(0) is CollisionShape2D:
		hit_shape = hitbox.get_child(0)
		hit_base_x = abs(hit_shape.position.x)
	if hurtbox != null and hurtbox.get_child_count() > 0 and hurtbox.get_child(0) is CollisionShape2D:
		hurt_shape = hurtbox.get_child(0)
		hurt_base_x = abs(hurt_shape.position.x)
	if attack_area != null and attack_area.get_child_count() > 0 and attack_area.get_child(0) is CollisionShape2D:
		range_shape = attack_area.get_child(0)
		range_base_x = abs(range_shape.position.x)

	if sprite != null:
		sprite.play("walk")

	player = get_tree().get_first_node_in_group("Player")
	world = get_tree().get_first_node_in_group("World")

	if attack_area != null:
		attack_area.body_entered.connect(_on_attack_area_entered)
		attack_area.body_exited.connect(_on_attack_area_exited)

	if move_speed_override > 0.0:
		default_speed = move_speed_override
	else:
		default_speed = enemy_data.speed
	speed = default_speed

	_update_status("State: Walking")

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return

	if default_speed == 0.0:
		if move_speed_override > 0.0:
			default_speed = move_speed_override
		else:
			default_speed = enemy_data.speed
		speed = default_speed

	var g = enemy_data.gravity
	if is_on_floor() == false:
		velocity.y += g * delta
	else:
		velocity.y = 0.0

	_try_begin_attack()

	var base_vx = 0.0
	if is_winding_up == true or is_attacking == true:
		base_vx = 0.0
	else:
		var dir_x = sign(player.global_position.x - global_position.x)
		base_vx = dir_x * speed
		_face_walk_dir(dir_x)
		if player_in_range == false:
			if sprite != null:
				sprite.play("walk")
			_update_status("State: Walking")
		else:
			_update_status("State: Waiting")

	if is_attacking == true:
		velocity.x = float(lunge_dir) * lunge_speed
	elif player_in_range == false:
		velocity.x = base_vx
	else:
		velocity.x = 0.0

	move_and_slide()

func _on_attack_area_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		player_in_range = true

func _on_attack_area_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player_in_range = false

func _try_begin_attack() -> void:
	if player_in_range == false:
		return
	if can_attack == false:
		return
	if is_attacking == true:
		return
	if is_winding_up == true:
		return
	if in_cooldown == true:
		return
	if is_on_floor() == false:
		return

	attack()

func attack() -> void:
	can_attack = false
	is_winding_up = true
	is_attacking = false
	in_cooldown = false

	var dir_x = sign(player.global_position.x - global_position.x)
	if dir_x == 0:
		dir_x = 1
	_face_attack_dir(dir_x)
	_update_status("State: Windup")
	if sprite != null:
		sprite.play("attack")
	lunge_dir = dir_x
	if lunge_dir == 0:
		lunge_dir = 1

	var windup_timer = get_tree().create_timer(windup_time, false)
	await windup_timer.timeout

	is_winding_up = false
	is_attacking = true
	_update_status("State: Attacking")

	if hitbox != null:
		hitbox.get_child(0).disabled = false
		hitbox.get_child(0).disabled = false

	var active_timer = get_tree().create_timer(attack_duration, false)
	await active_timer.timeout

	is_attacking = false
	in_cooldown = true
	_update_status("State: Cooldown")

	if hitbox != null:
		hitbox.get_child(0).disabled = true
		hitbox.get_child(0).disabled = true
	
	var cd_timer = get_tree().create_timer(attack_cooldown, false)
	await cd_timer.timeout

	in_cooldown = false
	can_attack = true

func _death(_source: Node):
	$AudioStreamPlayer2D.play()
	create_death_sound(death_sound)
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	await get_tree().create_timer(0.7).timeout
	queue_free()

func create_death_sound(audio: AudioStream) -> void:
	if audio == null: return
	var ap = AudioStreamPlayer2D.new()
	ap.pitch_scale = randf_range(0.85, 1.15)
	world.add_child(ap)
	ap.global_position = self.global_position
	ap.set_stream(audio)
	ap.play()

func _update_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _face_walk_dir(dir_x: int) -> void:
	if dir_x < 0:
		if sprite != null:
			sprite.flip_h = false
		_flip_shapes(-1)
	elif dir_x > 0:
		if sprite != null:
			sprite.flip_h = true
		_flip_shapes(1)

func _face_attack_dir(dir_x: int) -> void:
	if dir_x > 0:
		if sprite != null:
			sprite.flip_h = true
		_flip_shapes(1)
	elif dir_x < 0:
		if sprite != null:
			sprite.flip_h = false
		_flip_shapes(-1)

func _flip_shapes(sign_x: int) -> void:
	if hit_shape != null:
		hit_shape.position.x = hit_base_x * sign_x
	if hurt_shape != null:
		hurt_shape.position.x = hurt_base_x * sign_x
	if range_shape != null:
		range_shape.position.x = range_base_x * sign_x
