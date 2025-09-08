extends Control

@export var play_button: Button
@export var settings_button: Button
@export var credits_button: Button
@export var achievements_button: Button
@export var quit_button: Button

var ui_buttons := {}

func _ready() -> void:
	print("ready")
	ui_buttons = {
		play_button: "Play",
		settings_button: "Settings",
		credits_button: "Credits",
		achievements_button: "Achievements",
		quit_button: "Quit"
	}

	connect_buttons()

func connect_buttons() -> void:
	for button in ui_buttons.keys():
		if not button.is_connected("pressed", _on_button_pressed):
			button.pressed.connect(_on_button_pressed.bind(ui_buttons[button]))

func _on_button_pressed(action: String) -> void:
	match action:
		"Play":
			SceneLoader.goto_game()
		"Settings":
			print("Open settings")
		"Credits":
			print("Open credits")
		"Achievements":
			print("Open achievements")
		"Quit":
			print("Quit the game")
			get_tree().quit()
