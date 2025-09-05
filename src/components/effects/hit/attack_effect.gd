extends AnimatedSprite2D

func _ready() -> void:
	play("hit land")

func _on_animation_finished() -> void:
	queue_free()
