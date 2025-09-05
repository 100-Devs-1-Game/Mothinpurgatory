extends Panel
class_name AchievementCard

@export var icon_size: Vector2 = Vector2(24, 24)

@onready var _icon: TextureRect = $Margin/Row/Icon
@onready var _title: Label = $Margin/Row/Text/Title
@onready var _desc: Label = $Margin/Row/Text/Desc

var achievement_id: String = ""

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.15)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6

	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = icon_size
	_icon.size = icon_size
	_icon.size_flags_horizontal = 0
	_icon.size_flags_vertical = 0
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup_from_data(data: AchievementData) -> void:
	achievement_id = data.id
	_title.text = data.title

	var d := data.description
	if d == null:
		d = ""
	_desc.text = d

	if data.icon != null and data.icon is Texture2D:
		_icon.texture = data.icon
	else:
		_icon.texture = _placeholder_icon()

	_set_locked_visual(not data.unlocked)

func set_locked_state(unlocked: bool) -> void:
	_set_locked_visual(not unlocked)

func _set_locked_visual(is_locked: bool) -> void:
	if is_locked:
		_icon.modulate = Color(0, 0, 0, 1)
	else:
		_icon.modulate = Color(1, 1, 1, 1)

func _placeholder_icon() -> Texture2D:
	var w := int(max(1.0, icon_size.x))
	var h := int(max(1.0, icon_size.y))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
