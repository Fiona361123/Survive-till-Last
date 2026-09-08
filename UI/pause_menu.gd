extends CanvasLayer

var panel: Panel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(420, 560)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var bg_texture = load("res://UI/pause menu background.webp")
	if bg_texture:
		var style = StyleBoxTexture.new()
		style.texture = bg_texture
		panel.add_theme_stylebox_override("panel", style)
	else:
		var flat_style = StyleBoxFlat.new()
		flat_style.bg_color = Color(0.82, 0.68, 0.45, 1.0)
		flat_style.border_color = Color(0.4, 0.28, 0.12, 1.0)
		flat_style.set_border_width_all(8)
		panel.add_theme_stylebox_override("panel", flat_style)
	add_child(panel)
	
	var font_milky = load("res://UI/Milky Cream.otf")
	var font_harry  = load("res://UI/HARRYP__.TTF")
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	vbox.offset_left = 40
	vbox.offset_right = -40
	vbox.offset_top = 40
	vbox.offset_bottom = -30
	panel.add_child(vbox)
	
	# --- TITLE ---
	var title = Label.new()
	title.text = "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_harry: title.add_theme_font_override("font", font_harry)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.15, 0.07, 0.0))
	vbox.add_child(title)
	
	# --- SLIDERS ---
	var settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	vbox.add_child(settings_box)
	
	settings_box.add_child(_make_slider_row("Music", 80, font_milky,
		func(v): if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").set_music_volume(v / 100.0)))
	settings_box.add_child(_make_slider_row("Sound FX", 100, font_milky,
		func(v): if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").set_sfx_volume(v / 100.0)))
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# --- BUTTONS ---
	vbox.add_child(_make_btn("Restart Level", font_milky, _on_restart_pressed))
	vbox.add_child(_make_btn("Main Menu",     font_milky, _on_quit_pressed))
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer2)
	
	vbox.add_child(_make_btn("Back To Game",  font_milky, _on_continue_pressed, true))


func _make_btn(label_text: String, font: Font, callback: Callable, big: bool = false) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 62 if big else 54)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font: btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 36 if big else 30)
	btn.add_theme_color_override("font_color",         Color(0.08, 0.04, 0.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.3,  0.15, 0.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.5,  0.25, 0.0))
	var n_style = StyleBoxFlat.new()
	n_style.bg_color = Color(0.45, 0.30, 0.12, 1.0)
	n_style.border_color = Color(0.25, 0.15, 0.05, 1.0)
	n_style.set_border_width_all(3)
	n_style.corner_radius_top_left    = 10
	n_style.corner_radius_top_right   = 10
	n_style.corner_radius_bottom_left = 10
	n_style.corner_radius_bottom_right = 10
	n_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", n_style)
	var h_style = n_style.duplicate() as StyleBoxFlat
	h_style.bg_color = Color(0.62, 0.46, 0.22, 1.0)
	btn.add_theme_stylebox_override("hover", h_style)
	var p_style = n_style.duplicate() as StyleBoxFlat
	p_style.bg_color = Color(0.30, 0.18, 0.06, 1.0)
	btn.add_theme_stylebox_override("pressed", p_style)
	btn.add_theme_stylebox_override("focus", h_style)
	btn.pressed.connect(callback)
	return btn


func _make_slider_row(label_text: String, default_val: float, font: Font, on_change: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var lbl = Label.new()
	lbl.text = label_text + ":"
	lbl.custom_minimum_size = Vector2(96, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if font: lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0))
	row.add_child(lbl)
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(170, 24)
	slider.min_value = 0
	slider.max_value = 100
	slider.value = default_val
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row


func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().current_scene.name != "MainMenu":
			_toggle_pause()

func _toggle_pause():
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	if new_pause_state:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_continue_pressed():
	_toggle_pause()

func _on_restart_pressed():
	_toggle_pause()
	get_tree().reload_current_scene()

func _on_quit_pressed():
	var dungeon = get_tree().current_scene
	if dungeon != null and dungeon.name.begins_with("Dungeon"):
		var player = get_tree().get_first_node_in_group("player")
		if player != null and player.current_hp > 0:
			var killed = dungeon.get_current_enemies_killed() if dungeon.has_method("get_current_enemies_killed") else 0
			var flags = {
				"level_cleared":   dungeon.get("level_cleared"),
				"level_2_cleared": dungeon.get("level_2_cleared"),
				"level_3_cleared": dungeon.get("level_3_cleared"),
				"level_2_second_wave_spawned": dungeon.get("level_2_second_wave_spawned")
			}
			SaveSystem.save_dungeon_state(
				dungeon.get("current_level"),
				player.current_hp,
				player.max_hp,
				player.current_xp,
				player.current_level,
				killed,
				flags,
				player.global_position.x,
				player.global_position.y
			)
	_toggle_pause()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
