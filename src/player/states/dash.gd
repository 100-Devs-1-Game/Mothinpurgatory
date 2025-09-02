extends Node

var sm
var player
var timer = 0.0

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	timer = player.stats.dash_time
	sm.set_cooldown("dash", player.stats.dash_cooldown)
	player.velocity = Vector2(player._facing * player.stats.dash_speed, 0.0)
	player.get_node("Animator").play("dash")
	player.emit_signal("dash_started", player.stats.dash_time)

func update(delta: float) -> void:
	player.velocity.x = player._facing * player.stats.dash_speed
	player.velocity.y = 0.0
	player.emit_signal("dash_updated", timer, player.stats.dash_time)
	timer -= delta
	if timer <= 0.0:
		if not player.is_on_floor():
			sm.change_state("Air")
		else:
			sm.change_state("Idle")
		player.emit_signal("dash_ended")
		player.velocity.y = 0.0

func exit() -> void:
	pass
