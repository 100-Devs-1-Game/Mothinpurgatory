extends CharacterBody2D

@warning_ignore("unused_signal")
signal state_changed(new_state: String)
@warning_ignore("unused_signal")
signal dash_started(total_time: float)
@warning_ignore("unused_signal")
signal dash_updated(remaining_time: float, total_time: float)
@warning_ignore("unused_signal")
signal dash_ended()
signal player_died

@export var stats: PlayerStats
@export var animator_path: NodePath
@export var slash_effect: PackedScene
@export var hurtbox_collision: CollisionShape2D

@onready var animator: AnimatedSprite2D = get_node(animator_path)
@onready var sm: Node = $StateMachine

var interactable_faction = 0
var _facing := 1
var _invincible := 0.0
var _coyote := 0.5
var _jump_buffer := 0.0
var _jumps_max := 1
var _jumps_left := 1
var was_on_floor := false
var air_stall_used := false

func _ready() -> void:
	_recompute_jump_caps()
	_reset_jumps_on_ground(true)
	sm.init(self)
	if animator:
		animator.play("idle")

func _physics_process(delta: float) -> void:
	_update_common_timers(delta)
	if Input.is_action_just_pressed("jump"):
		if _jumps_left > 0:
			buffer_jump()
	sm.update(delta)
	move_and_slide()

func has_jump_buffer() -> bool:
	return _jump_buffer > 0.0

func consume_jump_buffer() -> void:
	_jump_buffer = 0.0

func buffer_jump() -> void:
	_jump_buffer = stats.jump_buffer_time

func can_coyote_jump() -> bool:
	return (_coyote > 0.0 and not is_on_floor()) or is_on_floor()

func consume_ground_or_coyote_jump() -> bool:
	if is_on_floor() and _jumps_left > 0:
		_jumps_left -= 1
		return true
	elif _coyote > 0.0 and _jumps_left > 0:
		_jumps_left -= 1
		_coyote = 0.0
		return true
	return false

func can_double_jump() -> bool:
	if not stats.enable_double_jump:
		return false
	if _jumps_left <= 0:
		return false
	if stats.allow_second_jump_from_ground:
		return true
	return not is_on_floor()

func consume_double_jump() -> void:
	if _jumps_left > 0:
		_jumps_left -= 1

func has_animator() -> bool:
	if animator:
		return true
	else:
		return false

func set_facing(dir: int) -> void:
	if dir != 0:
		_facing = dir
		if animator:
			animator.flip_h = _facing > 0

func set_hurtbox(state: bool) -> void:
	hurtbox_collision.disabled = state

func refresh_landing() -> void:
	_reset_jumps_on_ground(true)

func _update_common_timers(delta: float) -> void:
	var grounded = is_on_floor()
	if grounded and not was_on_floor:
		_coyote = stats.coyote_time
		_reset_jumps_on_ground(true)
		_jump_buffer = 0.0
		air_stall_used = false
	elif not grounded:
		_coyote = max(_coyote - delta, 0.0)
	_jump_buffer = max(_jump_buffer - delta, 0.0)
	_invincible = max(_invincible - delta, 0.0)
	was_on_floor = grounded

func _recompute_jump_caps() -> void:
	if stats.enable_double_jump:
		_jumps_max = 2
	else:
		_jumps_max = 1

func _reset_jumps_on_ground(full: bool) -> void:
	if full:
		_jumps_left = _jumps_max
	else:
		_jumps_left = 0

func _death(_source: Node) -> void:
	emit_signal("player_died")
	EventBus.player_died.emit()

func _notify_damage() -> void:
	print("player sent hit signal")
	EventBus.player_damaged.emit()

func apply_knockback(kb: Vector2, _attack_data: AttackData, _source: Node) -> void:
	print("knocked back")
	velocity += kb

func get_faction() -> int:
	return interactable_faction
