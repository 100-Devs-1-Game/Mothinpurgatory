extends Button

@export_range(0.0, 1.0) var line_width_ratio := 0.6
@export var line_height := 2
@export var grow_time := 0.15
@export var shrink_time := 0.12
@export var fade := true

@export var hover_sound: AudioStream
@export var click_sound: AudioStream

@onready var underline: ColorRect = $Underline
@onready var overline: ColorRect = $Overline
var _tween: Tween

const AMR_CLICK_02 = preload("res://audio/ui/amr_click_02.ogg")
const AMR_CLICK_01 = preload("res://audio/ui/amr_click_01.ogg")

func _ready() -> void:
	underline.size = Vector2(_target_width(), line_height)
	underline.position = Vector2((size.x - underline.size.x) * 0.5, size.y - line_height)
	underline.pivot_offset = Vector2(underline.size.x * 0.5, 0)
	underline.scale.x = 0.0
	underline.modulate.a = 0.0 if fade else 1.0

	overline.size = Vector2(_target_width(), line_height)
	overline.position = Vector2((size.x - overline.size.x) * 0.5, 0)
	overline.pivot_offset = Vector2(overline.size.x * 0.5, 0)
	overline.scale.x = 0.0
	overline.modulate.a = 0.0 if fade else 1.0

	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_button_pressed)

func _on_resized() -> void:
	underline.size = Vector2(_target_width(), line_height)
	underline.position = Vector2((size.x - underline.size.x) * 0.5, size.y - line_height)
	underline.pivot_offset = Vector2(underline.size.x * 0.5, 0)

	overline.size = Vector2(_target_width(), line_height)
	overline.position = Vector2((size.x - overline.size.x) * 0.5, 0)
	overline.pivot_offset = Vector2(overline.size.x * 0.5, 0)

func play_sound(audio: AudioStream) -> void:
	$AudioStreamPlayer.set_stream(audio)
	$AudioStreamPlayer.play()

func _on_mouse_entered() -> void:
	play_sound(AMR_CLICK_02)
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)

	for line in [underline, overline]:
		_tween.tween_property(line, "scale:x", 1.0, grow_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if fade:
			_tween.tween_property(line, "modulate:a", 1.0, grow_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)

	for line in [underline, overline]:
		_tween.tween_property(line, "scale:x", 0.0, shrink_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if fade:
			_tween.tween_property(line, "modulate:a", 0.0, shrink_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _on_button_pressed() -> void:
	play_sound(AMR_CLICK_01)

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

func _target_width() -> float:
	return max(1.0, size.x * line_width_ratio)
