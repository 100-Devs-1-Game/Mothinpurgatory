extends CharacterBody2D

@export var enemy_data: EnemyData
@export var move_speed_override: float = -1.0

@export var windup_time: float = 0.35
@export var attack_duration: float = 0.10
@export var attack_cooldown: float = 0.80

@export var shoot_range: float = 360.0
@export var y_tolerance: float = 48.0
@export var shoot_offset_y: float = -24.0

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 520.0

@export var knockback_drag: float = 2200.0
@export var knockback_resistance: float = 0.0
@export var knockup_gravity_scale: float = 1.0
@export var min_pop_window: float = 0.06
@export var max_kb_speed_x: float = 900.0


@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var status_label: Label = get_node_or_null("status")

var player: Node2D = null
var default_speed: float = 0.0
var speed: float = 0.0

var can_attack: bool = true
var is_winding_up: bool = false
var is_shooting: bool = false
var in_cooldown: bool = false

var external_velocity := Vector2.ZERO
var hitstun_timer := 0.0
var pop_off_floor_timer := 0.0

func _ready() -> void:
	if sprite != null:
		sprite.play("walk")

	player = get_tree().get_first_node_in_group("Player")

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

	var g: float = enemy_data.gravity
	if velocity.y < 0.0:
		g = enemy_data.gravity * knockup_gravity_scale

	if pop_off_floor_timer > 0.0:
		pop_off_floor_timer -= delta
		velocity.y += g * delta
	else:
		if is_on_floor() == false:
			velocity.y += g * delta
		else:
			velocity.y = 0.0

	if external_velocity.x != 0.0:
		var decel = sign(external_velocity.x) * knockback_drag * delta
		if abs(decel) >= abs(external_velocity.x):
			external_velocity.x = 0.0
		else:
			external_velocity.x -= decel

	if hitstun_timer > 0.0:
		hitstun_timer -= delta

	if hitstun_timer <= 0.0:
		_try_begin_attack()

	var base_vx: float = 0.0
	if is_winding_up == false and is_shooting == false:
		var dir_x: int = sign(player.global_position.x - global_position.x)
		base_vx = dir_x * speed
		_face_dir(dir_x)
		if _is_in_range() == false:
			if sprite != null:
				sprite.play("walk")
			_update_status("State: Walking")
		else:
			_update_status("State: Waiting")
		if _is_in_range() == true:
			base_vx = 0.0
	else:
		base_vx = 0.0

	var move_vx: float = base_vx
	var final_vx: float = move_vx + external_velocity.x
	velocity.x = final_vx

	move_and_slide()


func _is_in_range() -> bool:
	if player == null:
		return false
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = abs(player.global_position.y - global_position.y)
	if dx <= shoot_range and dy <= y_tolerance:
		return true
	return false

func _try_begin_attack() -> void:
	if _is_in_range() == false:
		return
	if can_attack == false:
		return
	if is_shooting == true:
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
	is_shooting = false
	in_cooldown = false

	var dir_x: int = sign(player.global_position.x - global_position.x)
	if dir_x == 0:
		dir_x = 1
	_face_dir(dir_x)
	_update_status("State: Windup")
	if sprite != null:
		if sprite.has_animation("shoot"):
			sprite.play("shoot")
		else:
			sprite.play("attack")

	var windup_timer = get_tree().create_timer(windup_time)
	await windup_timer.timeout

	is_winding_up = false
	is_shooting = true
	_update_status("State: Shooting")

	_spawn_spit()

	var active_timer = get_tree().create_timer(attack_duration)
	await active_timer.timeout

	is_shooting = false
	in_cooldown = true
	_update_status("State: Cooldown")

	var cd_timer = get_tree().create_timer(attack_cooldown)
	await cd_timer.timeout

	in_cooldown = false
	can_attack = true

func _spawn_spit() -> void:
	if projectile_scene == null:
		return

	var dir_x: int = sign(player.global_position.x - global_position.x)
	if dir_x == 0:
		dir_x = 1
	_face_dir(dir_x)

	var offset_x: float = 16.0
	var origin: Vector2 = global_position + Vector2(offset_x * dir_x, shoot_offset_y)

	var p: Node = projectile_scene.instantiate()
	if p.has_method("setup"):
		p.setup(self, origin, Vector2(dir_x, 0.0), projectile_speed, enemy_data.interactable_faction)
	else:
		if p is Node2D:
			(p as Node2D).global_position = origin
		if p.has_method("set_direction"):
			p.set_direction(Vector2(dir_x, 0.0))
		elif p.has_method("launch"):
			p.launch(Vector2(dir_x, 0.0))
		elif p.has_method("set_facing"):
			p.set_facing(dir_x)

	get_tree().current_scene.add_child(p)


func _death(source: Node) -> void:
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	queue_free()

func _update_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _face_dir(dir_x: int) -> void:
	if sprite == null:
		return
	if dir_x < 0:
		sprite.flip_h = false
	elif dir_x > 0:
		sprite.flip_h = true

func apply_knockback(_source: Node, kb: Vector2) -> void:
	var mult = 1.0 - clamp(knockback_resistance, 0.0, 1.0)

	var kx = kb.x * mult
	external_velocity.x = clamp(external_velocity.x + kx, -max_kb_speed_x, max_kb_speed_x)

	var vy = kb.y * mult
	if vy < 0.0:
		pop_off_floor_timer = max(pop_off_floor_timer, min_pop_window)
	velocity.y = min(velocity.y, vy)
