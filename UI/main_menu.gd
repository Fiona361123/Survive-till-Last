extends Control

@onready var upgrades_panel = $UpgradesPanel
@onready var coins_label = $UpgradesPanel/CoinsLabel
@onready var btn_hp = $UpgradesPanel/UpgradeList/BtnHP
@onready var btn_dmg = $UpgradesPanel/UpgradeList/BtnDamage
@onready var btn_spd = $UpgradesPanel/UpgradeList/BtnSpeed

# Profile UI References
@onready var btn_switch_profile = $ProfileBox/SwitchProfileButton

# Profile Dialog References (PvZ Style)
@onready var profile_dialog = $ProfileDialog
@onready var profile_list = $ProfileDialog/ProfileScroll/ProfileList
@onready var new_profile_input = $ProfileDialog/CreateBox/NewProfileInput
@onready var btn_create_profile = $ProfileDialog/CreateBox/CreateButton
@onready var btn_close_profile = $ProfileDialog/BtnCloseProfile

# Runner
var dummy_player: Node2D = null
var runner_speed: float = 160.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Apply Font to theme
	var default_font = load("res://UI/Milky Cream.otf")
	var title_font = load("res://UI/HARRYP__.TTF")
	if default_font:
		theme = Theme.new()
		theme.default_font = default_font
		
	var title_node = get_node_or_null("Title")
	if title_node and title_font:
		title_node.add_theme_font_override("font", title_font)
		
	_setup_dungeon_tile_background()
	_setup_running_character()
	
	# Connect Main Menu Buttons
	$MenuButtons/StartButton.pressed.connect(_on_start_pressed)
	$MenuButtons/UpgradesButton.pressed.connect(_on_upgrades_pressed)
	$MenuButtons/QuitButton.pressed.connect(_on_quit_pressed)
	
	# Connect Upgrade Buttons
	btn_hp.pressed.connect(_on_buy_hp)
	btn_dmg.pressed.connect(_on_buy_dmg)
	btn_spd.pressed.connect(_on_buy_spd)
	$UpgradesPanel/BtnBack.pressed.connect(_on_back_pressed)
	
	# Connect Profile Dialog
	btn_switch_profile.pressed.connect(_open_profile_dialog)
	btn_close_profile.pressed.connect(_close_profile_dialog)
	btn_create_profile.pressed.connect(_on_create_profile_pressed)
	new_profile_input.text_submitted.connect(func(_text): _on_create_profile_pressed())
	
	_update_profile_display()
	_update_upgrade_ui()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if profile_dialog and profile_dialog.visible:
			_close_profile_dialog()
		elif upgrades_panel and upgrades_panel.visible:
			_on_back_pressed()
		else:
			get_tree().quit()

# --- 1. Background Setup ---
func _setup_dungeon_tile_background():
	var dark_base = get_node_or_null("DarkBase")
	if dark_base:
		dark_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	var bg = get_node_or_null("Background")
	if bg is TextureRect:
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not bg.texture:
			bg.texture = load("res://Isometric/stoneTile_N.png")
		bg.stretch_mode = TextureRect.STRETCH_TILE

# --- 2. Running Character (Smaller Scale) ---
func _setup_running_character():
	# Clean up any prior runner
	var existing = get_node_or_null("DummyPlayer")
	if existing:
		existing.queue_free()
		
	var player_scene = load("res://Character/player.tscn")
	if not player_scene:
		return
		
	var temp_player = player_scene.instantiate()
	var orig_sprite = temp_player.get_node_or_null("AnimatedSprite2D")
	if not orig_sprite:
		temp_player.queue_free()
		return
		
	# Remove any HUD/Health elements attached to sprite
	var hp_bar = orig_sprite.get_node_or_null("HealthBarAnchor")
	if hp_bar:
		hp_bar.queue_free()
		
	# Detach the animated sprite so player.gd physics/scripts never run
	temp_player.remove_child(orig_sprite)
	temp_player.queue_free()
	
	dummy_player = Node2D.new()
	dummy_player.name = "DummyPlayer"
	# Compact normal scale (smaller as requested)
	dummy_player.scale = Vector2(2.3, 2.3)
	
	orig_sprite.position = Vector2.ZERO
	dummy_player.add_child(orig_sprite)
	
	if orig_sprite.sprite_frames and orig_sprite.sprite_frames.has_animation("run_up_right"):
		orig_sprite.play("run_up_right")
	elif orig_sprite.sprite_frames and orig_sprite.sprite_frames.has_animation("run_down_right"):
		orig_sprite.play("run_down_right")
	else:
		orig_sprite.play("default")
		
	var screen_size = get_viewport_rect().size
	dummy_player.position = Vector2(-80.0, screen_size.y - 70.0)
	
	# Place the runner above the background but behind UI panels
	add_child(dummy_player)
	var bg_idx = 0
	if get_node_or_null("Background"):
		bg_idx = get_node_or_null("Background").get_index()
	move_child(dummy_player, bg_idx + 1)
	
	set_process(true)

