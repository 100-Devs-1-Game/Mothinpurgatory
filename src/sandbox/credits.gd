extends CanvasLayer

@export var exit_credits: Button

func _ready() -> void:
	exit_credits.pressed.connect(_exit_credits)

func _exit_credits() -> void:
	EventBus.ui_closed.emit()
	queue_free()
