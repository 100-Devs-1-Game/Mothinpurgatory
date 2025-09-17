extends CanvasLayer

@onready var resume_button = $controlpnl/VBoxContainer/Resume
@onready var settings_button = $controlpnl/VBoxContainer/Settings
@onready var achievement_button = $controlpnl/VBoxContainer/Achievements
@onready var exit_button = $controlpnl/VBoxContainer/Exit

func _ready() -> void:
	resume_button.pressed.connect(_resume)
	settings_button.pressed.connect(_open_settings)
	achievement_button.pressed.connect(_open_achievements)
	exit_button.pressed.connect(_exit_game)
	EventBus.ui_closed.connect(_show_ui)

func _resume() -> void:
	SceneLoader.pause(false)
	SceneLoader.current_scene.show_ui(true)

func _show_ui() -> void:
	visible = true

func _open_settings() -> void:
	visible = false
	SceneLoader.open_overlay(SceneLoader.SETTINGS, self, 1)

func _open_achievements() -> void:
	visible = false
	SceneLoader.open_overlay(SceneLoader.ACHIEVEMENTS, self, 1)

func _exit_game() -> void:
	SceneLoader.goto_title()
	SceneLoader.pause(false)
	queue_free()