func _process(delta: float) -> void:
	if dummy_player:
		dummy_player.position.x += runner_speed * delta
		var screen_size = get_viewport_rect().size
		if dummy_player.position.x > screen_size.x + 80.0:
			dummy_player.position.x = -80.0
			dummy_player.position.y = screen_size.y - 70.0

# --- 3. Profile Management (PvZ Style) ---
func _update_profile_display():
	if btn_switch_profile:
		btn_switch_profile.text = "Welcome, " + SaveSystem.current_profile

func _open_profile_dialog():
	_refresh_profile_list()
	new_profile_input.text = ""
	$MenuButtons.visible = false
	upgrades_panel.visible = false
	profile_dialog.visible = true
	new_profile_input.grab_focus()

func _close_profile_dialog():
	profile_dialog.visible = false
	$MenuButtons.visible = true

func _refresh_profile_list():
	for child in profile_list.get_children():
		child.queue_free()
		
	var profiles = SaveSystem.profiles.keys()
	if profiles.is_empty():
		profiles = [SaveSystem.current_profile]
		
	profiles.sort()
	
	for p_name in profiles:
		var row = HBoxContainer.new()
		
		var p_btn = Button.new()
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.custom_minimum_size = Vector2(0, 38)
		p_btn.add_theme_font_size_override("font_size", 20)
		
		if p_name == SaveSystem.current_profile:
			p_btn.text = "> " + str(p_name) + "  (Current)"
			p_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		else:
			p_btn.text = str(p_name)
			
		p_btn.pressed.connect(func(): _select_profile(p_name))
		row.add_child(p_btn)
		
		var del_btn = Button.new()
		del_btn.text = " X "
		del_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		del_btn.pressed.connect(func(): _delete_profile(p_name))
		row.add_child(del_btn)
		
		profile_list.add_child(row)

func _delete_profile(profile_name: String):
	SaveSystem.delete_profile(profile_name)
	_refresh_profile_list()
	_update_profile_display()
	_update_upgrade_ui()

func _select_profile(profile_name: String):
	SaveSystem.switch_profile(profile_name)
	_update_profile_display()
	_update_upgrade_ui()
	_close_profile_dialog()

func _on_create_profile_pressed():
	var p_name = new_profile_input.text.strip_edges()
	if p_name == "":
		return
	_select_profile(p_name)

func _on_start_pressed():
	if SaveSystem.saved_dungeon_state.has("is_saved") and SaveSystem.saved_dungeon_state["is_saved"]:
		_show_resume_prompt()
	else:
		var wp = get_node_or_null("/root/WeaponProgress")
		if wp and wp.has_method("reset_progress"):
			wp.reset_progress()
		if SaveSystem.has_method("start_new_game"):
			SaveSystem.start_new_game()
		else:
			SaveSystem.clear_dungeon_state()
			SaveSystem.load_from_save = false
		get_tree().change_scene_to_file("res://Dungeon.tscn")

