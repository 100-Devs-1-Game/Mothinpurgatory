extends CharacterBody2D

@export var enemy_data: EnemyData

@export var move_speed: float = 210.0
@export var accel: float = 9.0
@export var friction: float = 10.0
@export var hover_radius: float = 32.0
@export var hover_speed: float = 1.5
@export var keep_distance: float = 340.0
@export var orbit_speed: float = 140.0

@export var fire_range: float = 580.0

@export var windup_time: float = 0.45
@export var burst_count: int = 3
@export var time_between_shots: float = 0.11
@export var fire_cooldown: float = 1.4
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 520.0

@export var post_burst_dash: float = 120.0
@export var post_burst_time: float = 0.2

@export var y_floor_limit: float = 2000.0
@export var ground_clearance: float = 16.0
@export var must_be_above_player: bool = true
@export var above_player_margin: float = 48.0
@export var altitude_deadzone: float = 8.0
@export var altitude_smoothing: float = 6.0
@export var altitude_max_correction_speed: float = 160.0

@export var death_effect: PackedScene
@export var death_sound: AudioStream

var world: Node2D
var player: Node2D
var can_fire := true
var is_winding_up := false
var is_firing := false
var in_cooldown := false

var t := 0.0
var desired_vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	world = get_tree().get_first_node_in_group("World")
	if find_child("AnimatedSprite2D"):
		$AnimatedSprite2D.play("flying")
	if has_node("Status"):
		$Status.text = "State: Patrolling"
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if player == null:
		return

	t += delta

	var to_player = player.global_position - global_position
	var dist = to_player.length()

	var radial_dir = (to_player.normalized() if dist != 0.0 else Vector2.RIGHT)
	var radial_push = 0.0
	if dist < keep_distance * 0.9:
		radial_push = -1.0
	elif dist > keep_distance * 1.1:
		radial_push = 1.0

	var tangent = Vector2(-radial_dir.y, radial_dir.x) * orbit_speed
	var bob = Vector2(0.0, sin(t * PI * hover_speed) * hover_radius)
	var target_v = radial_dir * (move_speed * radial_push) + tangent + bob
	desired_vel = target_v

	var to_desired = desired_vel - velocity
	var step = accel * to_desired * delta
	velocity += step
	if desired_vel.length() < 1.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var y_cap = INF
	if must_be_above_player and player:
		y_cap = min(y_cap, player.global_position.y - above_player_margin)
	y_cap = min(y_cap, y_floor_limit - ground_clearance)

	var err = y_cap - global_position.y
	if abs(err) > altitude_deadzone:
		var desired_corr = clamp(err * altitude_smoothing,
			-altitude_max_correction_speed,
			altitude_max_correction_speed)
		velocity.y = lerp(velocity.y, desired_corr, 0.25)
	else:
		velocity.y = lerp(velocity.y, 0.0, 0.1)

	_try_begin_fire(dist)

	if has_node("Status"):
		if is_winding_up:
			$Status.text = "State: About to spit"
			$AnimatedSprite2D.play("charge")
		elif is_firing:
			$Status.text = "State: Spitting"
		elif in_cooldown:
			$Status.text = "State: Moving"
		else:
			$Status.text = "State: Hovering"

	move_and_slide()

	var floor_cap = y_floor_limit - ground_clearance
	if global_position.y > floor_cap:
		global_position.y = floor_cap
		if velocity.y > 0.0:
			velocity.y = 0.0

	if has_node("AnimatedSprite2D"):
		var face_x = sign(player.global_position.x - global_position.x)
		if face_x == 0:
			face_x = sign(velocity.x)
		if face_x != 0:
			$AnimatedSprite2D.flip_h = face_x > 0

func _try_begin_fire(dist: float) -> void:
	if not can_fire:
		return
	if is_winding_up or is_firing or in_cooldown:
		return
	if dist > fire_range:
		return
	_fire_sequence()

func _fire_sequence() -> void:
	is_winding_up = true
	can_fire = false
	in_cooldown = false
	is_firing = false

	_telegraph_begin()
	await get_tree().create_timer(windup_time, false).timeout
	$AnimatedSprite2D.play("spit")
	_telegraph_end()

	is_winding_up = false
	is_firing = true

	for i in range(burst_count):
		_spawn_spit()
		if i < burst_count - 1:
			await get_tree().create_timer(time_between_shots, false).timeout

	is_firing = false

	in_cooldown = true
	var away = Vector2.UP
	if is_instance_valid(player):
		away = (global_position - player.global_position).normalized()

	var dash_end = Time.get_ticks_msec() + int(post_burst_time * 1000.0)
	while Time.get_ticks_msec() < dash_end:
		velocity = velocity.move_toward(away * post_burst_dash, accel * get_physics_process_delta_time())
		move_and_slide()
		await get_tree().process_frame

	await get_tree().create_timer(fire_cooldown, false).timeout
	in_cooldown = false
	can_fire = true

func _spawn_spit() -> void:
	if projectile_scene == null:
		return

	var p: Node = projectile_scene.instantiate()
	p.position = Vector2(40.0, 0.0)
	var from = global_position
	var offset = Vector2(0.0, -25.0)
	var to = player.global_position + offset

	var aim_dir = (to - from).normalized()

	if p.has_method("setup"):
		p.setup(self, from, aim_dir, projectile_speed, enemy_data.interactable_faction)

	get_tree().current_scene.add_child(p)
	p.global_position = from

	$AnimatedSprite2D.play("flying")

func _telegraph_begin() -> void:
	if has_node("AnimatedSprite2D"):
		#$AnimatedSprite2D.modulate = Color(1, 0.85, 0.85)
		pass

func _telegraph_end() -> void:
	if has_node("AnimatedSprite2D"):
		#$AnimatedSprite2D.modulate = Color(1, 1, 1)
		pass

func get_faction() -> int:
	return enemy_data.interactable_faction

func create_effect() -> void:
	if death_effect:
		var de = death_effect.instantiate()
		get_tree().get_first_node_in_group("game").add_child(de)
		de.play("fly")
		de.global_position = global_position
	else:
		push_warning("There is no set death effect, add one in the export.")

func create_death_sound(audio: AudioStream) -> void:
	if audio == null: return
	var ap = AudioStreamPlayer2D.new()
	ap.pitch_scale = randf_range(0.85, 1.15)
	world.add_child(ap)
	ap.global_position = self.global_position
	ap.set_stream(audio)
	ap.play()

func _death(_source: Node) -> void:
	create_effect()
	create_death_sound(death_sound)
	get_tree().call_group("game", "on_enemy_killed", enemy_data.score_on_death)
	queue_free()
