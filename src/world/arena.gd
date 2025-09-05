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

var _hitstop_depth := 0 #Just putting hitstop stuff in game node until I get stuff sorted

@export var time_label: Label
@export var score_label: Label

@export var player: CharacterBody2D

@export var enemy_scene: PackedScene
@export var base_spawn_interval: float = 12.0
@export var min_spawn_interval: float = 0.8
@export var ramp_per_minute: float = 0.85

@export var gnat_scene: PackedScene
@export var gnat_base_spawn_interval: float = 3.0
@export var gnat_min_spawn_interval: float = 0.4
@export var gnat_ramp_per_minute: float = 0.9
@export var gnat_max_alive: int = 12
@export var gnat_burst_min: int = 1
@export var gnat_burst_max: int = 3

@onready var left_spawn: Marker2D  = $LeftSpawn
@onready var right_spawn: Marker2D = $RightSpawn
@onready var enemy_container: Node = $Enemies
@export var enemy_scenes: Array[PackedScene] = []
@export var use_weighted_spawn: bool = false
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array() #when we add big boi


func _ready() -> void:
	add_to_group("game")
	$Background.play("default")
	reset_time()
	start_time()
	if !player:
		player = get_tree().get_first_node_in_group("Player")
	await get_tree().process_frame
	player.connect("player_died", _game_over)

func _process(delta: float) -> void:
	if !running:
		return

	elapsed += delta
	time_label.text = _format_time(elapsed)

	@warning_ignore("integer_division")
	var current_minute = int(elapsed) / 60
	if current_minute > last_minute_checked:
		var minutes_gained = current_minute - last_minute_checked
		score += minutes_gained * time_score_bonus
		last_minute_checked = current_minute
		_update_score_label()

func _format_time(t: float) -> String:
	@warning_ignore("integer_division")
	var m = int(t) / 60
	var s = int(t) % 60
	var ms = int(round((t - int(t)) * 1000.0))
	return "%02d:%02d.%03d" % [m, s, ms]

func start_time() -> void:
	running = true
	_spawn_loop()
	_gnat_spawn_loop()

func stop_time() -> void:
	running = false

func reset_time() -> void:
	elapsed = 0.0
	last_minute_checked = 0
	score = 0
	total_kills = 0
	time_label.text = _format_time(elapsed)
	_update_score_label()

func _update_score_label() -> void:
	score_label.text = "Score: " + "%06d" % score
	_flash_score()

func _flash_score() -> void:
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
	print("Player died, game over.")
	stop_time()
	$GameUI.visible = false
	$Gameover.visible = true
	for i in $Enemies.get_child_count():
		$Enemies.get_child(i).queue_free()
	$Gameover/VBoxContainer/Panel/timeoverlbl.text = "You survived for: " + time_label.text
	$Gameover/VBoxContainer/Panel2/scoreoverlbl.text = "Score: " + "%06d" % score

func _spawn_loop() -> void:
	while is_instance_valid(self):
		if running:
			_spawn_one()
			var wait_time = _current_spawn_interval()
			await get_tree().create_timer(wait_time).timeout
		else:
			await get_tree().process_frame

func _current_spawn_interval() -> float:
	var minutes_alive = int(elapsed) / 60
	var interval = base_spawn_interval * pow(ramp_per_minute, minutes_alive)
	if interval < min_spawn_interval:
		interval = min_spawn_interval
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

func _spawn_one() -> void:
	var scene_to_spawn = _pick_enemy_scene()
	if scene_to_spawn == null:
		return

	var which_side = randi() % 2
	var spawn_point: Marker2D = left_spawn if which_side == 0 else right_spawn

	var enemy = scene_to_spawn.instantiate()
	enemy.global_position = spawn_point.global_position

	if enemy.has_node("Sprite2D"):
		var spr: Sprite2D = enemy.get_node("Sprite2D")
		spr.flip_h = (which_side != 0)

	if is_instance_valid(enemy_container):
		enemy_container.add_child(enemy)
	else:
		add_child(enemy)

func _gnat_spawn_loop() -> void:
	while is_instance_valid(self):
		if running:
			_spawn_gnat_burst()
			var wait_time = _gnat_current_spawn_interval()
			await get_tree().create_timer(wait_time).timeout
		else:
			await get_tree().process_frame

func _gnat_current_spawn_interval() -> float:
	var minutes_alive = int(elapsed) / 60
	var interval = gnat_base_spawn_interval * pow(gnat_ramp_per_minute, minutes_alive)
	if interval < gnat_min_spawn_interval:
		interval = gnat_min_spawn_interval
	return interval

func _spawn_gnat_burst() -> void:
	if gnat_scene == null:
		return

	if gnat_max_alive > 0:
		var alive = _count_gnats_alive()
		if alive >= gnat_max_alive:
			return

	var count = randi_range(gnat_burst_min, gnat_burst_max)
	for i in count:
		if gnat_max_alive > 0 and _count_gnats_alive() >= gnat_max_alive:
			break
		_spawn_one_gnat()

func _count_gnats_alive() -> int:
	var total := 0
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
	var which_side = randi() % 2
	var spawn_point: Marker2D = left_spawn if which_side == 0 else right_spawn

	var gnat = gnat_scene.instantiate()
	gnat.global_position = spawn_point.global_position

	if gnat.has_node("Sprite2D"):
		var spr: Sprite2D = gnat.get_node("Sprite2D")
		spr.flip_h = (which_side != 0)

	if is_instance_valid(enemy_container):
		enemy_container.add_child(gnat)
	else:
		add_child(gnat)
