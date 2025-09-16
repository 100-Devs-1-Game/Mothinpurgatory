extends Node

enum WindowMode { WINDOWED = 0, BORDERLESS = 1, FULLSCREEN = 2 }

var window_mode: int = WindowMode.WINDOWED
var vsync: bool = true
var postfx: bool = true
var framecap: int = 0

var volumes: Dictionary = {
	"Master": 1.0,
	"SFX": 1.0,
	"Music": 1.0,
}

const CFG: String = "user://settings.cfg"
const SEC_VIDEO: String = "Video"
const SEC_AUDIO: String = "Audio"

func _ready() -> void:
	_load()

	set_window_mode(window_mode)
	set_vsync(vsync)
	set_postfx(postfx)
	set_framecap(framecap)

	var keys = volumes.keys()
	var i = 0
	while i < keys.size():
		var bus_name := String(keys[i])
		var linear := float(volumes[bus_name])
		_apply_bus_volume(bus_name, linear)
		i += 1

func set_window_mode(id: int) -> void:
	window_mode = id
	if id == WindowMode.FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif id == WindowMode.BORDERLESS:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MAX, true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	_save()

func get_game_window_mode() -> int:
	return window_mode

func set_vsync(on: bool) -> void:
	vsync = on
	if on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_save()

func set_postfx(on: bool) -> void:
	postfx = on
	_save()

func set_framecap(fps: int) -> void:
	var value = fps
	if value < 0:
		value = 0
	framecap = value
	Engine.max_fps = framecap
	_save()

func set_bus_volume(bus: String, linear_value: float) -> void:
	var linear = linear_value
	if linear < 0.0:
		linear = 0.0
	if linear > 1.0:
		linear = 1.0

	volumes[bus] = linear
	_apply_bus_volume(bus, linear)
	_save()

func get_bus_volume(bus: String) -> float:
	if volumes.has(bus):
		return float(volumes[bus])
	else:
		return 1.0

func get_all_volumes() -> Dictionary:
	var copy = {}
	var keys = volumes.keys()
	var i = 0
	while i < keys.size():
		var k = String(keys[i])
		copy[k] = float(volumes[k])
		i += 1
	return copy

func _apply_bus_volume(bus: String, linear: float) -> void:
	var index = AudioServer.get_bus_index(bus)
	if index == -1:
		push_error("Audio bus '" + bus + "' not found.")
		return

	var db_value = -80.0
	var should_mute = false

	if linear <= 0.0001:
		db_value = -80.0
		should_mute = true
	else:
		db_value = linear_to_db(linear)
		should_mute = false

	AudioServer.set_bus_volume_db(index, db_value)
	AudioServer.set_bus_mute(index, should_mute)

func get_settings() -> Dictionary:
	var result := {}
	result["window_mode"] = window_mode
	result["vsync"] = vsync
	result["postfx"] = postfx
	result["framecap"] = framecap
	result["volumes"] = get_all_volumes()
	return result

func _save() -> void:
	var c = ConfigFile.new()

	c.set_value(SEC_VIDEO, "window_mode", window_mode)
	c.set_value(SEC_VIDEO, "vsync", vsync)
	c.set_value(SEC_VIDEO, "postfx", postfx)
	c.set_value(SEC_VIDEO, "framecap", framecap)

	var keys = volumes.keys()
	var i = 0
	while i < keys.size():
		var bus = String(keys[i])
		c.set_value(SEC_AUDIO, bus, float(volumes[bus]))
		i += 1

	c.save(CFG)

func _load() -> void:
	var c = ConfigFile.new()
	var err = c.load(CFG)
	if err != OK:
		return

	window_mode = int(c.get_value(SEC_VIDEO, "window_mode", window_mode))
	vsync = bool(c.get_value(SEC_VIDEO, "vsync", vsync))
	postfx = bool(c.get_value(SEC_VIDEO, "postfx", postfx))
	framecap = int(c.get_value(SEC_VIDEO, "framecap", framecap))

	var known_buses = ["Master", "SFX", "Music"]
	var i = 0
	while i < known_buses.size():
		var bus := String(known_buses[i])
		if c.has_section_key(SEC_AUDIO, bus):
			var loaded := float(c.get_value(SEC_AUDIO, bus, 1.0))
			if loaded < 0.0:
				loaded = 0.0
			if loaded > 1.0:
				loaded = 1.0
			volumes[bus] = loaded
		i += 1
