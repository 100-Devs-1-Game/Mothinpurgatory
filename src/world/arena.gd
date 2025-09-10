extends Node2D

var elapsed := 0.0
var running := false

var score := 0
var time_score_bonus := 200
var last_minute_checked := 0

var kill_score := 100
var total_kills := 0

var _score_tween: Tween
const FLASH_SCALE := Vector2(1.15, 1.15)
const FLASH_UP_TIME := 0.08
const FLASH_DOWN_TIME := 0.15
const FLASH_COLOR := Color(1, 1, 0)
const NORMAL_COLOR := Color(1, 1, 1)


@export var time_label: Label
@export var score_label: Label
@export var player: CharacterBody2D
@export var enemy_scene: PackedScene

@export var gnat_scene: PackedScene
@export var gnat_base_spawn_interval: float = 3.0
@export var gnat_min_spawn_interval: float = 0.4
@export var gnat_ramp_per_minute: float = 0.9
@export var gnat_max_alive: int = 12
@export var gnat_burst_min: int = 1
@export var gnat_burst_max: int = 3

@export var retry_button: Button
@export var quit_button: Button

@export var base_spawn_interval: float = 12.0
@export var min_spawn_interval: float = 0.8
@export var ramp_per_minute: float = 1.7

@export var enemy_scenes: Array[PackedScene] = []
@export var use_weighted_spawn: bool = false
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()
@export var debug_testing := false

@onready var left_spawn: Marker2D  = $LeftSpawn
@onready var right_spawn: Marker2D = $RightSpawn
@onready var enemy_container: Node = $Enemies

var post_process_enabled := true
var _hitstop_depth := 0
var hitless_elapsed := 0.0
var hitless_last_minute := 0
var hitless_running := false
var game_over := false

func _ready() -> void:
	SceneLoader.current_scene = self
	EventBus.first_game.emit()
	add_to_group("game")
	$Background.play("default")
	retry_button.pressed.connect(retry)
	quit_button.pressed.connect(end_game)
	
	if not player:
		player = get_tree().get_first_node_in_group("Player")
	await get_tree().process_frame
	if player:
		player.connect("player_died", _game_over)

	if EventBus.has_signal("player_woke"):
		EventBus.player_woke.connect(_begin_game)

	if EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.connect(_on_player_damaged)

func _begin_game():
	$GameUI.visible = true
	reset_time()
	start_time()
	await get_tree().create_timer(2.0).timeout
	$GameUI/surv.visible = true
	await get_tree().create_timer(2.0).timeout
	$GameUI/surv.queue_free()

func _process(delta: float) -> void:
	if not running:
		return

	elapsed += delta
	if time_label:
		time_label.text = _format_time(elapsed)

	var current_minute = _whole_minutes(elapsed)
	if current_minute > last_minute_checked:
		var minutes_gained = current_minute - last_minute_checked
		EventBus.minute_passed.emit(minutes_gained)
		score += minutes_gained * time_score_bonus
		last_minute_checked = current_minute
		_update_score_label()

	if hitless_running:
		hitless_elapsed += delta
		var hl_minute = _whole_minutes(hitless_elapsed)
		if hl_minute > hitless_last_minute:
			var gained = hl_minute - hitless_last_minute
			hitless_last_minute = hl_minute
			EventBus.no_hit_minute_passed.emit(gained)

func show_ui(show: bool) -> void:
	$GameUI.visible = show

func _whole_minutes(t: float) -> int:
	@warning_ignore("integer_division")
	return int(t) / 60

func _format_time(t: float) -> String:
	@warning_ignore("integer_division")
	var m = int(t) / 60
	var s = int(t) % 60
	var ms = int(round((t - int(t)) * 1000.0))
	return "%02d:%02d.%03d" % [m, s, ms]

func start_time() -> void:
	running = true
	hitless_running = true
	if not debug_testing:
		_spawn_loop()
		_gnat_spawn_loop()

func stop_time() -> void:
	running = false
	hitless_running = false

func reset_time() -> void:
	elapsed = 0.0
	last_minute_checked = 0
	score = 0
	total_kills = 0
	hitless_elapsed = 0.0
	hitless_last_minute = 0
	if time_label:
		time_label.text = _format_time(elapsed)
	_update_score_label()

func _on_player_damaged() -> void:
	hitless_elapsed = 0.0
	hitless_last_minute = 0

func _update_score_label() -> void:
	if score_label:
		score_label.text = "Score: " + "%06d" % score
		_flash_score()

