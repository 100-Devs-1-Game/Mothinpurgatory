extends ParallaxBackground

@export var strength: float = 0.4
@export var max_offset_px: Vector2 = Vector2(160, 60)
@export var smooth_speed: float = 6.0

var target: Vector2 = Vector2.ZERO

func _process(delta):
	var ps = SettingsManager.get_game_window_mode()
	if ps == 2:
		scale = Vector2(1.52,1.80)
	else:
		scale = Vector2(1.0,1.0)

	var vp = get_viewport()
	var size = vp.get_visible_rect().size
	var mouse = vp.get_mouse_position()
	var centered = (mouse / size) - Vector2(0.5, 0.5)
	target = centered * size * strength
	if target.x < -max_offset_px.x:
		target.x = -max_offset_px.x
	if target.x > max_offset_px.x:
		target.x = max_offset_px.x
	if target.y < -max_offset_px.y:
		target.y = -max_offset_px.y
	if target.y > max_offset_px.y:
		target.y = max_offset_px.y
	scroll_offset = scroll_offset.lerp(target, delta * smooth_speed)
