extends BaseMenuUI

signal upgrade_chosen(upgrade_key: String)

const UPGRADES = {
	"max_hp":    { "name": "Vitality",     "desc": "+20 Max HP",            "color": Color(1.0, 0.3, 0.3) },
	"speed":     { "name": "Swift Feet",   "desc": "+20 Move Speed",        "color": Color(0.3, 0.8, 1.0) },
	"damage":    { "name": "Sharp Edge",   "desc": "+5 Attack Damage",      "color": Color(1.0, 0.7, 0.1) },
	"atk_speed": { "name": "Quick Hands",  "desc": "Attacks 15% Faster",    "color": Color(1.0, 0.5, 1.0) },
	"xp_radius": { "name": "Magnetism",    "desc": "+40 XP Attract Range",  "color": Color(0.3, 1.0, 0.5) },
}

var _card_container: HBoxContainer

func _ready() -> void:
	layer = 10
	build_base_ui("LEVEL UP!", "Choose an upgrade:", Color(1.0, 0.85, 0.2), true, "res://XPOrb/level_up_title.png")

	# Card row
	_card_container = HBoxContainer.new()
	_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.add_theme_constant_override("separation", 20)
	vbox.add_child(_card_container)

	hide()

func show_level_up(new_level: int) -> void:
	if title_label:
		title_label.text = "LEVEL UP!  -->  Level %d" % new_level
	if sub_label:
		sub_label.text = "Level %d! Choose a reward:" % new_level
		
	_populate_cards()
	show()
	get_tree().paused = true
	
	# Entrance Animation: Pop cards in one by one
	for i in range(_card_container.get_child_count()):
		var card = _card_container.get_child(i)
		card.scale = Vector2(0.1, 0.1)
		card.modulate.a = 0.0
		
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.3).set_delay(i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		var alpha_tween = create_tween()
		alpha_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		alpha_tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)

func _populate_cards() -> void:
	for child in _card_container.get_children():
		child.queue_free()

	var keys := UPGRADES.keys()
	keys.shuffle()
	var chosen := keys.slice(0, 3)

	for key in chosen:
		_card_container.add_child(_make_card(key, UPGRADES[key]))

func _make_card(key: String, data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(175, 220)
	panel.pivot_offset = Vector2(175.0 / 2.0, 220.0 / 2.0)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	style.border_color = data["color"]
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var hex_color = data["color"].to_html(false)
	var bb_text = "[center][b][color=#%s][font_size=20]%s[/font_size][/color][/b]\n\n[font_size=14]%s[/font_size][/center]" % [hex_color, data["name"], data["desc"]]
	rt.text = bb_text
	margin.add_child(rt)
	
	# Invisible button to capture clicks
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	panel.add_child(btn)
	
	btn.pressed.connect(_on_card_pressed.bind(key))
	btn.mouse_entered.connect(_on_card_hovered.bind(panel, style, data["color"]))
	btn.mouse_exited.connect(_on_card_unhovered.bind(panel, style, data["color"]))
	
	return panel

func _on_card_hovered(panel: PanelContainer, style: StyleBoxFlat, color: Color) -> void:
	style.bg_color = Color(0.18, 0.18, 0.28, 0.99)
	style.border_color = color.lightened(0.3)
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE)

func _on_card_unhovered(panel: PanelContainer, style: StyleBoxFlat, color: Color) -> void:
	style.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	style.border_color = color
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _on_card_pressed(key: String) -> void:
	upgrade_chosen.emit(key)
	hide()
	get_tree().paused = false
