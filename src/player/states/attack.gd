extends Node

var sm
var player

var air_gravity_scale := 0.65
var ground_brake := 3000.0
var air_stall_time := 0.02
var air_stall_timer := 0.0
var stall_lockout := 0.15
var stall_lock := 0.0

enum Phase { WINDUP, ACTIVE, RECOVERY }
var phase = Phase.WINDUP
var timer = 0.0

func init(p_sm, p_player):
	sm = p_sm
	player = p_player

func enter() -> void:
	air_stall_timer = 0.0
	if not player.is_on_floor() and not player.air_stall_used and stall_lock <= 0.0:
		air_stall_timer = air_stall_time
		player.air_stall_used = true
		stall_lock = stall_lockout

	sm.set_cooldown("attack", player.stats.attack_cooldown)
	phase = Phase.WINDUP
	timer = player.stats.attack_windup
	player.get_node("Animator").play("attack")
	_spawn_slash()

func update(delta) -> void:
	stall_lock = max(stall_lock - delta, 0.0)

	if player.is_on_floor():
		player.velocity.x = move_toward(player.velocity.x, 0.0, ground_brake * delta)
	else:
		if air_stall_timer > 0.0:
			air_stall_timer -= delta
			player.velocity.y = 0.0
		else:
			if player.velocity.y < 0.0 and Input.is_action_pressed("jump"):
				player.velocity.y += player.stats.gravity_up * air_gravity_scale * delta
			else:
				player.velocity.y += player.stats.gravity_down * air_gravity_scale * delta

	timer -= delta
	if phase == Phase.WINDUP and timer <= 0.0:
		phase = Phase.ACTIVE
		timer = player.stats.attack_active
	elif phase == Phase.ACTIVE and timer <= 0.0:
		phase = Phase.RECOVERY
		timer = player.stats.attack_recovery
	elif phase == Phase.RECOVERY and timer <= 0.0:
		if player.is_on_floor():
			sm.change_state("Idle")
		else:
			sm.change_state("Air")

func exit() -> void:
	pass

func _spawn_slash():
	var slash: AnimatedSprite2D = preload("res://components/effects/slash_effect.tscn").instantiate()
	player.add_child(slash)
	var offset = Vector2(120.0 * float(-player._facing), -26.0)
	slash.position = offset
	slash.scale = Vector2(0.85, 0.85)
	slash.flip_h = (player._facing < 0)
	slash.z_index = 10
	slash.play("slash_b")
