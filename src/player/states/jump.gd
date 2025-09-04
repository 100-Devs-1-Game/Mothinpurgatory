extends Node

var sm
var player

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	if player.has_jump_buffer():
		player.consume_jump_buffer()
	
	var did_jump := false
	var consume_double := false
	
	if player.consume_ground_or_coyote_jump():
		player.velocity.y = -player.stats.jump_speed
		did_jump = true
	elif player.can_double_jump():
		player.consume_double_jump()
		consume_double = true
		player.velocity.y = -player.stats.second_jump_speed
		did_jump = true

	if did_jump and player.animator:
		if !consume_double:
			player.animator.frame = 0
			player.animator.play("jump")
		else:
			player.animator.play("double jump")

func update(delta: float) -> void:
	if player.velocity.y < 0:
		if Input.is_action_pressed("jump"):
			player.velocity.y += player.stats.gravity_up * delta
		else:
			player.velocity.y += player.stats.gravity_down * delta
	else:
		player.velocity.y += player.stats.gravity_down * delta

	if player.velocity.y > player.stats.max_fall_speed:
		player.velocity.y = player.stats.max_fall_speed

	var x_input = Input.get_action_strength("right") - Input.get_action_strength("left")
	player.velocity.x = x_input * player.stats.move_speed

	if x_input > 0:
		player.set_facing(-1)
	elif x_input < 0:
		player.set_facing(1)

	if player.is_on_floor():
		sm.change_state("Idle")
	elif Input.is_action_just_pressed("attack") and sm.is_ready("Attack"):
		sm.change_state("Attack")
	elif Input.is_action_just_pressed("dash") and sm.is_ready("Dash"):
		sm.change_state("Dash")
	elif not player.is_on_floor():
		sm.change_state("Air")

func exit() -> void:
	pass
