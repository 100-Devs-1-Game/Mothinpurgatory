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

@onready var time_label: Label  = $CanvasLayer/TextureRect2/VBoxContainer/timelbl
@onready var score_label: Label = $CanvasLayer/TextureRect2/VBoxContainer/scorelbl

@export var player: CharacterBody2D

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

	var current_minute := int(elapsed) / 60
	if current_minute > last_minute_checked:
		var minutes_gained := current_minute - last_minute_checked
		score += minutes_gained * time_score_bonus
		last_minute_checked = current_minute
		_update_score_label()

func _format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	var ms := int(round((t - int(t)) * 1000.0))
	return "%02d:%02d.%03d" % [m, s, ms]

func start_time() -> void:
	running = true

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
