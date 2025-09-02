extends Node

var player
var states := {}
var cooldowns := {}
var current_state: Node = null
var previous_state_name := ""

func init(p_player: Node) -> void:
	player = p_player
	states["Idle"] = preload("res://player/states/idle.gd").new()
	states["Run"] = preload("res://player/states/run.gd").new()
	states["Air"] = preload("res://player/states/air.gd").new()
	states["Attack"] = preload("res://player/states/attack.gd").new()
	states["Dash"] = preload("res://player/states/dash.gd").new()
	states["Jump"] = preload("res://player/states/jump.gd").new()
	for s in states.values():
		s.init(self, player)
	change_state("Idle")

func update(delta: float) -> void:
	for k in cooldowns.keys():
		cooldowns[k] -= delta
		if cooldowns[k] < 0.0:
			cooldowns[k] = 0.0
	if current_state:
		current_state.update(delta)

func change_state(new_state_name: String) -> void:
	if current_state and current_state == states[new_state_name]:
		return

	if current_state:
		current_state.exit()
		previous_state_name = get_state_name(current_state)

	current_state = states[new_state_name]
	current_state.enter()

func get_state_name(state: Node) -> String:
	for k in states.keys():
		if states[k] == state:
			return k
	return ""

func is_ready(action: String) -> bool:
	return not cooldowns.has(action) or cooldowns[action] <= 0.0

func set_cooldown(action: String, time: float) -> void:
	cooldowns[action] = time