func _flash_score() -> void:
	if not score_label:
		return

	if _score_tween and _score_tween.is_running():
		_score_tween.kill()

	score_label.scale = Vector2.ONE
	score_label.modulate = NORMAL_COLOR

	_score_tween = create_tween()
	_score_tween.set_parallel(true)
	_score_tween.tween_property(score_label, "scale", FLASH_SCALE, FLASH_UP_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(score_label, "modulate", FLASH_COLOR, FLASH_UP_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_score_tween.set_parallel(false)
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, FLASH_DOWN_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_score_tween.tween_property(score_label, "modulate", NORMAL_COLOR, FLASH_DOWN_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func on_enemy_killed(points: int = kill_score) -> void:
	total_kills += 1
	score += points
	_update_score_label()

func apply_hitstop(duration: float = 0.06, timescale: float = 0.0) -> void:
	_hitstop_depth += 1
	Engine.time_scale = timescale
	await get_tree().create_timer(duration, false, true, true).timeout
	_hitstop_depth = max(0, _hitstop_depth - 1)
	if _hitstop_depth == 0:
		Engine.time_scale = 1.0

func _game_over():
	game_over = true
	stop_time()
	print("Player died, game over.")
	hitless_running = false
	await get_tree().create_timer(5.0).timeout
	$NewOver/Panel2/VBoxContainer/Panel/timelbl.text = "You survived for: " + (time_label.text if time_label else _format_time(elapsed))
	$NewOver/Panel2/VBoxContainer/Panel2/scorelbl.text = "Score: " + "%06d" % score
	$NewOver/Panel2/VBoxContainer/Panel3/killslbl.text = "Total Kills: " + "%06d" % total_kills
	$GameUI.visible = false
	$NewOver.visible = true
	$NewOver/GameoverAnim.play("fade")
	await $NewOver/GameoverAnim.animation_finished
	$NewOver/GameoverAnim.play("loop")

	var enemies = $Enemies
	if enemies:
		for i in range(enemies.get_child_count()):
			var child = enemies.get_child(i)
			if is_instance_valid(child):
				child.queue_free()


	EventBus.score_final.emit(score)

func _spawn_loop() -> void:
	while is_instance_valid(self) and !game_over:
		if running:
			_spawn_one()
			var wait_time = _ramped_interval(base_spawn_interval, ramp_per_minute, min_spawn_interval)
			await get_tree().create_timer(wait_time, false).timeout
		else:
			await get_tree().process_frame

func _gnat_spawn_loop() -> void:
	while is_instance_valid(self) and !game_over:
		if running:
			_spawn_gnat_burst()
			var wait_time = _ramped_interval(gnat_base_spawn_interval, gnat_ramp_per_minute, gnat_min_spawn_interval)
			await get_tree().create_timer(wait_time, false).timeout
		else:
			await get_tree().process_frame

func _ramped_interval(base_time: float, ramp: float, min_time: float) -> float:
	var minutes_alive = _whole_minutes(elapsed)
	var interval = base_time * pow(ramp, minutes_alive)
	if interval < min_time:
		interval = min_time
	return interval

func _pick_enemy_scene() -> PackedScene:
	if enemy_scenes.size() > 0:
		if use_weighted_spawn and spawn_weights.size() == enemy_scenes.size():
			var idx = _weighted_pick(spawn_weights)
			return enemy_scenes[idx]
		else:
			return enemy_scenes[randi() % enemy_scenes.size()]
	return enemy_scene

func _weighted_pick(weights: PackedFloat32Array) -> int:
	var total = 0.0
	for w in weights:
		total += max(0.0, w)
	if total <= 0.0:
		return randi() % max(1, weights.size())

	var roll = randf() * total
	var acc = 0.0
	for i in range(weights.size()):
		acc += max(0.0, weights[i])
		if roll <= acc:
			return i
	return weights.size() - 1

func _choose_spawn_point() -> Marker2D:
	var which_side = randi() % 2
	if which_side == 0:
		return left_spawn
	return right_spawn

func _flip_any_sprite(node: Node, flip_h: bool) -> void:
	if node.has_node("Sprite2D"):
		var s2d = node.get_node("Sprite2D")
		s2d.flip_h = flip_h
	elif node.has_node("AnimatedSprite2D"):
		var as2d = node.get_node("AnimatedSprite2D")
		as2d.flip_h = flip_h

func _spawn_into_container(node: Node) -> void:
	if is_instance_valid(enemy_container):
		enemy_container.add_child(node)
	else:
		add_child(node)

func _spawn_one() -> void:
	var scene_to_spawn = _pick_enemy_scene()
	if scene_to_spawn == null:
		return

	var spawn_point = _choose_spawn_point()
	var flip = false
	if spawn_point == right_spawn:
		flip = true

	var enemy = scene_to_spawn.instantiate()
	enemy.global_position = spawn_point.global_position
	_flip_any_sprite(enemy, flip)
	_spawn_into_container(enemy)

func _gnat_current_alive() -> int:
	var total = 0
	if is_instance_valid(enemy_container):
		for child in enemy_container.get_children():
			if child.is_in_group("Gnat"):
				total += 1
	else:
		for n in get_tree().get_nodes_in_group("Gnat"):
			if is_instance_valid(n):
				total += 1
	return total

func _spawn_one_gnat() -> void:
	if gnat_scene == null:
		return

	var spawn_point = _choose_spawn_point()
	var flip = false
	if spawn_point == right_spawn:
		flip = true

	var gnat = gnat_scene.instantiate()
	gnat.global_position = spawn_point.global_position
	_flip_any_sprite(gnat, flip)
	_spawn_into_container(gnat)

func _spawn_gnat_burst() -> void:
	if gnat_scene == null:
		return

	if gnat_max_alive > 0:
		var alive = _gnat_current_alive()
		if alive >= gnat_max_alive:
			return

	var count = randi_range(gnat_burst_min, gnat_burst_max)
	for i in count:
		if gnat_max_alive > 0 and _gnat_current_alive() >= gnat_max_alive:
			break
		_spawn_one_gnat()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_post"):
		post_process_enabled = not post_process_enabled
		$Enviroment.visible = post_process_enabled
		$Enviroment/CanvasLayer.visible = post_process_enabled

func end_game():
	EventBus.score_final.emit(score)
	SceneLoader.goto_title()

func retry():
	EventBus.score_final
	SceneLoader.goto_game()

func _exit_tree() -> void:
	EventBus.score_final.emit(score)
