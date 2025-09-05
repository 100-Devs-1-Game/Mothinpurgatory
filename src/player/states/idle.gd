extends Node

var sm
var player
var playing_enter := false
var landing := false

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	playing_enter = false
	landing = false
	player.velocity.x = 0.0

	if sm.previous_state_name in ["Air", "Jump"]:
		landing = true
		if player.animator:
			player.animator.play("land")
	else:
		playing_enter = true
		if player.animator:
			player.animator.play("idle enter")

func update(_delta: float) -> void:
	var x_input = Input.get_action_strength("right") - Input.get_action_strength("left")

	if player.has_jump_buffer() and player.can_coyote_jump():
		sm.change_state("Jump")
		return
	if not player.is_on_floor():
		sm.change_state("Air")
		return

	if landing and player.animator and not player.animator.is_playing():
		landing = false
		player.animator.play("idle")

	if playing_enter and player.animator and not player.animator.is_playing():
		playing_enter = false
		player.animator.play("idle")

	if playing_enter:
		if x_input != 0:
			sm.change_state("Run")
			return
		if Input.is_action_just_pressed("jump") and player.can_coyote_jump():
			sm.change_state("Jump")
			return
		if Input.is_action_just_pressed("attack") and sm.is_ready("Attack"):
			sm.change_state("Attack")
			return
		if Input.is_action_just_pressed("dash") and sm.is_ready("Dash"):
			sm.change_state("Dash")
			return

	if not landing and not playing_enter:
		if x_input != 0:
			sm.change_state("Run")
			return
		if Input.is_action_just_pressed("attack") and sm.is_ready("Attack"):
			sm.change_state("Attack")
			return
		if Input.is_action_just_pressed("dash") and sm.is_ready("Dash"):
			sm.change_state("Dash")
			return

func exit() -> void:
	pass
