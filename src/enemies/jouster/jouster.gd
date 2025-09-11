extends CharacterBody2D

@export var enemy_data: EnemyData

@export var windup_time: float = 0.4
@export var charge_duration: float = 1.4
@export var charge_speed: float = 760.0
@export var charge_cooldown: float = 3.0
@export var charge_area: Area2D
@export var hit_col: CollisionShape2D

@export var knockback_drag: float = 2200.0
@export var knockback_resistance: float = 0.0
@export var knockup_gravity_scale: float = 1.0
@export var min_pop_window: float = 0.06

@export var max_kb_speed_x: float = 900.0

@export var bounce_count: int = 3
@export var bounce_speed: float = 220.0
@export var bounce_damping: float = 0.55
@export var bounce_pause: float = 0.05

@export var carry_duration: float = 0.35
@export var carry_initial_factor: float = 0.55
@export var carry_ease: float = 2.0
@export var carry_turn_lock_time: float = 0.15

@export var recover_lock_duration: float = 0.4
@export var standup_duration: float = 0.3

var player: Node2D
var player_in_range := false

var can_charge := false
var is_charging := false
var is_winding_up := false
var in_cooldown := false

var default_speed: float
var speed: float
var charge_dir_x := 0

var external_velocity := Vector2.ZERO
var hitstun_timer := 0.0
var pop_off_floor_timer := 0.0
var is_carrying := false
var carry_time := 0.0
var is_recover_locked := false
var recover_lock_time := 0.0
var is_standing_up := false

func _ready() -> void:
	await get_tree().process_frame
	$status.text = "State: Chasing"
	$AnimatedSprite2D.play("walk")
	default_speed = enemy_data.speed
	speed = default_speed
	player = get_tree().get_first_node_in_group("Player")
	_connect_regions()
	await get_tree().create_timer(2.0).timeout
	can_charge = true

func _connect_regions():
	charge_area.body_entered.connect(_on_chargerange_body_entered)
	charge_area.body_exited.connect(_on_chargerange_body_exited)

func _physics_process(delta: float) -> void:
	if not player:
		return

	var g_scale = 1.0
	if velocity.y < 0.0:
		g_scale = knockup_gravity_scale
	var g = enemy_data.gravity * g_scale

	if pop_off_floor_timer > 0.0:
		pop_off_floor_timer -= delta
		velocity.y += g * delta
	else:
		if not is_on_floor():
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
		is_winding_up = false
		is_charging = false
		is_carrying = false
		is_recover_locked = false
		is_standing_up = false
	else:
		_try_begin_charge()

	var base_vx = 0.0
	if hitstun_timer <= 0.0:
		if is_winding_up:
			$status.text = "State: Beginning charge"
			base_vx = 0.0
		elif is_charging:
			$status.text = "State: Charging"
			base_vx = charge_dir_x * charge_speed
		elif is_carrying:
			$status.text = "State: Recovering"
			carry_time += delta
			var t = clamp(carry_time / carry_duration, 0.0, 1.0)
			var factor = lerp(carry_initial_factor, 0.0, pow(t, carry_ease))
			base_vx = charge_dir_x * charge_speed * factor
			if carry_time >= carry_turn_lock_time:
				is_carrying = false
		elif is_recover_locked:
			$status.text = "State: Stunned"
			recover_lock_time += delta
			base_vx = 0.0
			if recover_lock_time >= recover_lock_duration:
				is_recover_locked = false
				is_standing_up = true
				recover_lock_time = 0.0
		elif is_standing_up:
			$status.text = "State: Standing up"
			base_vx = 0.0
		else:
			$status.text = "State: Chasing"
			var dir_x = sign(player.global_position.x - global_position.x)
			speed = default_speed
			base_vx = dir_x * speed
	else:
		$status.text = "State: Hitstun"

	velocity.x = base_vx + external_velocity.x

	move_and_slide()

	if has_node("AnimatedSprite2D"):
		var face_x = 0
		if is_charging or is_carrying or is_recover_locked or is_standing_up:
			if charge_dir_x != 0:
				face_x = charge_dir_x
			else:
				face_x = sign(velocity.x)
		else:
			face_x = sign(velocity.x)
		if face_x != 0:
			$AnimatedSprite2D.flip_h = face_x > 0

func _try_begin_charge() -> void:
	if not player_in_range: return
	if not can_charge: return
	if is_charging: return
	if is_winding_up: return
	if in_cooldown: return
	if not is_on_floor(): return
	charge()

func _wait_until_landed() -> void:
	while not is_on_floor():
		await get_tree().physics_frame
	await get_tree().physics_frame

func _do_bounce_sequence() -> void:
	var v = bounce_speed
	for i in range(bounce_count):
		if hitstun_timer > 0.0:
			return
		pop_off_floor_timer = max(pop_off_floor_timer, min_pop_window)
		velocity.y = -v
		await _wait_until_landed()
		if bounce_pause > 0.0:
			await get_tree().create_timer(bounce_pause).timeout
		v *= bounce_damping

func charge() -> void:
	is_winding_up = true
	is_charging = false
	in_cooldown = false
	can_charge = false
	animation_play("charge")

	charge_dir_x = sign(player.global_position.x - global_position.x)
	if charge_dir_x == 0:
		charge_dir_x = 1

	await get_tree().create_timer(windup_time).timeout
	if hitstun_timer > 0.0:
		return

	is_winding_up = false
	is_charging = true
	animation_play("joust")

	await get_tree().create_timer(charge_duration).timeout

	is_charging = false
	is_carrying = true
	carry_time = 0.0
	in_cooldown = true
	speed = default_speed
	animation_play("fallen")
	hit_col.disabled = true

	_do_bounce_sequence()

	await get_tree().create_timer(carry_duration).timeout
	is_carrying = false

	is_recover_locked = true
	recover_lock_time = 0.0
	await get_tree().create_timer(recover_lock_duration).timeout
	is_recover_locked = false

	is_standing_up = true
	animation_play("get_up")
	await get_tree().create_timer(standup_duration).timeout
	is_standing_up = false

	animation_play("walk")
	hit_col.disabled = false
	await get_tree().create_timer(charge_cooldown).timeout
	in_cooldown = false
	can_charge = true

func get_faction() -> int:
	return enemy_data.interactable_faction

func _death(_source: Node) -> void:
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	queue_free()

func _on_chargerange_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		player_in_range = true

func _on_chargerange_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player_in_range = false

func enter_hitstun(duration: float) -> void:
	hitstun_timer = max(hitstun_timer, duration)
	is_charging = false
	is_winding_up = false
	is_carrying = false
	is_recover_locked = false
	is_standing_up = false

func apply_knockback(_source: Node, kb: Vector2) -> void:
	var mult = 1.0 - clamp(knockback_resistance, 0.0, 1.0)
	var kx = kb.x * mult
	external_velocity.x = clamp(external_velocity.x + kx, -max_kb_speed_x, max_kb_speed_x)
	var vy = kb.y * mult
	if vy < 0.0:
		pop_off_floor_timer = max(pop_off_floor_timer, min_pop_window)
	velocity.y = min(velocity.y, vy)

func animation_play(anim: String) -> void:
	var s = get_node_or_null("AnimatedSprite2D")
	if s and s.sprite_frames and s.sprite_frames.has_animation(anim):
		s.play(anim)
	else:
		push_warning("No animation under this name.")
