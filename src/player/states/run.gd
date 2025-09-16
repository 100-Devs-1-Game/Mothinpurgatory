# RunState.gd
extends Node

var sm
var player
var started := false
var landing := false

const BASE_STRIDE_PX := 84.0

var _dist_accum := 0.0
var _prev_pos := Vector2.ZERO

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	started = false
	landing = false
	_dist_accum = 0.0
	_prev_pos = player.global_position

	if sm.previous_state_name in ["Air", "Jump"]:
		landing = true
		if player.animator:
			player.animator.play("land")
	else:
		if player.animator:
			player.animator.play("run_start")

func update(_delta: float) -> void:
	var x_input := Input.get_action_strength("right") - Input.get_action_strength("left")

	if not player.has_knockback_control():
		player.velocity.x = x_input * player.stats.move_speed

	# Facing
	if x_input > 0:
		player.set_facing(-1)
	elif x_input < 0:
		player.set_facing(1)

	if player.has_jump_buffer() and player.can_coyote_jump():
		sm.change_state("Jump")
		return

	if not player.is_on_floor():
		sm.change_state("Air")
		return
	
	if player.animator and not player.animator.is_playing():
		if landing:
			landing = false
			player.animator.play("run")
			started = true
		elif not started:
			started = true
			player.animator.play("run")

	if player.is_on_floor() and not landing:
		var now_pos = player.global_position
		_dist_accum += (now_pos - _prev_pos).length()
		_prev_pos = now_pos

		var stride := BASE_STRIDE_PX
		while _dist_accum >= stride:
			_dist_accum -= stride
			player.play_step_sfx()

	if x_input == 0 and started and not landing:
		sm.change_state("Idle")
		return

	if Input.is_action_just_pressed("attack") and sm.is_ready("Attack"):
		sm.change_state("Attack")
		return
	if Input.is_action_just_pressed("dash") and sm.is_ready("Dash"):
		sm.change_state("Dash")
		return

func exit() -> void:
	pass
