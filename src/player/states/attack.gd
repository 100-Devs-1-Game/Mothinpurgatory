extends Node

var sm
var player

var air_gravity_scale := 0.65
var ground_brake := 3000.0
var air_stall_time := 0.02
var air_stall_timer := 0.0
var stall_lockout := 0.15
var stall_lock := 0.0

const CONE_ANGLE_DEG := 60.0
const CONE_RADIUS := 160.0
const CONE_SEGMENTS := 8

enum Phase { WINDUP, ACTIVE, RECOVERY }
var phase = Phase.WINDUP
var timer = 0.0

enum Dir { NEUTRAL, DOWN, UP }
var dir = Dir.NEUTRAL

const hitbox = preload("res://components/combat/attack/Hitbox.tscn")
var normal_attack_resource = preload("res://resources/combat/normal_attack.tres")

var slash_effect

func init(p_sm, p_player):
	sm = p_sm
	player = p_player
	slash_effect = player.slash_effect

func enter() -> void:
	air_stall_timer = 0.0
	if not player.is_on_floor() and not player.air_stall_used and stall_lock <= 0.0:
		air_stall_timer = air_stall_time
		player.air_stall_used = false
		stall_lock = stall_lockout

	sm.set_cooldown("attack", player.stats.attack_cooldown)
	phase = Phase.WINDUP
	timer = player.stats.attack_windup

	dir = Dir.NEUTRAL

	var jump_held = Input.is_action_pressed("jump")
	var down_held = Input.is_action_pressed("down")
	var left_held = Input.is_action_pressed("left")
	var right_held = Input.is_action_pressed("right")
	var moving_horizontally = false
	if left_held or right_held:
		moving_horizontally = true

	if jump_held:
		if down_held and not player.is_on_floor():
			dir = Dir.DOWN
		else:
			if moving_horizontally:
				dir = Dir.NEUTRAL
			else:
				dir = Dir.UP
	else:
		if down_held and not player.is_on_floor():
			dir = Dir.DOWN
		else:
			dir = Dir.NEUTRAL

	if dir == Dir.DOWN:
		player.get_node("Animator").play("attack down")
	elif dir == Dir.UP:
		player.get_node("Animator").play("attack up")
	else:
		player.get_node("Animator").play("attack")

	_spawn_slash()
	_spawn_hitbox()

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
	if slash_effect:
		var slash = slash_effect.instantiate()
		player.add_child(slash)

		if dir == Dir.DOWN:
			slash.position = Vector2(0.0, 90.0)
			slash.scale = Vector2(0.85, 0.85)
			slash.flip_h = false
			slash.z_index = 10
			slash.play("slash_down")

		elif dir == Dir.UP:
			slash.position = Vector2(0.0, -180.0)
			slash.scale = Vector2(0.85, 0.85)
			slash.flip_h = false
			slash.z_index = 10
			slash.play("slash_up")

		else:
			var offset = Vector2(120.0 * float(-player._facing), -26.0)
			slash.position = offset
			slash.scale = Vector2(0.85, 0.85)
			slash.flip_h = (player._facing < 0)
			slash.z_index = 10
			slash.play("slash_b")


func _spawn_hitbox():
	var hb = hitbox.instantiate()
	hb.enable_lifetime = true
	player.add_child(hb)
	hb.a_owner = player
	hb.attack_data = normal_attack_resource

	if dir == Dir.DOWN:
		hb.position = Vector2(0.0, 20.0)
		var poly_d = _make_cone_polygon(CONE_ANGLE_DEG, CONE_RADIUS, CONE_SEGMENTS, PI * 0.5)
		var cpd = CollisionPolygon2D.new()
		cpd.polygon = poly_d
		hb.add_child(cpd)

	elif dir == Dir.UP:
		hb.position = Vector2(0.0, -110.0)
		var poly_u = _make_cone_polygon(CONE_ANGLE_DEG, CONE_RADIUS, CONE_SEGMENTS, -PI * 0.5)
		var cpu = CollisionPolygon2D.new()
		cpu.polygon = poly_u
		hb.add_child(cpu)

	else:
		var offset = Vector2(40.0 * float(-player._facing), -40.0)
		hb.position = offset

		var poly_n = _make_cone_polygon(CONE_ANGLE_DEG, CONE_RADIUS, CONE_SEGMENTS, 0.0)
		var mirror = float(-player._facing)
		for i in range(poly_n.size()):
			poly_n[i].x *= mirror

		var cpn = CollisionPolygon2D.new()
		cpn.polygon = poly_n
		hb.add_child(cpn)


func _make_cone_polygon(angle_deg: float, radius: float, segments: int, angle_offset: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)

	var half = deg_to_rad(angle_deg) * 0.5
	var total = half * 2.0
	for i in range(segments + 1):
		var t = -half + (total * (float(i) / float(segments))) #this is hell
		var move_dir = Vector2(cos(t + angle_offset), sin(t + angle_offset))
		points.append(move_dir * radius)
	return points

func _rotate_polygon(poly: PackedVector2Array, angle: float) -> PackedVector2Array:
	var rotated = PackedVector2Array()
	for i in range(poly.size()):
		var p = poly[i]
		var rp = Vector2(
			p.x * cos(angle) - p.y * sin(angle),
			p.x * sin(angle) + p.y * cos(angle)
		)
		rotated.append(rp)
	return rotated
