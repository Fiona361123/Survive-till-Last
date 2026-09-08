@tool
extends EditorScript

func _run():
	var root = Control.new()
	root.name = "MainMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg = TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://Isometric/stoneTile_N.png")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	bg.owner = root
	
	var title = Label.new()
	title.name = "Title"
	title.text = "SURVIVE TILL LAST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 50)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0,0,0))
	title.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(title)
	title.owner = root
	
	var vbox = VBoxContainer.new()
	vbox.name = "MenuButtons"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	root.add_child(vbox)
	vbox.owner = root
	
	var btn_start = Button.new()
	btn_start.name = "StartButton"
	btn_start.text = "Start Game"
	btn_start.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(btn_start)
	btn_start.owner = root
	
	var btn_upgrades = Button.new()
	btn_upgrades.name = "UpgradesButton"
	btn_upgrades.text = "Upgrades"
	btn_upgrades.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(btn_upgrades)
	btn_upgrades.owner = root
	
	var btn_quit = Button.new()
	btn_quit.name = "QuitButton"
	btn_quit.text = "Quit"
	btn_quit.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(btn_quit)
	btn_quit.owner = root
	
	# Upgrades Panel
	var upgrades_panel = Panel.new()
	upgrades_panel.name = "UpgradesPanel"
	upgrades_panel.set_anchors_preset(Control.PRESET_CENTER)
	upgrades_panel.custom_minimum_size = Vector2(600, 400)
	upgrades_panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9) # Dark semi-transparent
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	upgrades_panel.add_theme_stylebox_override("panel", style)
	root.add_child(upgrades_panel)
	upgrades_panel.owner = root
	
	var up_title = Label.new()
	up_title.name = "UpgradesTitle"
	up_title.text = "Permanent Upgrades"
	up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	up_title.add_theme_font_size_override("font_size", 32)
	upgrades_panel.add_child(up_title)
	up_title.owner = root
	
	var coins_label = Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.text = "Blue Coins: 0"
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 60)
	coins_label.add_theme_font_size_override("font_size", 24)
	coins_label.add_theme_color_override("font_color", Color(0.2, 0.5, 1.0))
	upgrades_panel.add_child(coins_label)
	coins_label.owner = root
	
	var up_vbox = VBoxContainer.new()
	up_vbox.name = "UpgradeList"
	up_vbox.set_anchors_preset(Control.PRESET_CENTER)
	up_vbox.add_theme_constant_override("separation", 15)
	upgrades_panel.add_child(up_vbox)
	up_vbox.owner = root
	
	var btn_hp = Button.new()
	btn_hp.name = "BtnHP"
	btn_hp.text = "Vitality (+10 Max HP) - Cost: 10"
	btn_hp.custom_minimum_size = Vector2(300, 40)
	up_vbox.add_child(btn_hp)
	btn_hp.owner = root
	
	var btn_dmg = Button.new()
	btn_dmg.name = "BtnDamage"
	btn_dmg.text = "Strength (+5 Damage) - Cost: 10"
	btn_dmg.custom_minimum_size = Vector2(300, 40)
	up_vbox.add_child(btn_dmg)
	btn_dmg.owner = root
	
	var btn_spd = Button.new()
	btn_spd.name = "BtnSpeed"
	btn_spd.text = "Agility (+10 Speed) - Cost: 10"
	btn_spd.custom_minimum_size = Vector2(300, 40)
	up_vbox.add_child(btn_spd)
	btn_spd.owner = root
	
	var btn_back = Button.new()
	btn_back.name = "BtnBack"
	btn_back.text = "Back"
	btn_back.custom_minimum_size = Vector2(100, 40)
	btn_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	upgrades_panel.add_child(btn_back)
	btn_back.owner = root
	
	# Save scene
	var scene = PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, "res://UI/MainMenu.tscn")
	print("MainMenu.tscn created!")
