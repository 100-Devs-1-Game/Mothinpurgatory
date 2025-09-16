extends CanvasLayer

@export var health_component: Node
@export var health_bar: TextureProgressBar
@export var degrader: TextureProgressBar
@export var delay_after_hit: float = 0.6
@export var tween_duration: float = 0.35

var previous: float = 0.0
var timer: Timer
var _tween: Tween

func _ready() -> void:
	await get_tree().process_frame
	previous = float(health_component.current_health)

	health_bar.max_value = health_component.max_health
	health_bar.value = previous
	degrader.max_value = health_component.max_health
	degrader.value = previous

	timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = delay_after_hit
	add_child(timer)
	timer.timeout.connect(_on_timeout)

func _process(_delta: float) -> void:
	var h = float(health_component.current_health)
	var mx = float(health_component.max_health)
	if mx != health_bar.max_value:
		health_bar.max_value = mx
		degrader.max_value = mx

	health_bar.value = h

	if h > degrader.value:
		_kill_tween()
		degrader.value = h

	if h < previous:
		_kill_tween()
		timer.stop()
		timer.start()

	previous = h

func _on_timeout() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(degrader, "value", health_bar.value, tween_duration)

func _kill_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null
