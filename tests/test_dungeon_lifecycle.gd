extends SceneTree


func _initialize() -> void:
	await process_frame
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	var dungeon := dungeon_scene.instantiate()
	dungeon.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(dungeon)
	await process_frame

	# Huang Wan Jun 2204536 - Connect the existing Level 4 entrance and HUD to the boss trial.
	var boss_encounter := dungeon.get_node_or_null("BossEncounter") as BossEncounterController
	assert(boss_encounter != null, "Dungeon contains the boss encounter")
	dungeon.call("_on_level_entrance_entered", 4)
	await process_frame
	assert(boss_encounter.get_encounter_state() == BossEncounterController.State.WAVE_1,
		"entering Level 4 starts Wave 1")
	dungeon.call("_update_enemy_counter")
	var counter := dungeon.get_node("LevelClearUI/EnemyCounterLabel") as Label
	assert(counter.visible and counter.text.contains("BOSS TRIAL - WAVE 1"),
		"Level 4 HUD announces Wave 1")
	# Huang Wan Jun 2204536 - Keep the boss-trial wording below Guard Halo like Level 3.
	assert(is_equal_approx(counter.position.y, 185.0),
		"Level 4 lowers the enemy counter below Guard Halo")

	# The preparation trial now starts the real boss instead of declaring an
	# early victory, and the boss is registered for Level 4 weapon targeting.
	boss_encounter.debug_complete_trial()
	await process_frame
	var final_boss: Node2D = dungeon.active_final_boss as Node2D
	assert(is_instance_valid(final_boss),
		"clearing the boss trial creates the final boss")
	assert(final_boss.is_in_group("enemy") and final_boss.is_in_group("boss_enemy"),
		"final boss belongs to the common and Level 4 weapon target groups")
	assert(not dungeon.win_screen_shown,
		"clearing preparation waves does not show the victory screen")
	assert(final_boss.is_connected(
		"boss_defeated", Callable(dungeon, "_on_final_boss_defeated")
	), "final boss defeat is connected to the real victory flow")

	# Reproduce a scene reload while the Level 2 watcher is awaiting a frame.
	dungeon.queue_free()
	await process_frame
	await process_frame
	await process_frame

	print("Dungeon lifecycle watcher test passed.")
	quit(0)
