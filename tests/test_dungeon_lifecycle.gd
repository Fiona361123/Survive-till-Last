extends SceneTree


func _initialize() -> void:
	await process_frame
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	var dungeon := dungeon_scene.instantiate()
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
	assert(is_equal_approx(counter.offset_top, 140.0),
		"Level 4 lowers the enemy counter below Guard Halo")

	# Reproduce a scene reload while the Level 2 watcher is awaiting a frame.
	dungeon.queue_free()
	await process_frame
	await process_frame
	await process_frame

	print("Dungeon lifecycle watcher test passed.")
	quit(0)
