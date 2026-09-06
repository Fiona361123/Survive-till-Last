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
	await _test_death_markers(packed)

	# Huang Wan Jun 2204536 - Integrate minimap progress with the dungeon HUD and entrances.
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	_expect(dungeon_scene != null, "Dungeon scene loads for minimap integration")
	if dungeon_scene != null:
		var dungeon := dungeon_scene.instantiate() as Node2D
		root.add_child(dungeon)
		_test_dungeon_geometry(dungeon)
		await process_frame
		var dungeon_minimap := dungeon.get_node_or_null(
			"LevelClearUI/DungeonMinimap"
		) as DungeonMinimap
		_expect(dungeon_minimap != null, "Dungeon HUD contains the progression minimap")
		if dungeon_minimap != null:
			_expect(dungeon_minimap.get_current_level() == 1,
				"Dungeon minimap starts on Level 1")
			dungeon.call("_on_level_entrance_entered", 2)
			_expect(dungeon_minimap.get_current_level() == 2,
				"entering Level 2 updates the dungeon minimap")
			_expect(dungeon_minimap.get_revealed_levels() == [1],
				"Dungeon starts with only Level 1 revealed")
			dungeon.call("unlock_path_after_level", 1)
			_expect(dungeon_minimap.get_revealed_levels() == [1, 2],
				"clearing Level 1 reveals Level 2")
			dungeon.call("unlock_path_after_level", 2)
			_expect(dungeon_minimap.get_revealed_levels() == [1, 2, 3],
				"clearing Level 2 reveals Level 3")
			dungeon.call("unlock_path_after_level", 3)
			_expect(dungeon_minimap.get_revealed_levels() == [1, 2, 3, 4],
				"clearing Level 3 reveals the boss section")
		dungeon.queue_free()
		await process_frame
	quit(0 if failures == 0 else 1)

# Huang Wan Jun 2204536 - Catch misplaced footprints using real scene transforms before actors move.
func _test_dungeon_geometry(dungeon: Node2D) -> void:
	var minimap := dungeon.get_node("LevelClearUI/DungeonMinimap") as DungeonMinimap
	_expect_section_contains(minimap, 1, dungeon.get_node("Player").global_position, "player start")
	_expect_section_contains(minimap, 1, dungeon.get_node("Map Size/skeleton").global_position, "Level 1 skeleton")
	for enemy in dungeon.get_node("Level2Enemies/InitialSkeletons").get_children():
		_expect_section_contains(minimap, 2, enemy.global_position, enemy.name)
	for spawn in dungeon.get_node("Level2Enemies/SpawnPoints").get_children():
		_expect_section_contains(minimap, 2, spawn.global_position, spawn.name)
	for enemy in dungeon.get_node("Level3Enemies").get_children():
		_expect_section_contains(minimap, 3, enemy.global_position, enemy.name)
	_expect_section_contains(minimap, 4, dungeon.get_node("RangedEnemy").global_position, "boss room enemy")
	for entry in [[2, "Level2Entrance"], [3, "Level3Entrance"], [4, "BossEntrance"]]:
		var collision := dungeon.get_node(String(entry[1]) + "/CollisionPolygon2D") as CollisionPolygon2D
		var center := Vector2.ZERO
		for vertex in collision.polygon:
			center += vertex
		center /= collision.polygon.size()
		_expect_section_contains(minimap, entry[0], collision.to_global(center), entry[1])
	_expect_section_contains(minimap, 4, Vector2(960, -1420), "boss entrance origin")
	var boundary := dungeon.get_node("Wall/FirstLevelWallArea/EnemyBoundary/BoundaryPolygon") as CollisionPolygon2D
	for vertex in boundary.polygon:
		_expect_section_contains(minimap, 1, boundary.to_global(vertex).lerp(Vector2(702, 99), 0.01), "Level 1 boundary interior")
	var map_boundary := dungeon.get_node("Map Size/CollisionPolygon2D") as CollisionPolygon2D
	for vertex in map_boundary.polygon:
		_expect(minimap.world_bounds.has_point(map_boundary.to_global(vertex)), "world bounds contain dungeon boundary")

# Huang Wan Jun 2204536 - Assert that actors occupy their section both in world space and on the drawn map.
func _expect_section_contains(minimap: DungeonMinimap, level: int, position: Vector2, label: String) -> void:
	var polygon: PackedVector2Array = DungeonMinimap.LEVEL_POLYGONS[level]
	_expect(Geometry2D.is_point_in_polygon(position, polygon), "%s lies in Level %d footprint" % [label, level])
	var mapped_polygon := PackedVector2Array()
	for vertex in polygon:
		mapped_polygon.append(minimap.world_to_minimap(vertex))
	_expect(Geometry2D.is_point_in_polygon(minimap.world_to_minimap(position), mapped_polygon),
		"%s marker lies on Level %d floor" % [label, level])

# Huang Wan Jun 2204536 - Exercise lethal damage on actual enemy scenes while their death animations remain alive.
func _test_death_markers(minimap_scene: PackedScene) -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var minimap := minimap_scene.instantiate() as DungeonMinimap
	arena.add_child(minimap)
	for scene_path in ["res://skeleton.tscn", "res://Enemy/slime.tscn", "res://RangedEnemy.tscn"]:
		var enemy := (load(scene_path) as PackedScene).instantiate() as Node2D
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.add_to_group("level1_enemy")
		arena.add_child(enemy)
		minimap.refresh_markers()
		_expect(minimap.get_enemy_markers().size() == 1, "%s living enemy is marked" % scene_path)
		enemy.call("take_damage", enemy.get("current_health"))
		_expect(enemy.is_inside_tree() and not enemy.is_queued_for_deletion(), "%s dead enemy remains in-tree for its animation" % scene_path)
		minimap.refresh_markers()
		_expect(minimap.get_enemy_markers().is_empty(), "%s zero-health enemy immediately disappears" % scene_path)
		await create_timer(0.2).timeout
		if is_instance_valid(enemy):
			enemy.queue_free()
		await process_frame
	arena.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
