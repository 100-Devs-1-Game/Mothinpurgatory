extends Node

signal achievement_unlocked(id: StringName, data: AchievementData)
signal achievement_progress(data: AchievementData, current: int, required: int)

const FORCE_PACK := preload("res://resources/achievements/force_pack.gd")
const ACHIEVEMENTS_DIR := "res://resources/achievements/"
const SAVE_PATH := "user://achievements.cfg"
const SAVE_SECTION := "achievements"
const SAVE_SECTION_PROGRESS := "achievement_progress"

var _achievements_by_id: Dictionary = {}
var _unlocked_ids := {}
var _progress_by_id: Dictionary = {}

var _run_survival_minutes := 0
var _run_hitless_minutes := 0
var _run_score := 0

var _bus_connected := false

const SURVIVAL_IDS := [
	"survivor_I", "survivor_II", "survivor_III"
]

const UNTOUCHABLE_IDS := [
	"untouched_I", "untouched_II", "untouched_III", "untouched_IV",
]
var _no_hit_streak := true

const WAVE_IDS := [
	"waves_five", "waves_ten", "waves_twenty", "waves_thirty", "waves_fifty", "waves_hundred"
	]
var _run_waves := 0

func _ready() -> void:
	_connect_default_listeners(EventBus)
	_load_definitions()
	_load_progress()
	_apply_loaded_progress()

	if not is_connected("achievement_unlocked", Callable(self, "_on_achievement_unlocked")):
		connect("achievement_unlocked", Callable(self, "_on_achievement_unlocked"))

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
	emit_signal("achievement_unlocked", data.id, data)

func _on_achievement_unlocked(id: StringName, data: AchievementData) -> void:
	var title = data.title
	var desc = data.description
	var icon: Texture2D = data.icon if data.icon else null
	AchievementDisplayQueue.queue_unlock(id, title, desc, icon)

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
		push_warning("Achievements directory not found at " + ACHIEVEMENTS_DIR)
		return

	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if dir.current_is_dir():
			continue

		var should_consider = false
		if file.ends_with(".tres"):
			should_consider = true
		elif file.ends_with(".res"):
			should_consider = true
		elif file.ends_with(".tres.remap"):
			should_consider = true
		elif file.ends_with(".res.remap"):
			should_consider = true

		if not should_consider:
			continue

		var load_name = file
		if file.ends_with(".remap"):
			load_name = file.substr(0, file.length() - 6)

		var path = ACHIEVEMENTS_DIR + load_name
		var res = ResourceLoader.load(path)

		if res == null:
			push_warning("Failed to load achievement resource: " + path)
			continue
		if not (res is AchievementData):
			push_warning("Resource at " + path + " is not AchievementData.")
			continue

		var id = res.id
		if id == "":
			push_warning("Achievement missing id at " + path)
			continue
		if _achievements_by_id.has(id):
			push_warning("Duplicate achievement id '" + id + "' at " + path)
			continue

		_achievements_by_id[id] = res

	dir.list_dir_end()

func _load_progress() -> void:
	_unlocked_ids.clear()
	_progress_by_id.clear()
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	if err != OK:
		return

	if cfg.has_section(SAVE_SECTION):
		for id in cfg.get_section_keys(SAVE_SECTION):
			if cfg.get_value(SAVE_SECTION, id, false):
				_unlocked_ids[id] = true

	if cfg.has_section(SAVE_SECTION_PROGRESS):
		for id in cfg.get_section_keys(SAVE_SECTION_PROGRESS):
			_progress_by_id[id] = int(cfg.get_value(SAVE_SECTION_PROGRESS, id, 0))

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Couldn't load existing %s (code %d); writing fresh." % [SAVE_PATH, err])
		cfg = ConfigFile.new()

	if cfg.has_section(SAVE_SECTION):
		cfg.erase_section(SAVE_SECTION)
	if cfg.has_section(SAVE_SECTION_PROGRESS):
		cfg.erase_section(SAVE_SECTION_PROGRESS)

	for id in _achievements_by_id.keys():
		cfg.set_value(SAVE_SECTION, id, _unlocked_ids.has(id))
		var data: AchievementData = _achievements_by_id[id]
		if data.progressive:
			var cur: int = int(_progress_by_id.get(id, data.current_amount))
			cfg.set_value(SAVE_SECTION_PROGRESS, id, cur)

	err = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Failed to save achievements at %s (code %d)" % [SAVE_PATH, err])

func reset_all() -> void:
	_unlocked_ids.clear()
	_progress_by_id.clear()
	for id in _achievements_by_id.keys():
		var data: AchievementData = _achievements_by_id[id]
		if data.progressive:
			data.current_amount = 0
		data.unlocked = false
	_save_progress()

func _reset_run_scoped() -> void:
	_run_survival_minutes = 0
	_run_hitless_minutes = 0
	_run_score = 0
	_no_hit_streak = true
	_run_waves = 0

