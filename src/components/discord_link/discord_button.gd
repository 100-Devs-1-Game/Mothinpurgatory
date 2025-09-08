extends TextureButton

@onready var panel: Panel = $".."
var sb: StyleBoxFlat
var tween: Tween

func _ready() -> void:
	var base_sb := panel.get_theme_stylebox("panel")
	if base_sb is StyleBoxFlat:
		sb = (base_sb as StyleBoxFlat).duplicate()
	else:
		sb = StyleBoxFlat.new()
	panel.add_theme_stylebox_override("panel", sb)

	sb.shadow_color = Color(1, 0, 0, 0.0)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2.ZERO

	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16

	panel.pivot_offset = panel.size * 0.5
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)

func _on_enter() -> void:
	if tween:
		tween.kill()

	sb.shadow_color = Color(1, 0, 0, 0.6)
	sb.shadow_size = 18.0

	tween = create_tween().set_loops()
	tween.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(sb, "shadow_color", Color(1, 0, 0, 0.2), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(sb, "shadow_color", Color(1, 0, 0, 0.6), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_exit() -> void:
	if tween:
		tween.kill()
	sb.shadow_color = Color(1, 0, 0, 0.0)
	sb.shadow_size = 0
	panel.scale = Vector2.ONE

func _on_pressed() -> void:
	OS.shell_open("https://discord.gg/UHN4AjMw4d")
