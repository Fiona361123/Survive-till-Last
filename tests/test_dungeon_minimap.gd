extends SceneTree

var failures: int = 0

func _initialize() -> void:
	var packed := load("res://UI/DungeonMinimap.tscn") as PackedScene
	_expect(packed != null, "minimap scene loads")
	if packed == null:
		quit(1)
		return
	var minimap := packed.instantiate() as DungeonMinimap
	root.add_child(minimap)
	await process_frame

	# Huang Wan Jun 2204536 - Verify the minimap layout, initial reveal, and shared transform.
	_expect(minimap.anchor_left == 1.0 and minimap.anchor_top == 1.0, "minimap anchors to bottom-right")
	_expect(minimap.offset_right == -24.0 and minimap.offset_bottom == -24.0, "minimap keeps a 24 pixel edge gap")
	_expect(minimap.size == Vector2(230.0, 160.0), "minimap has the designed compact size")
	_expect(minimap.get_revealed_levels() == [1], "only Level 1 starts revealed")
	minimap.reveal_level(2)
	minimap.reveal_level(2)
	_expect(minimap.get_revealed_levels() == [1, 2], "reveals are permanent and idempotent")
	var top_left := minimap.world_to_minimap(minimap.world_bounds.position)
	var bottom_right := minimap.world_to_minimap(minimap.world_bounds.end)
	_expect(minimap.get_drawable_rect().has_point(top_left), "world minimum maps inside drawable area")
	_expect(minimap.get_drawable_rect().has_point(bottom_right), "world maximum maps inside drawable area")
	_expect(top_left.x < bottom_right.x and top_left.y < bottom_right.y, "world transform preserves direction")

	var player := Node2D.new()
	player.global_position = Vector2(-5500.0, 800.0)
	player.add_to_group("player")
	root.add_child(player)
	var level_1_enemy := Node2D.new()
	level_1_enemy.global_position = Vector2(-3000.0, 100.0)
	level_1_enemy.add_to_group("level1_enemy")
	root.add_child(level_1_enemy)
	var level_2_enemy := Node2D.new()
	level_2_enemy.global_position = Vector2(500.0, 400.0)
	level_2_enemy.add_to_group("level2_enemy")
	root.add_child(level_2_enemy)

	# Huang Wan Jun 2204536 - Show the player and only living enemies from the active level.
	minimap.set_current_level(1)
	minimap.refresh_markers()
	_expect(minimap.get_player_marker() == minimap.world_to_minimap(player.global_position), "player marker follows player")
	_expect(minimap.get_enemy_markers().size() == 1, "Level 1 hides Level 2 enemies")
	minimap.set_current_level(2)
	minimap.refresh_markers()
	_expect(minimap.get_enemy_markers()[0] == minimap.world_to_minimap(level_2_enemy.global_position), "Level 2 shows its own enemy")
	level_2_enemy.queue_free()
	await process_frame
	minimap.refresh_markers()
	_expect(minimap.get_enemy_markers().is_empty(), "freed enemies disappear")
	player.queue_free()
	await process_frame
	minimap.refresh_markers()
	_expect(minimap.get_player_marker() == null, "missing player is tolerated")
	minimap.set_current_level(4)
	minimap.refresh_markers()
	_expect(minimap.get_enemy_markers().is_empty(), "missing boss group is tolerated")
	level_1_enemy.queue_free()
	await process_frame

	minimap.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