func _apply_loaded_progress() -> void:
	for id in _achievements_by_id.keys():
		var data: AchievementData = _achievements_by_id[id]
		data.unlocked = _unlocked_ids.has(id)
		data.current_amount = int(_progress_by_id.get(id, 0))

func _connect_default_listeners(bus: Object) -> void:
	if _bus_connected:
		return

	if bus.has_signal("player_died") and not bus.player_died.is_connected(_on_player_died):
		bus.player_died.connect(_on_player_died)

	if bus.has_signal("player_damaged") and not bus.player_damaged.is_connected(_on_player_damaged):
		bus.player_damaged.connect(_on_player_damaged)

	if bus.has_signal("bug_killed") and not bus.bug_killed.is_connected(_on_bug_killed):
		bus.bug_killed.connect(_on_bug_killed)

	if bus.has_signal("first_boss") and not bus.first_boss.is_connected(_first_boss_killed):
		bus.first_boss.connect(_first_boss_killed)

	if bus.has_signal("first_game") and not bus.first_game.is_connected(_first_game_played):
		bus.first_game.connect(_first_game_played)

	if bus.has_signal("minute_passed") and not bus.minute_passed.is_connected(_minute_passed):
		bus.minute_passed.connect(_minute_passed)

	if bus.has_signal("no_hit_minute_passed") and not bus.no_hit_minute_passed.is_connected(_no_hit_minute):
		bus.no_hit_minute_passed.connect(_no_hit_minute)

	if bus.has_signal("score_final") and not bus.score_final.is_connected(_on_score_final):
		bus.score_final.connect(_on_score_final)

	if bus.has_signal("wave_survived") and not bus.wave_survived.is_connected(_wave_survived):
		bus.wave_survived.connect(_wave_survived)

	_bus_connected = true

func add_progress(id: String, delta: int) -> void:
	if not _achievements_by_id.has(id):
		return
	var data: AchievementData = _achievements_by_id[id]
	if not data.progressive:
		return

	var cur = int(_progress_by_id.get(id, data.current_amount))
	cur += delta
	if cur < 0:
		cur = 0
	if data.required_amount > 0:
		cur = min(cur, data.required_amount)

	_progress_by_id[id] = cur
	data.current_amount = cur

	emit_signal("achievement_progress", data, cur, data.required_amount)
	try_unlock_on_threshold(id, cur, data.required_amount)
	_save_progress()

func set_progress(id: String, value: int) -> void:
	add_progress(id, value - int(_progress_by_id.get(id, 0)))

func get_progress(id: String) -> int:
	return int(_progress_by_id.get(id, 0))

func _on_player_died() -> void:
	try_unlock_on_predicate("death_I", func() -> bool: return true)
	_no_hit_streak = false
	_run_survival_minutes = 0
	_run_hitless_minutes = 0
	_run_score = 0

func _on_player_damaged() -> void:
	_no_hit_streak = false
	_run_hitless_minutes = 0

func _on_bug_killed() -> void:
	add_progress("no_bugs", 1)
	add_progress("no_bugs_II", 1)

func _first_boss_killed() -> void:
	try_unlock_on_predicate("first_boss", func() -> bool: return true)
	print("achievement unlocked: First boss")

func _first_game_played() -> void:
	try_unlock_on_predicate("first_game", func() -> bool: return true)
	_reset_run_scoped()

func _no_hit_minute(minutes: int) -> void:
	_run_hitless_minutes += minutes
	for id in UNTOUCHABLE_IDS:
		if not _achievements_by_id.has(id):
			continue
		var req = _achievements_by_id[id].required_amount
		try_unlock_on_threshold(id, _run_hitless_minutes, req)
		var best = get_progress(id)
		if _run_hitless_minutes > best:
			set_progress(id, _run_hitless_minutes)

func _minute_passed(minutes: int = 1) -> void:
	_run_survival_minutes += minutes
	for id in SURVIVAL_IDS:
		if not _achievements_by_id.has(id):
			continue
		var req = _achievements_by_id[id].required_amount
		try_unlock_on_threshold(id, _run_survival_minutes, req)

		var best = get_progress(id)
		if _run_survival_minutes > best:
			set_progress(id, _run_survival_minutes)

func _on_score_final(final_score: int) -> void:
	_run_score = final_score
	_commit_run_best()

func _wave_survived() -> void:
	_run_waves += 1
	for id in WAVE_IDS:
		if not _achievements_by_id.has(id):
			continue
		var req = _achievements_by_id[id].required_amount
		try_unlock_on_threshold(id, _run_waves, req)
		var best = get_progress(id)
		if _run_waves > best:
			set_progress(id, _run_waves)

func _commit_run_best() -> void:
	var BEST_ID = "high_score"
	if _achievements_by_id.has(BEST_ID):
		var best = get_progress(BEST_ID)
		if _run_score > best:
			set_progress(BEST_ID, _run_score)
