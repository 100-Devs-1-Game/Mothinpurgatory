extends Node
class_name AchievementQueuer

@export var suppress_time := 6.0

const DISPLAY_SCENE = preload("res://core/achievements/achievement_displayer.tscn")

var queue: Array[Dictionary] = []
var is_active := false
var last_shown := {}

func queue_unlock(id: StringName, title: String, desc: String, icon: Texture2D) -> void:
	var time = Time.get_unix_time_from_system()
	if last_shown.has(id) and (time - float(last_shown[id])) < suppress_time:
		return
	last_shown[id] = time

	queue.append({
		"id": id,
		"title": title,
		"desc": desc,
		"icon": icon
	})
	_push() 

func _push() -> void:
	if is_active or queue.is_empty():
		return
	is_active = true

	var request = queue.pop_front()
	var displayer = DISPLAY_SCENE.instantiate()
	get_tree().root.add_child(displayer)
	var total = displayer.show_achievement(request.title, request.desc, request.icon)
	await get_tree().create_timer(total).timeout
	displayer.queue_free()
	is_active = false
	_push()
