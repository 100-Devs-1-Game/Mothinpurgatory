extends Area2D
class_name Hitbox

@export var attack_data: Resource
@export var lifetime: float = 0.2
@export var enable_lifetime: bool = false
@export var tick_interval: float = 0.5
@export var damage_on_enter: bool = true

var a_owner: Node
var ticking := {}
var _accums := {}

func _ready() -> void:
	add_to_group("hitbox")
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)
	a_owner = get_parent()
	if enable_lifetime:
		await get_tree().create_timer(lifetime, false).timeout
		queue_free()

func _process(delta: float) -> void:
	for area in ticking.keys():
		if not is_instance_valid(area):
			ticking.erase(area)
			_accums.erase(area)
		else:
			_accums[area] += delta
			if _accums[area] >= tick_interval:
				_accums[area] = 0.0
				area.apply_damage(attack_data, a_owner if a_owner != null else self)

func _on_area_entered(area: Area2D) -> void:
	ticking[area] = true
	_accums[area] = 0.0
	if damage_on_enter:
		area.apply_damage(attack_data, a_owner if a_owner != null else self)

func _on_area_exited(area: Area2D) -> void:
	ticking.erase(area)
	_accums.erase(area)
