extends CanvasLayer

@export var root: MarginContainer
@export var card: PanelContainer
@export var achievement_icon: TextureRect
@export var achievement_title: Label
@export var achievement_desc: Label

@export var slide_pixels := 40
@export var in_time := 2.0
@export var hold_time := 2.25
@export var out_time := 2.0

var tween: Tween
var tween_playing := false

signal finished

func _ready() -> void:
	visible = false
	card.modulate.a = 0.0
	card.position.x = slide_pixels

func show_achievement(title: String, desc: String, icon: Texture2D) -> float:
	achievement_title.text = title
	achievement_desc.text = desc
	achievement_icon.texture = icon

	visible = true
	card.position.x = slide_pixels
	card.modulate.a = 0.0

	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween_playing = true
	tween.tween_property(card, "position:x", 0, in_time)
	tween.parallel().tween_property(card, "modulate:a", 1.0, in_time)
	tween.tween_interval(hold_time)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(card, "position:x", slide_pixels, out_time)
	tween.parallel().tween_property(card, "modulate:a", 0.0, out_time)
	tween.tween_callback(func ():
		visible = false
		tween_playing = false
		emit_signal("finished")
	)

	return in_time + hold_time + out_time
