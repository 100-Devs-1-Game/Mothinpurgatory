extends Node

@export var fade_time := 0.25
@export var fade_color := Color.BLACK

var _overlay: ColorRect
var _layer: CanvasLayer
var _busy := false

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)

	_overlay = ColorRect.new()
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

func goto_game() -> void:
	goto("res://world/Arena.tscn")

func _fade_to(target: float) -> void:
	var t = create_tween()
	t.tween_property(_overlay, "modulate:a", target, fade_time)
	await t.finished
