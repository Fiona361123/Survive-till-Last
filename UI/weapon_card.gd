extends PanelContainer
class_name WeaponCard

signal purchase_requested(weapon_id: StringName)

@onready var icon: TextureRect = $Margin/Content/Header/IconFrame/Icon
@onready var fallback_icon: Label = $Margin/Content/Header/IconFrame/FallbackIcon
@onready var name_label: Label = $Margin/Content/Header/Names/NameLabel
@onready var type_label: Label = $Margin/Content/Header/Names/TypeLabel
@onready var lock_label: Label = $Margin/Content/Header/LockLabel
@onready var description_label: Label = $Margin/Content/DescriptionLabel
@onready var requirement_label: Label = $Margin/Content/RequirementLabel
@onready var buy_button: Button = $Margin/Content/BuyButton
@onready var new_label: Label = $Margin/Content/NewLabel

var weapon_id: StringName = &""
var _locked: bool = true
var _unseen: bool = false
var _accent := Color(0.25, 0.8, 1.0)
var _pulse_tween: Tween = null


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)


func configure(id: StringName, data: Dictionary, unlocked: bool, unseen: bool) -> void:
	weapon_id = id
	_locked = not unlocked
	_unseen = unseen
	_accent = Color.html(str(data.get("accent", "35d9ff")))

	name_label.text = str(data.get("name", id))
	type_label.text = "PASSIVE PROTECTION" if bool(data.get("passive", false)) else "ACTIVE WEAPON"
	description_label.text = str(data.get("description", ""))
	fallback_icon.text = str(data.get("short_name", "?"))

	var icon_path := str(data.get("icon_path", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
		icon.visible = true
		fallback_icon.visible = false
	else:
		icon.visible = false
		fallback_icon.visible = true

	var weapon_progress := get_node("/root/WeaponProgress")
	var xp_price := int(data.get("xp_price", 0))
	buy_button.visible = _locked and bool(data.get("purchase_only", false)) and xp_price > 0
	if buy_button.visible:
		buy_button.text = "BUY  •  %d XP" % xp_price

	if _locked:
		requirement_label.text = weapon_progress.get_requirement_text(id)
	elif bool(data.get("passive", false)):
		requirement_label.text = "AUTOMATICALLY EQUIPPED"
	else:
		requirement_label.text = "PRESS [%d] TO SWITCH" % int(data.get("slot", 0))

	_apply_state()


func set_purchase_feedback(message: String) -> void:
	requirement_label.text = message
	requirement_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.62))


func _on_buy_pressed() -> void:
	purchase_requested.emit(weapon_id)


func mark_seen() -> void:
	_unseen = false
	new_label.hide()
	_stop_pulse()


func _apply_state() -> void:
	lock_label.visible = _locked
	new_label.visible = _unseen and not _locked
	icon.modulate = Color(1.0, 1.0, 1.0, 0.42 if _locked else 1.0)
	fallback_icon.modulate = Color(1.0, 1.0, 1.0, 0.42 if _locked else 1.0)
	name_label.modulate = Color(0.68, 0.7, 0.76) if _locked else Color.WHITE
	description_label.modulate = Color(0.62, 0.64, 0.7) if _locked else Color(0.82, 0.86, 0.92)
	requirement_label.add_theme_color_override(
		"font_color",
		Color(0.75, 0.76, 0.82) if _locked else _accent
	)

	var panel_style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.bg_color = Color(0.035, 0.04, 0.065, 0.96) if _locked else Color(0.035, 0.065, 0.09, 0.98)
	panel_style.border_color = Color(0.28, 0.29, 0.36, 0.8) if _locked else _accent
	add_theme_stylebox_override("panel", panel_style)

	queue_redraw()
	if _unseen and not _locked:
		_start_pulse()
	else:
		_stop_pulse()


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate", Color(1.18, 1.18, 1.3, 1.0), 0.55)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.55)


func _stop_pulse() -> void:
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_pulse_tween = null
	modulate = Color.WHITE


func _draw() -> void:
	if not _locked:
		return

	var border_color := Color(0.72, 0.72, 0.8, 0.72)
	var inset := 5.0
	var left := inset
	var top := inset
	var right := size.x - inset
	var bottom := size.y - inset
	draw_dashed_line(Vector2(left, top), Vector2(right, top), border_color, 2.0, 9.0)
	draw_dashed_line(Vector2(right, top), Vector2(right, bottom), border_color, 2.0, 9.0)
	draw_dashed_line(Vector2(right, bottom), Vector2(left, bottom), border_color, 2.0, 9.0)
	draw_dashed_line(Vector2(left, bottom), Vector2(left, top), border_color, 2.0, 9.0)