func _show_resume_prompt():
	var existing = get_node_or_null("ResumeDialogOverlay")
	if existing:
		existing.queue_free()
		
	var overlay = ColorRect.new()
	overlay.name = "ResumeDialogOverlay"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(480, 260)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var font_milky = load("res://UI/Milky Cream.otf")
	var font_harry = load("res://UI/HARRYP__.TTF")
	
	var bg_texture = load("res://UI/pause menu background.webp")
	if bg_texture:
		var style = StyleBoxTexture.new()
		style.texture = bg_texture
		panel.add_theme_stylebox_override("panel", style)
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.45, 0.30, 0.12, 1.0)
		style.border_color = Color(0.25, 0.15, 0.05, 1.0)
		style.set_border_width_all(4)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	vbox.offset_left = 30
	vbox.offset_right = -30
	vbox.offset_top = 26
	vbox.offset_bottom = -26
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "RESUME GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_harry: title.add_theme_font_override("font", font_harry)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.15, 0.07, 0.0))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "You have an unfinished dungeon run.\nDo you want to resume?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_milky: desc.add_theme_font_override("font", font_milky)
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.15, 0.08, 0.0))
	vbox.add_child(desc)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var btn_resume = Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(170, 48)
	if font_milky: btn_resume.add_theme_font_override("font", font_milky)
	btn_resume.add_theme_font_size_override("font_size", 24)
	btn_resume.add_theme_color_override("font_color", Color(0.08, 0.04, 0.0))
	
	var n_style = StyleBoxFlat.new()
	n_style.bg_color = Color(0.45, 0.30, 0.12, 1.0)
	n_style.border_color = Color(0.25, 0.15, 0.05, 1.0)
	n_style.set_border_width_all(3)
	n_style.corner_radius_top_left = 8
	n_style.corner_radius_top_right = 8
	n_style.corner_radius_bottom_left = 8
	n_style.corner_radius_bottom_right = 8
	btn_resume.add_theme_stylebox_override("normal", n_style)
	
	var h_style = n_style.duplicate() as StyleBoxFlat
	h_style.bg_color = Color(0.62, 0.46, 0.22, 1.0)
	btn_resume.add_theme_stylebox_override("hover", h_style)
	btn_resume.add_theme_stylebox_override("focus", h_style)
	
	btn_resume.pressed.connect(func():
		SaveSystem.load_from_save = true
		get_tree().change_scene_to_file("res://Dungeon.tscn")
	)
	hbox.add_child(btn_resume)
	
	var btn_new = Button.new()
	btn_new.text = "Start New"
	btn_new.custom_minimum_size = Vector2(170, 48)
	if font_milky: btn_new.add_theme_font_override("font", font_milky)
	btn_new.add_theme_font_size_override("font_size", 24)
	btn_new.add_theme_color_override("font_color", Color(0.08, 0.04, 0.0))
	btn_new.add_theme_stylebox_override("normal", n_style)
	btn_new.add_theme_stylebox_override("hover", h_style)
	btn_new.add_theme_stylebox_override("focus", h_style)
	
	btn_new.pressed.connect(func():
		var wp = get_node_or_null("/root/WeaponProgress")
		if wp and wp.has_method("reset_progress"):
			wp.reset_progress()
		if SaveSystem.has_method("start_new_game"):
			SaveSystem.start_new_game()
		else:
			SaveSystem.clear_dungeon_state()
			SaveSystem.load_from_save = false
		get_tree().change_scene_to_file("res://Dungeon.tscn")
	)
	hbox.add_child(btn_new)
	
	add_child(overlay)

func _on_quit_pressed():
	get_tree().quit()

func _on_upgrades_pressed():
	$MenuButtons.visible = false
	profile_dialog.visible = false
	upgrades_panel.visible = true
	_update_upgrade_ui()

func _on_back_pressed():
	upgrades_panel.visible = false
	$MenuButtons.visible = true

func _update_upgrade_ui():
	coins_label.text = "Gold Coins: " + str(SaveSystem.gold_coins)
	
	var hp_cost = 10 + (SaveSystem.upgrade_max_hp_level * 5)
	btn_hp.text = "Vitality (+10 Max HP)\nLevel: " + str(SaveSystem.upgrade_max_hp_level) + "  |  Cost: " + str(hp_cost)
	btn_hp.disabled = SaveSystem.gold_coins < hp_cost
	
	var dmg_cost = 10 + (SaveSystem.upgrade_damage_level * 5)
	btn_dmg.text = "Strength (+5 Damage)\nLevel: " + str(SaveSystem.upgrade_damage_level) + "  |  Cost: " + str(dmg_cost)
	btn_dmg.disabled = SaveSystem.gold_coins < dmg_cost
	
	var spd_cost = 10 + (SaveSystem.upgrade_speed_level * 5)
	btn_spd.text = "Agility (+10 Speed)\nLevel: " + str(SaveSystem.upgrade_speed_level) + "  |  Cost: " + str(spd_cost)
	btn_spd.disabled = SaveSystem.gold_coins < spd_cost

func _on_buy_hp():
	var cost = 10 + (SaveSystem.upgrade_max_hp_level * 5)
	if SaveSystem.spend_gold_coins(cost):
		SaveSystem.upgrade_max_hp_level += 1
		SaveSystem.save_game()
		_update_upgrade_ui()

func _on_buy_dmg():
	var cost = 10 + (SaveSystem.upgrade_damage_level * 5)
	if SaveSystem.spend_gold_coins(cost):
		SaveSystem.upgrade_damage_level += 1
		SaveSystem.save_game()
		_update_upgrade_ui()

func _on_buy_spd():
	var cost = 10 + (SaveSystem.upgrade_speed_level * 5)
	if SaveSystem.spend_gold_coins(cost):
		SaveSystem.upgrade_speed_level += 1
		SaveSystem.save_game()
		_update_upgrade_ui()
