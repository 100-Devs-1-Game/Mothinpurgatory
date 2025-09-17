extends Node

var sm
var player
var timer = 0.0

const CANCEL_LOCKOUT := 0.03
const EARLY_CANCEL_COOLDOWN_MULTIPLIER := 1.5
var _cancel_left := 0.0
var _dash_dir := 1

const DASH = preload("res://audio/ambience/dash.wav")

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	player.play_sfx(DASH)
	player.set_hurtbox(true)
	timer = player.stats.dash_time
	sm.set_cooldown("Dash", player.stats.dash_cooldown)

	var r := Input.get_action_strength("right")
	var l := Input.get_action_strength("left")
	if r > l:
		_dash_dir = -1
	elif l > r:
		_dash_dir = 1
	else:
		_dash_dir = player._facing

	player.set_facing(_dash_dir)

	player.velocity = Vector2(_dash_dir * player.stats.dash_speed, 0.0)
	player.get_node("Animator").play("dash")
	player.emit_signal("dash_started", player.stats.dash_time)
	_cancel_left = CANCEL_LOCKOUT

func update(delta: float) -> void:
	player.velocity.x = _dash_dir * player.stats.dash_speed
	player.velocity.y = 0.0
	player.emit_signal("dash_updated", timer, player.stats.dash_time)

	if _cancel_left > 0.0:
		_cancel_left -= delta
	elif Input.is_action_just_pressed("attack"):
		early_exit()
		return

	timer -= delta
	if timer <= 0.0:
		player.set_hurtbox(false)
		if not player.is_on_floor():
			sm.change_state("Air")
		else:
			sm.change_state("Idle")
		player.emit_signal("dash_ended")
		player.velocity.y = 0.0

func early_exit() -> void:
	sm.set_cooldown("Dash", player.stats.dash_cooldown * EARLY_CANCEL_COOLDOWN_MULTIPLIER)

	player.set_hurtbox(false)
	player.emit_signal("dash_ended")

	player.velocity.x = 0.0
	player.velocity.y = 0.0

	var want_up := Input.is_action_pressed("jump")

	if want_up:
		player.set_meta("force_attack_up", true)

		if player.has_jump_buffer() and player.can_coyote_jump():
			sm.change_state("Jump")
			sm.change_state("Attack")
			return

	sm.change_state("Attack")

func exit() -> void:
	pass
