extends Control

@export var play_button: Button
@export var settings_button: Button
@export var credits_button: Button
@export var achievements_button: Button
@export var quit_button: Button

const AMR_CLICK_02 = preload("res://audio/ui/amr_click_02.ogg")
const AMR_CLICK_01 = preload("res://audio/ui/amr_click_01.ogg")

var ui_buttons := {}

func _ready() -> void:
	EventBus.connect("ui_closed", show_title_buttons.bind(true))
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

func show_title_buttons(display: bool):
	$Main/VBoxContainer.visible = display
	$Main/GameTitle.visible = display
	$Main/DiscordButton.visible = display

func _on_button_pressed(action: String) -> void:
	match action:
		"Play":
			SceneLoader.goto_game()
		"Settings":
			SceneLoader.open_overlay(SceneLoader.SETTINGS, self, 0)
			show_title_buttons(false)
		"Credits":
			SceneLoader.open_overlay(SceneLoader.CREDITS, self, 0)
			show_title_buttons(false)
		"Achievements":
			SceneLoader.open_overlay(SceneLoader.ACHIEVEMENTS, self, 0)
			show_title_buttons(false)
		"Quit":
			get_tree().quit()
