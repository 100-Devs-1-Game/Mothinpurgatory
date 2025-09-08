extends CanvasLayer

@export var scroll_path: NodePath
@export var vbox_path: NodePath
@export var card_scene: PackedScene
@export var row_gap: int = 10
@export var min_row_height: int = 56
@export var btn_reset: Button
@export var btn_back: Button
@export var conf_reset: Button
@export var cncl_reset: Button

var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _cards_by_id: Dictionary = {}
var _am: Node = null
var _connected: bool = false

func _ready() -> void:
	_setup()
	btn_reset.pressed.connect(_reset_request)
	btn_back.pressed.connect(_exit_achievement_page)
	conf_reset.pressed.connect(_reset_achievement_progress)
	cncl_reset.pressed.connect(_reset_cancelled)
	
	_scroll = get_node_or_null(scroll_path)
	_vbox = get_node_or_null(vbox_path)

	if _scroll == null or _vbox == null:
		push_error("AchievementsView: assign scroll_path and vbox_path.")
		return

	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_vbox.add_theme_constant_override("separation", row_gap)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if has_node("/root/AchievementManager"):
		_am = get_node("/root/AchievementManager")
		_build_from_manager()
		_connect_updates()
	else:
		push_warning("AchievementsView: /root/AchievementManager not found. Nothing to show.")

func _setup():
	AchievementManager.unlock("first_game")
	AchievementManager.unlock("no_bugs")
	AchievementManager.unlock("death_I")
	AchievementManager.unlock("survivor_I")
	AchievementManager.unlock("survivor_II")
	AchievementManager.unlock("untouched_I")

func _reset_request() -> void:
	$Confirm.visible = true
	$Main.visible = false

func _reset_achievement_progress() -> void:
	AchievementManager.reset_all()
	rebuild()
	$Confirm.visible = false
	$Main.visible = true

func _exit_achievement_page() -> void:
	EventBus.ui_closed.emit()
	queue_free() #Achievement page will just be instantiated as a child of the main scene

func _reset_cancelled() -> void:
	$Confirm.visible = false
	$Main.visible = true

func _build_from_manager() -> void:
	_clear_list()
	if _am == null:
		return
	var list: Array = _am.call("all")
	for data in list:
		_add_card(data)

func _add_card(data: AchievementData) -> void:
	if card_scene == null:
		push_error("AchievementsView: card_scene not set.")
		return
	var card := card_scene.instantiate() as AchievementCard
	if card == null:
		push_error("AchievementsView: card_scene must be AchievementCard.tscn.")
		return

	card.custom_minimum_size = Vector2(0, float(min_row_height))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_vbox.add_child(card)
	card.setup_from_data(data)
	_cards_by_id[data.id] = card

func _clear_list() -> void:
	for c in _vbox.get_children():
		c.queue_free()
	_cards_by_id.clear()

func _connect_updates() -> void:
	if _am != null and not _connected and _am.has_signal("achievement_unlocked"):
		_am.achievement_unlocked.connect(_on_achievement_unlocked)
		_connected = true

func _on_achievement_unlocked(data: AchievementData) -> void:
	if _cards_by_id.has(data.id):
		var card := _cards_by_id[data.id] as AchievementCard
		if card:
			card.set_locked_state(true)

func rebuild() -> void:
	_build_from_manager()
