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
@export var camera: Camera2D

@onready var animator: AnimatedSprite2D = get_node(animator_path)
@onready var sm: Node = $StateMachine

@export var footstep_sounds: Array[AudioStream] = []
@export var step_player: AudioStreamPlayer2D
@export var sfx_player: AudioStreamPlayer2D

const FOOTSTEP_01 = preload("res://audio/gameplay/footstep_01.wav")
const FOOTSTEP_02 = preload("res://audio/gameplay/footstep_02.wav")
const FOOTSTEP_03 = preload("res://audio/gameplay/footstep_03.wav")
const FOOTSTEP_04 = preload("res://audio/gameplay/footstep_04.wav")
const FOOTSTEP_05 = preload("res://audio/gameplay/footstep_05.wav")

var _knockback: Vector2 = Vector2.ZERO
var _knockback_time_left: float = 0.0
var _knockback_decay: float = 14.0

var last_step := -1
var interactable_faction = 0
var _facing := 1
var _invincible := 0.0
var _coyote := 0.5
var _jump_buffer := 0.0
var _jumps_max := 1
var _jumps_left := 1
var was_on_floor := false
var air_stall_used := false

var getting_up: bool = true
var is_dead: bool = false
var adjust_cam: bool = false

func _ready() -> void:
	if getting_up:
		await get_tree().create_timer(2.0).timeout
		adjust_cam = true
		await get_tree().create_timer(2.0).timeout
		animator.animation_finished.connect(_wake_player)
		animator.play("wake_up")
	while getting_up:
		await get_tree().create_timer(0.1).timeout
	_recompute_jump_caps()
	_reset_jumps_on_ground(true)
	sm.init(self)
	if animator:
		animator.play("idle")

func play_step_sfx() -> void:
	if footstep_sounds.is_empty():
		return
	var index = randi() % footstep_sounds.size()
	if footstep_sounds.size() > 1 and index == last_step:
		index = (index + 1) % footstep_sounds.size()
	last_step = index

	step_player.set_stream(footstep_sounds[index])
	step_player.pitch_scale = randf_range(0.93, 1.05)
	step_player.play()

func play_sfx(audio: AudioStream) -> void:
	sfx_player.set_stream(audio)
	sfx_player.play()

func adjust_camera(delta) -> void:
	if adjust_cam and getting_up:
		camera.position = lerp(camera.position, Vector2.ZERO, 0.04)
	elif is_dead:
		camera.offset = lerp(camera.offset, Vector2(15.0, 0.0), 0.04)
		camera.position = lerp(camera.position, Vector2.ZERO, 0.04)
		camera.zoom = lerp(camera.zoom, Vector2(0.912, 0.912), 0.04)

func _physics_process(delta: float) -> void:
	if !is_dead:
		adjust_camera(delta)
		_update_common_timers(delta)
		if Input.is_action_just_pressed("jump"):
			if _jumps_left > 0:
				buffer_jump()
		sm.update(delta)

		if _knockback_time_left > 0.0:
			_knockback_time_left = max(_knockback_time_left - delta, 0.0)
			_knockback = _knockback.move_toward(Vector2.ZERO, _knockback_decay * delta)
			velocity.x = _knockback.x
			if _knockback.y != 0.0:
				if _knockback.y < velocity.y:
					velocity.y = _knockback.y
	else:
		adjust_camera(delta)
		velocity.x = 0.0
		velocity.y = 150.0

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
	set_facing(-1)
	camera.limit_left = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 820
	EventBus.player_died.emit()
	is_dead = true
	animator.z_index = 30
	if animator:
		animator.play("dead")

func _wake_player():
	if getting_up:
		await get_tree().create_timer(2.0).timeout
		EventBus.player_woke.emit()
		getting_up = false

func _notify_damage() -> void: #Temporary, I'll improve it later
	EventBus.player_damaged.emit()
	print("Player taking damage")

func has_knockback_control() -> bool:
	return _knockback_time_left > 0.0

func apply_knockback(source: Node, kb: Vector2) -> void:
	_knockback = kb
	_knockback_time_left = 0.2
	if animator:
		animator.play("stun")

func get_faction() -> int:
	return interactable_faction
