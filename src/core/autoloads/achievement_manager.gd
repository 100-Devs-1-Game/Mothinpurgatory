extends Node

signal achievement_unlocked(data: AchievementData)

const ACHIEVEMENTS_DIR := "res://resources/achievements/"
const SAVE_PATH := "user://achievements.cfg"
const SAVE_SECTION := "achievements"

var _achievements_by_id: Dictionary = {}
var _unlocked_ids: = {}

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	_load_definitions()
	_load_progress()
	_apply_loaded_progress()

func all() -> Array:
	var list = _achievements_by_id.values()
	list.sort_custom(func(a, b): return a.title.naturalnocasecmp_to(b.title) < 0)
	return list

func get_by_id(id: String) -> AchievementData:
	return _achievements_by_id.get(id)

func is_unlocked(id: String) -> bool:
	return _unlocked_ids.has(id)

func unlock(id: String) -> void:
	var data: AchievementData = _achievements_by_id.get(id)
	if data == null:
		push_warning("Tried to unlock unknown achievement id='%s'" % id)
		return
	if _unlocked_ids.has(id):
		return
	_unlocked_ids[id] = true
	data.unlocked = true
	_save_progress()
	emit_signal("achievement_unlocked", data)

func try_unlock_on_predicate(id: String, predicate: Callable) -> void:
	if is_unlocked(id):
		return
	if predicate.call():
		unlock(id)

func try_unlock_on_threshold(id: String, current_value: int, required: int) -> void:
	if is_unlocked(id):
		return
	if current_value >= required:
		unlock(id)

func _load_definitions() -> void:
	_achievements_by_id.clear()
	var dir = DirAccess.open(ACHIEVEMENTS_DIR)
	if dir == null:
		push_warning("Achievements directory not found at %s" % ACHIEVEMENTS_DIR)
		return
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if dir.current_is_dir():
			continue
		if file.ends_with(".tres") or file.ends_with(".res"):
			var path = "%s/%s" % [ACHIEVEMENTS_DIR, file]
			var res = ResourceLoader.load(path)
			if res == null:
				push_warning("Failed to load achievement resource: %s" % path)
				continue
			if not res is AchievementData:
				push_warning("Resource at %s is not AchievementData." % path)
				continue
			var id = res.id
			if id == "":
				push_warning("Achievement missing id at %s" % path)
				continue
			if _achievements_by_id.has(id):
				push_warning("Duplicate achievement id '%s' at %s" %  [id, path])
				continue
			_achievements_by_id[id] = res

func _load_progress() -> void:
	_unlocked_ids.clear()
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	if err != OK:
		return
	if cfg.has_section(SAVE_SECTION):
		for id in cfg.get_section_keys(SAVE_SECTION):
			if cfg.get_value(SAVE_SECTION, id, false):
				_unlocked_ids[id] = true

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Couldn't load existing %s (code %d); writing fresh." % [SAVE_PATH, err])
		cfg = ConfigFile.new()
	if cfg.has_section(SAVE_SECTION):
		cfg.erase_section(SAVE_SECTION)
	for id in _achievements_by_id.keys():
		cfg.set_value(SAVE_SECTION, id, _unlocked_ids.has(id))
	err = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Failed to save achievements at %s (code %d)" % [SAVE_PATH, err])

func reset_all() -> void:
	_unlocked_ids.clear()
	for id in _achievements_by_id.keys():
		var data: AchievementData = _achievements_by_id[id]
		data.unlocked = false
	_save_progress()

func _apply_loaded_progress() -> void:
	for id in _achievements_by_id.keys():
		var data: AchievementData = _achievements_by_id[id]
		data.unlocked = _unlocked_ids.has(id)

func _connect_default_listeners(bus: Object) -> void:
	if bus.has_signal("player_died"):
		bus.connect("player_died", Callable(self, "_on_player_died"))

func _on_player_died() -> void:
	try_unlock_on_predicate("death_I", func() -> bool: return true)
	print("player died!")
