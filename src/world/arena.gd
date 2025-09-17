extends Node2D
signal wave_started(wave: int)

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
@export var wave_label: Label
@export var player: CharacterBody2D

@export var enemy_scenes: Array[PackedScene] = []
@export var use_weighted_spawn: bool = false
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()

@export var retry_button: Button
@export var quit_button: Button

@export var wave_intermission_time: float = 8.0
@export var wave_size_start: int = 8
@export var wave_size_growth: float = 1.3
@export var wave_concurrent_cap_base: int = 6
@export var wave_concurrent_cap_growth: int = 1
@export var wave_spawn_interval_start: float = 1.5
@export var wave_spawn_interval_decay: float = 0.93
@export var wave_min_spawn_interval: float = 0.25

@onready var left_spawn: Marker2D  = $LeftSpawn
@onready var right_spawn: Marker2D = $RightSpawn
@onready var enemy_container: Node = $Enemies
@export var enemy_unlock_wave: PackedInt32Array = PackedInt32Array()

var post_process_enabled := true
var _hitstop_depth := 0
var hitless_elapsed := 0.0
var hitless_last_minute := 0
var hitless_running := false
var game_over := false

var current_wave: int = 0
var wave_running: bool = false
var wave_enemies_to_spawn: int = 0
var wave_enemies_spawned: int = 0
var wave_spawn_interval: float = 1.0
var wave_concurrent_cap: int = 0

func _ready() -> void:
	$Music.play()
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
	$GameUI/waves.visible = true
	await get_tree().create_timer(2.0).timeout
	_start_waves()

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

	update_enemy_count()

func update_enemy_count() -> void:
	if $GameUI/enemycount:
		$GameUI/enemycount.text = "Enemies:" + str(_alive_enemies())

func show_ui(display: bool) -> void:
	$GameUI.visible = display

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
	_score_tween.tween_property(score_label, "scale", FLASH_SCALE, FLASH_UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(score_label, "modulate", FLASH_COLOR, FLASH_UP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_score_tween.set_parallel(false)
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, FLASH_DOWN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_score_tween.tween_property(score_label, "modulate", NORMAL_COLOR, FLASH_DOWN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

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
	hitless_running = false
	await get_tree().create_timer(5.0).timeout
	var ttxt = ""
	if time_label:
		ttxt = time_label.text
	else:
		ttxt = _format_time(elapsed)
	$NewOver/Panel2/VBoxContainer/Panel/timelbl.text = "You survived for: " + ttxt
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

func _start_waves() -> void:
	current_wave = 0
	_next_wave()

func _next_wave() -> void:
	$Wavehorn.play()
	EventBus.wave_survived.emit()
	current_wave += 1
	wave_enemies_to_spawn = int(round(wave_size_start * pow(wave_size_growth, max(0, current_wave - 1))))
	wave_enemies_spawned = 0
	wave_concurrent_cap = wave_concurrent_cap_base + (max(0, current_wave - 1) * wave_concurrent_cap_growth)
	wave_spawn_interval = max(wave_min_spawn_interval, wave_spawn_interval_start * pow(wave_spawn_interval_decay, max(0, current_wave - 1)))
	wave_running = true
	emit_signal("wave_started", current_wave) #incase I add something else
	if wave_label:
		if wave_label.visible == false:
			wave_label.visible = true
		if wave_label.modulate.a > 0.01:
			var tw = create_tween()
			tw.tween_property(wave_label, "modulate:a", 0.0, 0.2)
			await tw.finished
		wave_label.text = "Wave " + str(current_wave)
		var tw2 = create_tween()
		tw2.tween_property(wave_label, "modulate:a", 1.0, 0.35)
		await tw2.finished
	_wave_loop()

func _current_enemy_pool() -> Array[int]:
	var res: Array[int] = []
	var n = enemy_scenes.size()
	var ulen = enemy_unlock_wave.size()
	for i in range(n):
		var unlock_at = 1
		if i < ulen:
			unlock_at = enemy_unlock_wave[i]
		if current_wave >= unlock_at:
			res.append(i)
	return res


func _alive_enemies() -> int:
	if is_instance_valid(enemy_container):
		var count = 0
		for c in enemy_container.get_children():
			if is_instance_valid(c):
				count += 1
		return count
	return 0

func _can_spawn_more() -> bool:
	if wave_enemies_spawned >= wave_enemies_to_spawn:
		return false
	return _alive_enemies() < wave_concurrent_cap

func _wave_loop() -> void:
	await get_tree().process_frame
	while is_instance_valid(self) and running and !game_over:
		if !wave_running:
			return
		if _can_spawn_more():
			_spawn_one()
			wave_enemies_spawned += 1
			await get_tree().create_timer(wave_spawn_interval, false).timeout
		else:
			var tree = get_tree()
			if tree == null or !is_instance_valid(self) or !is_inside_tree(): #overkill but this was driving me nuts
				return
			await tree.process_frame
			if !is_instance_valid(self) or !is_inside_tree():
				return
		if wave_enemies_spawned >= wave_enemies_to_spawn and _alive_enemies() == 0:
			_end_wave_and_queue_next()
			return

func _end_wave_and_queue_next() -> void:
	wave_running = false
	await get_tree().create_timer(wave_intermission_time, false).timeout
	if running and !game_over:
		_next_wave()

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

func _pick_enemy_scene() -> PackedScene:
	var unlocked = _current_enemy_pool()
	if unlocked.size() == 0:
		return null
	if use_weighted_spawn and spawn_weights.size() == enemy_scenes.size():
		var total = 0.0
		for i in unlocked:
			var w = spawn_weights[i]
			if w > 0.0:
				total += w
		if total > 0.0:
			var roll = randf() * total
			var acc = 0.0
			for i in unlocked:
				var w = spawn_weights[i]
				if w < 0.0:
					w = 0.0
				acc += w
				if roll <= acc:
					return enemy_scenes[i]
	var idx = unlocked[randi() % unlocked.size()]
	return enemy_scenes[idx]


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

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_post"):
		post_process_enabled = not post_process_enabled
		$Enviroment.visible = post_process_enabled
		$Enviroment/CanvasLayer.visible = post_process_enabled

func end_game():
	EventBus.score_final.emit(score)
	SceneLoader.goto_title()

func retry():
	EventBus.score_final.emit(score)
	SceneLoader.goto_game()

func _exit_tree() -> void:
	running = false
	wave_running = false
	EventBus.score_final.emit(score)

func _on_music_finished() -> void:
	$Music.play()

func _on_audio_stream_player_finished() -> void:
	$Cheers.play()
