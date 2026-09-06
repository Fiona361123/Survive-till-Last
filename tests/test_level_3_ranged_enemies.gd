extends SceneTree

var failures := 0


func _initialize() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	_expect(dungeon_scene != null, "Dungeon scene loads")
	if dungeon_scene == null:
		quit(1)
		return

	var dungeon := dungeon_scene.instantiate()
	root.add_child(dungeon)
	await process_frame

	var level_3_enemies := dungeon.get_node_or_null("Level3Enemies") as Node2D
	_expect(level_3_enemies != null, "Level 3 has a dedicated enemy container")
	if level_3_enemies != null:
		_expect(level_3_enemies.get_child_count() == 6,
			"Level 3 contains exactly six ranged enemies")
		for enemy in level_3_enemies.get_children():
			_expect(enemy.is_in_group("level3_enemy"),
				"every Level 3 ranged enemy belongs to level3_enemy")

	var counter := dungeon.get_node("LevelClearUI/EnemyCounterLabel") as Label
	_expect(is_equal_approx(counter.offset_top, 24.0),
		"enemy counter starts at its normal top position")
	dungeon.call("_on_level_entrance_entered", 2)
	dungeon.call("_complete_level_two")
	_expect(is_equal_approx(counter.offset_top, 140.0),
		"clearing Level 2 immediately lowers its completed counter")
	dungeon.set("level_2_cleared", false)
	dungeon.call("_on_level_entrance_entered", 3)
	_expect(is_equal_approx(counter.offset_top, 140.0),
		"Level 3 moves the enemy counter below the Guard Halo panel")
	dungeon.call("_on_level_entrance_entered", 2)
	_expect(is_equal_approx(counter.offset_top, 24.0),
		"leaving Level 3 restores the normal enemy-counter position")
	dungeon.call("_on_level_entrance_entered", 3)
	dungeon.call("_update_enemy_counter")
	_expect(counter.text.contains("0 / 6") and counter.text.contains("Enemies Left: 6"),
		"Level 3 counter starts at zero defeated and six remaining")

	if level_3_enemies != null:
		for enemy in level_3_enemies.get_children():
			enemy.queue_free()
	await process_frame
	await process_frame
	_expect(dungeon.get("level_3_cleared") == true,
		"defeating all six ranged enemies clears Level 3")

	dungeon.queue_free()
	await process_frame
	if failures == 0:
		print("Level 3 ranged-enemy tests passed.")
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
