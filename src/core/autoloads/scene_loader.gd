extends Node

@export var fade_time := 0.25
@export var fade_color := Color.BLACK

var _overlay: ColorRect
var _layer: CanvasLayer
var _busy := false
var _paused := false
var _ingame := false

const PAUSED = preload("res://interface/paused.tscn")
const SETTINGS = preload("res://interface/settings_overlay.tscn")
const CREDITS = preload("res://interface/credits.tscn")
const ACHIEVEMENTS = preload("res://core/achievements/achievement_page.tscn")

var current_scene
var overlays := {}

func _ready() -> void:
	process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS

	_layer = CanvasLayer.new()
	_layer.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_overlay = ColorRect.new()
	_overlay.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS
	_overlay.color = fade_color
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_overlay)

	_overlay.anchor_left = 0
	_overlay.anchor_top = 0
	_overlay.anchor_right = 1
	_overlay.anchor_bottom = 1

func goto(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade_to(0.0)
	_busy = false

func goto_title() -> void:
	goto("res://world/title.tscn")
	_ingame = false

func goto_game() -> void:
	goto("res://world/Arena.tscn")
	_ingame = true

func open_overlay(scene: PackedScene, caller: Node = null, id: int = 0) -> void:
	var existing = overlays.get(id, null)
	if existing != null and is_instance_valid(existing):
		return
	var p := scene.instantiate()
	if caller == null:
		caller = _layer
	caller.add_child(p)
	_register_overlay(p, id)

func close_overlay(id: int) -> void: #UI can close themselves or this can
	var n = overlays.get(id, null)
	if n != null and is_instance_valid(n) and !n.is_queued_for_deletion():
		n.queue_free()

func toggle_overlay(scene: PackedScene, caller: Node = null, id: int = 0) -> void:
	if is_overlay_open(id):
		close_overlay(id)
	else:
		open_overlay(scene, caller, id)

func is_overlay_open(id: int) -> bool:
	return overlays.has(id) and is_instance_valid(overlays[id])

func _register_overlay(p: Node, id: int) -> void:
	overlays[id] = p
	p.tree_exited.connect(_on_overlay_tree_exited.bind(id))

func _get_overlay(id: int) -> Node:
	return overlays[id]

func _on_overlay_tree_exited(id: int) -> void:
	if overlays.has(id):
		overlays.erase(id)

func _fade_to(target: float) -> void:
	var t = create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_overlay, "modulate:a", target, fade_time)
	await t.finished

func pause(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_paused = is_paused
	if _paused:
		open_overlay(PAUSED)
	else:
		close_overlay(0)

func is_game_paused() -> bool:
	return _paused

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		if _ingame:
			if !_paused:
				pause(true)
				if current_scene != null and current_scene.has_method("show_ui"):
					current_scene.show_ui(false)
			else:
				pause(false)
				if current_scene != null and current_scene.has_method("show_ui"):
					current_scene.show_ui(true)

		print("Game paused: ", _paused)
