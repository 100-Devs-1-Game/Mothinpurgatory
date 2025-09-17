extends CanvasLayer

@export var tabs_hbox: HBoxContainer
@export var pages_root: Control
@export var exit_buttton: Button

var tabs: Array = []
var pages: Array = []
var page_names: Dictionary = {}

#handles tabbing because the actual tab containers suck >:(

func _ready() -> void:
	for child in tabs_hbox.get_children():
		if child is BaseButton:
			tabs.append(child)

	exit_buttton.pressed.connect(_previous_menu)

	for child in pages_root.get_children():
		if child is Control:
			pages.append(child)
			page_names[child.name] = child

	for button in tabs:
		button.toggle_mode = true
		button.pressed.connect(_on_tab_pressed.bind(button))

	if tabs.size() > 0:
		_select_tab_by_name(tabs[0].name)

func _on_tab_pressed(button: BaseButton) -> void:
	_select_tab_by_name(button.name)

func _select_tab_by_name(_name: String) -> void:
	for button in tabs:
		button.button_pressed = (button.name == _name)

	for page in pages:
		page.visible = (page.name == _name)

func _previous_menu() -> void:
	EventBus.ui_closed.emit()
	queue_free()
