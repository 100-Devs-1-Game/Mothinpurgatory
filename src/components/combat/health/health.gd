extends Node
class_name Health

@export var max_health: int = 10
@export var overwrite_data: Resource
@export var tint_on_damage: bool = false

@export var apply_knockback_on_damage: bool = true
@export var knockback_resistance: float = 0.0
@export var only_knockback_if_alive: bool = true

@export var is_players: bool = false
@export var health_regen_enabled: bool = false
@export var health_regen_amount: int = 1
@export var health_regen_time: int = 3 # per 3 seconds or somethin

@export var iframes_enabled: bool = true
@export var iframe_duration: float = 0.5
@export var flicker_on_iframes: bool = true
@export var flicker_interval: float = 0.08
@export var flicker_sprite: AnimatedSprite2D

var world: Node2D
var regen_timer: Timer
var iframe_timer: Timer
var flicker_timer: Timer

var current_health: int
var declared_dead: bool = false
var invulnerable: bool = false

signal health_changed(new_value: int, max_value: int)
signal damaged(damage_data, source)

const HITSOUND = preload("res://audio/gameplay/thwack_01.wav.wav")

func _ready() -> void:
	if overwrite_data and "max_health" in overwrite_data:
		max_health = overwrite_data.max_health
	current_health = max_health

	world = get_tree().get_first_node_in_group("World")

	if health_regen_enabled:
		if regen_timer == null:
			regen_timer = Timer.new()
			regen_timer.wait_time = health_regen_time
			regen_timer.timeout.connect(heal_damage.bind(health_regen_amount))
			regen_timer.one_shot = false
			add_child(regen_timer)
			regen_timer.start()

	if iframe_timer == null:
		iframe_timer = Timer.new()
		iframe_timer.wait_time = iframe_duration
		iframe_timer.one_shot = true
		iframe_timer.timeout.connect(_end_iframes)
		add_child(iframe_timer)

	if flicker_timer == null:
		flicker_timer = Timer.new()
		flicker_timer.wait_time = flicker_interval
		flicker_timer.one_shot = false
		flicker_timer.timeout.connect(_tick_flicker)
		add_child(flicker_timer)

func heal_damage(amount: int) -> void:
	if current_health < max_health:
		current_health += amount

func take_damage(damage_data: Resource, source: Node) -> void:
	if damage_data == null:
		push_warning("Received damage_data is null on ", source)
		return

	if declared_dead:
		return

	if is_players:
		if iframes_enabled:
			if invulnerable:
				return

	var target = get_parent()

	var dmg = 0
	if "damage" in damage_data:
		dmg = int(damage_data.damage)

	current_health = clamp(current_health - dmg, 0, max_health)
	health_changed.emit(current_health, max_health)
	damaged.emit(damage_data, source)

	if is_players:
		if iframes_enabled:
			_begin_iframes()

	if !is_players:
		var s = AudioStreamPlayer2D.new()
		world.add_child(s)
		s.set_stream(HITSOUND)
		s.volume_db = -11.0
		s.finished.connect(_terminate.bind(s))
		s.global_position = get_parent().global_position
		s.play()

	if is_players:
		if target and target.has_method("_notify_damage"):
			if target.animator:
				target.animator.play("stun")
			target._notify_damage()

	var can_apply_kb = false
	if apply_knockback_on_damage and target:
		if target.has_method("apply_knockback"):
			can_apply_kb = true

	if can_apply_kb:
		if current_health > 0 or not only_knockback_if_alive:
			var kb_mag = _extract_knockback(damage_data)
			if kb_mag != Vector2.ZERO:
				var attacker = _resolve_attacker_node2d(source)
				var tgt2d = target as Node2D
				var dir_x = 1.0
				if attacker and tgt2d:
					dir_x = _compute_dir_x(attacker, tgt2d)
				var final_kb = Vector2(dir_x * kb_mag.x, -kb_mag.y)
				var resist = 1.0 - clamp(knockback_resistance, 0.0, 1.0)

				var eff_source: Node = source
				if attacker != null:
					eff_source = attacker

				target.apply_knockback(eff_source, final_kb * resist)

	if target and target.has_method("enter_hitstun"):
		if "hitstun" in damage_data and float(damage_data.hitstun) > 0.0:
			target.enter_hitstun(damage_data.hitstun)

	if current_health == 0 and source:
		_notify_death(source)

func _begin_iframes() -> void:
	invulnerable = true
	iframe_timer.stop()
	iframe_timer.wait_time = iframe_duration
	iframe_timer.start()

	if flicker_on_iframes:
		if flicker_sprite != null:
			flicker_sprite.visible = true
			flicker_timer.stop()
			flicker_timer.wait_time = flicker_interval
			flicker_timer.start()

func _end_iframes() -> void:
	invulnerable = false
	_stop_flicker()

func _stop_flicker() -> void:
	flicker_timer.stop()
	if flicker_sprite != null:
		flicker_sprite.visible = true

func _tick_flicker() -> void:
	if not invulnerable:
		_stop_flicker()
		return
	if flicker_sprite == null:
		_stop_flicker()
		return
	flicker_sprite.visible = not flicker_sprite.visible

func _terminate(what: Node) -> void:
	if what:
		what.queue_free()

func _extract_knockback(damage_data: Resource) -> Vector2:
	var horiz = 0.0
	var up = 0.0
	if "knockback" in damage_data:
		var kbv = damage_data.knockback
		if typeof(kbv) == TYPE_VECTOR2:
			horiz = float(kbv.x)
			up = float(kbv.y)
		else:
			horiz = float(kbv)
	if "knockup" in damage_data:
		up = float(damage_data.knockup)
	return Vector2(max(0.0, horiz), max(0.0, up))

func _compute_dir_x(attacker: Node2D, target: Node2D) -> float:
	var dx = target.global_position.x - attacker.global_position.x
	if dx > 0.0:
		return 1.0
	if dx < 0.0:
		return -1.0
	var facing_x = sign(attacker.global_transform.x.x)
	if facing_x != 0.0:
		return facing_x
	return 1.0

func _resolve_attacker_node2d(src: Node) -> Node2D:
	var n = src
	while n and not (n is Node2D):
		n = n.get_parent()
	return n as Node2D

func _notify_death(source: Node) -> void:
	var target = get_parent()
	if target and target.has_method("_death"):
		target.call_deferred("_death", source)
		declared_dead = true
