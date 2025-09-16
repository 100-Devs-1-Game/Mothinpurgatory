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

var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _cards_by_id: Dictionary = {}
var _am: Node = null
var _connected: bool = false

func _ready() -> void:
	_setup()

	if btn_reset != null:
		btn_reset.pressed.connect(_reset_request)
	if btn_back != null:
		btn_back.pressed.connect(_exit_achievement_page)
	if conf_reset != null:
		conf_reset.pressed.connect(_reset_achievement_progress)
	if cncl_reset != null:
		cncl_reset.pressed.connect(_reset_cancelled)

	_scroll = get_node_or_null(scroll_path)
	_vbox = get_node_or_null(vbox_path)

	if _scroll == null:
		push_error("AchievementsView: scroll_path is not assigned or node not found.")
		return
	if _vbox == null:
		push_error("AchievementsView: vbox_path is not assigned or node not found.")
		return

	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	var v = _scroll.get_v_scroll_bar()
	if v != null:
		v.self_modulate.a = 0.0
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vbox.add_theme_constant_override("separation", row_gap)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	await get_tree().process_frame

	if typeof(AchievementManager) != TYPE_NIL:
		_am = AchievementManager
	else:
		_am = null

	if _am == null:
		push_warning("AchievementsView: AchievementManager autoload not found. Nothing to show.")
		return

	_build_from_manager()
	_connect_updates()

func _setup() -> void:
	pass

func _reset_request() -> void:
	var confirm = get_node_or_null("Confirm")
	var main = get_node_or_null("Main")
	if confirm != null:
		confirm.visible = true
	if main != null:
		main.visible = false

func _reset_achievement_progress() -> void:
	if typeof(AchievementManager) != TYPE_NIL:
		AchievementManager.reset_all()
	rebuild()

	var confirm = get_node_or_null("Confirm")
	var main = get_node_or_null("Main")
	if confirm != null:
		confirm.visible = false
	if main != null:
		main.visible = true

func _exit_achievement_page() -> void:
	if typeof(EventBus) != TYPE_NIL:
		EventBus.ui_closed.emit()
	queue_free()

func _reset_cancelled() -> void:
	var confirm = get_node_or_null("Confirm")
	var main = get_node_or_null("Main")
	if confirm != null:
		confirm.visible = false
	if main != null:
		main.visible = true

func _build_from_manager() -> void:
	_clear_list()

	if _am == null:
		push_warning("AchievementsView: no manager; cannot build.")
		return

	var list: Array = []
	if _am.has_method("all"):
		list = _am.call("all")
	else:
		push_error("AchievementsView: AchievementManager has no 'all()' method.")
		return

	print("AchievementsView: achievements found = ", list.size())
	var i = 0
	while i < list.size():
		var res = list[i]
		_add_card(res)
		i += 1

func _add_card(data: Resource) -> void:
	if card_scene == null:
		push_error("AchievementsView: card_scene is not set (null).")
		return

	var inst = card_scene.instantiate()
	if inst == null:
		push_error("AchievementsView: failed to instantiate card_scene.")
		return

	var card = inst as AchievementCard
	if card == null:
		push_error("AchievementsView: card_scene must be an AchievementCard.tscn.")
		inst.queue_free()
		return

	var ach = data as AchievementData
	if ach == null:
		push_error("AchievementsView: provided resource is not AchievementData.")
		inst.queue_free()
		return

	card.custom_minimum_size = Vector2(0.0, float(min_row_height))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_vbox.add_child(card)
	card.setup_from_data(ach)
	_cards_by_id[ach.id] = card

	if ach.progressive:
		var cur = 0
		if _am != null:
			if _am.has_method("get_progress"):
				cur = int(_am.call("get_progress", ach.id))
		card.set_progress(cur, ach.required_amount)

func _clear_list() -> void:
	var children = _vbox.get_children()
	var i = 0
	while i < children.size():
		var c = children[i]
		if c is Node:
			c.queue_free()
		i += 1
	_cards_by_id.clear()

func _connect_updates() -> void:
	if _am == null:
		return
	if _connected:
		return

	if _am.has_signal("achievement_unlocked"):
		_am.achievement_unlocked.connect(_on_achievement_unlocked)

	if _am.has_signal("achievement_progress"):
		_am.achievement_progress.connect(_on_achievement_progress)

	_connected = true

func _on_achievement_unlocked(data: AchievementData) -> void:
	if data == null:
		return
	if _cards_by_id.has(data.id):
		var node = _cards_by_id[data.id]
		var card = node as AchievementCard
		if card != null:
			card.set_locked_state(false)

func _on_achievement_progress(data: AchievementData, current: int, required: int) -> void:
	if data == null:
		return
	if _cards_by_id.has(data.id):
		var node = _cards_by_id[data.id]
		var card = node as AchievementCard
		if card != null:
			card.set_progress(current, required)

func rebuild() -> void:
	_build_from_manager()
