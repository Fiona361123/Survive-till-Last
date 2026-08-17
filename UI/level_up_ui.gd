extends BaseMenuUI

signal upgrade_chosen(upgrade_key: String)

const UPGRADES = {
	"speed":     { "name": "Swift Feet",  "icon": "SPD", "desc": "+20 Move Speed",       "flavor": "You move faster across the map.",   "color": Color(0.3, 0.8, 1.0)  },
	"hp_xp":     { "name": "Vitality",    "icon": "HP+", "desc": "+30 HP  &  +15 XP",   "flavor": "Restore health and gain experience.", "color": Color(0.3, 1.0, 0.45) },
	"atk_speed": { "name": "Quick Hands", "icon": "ATK", "desc": "Attacks 15% Faster",   "flavor": "Strike more often per second.",     "color": Color(1.0, 0.5, 1.0)  },
	"damage":    { "name": "Sharp Edge",  "icon": "DMG", "desc": "+5 Attack Damage",     "flavor": "Your attacks hit harder.",          "color": Color(1.0, 0.7, 0.1)  },
	"xp_radius": { "name": "Magnetism",   "icon": "MAG", "desc": "+40 XP Attract Range", "flavor": "Coins are drawn toward you.",       "color": Color(0.8, 1.0, 0.5)  },
}

var _card_container: HBoxContainer
var _picks_remaining: int = 1

func _ready() -> void:
	layer = 10
	build_base_ui("LEVEL UP!", "Choose your reward wisely, survivor.", Color(1.0, 0.85, 0.2), true, "res://XPOrb/level_up_title.png")

	# Widen the panel to fit cards
	container.custom_minimum_size = Vector2(760, 500)

	# Card row
	_card_container = HBoxContainer.new()
	_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.add_theme_constant_override("separation", 24)
	vbox.add_child(_card_container)

	hide()

func show_level_up(new_level: int, picks: int = 1) -> void:
	_picks_remaining = picks
	
	if _picks_remaining > 1:
		container.custom_minimum_size = Vector2(1180, 500) # Wide enough for 5 cards in a row
		if title_label: title_label.text = "** CHEST FOUND **"
		if sub_label: sub_label.text = "Choose %d rewards wisely, survivor." % _picks_remaining
	else:
		container.custom_minimum_size = Vector2(760, 500)
		if title_label: title_label.text = "** LEVEL UP **   Level %d" % new_level
		if sub_label: sub_label.text = "Choose your reward wisely, survivor."

	_populate_cards()
	show()
	get_tree().paused = true

	# Cards slide in from below one by one
	for i in range(_card_container.get_child_count()):
		var card = _card_container.get_child(i)
		card.position.y = 80
		card.modulate.a = 0.0

		var tw = create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(i * 0.12)
		tw.parallel().tween_property(card, "position:y", 0.0, 0.35)\
			.set_delay(i * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _populate_cards() -> void:
	for child in _card_container.get_children():
		child.queue_free()

	if _picks_remaining == 1:
		# Standard level up: show only the original 3 cards
		for key in ["speed", "hp_xp", "atk_speed"]:
			_card_container.add_child(_make_card(key, UPGRADES[key]))
	else:
		# Chest: show all 5 cards
		for key in UPGRADES.keys():
			_card_container.add_child(_make_card(key, UPGRADES[key]))

func _make_card(key: String, data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)
	panel.pivot_offset = Vector2(100.0, 140.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.13, 0.98)
	style.border_color = data["color"]
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.shadow_color = data["color"].darkened(0.3)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	# Icon label
	var icon_lbl := Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", data["color"])
	vb.add_child(icon_lbl)

	# Card name
	var name_rt := RichTextLabel.new()
	name_rt.bbcode_enabled = true
	name_rt.fit_content = true
	name_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hex = data["color"].to_html(false)
	name_rt.text = "[center][b][color=#%s][font_size=19]%s[/font_size][/color][/b][/center]" % [hex, data["name"]]
	vb.add_child(name_rt)

	# Divider
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", data["color"].darkened(0.2))
	vb.add_child(sep)

	# Stat box
	var stat_panel := PanelContainer.new()
	var stat_style := StyleBoxFlat.new()
	stat_style.bg_color = data["color"].darkened(0.68)
	stat_style.set_corner_radius_all(8)
	stat_style.set_border_width_all(1)
	stat_style.border_color = data["color"].darkened(0.3)
	stat_panel.add_theme_stylebox_override("panel", stat_style)
	vb.add_child(stat_panel)

	var stat_lbl := Label.new()
	stat_lbl.text = data["desc"]
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_font_size_override("font_size", 15)
	stat_lbl.add_theme_color_override("font_color", Color.WHITE)
	stat_lbl.add_theme_constant_override("outline_size", 2)
	stat_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stat_panel.add_child(stat_lbl)

	# Flavor text
	var flavor_lbl := Label.new()
	flavor_lbl.text = data["flavor"]
	flavor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_lbl.add_theme_font_size_override("font_size", 11)
	flavor_lbl.add_theme_color_override("font_color", Color(0.62, 0.62, 0.72))
	flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(flavor_lbl)

	# Flexible spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	# SELECT button panel
	var btn_panel := PanelContainer.new()
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = data["color"].darkened(0.45)
	btn_style.border_color = data["color"]
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(10)
	btn_panel.add_theme_stylebox_override("panel", btn_style)
	vb.add_child(btn_panel)

	var btn_lbl := Label.new()
	btn_lbl.text = "[ SELECT ]"
	btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_lbl.add_theme_font_size_override("font_size", 13)
	btn_lbl.add_theme_color_override("font_color", Color.WHITE)
	btn_lbl.add_theme_constant_override("outline_size", 2)
	btn_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	btn_panel.add_child(btn_lbl)

	# Invisible full-card click area
	var click_btn := Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.focus_mode = Control.FOCUS_NONE
	panel.add_child(click_btn)

	click_btn.pressed.connect(_on_card_pressed.bind(key, panel))
	click_btn.mouse_entered.connect(_on_card_hovered.bind(panel, style, btn_style, data["color"]))
	click_btn.mouse_exited.connect(_on_card_unhovered.bind(panel, style, btn_style, data["color"]))

	return panel

func _on_card_hovered(panel: PanelContainer, style: StyleBoxFlat, btn_style: StyleBoxFlat, color: Color) -> void:
	style.bg_color = Color(0.15, 0.15, 0.25, 0.99)
	style.border_color = color.lightened(0.35)
	style.set_border_width_all(5)
	btn_style.bg_color = color.darkened(0.2)

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "scale", Vector2(1.07, 1.07), 0.12).set_trans(Tween.TRANS_SINE)

func _on_card_unhovered(panel: PanelContainer, style: StyleBoxFlat, btn_style: StyleBoxFlat, color: Color) -> void:
	style.bg_color = Color(0.07, 0.07, 0.13, 0.98)
	style.border_color = color
	style.set_border_width_all(3)
	btn_style.bg_color = color.darkened(0.45)

	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)

func _on_card_pressed(key: String, card_node: Control) -> void:
	upgrade_chosen.emit(key)
	_picks_remaining -= 1
	
	card_node.queue_free() # Actually remove the card so others snap together
	
	if _picks_remaining <= 0:
		hide()
		get_tree().paused = false
	else:
		if sub_label:
			sub_label.text = "Choose %d more rewards!" % _picks_remaining

