extends Control
class_name WeaponStoreUI

const WEAPON_CARD_SCENE: PackedScene = preload("res://UI/WeaponCard.tscn")

@onready var store_button: Button = $StoreButton
@onready var new_badge: Label = $StoreButton/NewBadge
@onready var overlay: ColorRect = $Overlay
@onready var close_button: Button = $Overlay/Center/Window/Margin/Content/Header/CloseButton
@onready var xp_balance_label: Label = $Overlay/Center/Window/Margin/Content/Header/XPBalanceLabel
@onready var card_grid: GridContainer = $Overlay/Center/Window/Margin/Content/CardScroll/CardGrid
@onready var purchase_message: Label = $Overlay/Center/Window/Margin/Content/PurchaseMessage

var cards: Dictionary = {}
var _was_paused: bool = false
var _button_tween: Tween = null
@onready var weapon_progress: Node = get_node("/root/WeaponProgress")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	store_button.pressed.connect(open_store)
	close_button.pressed.connect(close_store)
	weapon_progress.weapon_unlocked.connect(_on_weapon_unlocked)
	weapon_progress.weapon_seen.connect(_on_weapon_seen)
	weapon_progress.weapon_xp_changed.connect(_on_weapon_xp_changed)
	weapon_progress.purchase_succeeded.connect(_on_purchase_succeeded)
	weapon_progress.purchase_failed.connect(_on_purchase_failed)
	weapon_progress.progression_changed.connect(_update_new_badge)
	overlay.hide()
	_update_new_badge()
	_on_weapon_xp_changed(weapon_progress.weapon_xp_balance)


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		close_store()
		get_viewport().set_input_as_handled()


func open_store() -> void:
	if overlay.visible:
		return

	_was_paused = get_tree().paused
	overlay.show()
	purchase_message.text = ""
	_rebuild_cards()
	get_tree().paused = true
	_mark_visible_cards_seen_after_delay()


func close_store() -> void:
	if not overlay.visible:
		return

	overlay.hide()
	get_tree().paused = _was_paused


func _rebuild_cards() -> void:
	for child in card_grid.get_children():
		child.queue_free()
	cards.clear()

	for weapon_id in weapon_progress.WEAPON_ORDER:
		var card := WEAPON_CARD_SCENE.instantiate() as WeaponCard
		card_grid.add_child(card)
		card.configure(
			weapon_id,
			weapon_progress.get_weapon_data(weapon_id),
			weapon_progress.is_weapon_unlocked(weapon_id),
			weapon_id in weapon_progress.unseen_weapon_ids
		)
		card.purchase_requested.connect(_on_purchase_requested)
		cards[weapon_id] = card


func _mark_visible_cards_seen_after_delay() -> void:
	await get_tree().create_timer(0.8, true).timeout
	if not is_instance_valid(self) or not overlay.visible:
		return

	weapon_progress.mark_all_weapons_seen()
	for card in cards.values():
		(card as WeaponCard).mark_seen()


func _on_weapon_unlocked(_weapon_id: StringName) -> void:
	_update_new_badge()
	_play_button_attention()
	if overlay.visible:
		_rebuild_cards()


func _on_weapon_seen(weapon_id: StringName) -> void:
	if cards.has(weapon_id):
		(cards[weapon_id] as WeaponCard).mark_seen()
	_update_new_badge()


func _update_new_badge() -> void:
	new_badge.visible = weapon_progress.has_unseen_weapons()


func _on_purchase_requested(weapon_id: StringName) -> void:
	weapon_progress.purchase_weapon(weapon_id)


func _on_weapon_xp_changed(new_balance: int) -> void:
	xp_balance_label.text = "WEAPON XP  %d" % new_balance
	if overlay.visible:
		_rebuild_cards()


func _on_purchase_succeeded(weapon_id: StringName) -> void:
	var data: Dictionary = weapon_progress.get_weapon_data(weapon_id)
	purchase_message.add_theme_color_override("font_color", Color(0.35, 1.0, 0.68))
	purchase_message.text = "%s PURCHASED — PRESS [%d] TO SWITCH" % [
		str(data.get("name", weapon_id)),
		int(data.get("slot", 0)),
	]


func _on_purchase_failed(weapon_id: StringName, reason: String) -> void:
	purchase_message.add_theme_color_override("font_color", Color(1.0, 0.42, 0.62))
	purchase_message.text = reason
	if cards.has(weapon_id):
		(cards[weapon_id] as WeaponCard).set_purchase_feedback(reason)


func _play_button_attention() -> void:
	if is_instance_valid(_button_tween):
		_button_tween.kill()
	store_button.pivot_offset = store_button.size * 0.5
	_button_tween = create_tween()
	_button_tween.tween_property(store_button, "scale", Vector2(1.08, 1.08), 0.12)
	_button_tween.tween_property(store_button, "scale", Vector2.ONE, 0.12)
	_button_tween.set_loops(3)
