extends BaseMenuUI

func _ready() -> void:
	layer = 20
	build_base_ui("VICTORY", "You have conquered the dungeon!", Color(1.0, 0.8, 0.2), false)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# Button row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var replay = make_styled_button("Play Again", Color(0.2, 0.8, 0.3), Vector2(180, 52), 20)
	replay.pressed.connect(_on_replay_pressed)
	hbox.add_child(replay)

	var exit = make_styled_button("Main Menu", Color(0.8, 0.2, 0.2), Vector2(180, 52), 20)
	exit.pressed.connect(_on_exit_pressed)
	hbox.add_child(exit)

	hide()

func show_game_win() -> void:
	if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").play_win()
	show()
	get_tree().paused = true

func _on_replay_pressed() -> void:
	# Must unpause BEFORE any tree operations
	get_tree().paused = false
	var weapon_progress = get_node_or_null("/root/WeaponProgress")
	if weapon_progress != null and weapon_progress.has_method("reset_progress"):
		weapon_progress.reset_progress()
	if SaveSystem.has_method("start_new_game"):
		SaveSystem.start_new_game()
	else:
		SaveSystem.clear_dungeon_state()
	queue_free()
	get_tree().call_deferred("reload_current_scene")

func _on_exit_pressed() -> void:
	get_tree().paused = false
	SaveSystem.clear_dungeon_state()
	queue_free()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
