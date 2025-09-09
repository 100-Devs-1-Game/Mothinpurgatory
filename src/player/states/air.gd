extends Node

var sm
var player

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	if player.animator:
		if player.velocity.y >= 0.0:
			player.animator.play("jump")

func update(delta: float) -> void:
	var x_input = Input.get_action_strength("right") - Input.get_action_strength("left")
	if not player.has_knockback_control():
		player.velocity.x = x_input * player.stats.move_speed

	if x_input > 0:
		player.set_facing(-1)
	elif x_input < 0:
		player.set_facing(1)

	if player.velocity.y < 0.0:
		if Input.is_action_just_released("jump"):
			player.velocity.y *= player.stats.short_hop_multiplier
		elif Input.is_action_pressed("jump"):
			player.velocity.y += player.stats.gravity_up * delta
		else:
			player.velocity.y += player.stats.gravity_down * delta
	else:
		player.velocity.y += player.stats.gravity_down * delta

	if player.is_on_floor():
		if player.has_jump_buffer():
			sm.change_state("Jump")
			return
		if x_input == 0:
			sm.change_state("Idle")
		else:
			sm.change_state("Run")
		return

	if Input.is_action_just_pressed("jump") or player.has_jump_buffer():
		sm.change_state("Jump")
		return

	if Input.is_action_just_pressed("attack") and sm.is_ready("Attack"):
		sm.change_state("Attack")
		return
	if Input.is_action_just_pressed("dash") and sm.is_ready("Dash"):
		sm.change_state("Dash")
		return

func exit() -> void:
	pass
