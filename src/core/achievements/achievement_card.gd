extends Panel
class_name AchievementCard

@export var icon_size: Vector2 = Vector2(24, 24)

@onready var icon_tex: TextureRect = $Margin/Row/Icon
@onready var title_label: Label = $Margin/Row/Text/Title
@onready var desc_label: Label = $Margin/Row/Text/Desc
@onready var progress: TextureProgressBar = $progress

var data: AchievementData = null
var _locked: bool = true
var _sb: StyleBoxFlat

const GOLD_BG := Color(0.98, 0.86, 0.32, 0.22)
const GOLD_BORDER := Color(1.00, 0.92, 0.45, 1.0)
const LOCKED_BG := Color(1, 1, 1, 0.10)

func _ready() -> void:
	_sb = StyleBoxFlat.new()
	_sb.bg_color = LOCKED_BG
	_sb.corner_radius_top_left = 6
	_sb.corner_radius_top_right = 6
	_sb.corner_radius_bottom_left = 6
	_sb.corner_radius_bottom_right = 6
	_sb.border_width_left = 0
	_sb.border_width_top = 0
	_sb.border_width_right = 0
	_sb.border_width_bottom = 0
	add_theme_stylebox_override("panel", _sb)

	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.custom_minimum_size = icon_size
	icon_tex.size = icon_size
	icon_tex.size_flags_horizontal = 0
	icon_tex.size_flags_vertical = 0

	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup_from_data(p_data: AchievementData) -> void:
	data = p_data

	title_label.text = _format_title_with_progress(
		data.title, data.progressive, data.current_amount, data.required_amount
	)
	desc_label.text = data.description
	if icon_tex != null:
		icon_tex.texture = data.icon

	if data.progressive and data.required_amount > 0:
		progress.visible = true
		progress.min_value = 0
		progress.max_value = float(data.required_amount)
		progress.value = float(data.current_amount)
	else:
		progress.visible = false

	set_locked_state(not data.unlocked)

func set_progress(current: int, required: int) -> void:
	if required <= 0:
		progress.visible = false
	else:
		progress.visible = true
		if current < 0:
			current = 0
		if current > required:
			current = required
		progress.min_value = 0
		progress.max_value = float(required)
		progress.value = float(current)

	if data != null:
		title_label.text = _format_title_with_progress(
			data.title, data.progressive, current, required
		)

func set_locked_state(locked: bool) -> void:
	_locked = locked

	if locked:
		modulate = Color(0.75, 0.75, 0.75, 1.0)
		icon_tex.self_modulate = Color(0, 0, 0, 1)
		_sb.bg_color = LOCKED_BG
		_sb.border_width_left = 0
		_sb.border_width_top = 0
		_sb.border_width_right = 0
		_sb.border_width_bottom = 0
	else:
		modulate = Color(1, 1, 1, 1)
		icon_tex.self_modulate = Color(1, 1, 1, 1)
		_sb.bg_color = GOLD_BG
		_sb.border_color = GOLD_BORDER
		_sb.border_width_left = 2
		_sb.border_width_top = 2
		_sb.border_width_right = 2
		_sb.border_width_bottom = 2

func _format_title_with_progress(base_title: String, is_progressive: bool, current: int, required: int) -> String:
	if is_progressive and required > 0:
		if current < 0:
			current = 0
		elif current > required:
			current = required
		return "%s (%d/%d)" % [base_title, current, required]
	return base_title
