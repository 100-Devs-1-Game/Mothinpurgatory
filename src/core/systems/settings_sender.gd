extends Control

@export var window_mode: OptionButton
@export var checkbox_vsync: CheckBox
@export var checkbox_postfx: CheckBox
@export var spinbox_framecap: SpinBox

@export var master_slider: Slider
@export var sfx_slider: Slider
@export var music_slider: Slider

var settings_manager: Node

func _ready() -> void:
	if OS.has_feature("web"):
		$Pages/Video/VBoxContainer/HBoxContainer/WindowMode.visible = false
		$Pages/Video/VBoxContainer/HBoxContainer/window.visible = false
		$Pages/Video/VBoxContainer/HBoxContainer2/vsync.visible = false
		$Pages/Video/VBoxContainer/HBoxContainer2/CheckBox.visible = false
	settings_manager = get_node_or_null("/root/settings_manager")
	if settings_manager == null:
		settings_manager = get_node_or_null("/root/SettingsManager")

	if settings_manager == null:
		push_error("settings_manager autoload not found at /root/settings_manager (or /root/SettingsManager).")
	else:
		_setup_window_mode_items()
		_load_from_settings_manager()
		_load_audio_sliders()
		_connect_signals()

func _connect_signals() -> void:
	window_mode.item_selected.connect(_on_window_mode_selected)
	checkbox_vsync.toggled.connect(_on_vsync_toggled)
	checkbox_postfx.toggled.connect(_on_postfx_toggled)
	spinbox_framecap.value_changed.connect(_on_framecap_changed)
	master_slider.value_changed.connect(_on_master_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)

func _setup_window_mode_items() -> void:
	window_mode.clear()
	window_mode.add_item("Windowed", 0)
	window_mode.add_item("Borderless", 1)
	window_mode.add_item("Fullscreen", 2)

func _load_audio_sliders() -> void:
	var audio_sliders = settings_manager.get_all_volumes()
	master_slider.value = audio_sliders["Master"] * 100.0
	sfx_slider.value = audio_sliders["SFX"] * 100.0
	music_slider.value = audio_sliders["Music"] * 100.0

func _load_from_settings_manager() -> void:
	if settings_manager.has_method("get_settings"):
		var settings: Dictionary = settings_manager.get_settings()

		var saved_window_mode: int = 0
		if settings.has("window_mode"):
			saved_window_mode = int(settings["window_mode"])

		var saved_vsync: bool = true
		if settings.has("vsync"):
			saved_vsync = bool(settings["vsync"])

		var saved_postfx: bool = true
		if settings.has("postfx"):
			saved_postfx = bool(settings["postfx"])

		var saved_framecap: int = 0
		if settings.has("framecap"):
			saved_framecap = int(settings["framecap"])

		var selected_index := window_mode.get_item_index(saved_window_mode)
		if selected_index >= 0:
			window_mode.select(selected_index)

		checkbox_vsync.button_pressed = saved_vsync
		checkbox_postfx.button_pressed = saved_postfx
		spinbox_framecap.value = saved_framecap
	else:
		if settings_manager.has_method("get_window_mode"):
			var mode_from_manager = int(settings_manager.get_window_mode())
			var index_from_manager := window_mode.get_item_index(mode_from_manager)
			if index_from_manager >= 0:
				window_mode.select(index_from_manager)

		if settings_manager.has_method("get_vsync"):
			checkbox_vsync.button_pressed = bool(settings_manager.get_vsync())

		if settings_manager.has_method("get_postfx"):
			checkbox_postfx.button_pressed = bool(settings_manager.get_postfx())

		if settings_manager.has_method("get_framecap"):
			spinbox_framecap.value = int(settings_manager.get_framecap())

func _on_window_mode_selected(_index: int) -> void:
	if settings_manager != null and settings_manager.has_method("set_window_mode"):
		var selected_id: int = window_mode.get_selected_id()
		settings_manager.set_window_mode(selected_id)

func _on_vsync_toggled(enabled: bool) -> void:
	if settings_manager != null and settings_manager.has_method("set_vsync"):
		settings_manager.set_vsync(enabled)

func _on_postfx_toggled(enabled: bool) -> void:
	if settings_manager != null and settings_manager.has_method("set_postfx"):
		settings_manager.set_postfx(enabled)

func _on_framecap_changed(new_value: float) -> void:
	if settings_manager != null and settings_manager.has_method("set_framecap"):
		var framecap_value: int = int(new_value)
		if framecap_value < 0:
			framecap_value = 0
		settings_manager.set_framecap(framecap_value)

func _on_master_slider_changed(value: float) -> void:
	var new_value = value / 100
	if settings_manager != null:
		if settings_manager.has_method("set_bus_volume"):
			settings_manager.set_bus_volume("Master", new_value)

func _on_sfx_slider_changed(value: float) -> void:
	var new_value = value / 100
	if settings_manager != null:
		if settings_manager.has_method("set_bus_volume"):
			settings_manager.set_bus_volume("SFX", new_value)

func _on_music_slider_changed(value: float) -> void:
	var new_value = value / 100
	if settings_manager != null:
		if settings_manager.has_method("set_bus_volume"):
			settings_manager.set_bus_volume("Music", new_value)
