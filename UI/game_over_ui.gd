extends BaseMenuUI

func _ready() -> void:
	layer = 20
	build_base_ui("GAME OVER", "You have been defeated...", Color(1.0, 0.2, 0.2), false)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# Button row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var replay = make_styled_button("Replay", Color(0.2, 0.8, 0.3), Vector2(140, 52), 20)
	replay.pressed.connect(_on_replay_pressed)
	hbox.add_child(replay)

	var exit = make_styled_button("Exit", Color(0.8, 0.2, 0.2), Vector2(140, 52), 20)
	exit.pressed.connect(_on_exit_pressed)
	hbox.add_child(exit)

	hide()

func show_game_over() -> void:
	show()
	get_tree().paused = true

func _on_replay_pressed() -> void:
	# Must unpause BEFORE any tree operations
	get_tree().paused = false
	# Free this UI node (it lives on root, outside the scene, so reload won't remove it)
	queue_free()
	# Reload deferred so queue_free finishes first
	get_tree().call_deferred("reload_current_scene")

func _on_exit_pressed() -> void:
	get_tree().quit()
