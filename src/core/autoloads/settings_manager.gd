extends Node

enum WindowMode { WINDOWED = 0, BORDERLESS = 1, FULLSCREEN = 2 }

var window_mode: int = WindowMode.WINDOWED
var vsync: bool = true
var postfx: bool = true
var framecap: int = 0

const CFG := "user://settings.cfg"
const SEC := "Video"

func _ready() -> void:
	_load()
	set_window_mode(window_mode)
	set_vsync(vsync)
	set_postfx(postfx)
	set_framecap(framecap)

func set_window_mode(id: int) -> void:
	window_mode = id
	match id:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MAX, true)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	_save()

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
	if fps < 0:
		fps = 0
	framecap = fps
	Engine.max_fps = framecap
	_save()

func get_settings() -> Dictionary:
	return {
		"window_mode": window_mode,
		"vsync": vsync,
		"postfx": postfx,
		"framecap": framecap,
	}

func _save() -> void:
	var c = ConfigFile.new()
	c.set_value(SEC, "window_mode", window_mode)
	c.set_value(SEC, "vsync", vsync)
	c.set_value(SEC, "postfx", postfx)
	c.set_value(SEC, "framecap", framecap)
	c.save(CFG)

func _load() -> void:
	var c = ConfigFile.new()
	if c.load(CFG) != OK:
		return
	window_mode = int(c.get_value(SEC, "window_mode", window_mode))
	vsync = bool(c.get_value(SEC, "vsync", vsync))
	postfx = bool(c.get_value(SEC, "postfx", postfx))
	framecap = int(c.get_value(SEC, "framecap", framecap))
