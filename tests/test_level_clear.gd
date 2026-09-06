extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_level_exit_stays_in_dungeon_and_announces_level_two()
	_test_dungeon_scene_has_level_clear_nodes()
	await _test_level_three_trap_lifecycle()
	await _test_enemy_spawn_positions_clear_solid_walls()
	await _test_level_two_skeleton_wave()
	await _test_debug_clear_removes_level_one_enemies()
	await _test_debug_clear_removes_level_two_enemies()

	if failures == 0:
		print("Level-clear tests passed.")
		quit(0)
	else:
		push_error("%d level-clear test(s) failed." % failures)
		quit(1)


func _test_level_exit_stays_in_dungeon_and_announces_level_two() -> void:
	var exit_script := load("res://level_exit.gd") as GDScript
	_expect(exit_script != null, "level_exit.gd can be loaded")
	if exit_script == null:
		return

	var level_exit: Node = Area2D.new()
	level_exit.set_script(exit_script)
	root.add_child(level_exit)
	await process_frame

	_expect(level_exit.get("unlocked") == false, "LevelExit starts locked")

	var entered_level: Array[int] = [0]
	level_exit.connect("level_entered", func(level_number: int) -> void:
		entered_level[0] = level_number
	)

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	root.add_child(player)
	level_exit.call("_on_body_entered", player)
	_expect(entered_level[0] == 0, "locked LevelExit ignores the player")

	level_exit.call("unlock_exit")
	_expect(level_exit.get("unlocked") == true, "unlock_exit unlocks LevelExit")
	level_exit.call("_on_body_entered", player)
	_expect(entered_level[0] == 2, "unlocked LevelExit announces entry to Level 2")

	player.queue_free()
	level_exit.queue_free()


func _test_dungeon_scene_has_level_clear_nodes() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	_expect(dungeon_scene != null, "Dungeon.tscn can be loaded")
	if dungeon_scene == null:
		return

	var dungeon := dungeon_scene.instantiate() as Node2D
	_expect(dungeon.get_node_or_null("ExitToLevel2") is TileMapLayer,
		"Dungeon has a separate Level 2 gate layer")
	_expect(dungeon.get_node_or_null("ExitToLevel3") is TileMapLayer,
		"Dungeon has a separate Level 3 gate layer")
	_expect(dungeon.get_node_or_null("ExitToBoss") is TileMapLayer,
		"Dungeon has a separate boss gate layer")
	var level_1_obstacles := dungeon.get_node_or_null("Level1Obstacles") as TileMapLayer
	_expect(level_1_obstacles != null,
		"Dungeon has an independent Level 1 obstacle layer")
	if level_1_obstacles:
		# Huang Wan Jun 2204536 - Preserve the player's original two-tile Level 1 layout.
		_expect(level_1_obstacles.get_used_cells().size() == 2,
			"Level 1 preserves exactly two dungeon obstacles")
		_expect(level_1_obstacles.get_used_cells().has(Vector2i(0, 4))
			and level_1_obstacles.get_used_cells().has(Vector2i(1, 4)),
			"Level 1 preserves the player's obstacle cells (0,4) and (1,4)")
		_expect(level_1_obstacles.tile_set != null
			and level_1_obstacles.tile_set.get_physics_layers_count() > 0,
			"Level 1 obstacle TileSet contains collision")
		for obstacle_cell in level_1_obstacles.get_used_cells():
			_expect(level_1_obstacles.get_cell_source_id(obstacle_cell) == 27,
				"Level 1 obstacles use the selected stoneWallHalf_N tile")
			var obstacle_tile_data := level_1_obstacles.get_cell_tile_data(obstacle_cell)
			_expect(obstacle_tile_data != null
				and obstacle_tile_data.get_collision_polygons_count(0) > 0,
				"Level 1 obstacle at (%d,%d) blocks movement" % [
					obstacle_cell.x, obstacle_cell.y
				])
	_expect(dungeon.get_node_or_null("Level2Obstacles") is TileMapLayer,
		"Dungeon has an independent Level 2 obstacle layer")
	var level_2_walls := dungeon.get_node_or_null("Level2Walls") as TileMapLayer
	_expect(level_2_walls != null,
		"Dungeon has a separate Level 2 wall layer")
	if level_2_walls:
		_expect(level_2_walls.get_used_cells().size() >= 100,
			"Level 2 walls surround the outer arena perimeter")
		for entrance_x in range(4, 7):
			_expect(level_2_walls.get_cell_source_id(Vector2i(entrance_x, 18)) == -1,
				"Level 2 wall entrance remains open at x=%d" % entrance_x)
	# Huang Wan Jun 2204536
	_expect(dungeon.get_node_or_null("Level2BridgeSystem") is Node2D,
		"Dungeon has the Level 2 bridge system")
	_expect(dungeon.get_node_or_null("Level2BridgeSystem/SafeBridge") is TileMapLayer,
		"Level 2 has a safe alternative bridge")
	var safe_bridge := dungeon.get_node_or_null("Level2BridgeSystem/SafeBridge") as TileMapLayer
	if safe_bridge and safe_bridge.tile_set:
		# Huang Wan Jun 2204536 - Flat bridge surfaces render below the player.
		var dungeon_player := dungeon.get_node_or_null("Player") as CharacterBody2D
		_expect(dungeon_player != null and safe_bridge.z_index < dungeon_player.z_index,
			"safe bridge renders below the player")
		_expect(safe_bridge.tile_set.get_physics_layers_count() == 0,
			"safe bridge visuals do not block top-down movement")
		# Huang Wan Jun 2204536 - Keep every bridge direction available for painting.
		var bridge_texture_paths: Array[String] = []
		for source_index in safe_bridge.tile_set.get_source_count():
			var source_id := safe_bridge.tile_set.get_source_id(source_index)
			var atlas := safe_bridge.tile_set.get_source(source_id) as TileSetAtlasSource
			if atlas != null and atlas.texture != null:
				bridge_texture_paths.append(atlas.texture.resource_path)
		for direction in ["E", "N", "S", "W"]:
			_expect(
				"res://Isometric/bridge_%s.png" % direction in bridge_texture_paths,
				"safe bridge TileSet includes the %s bridge direction" % direction
			)
			# Huang Wan Jun 2204536 - Wide bridges remain selectable beside narrow bridges.
			_expect(
				"res://Isometric/bridgeWide_%s.png" % direction in bridge_texture_paths,
				"safe bridge TileSet includes the wide %s bridge direction" % direction
			)
	var section_names: Array[String] = ["UnstableSection1", "UnstableSection2", "UnstableSection3"]
	for section_name in section_names:
		var section := dungeon.get_node_or_null("Level2BridgeSystem/" + section_name) as CollapsingBridgeSection
		_expect(section is CollapsingBridgeSection,
			"Level 2 has independent " + section_name)
		if section:
			var section_tile := section.get_node_or_null("BridgeTile") as TileMapLayer
			_expect(section_tile != null and section_tile.tile_set != null
				and section_tile.tile_set.get_physics_layers_count() == 0,
				section_name + " visual does not block top-down movement")
	_expect(dungeon.get_node_or_null("Level2BridgeSystem/SafeRespawnLeft") is Marker2D,
		"Level 2 has a left safe respawn marker")
	_expect(dungeon.get_node_or_null("Level2BridgeSystem/SafeRespawnRight") is Marker2D,
		"Level 2 has a right safe respawn marker")
	# Huang Wan Jun 2204536 - Level 2 currently uses one permanent fall-hazard row.
	var permanent_fall_areas := dungeon.get_node_or_null(
		"Level2BridgeSystem/PermanentFallAreas"
	) as Node2D
	_expect(permanent_fall_areas != null, "Level 2 has permanent fall areas")
	if permanent_fall_areas:
		var row_29_hazard := permanent_fall_areas.get_node_or_null("FallHazardRow29") as FallHazard
		_expect(row_29_hazard is FallHazard,
			"Level 2 keeps FallHazardRow29")
		# Huang Wan Jun 2204536 - Permanent holes detect player layer 2 and enemy layer 4.
		if row_29_hazard:
			_expect((row_29_hazard.collision_mask & 2) != 0,
				"permanent holes detect the player collision layer")
			_expect((row_29_hazard.collision_mask & 4) != 0,
				"permanent holes detect the enemy collision layer")
		for removed_row in range(30, 34):
			_expect(
				permanent_fall_areas.get_node_or_null("FallHazardRow%d" % removed_row) == null,
				"Level 2 does not keep FallHazardRow%d" % removed_row
			)
	_assert_level_2_routes_clear_permanent_hazards(dungeon)
	var level_2_obstacles := dungeon.get_node_or_null("Level2Obstacles") as TileMapLayer
	if level_2_obstacles:
		# Huang Wan Jun 2204536 - Every painted Level 2 obstacle must physically block the player.
		_expect(not level_2_obstacles.get_used_cells().is_empty(),
			"Level 2 obstacle layer contains the player's obstacle design")
		var used_source_ids: Dictionary = {}
		for obstacle_cell in level_2_obstacles.get_used_cells():
			used_source_ids[level_2_obstacles.get_cell_source_id(obstacle_cell)] = true
		for obstacle_source_id in used_source_ids:
			var obstacle_tile_data := level_2_obstacles.get_cell_tile_data(
				level_2_obstacles.get_used_cells_by_id(int(obstacle_source_id))[0]
			)
			_expect(
				obstacle_tile_data != null
				and obstacle_tile_data.get_collision_polygons_count(0) > 0,
				"painted Level 2 obstacle source %d blocks the player" % int(obstacle_source_id)
			)
	_expect(dungeon.get_node_or_null("Level2Entrance") is Area2D,
		"Dungeon has a Level 2 entrance")
	_expect(dungeon.get_node_or_null("Level3Entrance") is Area2D,
		"Dungeon has a Level 3 entrance")
	_expect(dungeon.get_node_or_null("BossEntrance") is Area2D,
		"Dungeon has a boss entrance")
	_expect(dungeon.get_node_or_null("Level2Entrance/CollisionPolygon2D") is CollisionPolygon2D,
		"Level 2 entrance uses an editable collision polygon")
	_expect(dungeon.get_node_or_null("Level3Entrance/CollisionPolygon2D") is CollisionPolygon2D,
		"Level 3 entrance uses an editable collision polygon")
	_expect(dungeon.get_node_or_null("BossEntrance/CollisionPolygon2D") is CollisionPolygon2D,
		"Boss entrance uses an editable collision polygon")
	_expect(dungeon.get_node_or_null("Enemy") == null,
		"Dungeon has no hidden untracked enemy")
	_expect(dungeon.get_node_or_null("skeleton") == null,
		"Dungeon has no legacy root skeleton that auto-spawns untracked enemies")
	# Huang Wan Jun 2204536 - Corridor walls use a shallow diagonal footprint at the wall base.
	var wall_layer := dungeon.get_node_or_null("Wall") as TileMapLayer
	if wall_layer != null:
		for wall_cell in wall_layer.get_used_cells():
			var wall_tile_data := wall_layer.get_cell_tile_data(wall_cell)
			if wall_tile_data == null or wall_tile_data.get_collision_polygons_count(0) == 0:
				continue
			var wall_polygon := wall_tile_data.get_collision_polygon_points(0, 0)
			var twice_area: float = 0.0
			var longest_edge: float = 0.0
			for point_index in wall_polygon.size():
				var next_index: int = (point_index + 1) % wall_polygon.size()
				twice_area += wall_polygon[point_index].cross(wall_polygon[next_index])
				longest_edge = maxf(
					longest_edge,
					wall_polygon[point_index].distance_to(wall_polygon[next_index])
				)
			var effective_thickness: float = absf(twice_area) / (2.0 * longest_edge)
			_expect(effective_thickness <= 24.0,
				"wall collision footprint remains shallow beside the wall")
	var first_level_spawn_area := dungeon.get_node_or_null("Wall/FirstLevelWallArea") as Area2D
	var dungeon_player := dungeon.get_node_or_null("Player") as CharacterBody2D
	_expect(
		first_level_spawn_area != null
		and dungeon_player != null
		and (first_level_spawn_area.collision_mask & dungeon_player.collision_layer) != 0,
		"Level 1 spawn area detects the Player collision layer"
	)
	# Huang Wan Jun 2204536 - Every entrance must listen for the Player's physics layer.
	for entrance_path in ["Level2Entrance", "Level3Entrance", "BossEntrance"]:
		var entrance := dungeon.get_node_or_null(entrance_path) as Area2D
		_expect(
			entrance != null
			and dungeon_player != null
			and (entrance.collision_mask & dungeon_player.collision_layer) != 0,
			"%s detects the Player collision layer" % entrance_path
		)

	var level_2_gates := dungeon.get_node_or_null("ExitToLevel2") as TileMapLayer
	_expect(
		level_2_gates != null
		and level_2_gates.tile_set != null
		and level_2_gates.tile_set.get_physics_layers_count() > 0,
		"closed gate TileSet has a physics collision layer"
	)
	_expect(dungeon.get_node_or_null("LevelClearUI/ClearLabel") is Label,
		"Dungeon has a LevelClearUI/ClearLabel")
	_expect(dungeon.get_node_or_null("LevelClearUI/EnemyCounterLabel") is Label,
		"Dungeon has a LevelClearUI/EnemyCounterLabel")
	# Huang Wan Jun 2204536 - The dungeon HUD must contain the progression minimap.
	_expect(dungeon.get_node_or_null("LevelClearUI/DungeonMinimap") is DungeonMinimap,
		"Dungeon has a bottom-right progression minimap")
	_expect((dungeon.get_node_or_null("LevelClearUI") as CanvasLayer).visible,
		"Level clear UI canvas remains visible for the enemy counter")
	var level_3_traps := dungeon.get_node_or_null("Level3Traps") as Node2D
	_expect(level_3_traps != null, "Level 3 has a trap controller")
	var spike_rows := dungeon.get_node_or_null("Level3Traps/SpikeRows")
	_expect(spike_rows != null and spike_rows.get_child_count() == 3,
		"Level 3 has exactly three spike rows")
	var spike_editor_visuals := dungeon.get_node_or_null("Level3Traps/SpikeEditorVisuals")
	_expect(spike_editor_visuals != null and spike_editor_visuals.get_child_count() == 8,
		"Dungeon stores eight direct spike-tile previews for the authored 3/2/3 layout")
	if spike_rows != null:
		var authored_tile_counts: Array[int] = []
		for row in spike_rows.get_children():
			var spike_row := row as SpikeRow
			_expect(spike_row != null and spike_row.scale == Vector2.ONE
				and is_zero_approx(spike_row.rotation),
				"Level 3 spike clusters use unscaled isometric placement")
			if spike_row != null:
				authored_tile_counts.append(spike_row.tile_count)
		_expect(authored_tile_counts == [3, 2, 3],
			"Level 3 uses three short, intentionally varied spike clusters")
	_expect(dungeon.get_node_or_null("Level3Traps/FireSweep") != null,
		"Level 3 has one fire sweep")
	var rock_targets := dungeon.get_node_or_null("Level3Traps/RockTargets")
	_expect(rock_targets != null and rock_targets.get_child_count() >= 2,
		"Level 3 has authored rock targets")
	_expect(dungeon.get_node_or_null("Level3Traps/EntranceSafeArea") is Area2D,
		"Level 3 entrance is protected from random strikes")
	if level_3_traps != null:
		_assert_trap_damage_masks(level_3_traps, "authored Level 3 trap")
		var rock_strike_scene := level_3_traps.get("rock_strike_scene") as PackedScene
		_expect(rock_strike_scene != null, "Level 3 controller has a RockStrike scene")
		if rock_strike_scene != null:
			var rock_strike := rock_strike_scene.instantiate()
			_assert_trap_damage_masks(rock_strike, "Level 3 RockStrike")
			rock_strike.free()
	dungeon.queue_free()


func _test_level_three_trap_lifecycle() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	if dungeon_scene == null:
		_expect(false, "Dungeon loads for the Level 3 trap lifecycle")
		return

	var dungeon := dungeon_scene.instantiate() as Node2D
	root.add_child(dungeon)
	await process_frame
	var level_3_traps := dungeon.get_node_or_null("Level3Traps")
	_expect(level_3_traps != null and level_3_traps.get("is_running") == false,
		"Level 3 traps begin stopped")
	dungeon.call("_on_level_entrance_entered", 3)
	_expect(level_3_traps != null and level_3_traps.get("is_running") == true,
		"entering Level 3 starts its traps")
	dungeon.call("_complete_level_three")
	_expect(level_3_traps != null and level_3_traps.get("is_running") == false,
		"clearing Level 3 stops its traps before the clear-message wait")
	dungeon.queue_free()
	await process_frame


func _assert_trap_damage_masks(trap_root: Node, label: String) -> void:
	var damage_areas := trap_root.find_children("TrapDamageArea", "Area2D", true, false)
	_expect(not damage_areas.is_empty(), "%s has a damage area" % label)
	for damage_area in damage_areas:
		_expect((damage_area as Area2D).collision_mask == 6,
			"%s damage area detects player and enemy layers" % label)


func _test_enemy_spawn_positions_clear_solid_walls() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	if dungeon_scene == null:
		_expect(false, "Dungeon loads for enemy spawn clearance checks")
		return

	var dungeon := dungeon_scene.instantiate() as Node2D
	root.add_child(dungeon)
	await physics_frame

	var spawner := dungeon.get_node("Wall/FirstLevelWallArea")
	spawner.set("spawn_delay", 0.0)
	spawner.call("spawn_enemies_from_holes")
	await physics_frame
	var wall_target := spawner.get_node("WallTarget") as Marker2D
	for enemy_node in get_nodes_in_group("level1_enemy"):
		var enemy := enemy_node as CollisionObject2D
		_expect(enemy != null and not _body_overlaps_solid_world(enemy),
			"Level 1 spawned enemy clears solid wall collision")
		_expect(enemy != null and not _solid_world_blocks_segment(
			enemy, enemy.global_position, wall_target.global_position
		), "Level 1 spawned enemy has an unobstructed route into the arena")

	for enemy_node in dungeon.call("_get_level_two_enemy_nodes") as Array:
		var enemy := enemy_node as CollisionObject2D
		_expect(enemy != null and not _body_overlaps_solid_world(enemy),
			"Level 2 placed enemy clears solid wall collision")

	dungeon.call("_spawn_level_two_second_wave")
	await physics_frame
	var second_wave := dungeon.get_node("Level2Enemies/SecondWave") as Node2D
	for enemy_node in second_wave.get_children():
		var enemy := enemy_node as CollisionObject2D
		_expect(enemy != null and not _body_overlaps_solid_world(enemy),
			"Level 2 spawned enemy clears solid wall collision")

	dungeon.queue_free()
	await process_frame


func _body_overlaps_solid_world(body: CollisionObject2D) -> bool:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return true
	body.force_update_transform()
	collision.force_update_transform()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [body.get_rid()]
	return not body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _solid_world_blocks_segment(
	body: CollisionObject2D, from: Vector2, to: Vector2
) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [body.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _test_level_two_skeleton_wave() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	_expect(dungeon_scene != null, "Dungeon scene loads for the Level 2 skeleton wave")
	if dungeon_scene == null:
		return
	var dungeon := dungeon_scene.instantiate() as Node2D
	root.add_child(dungeon)
	await process_frame
	var level_2_enemies := dungeon.get_node_or_null("Level2Enemies") as Node2D
	var initial_skeletons := dungeon.get_node_or_null(
		"Level2Enemies/InitialSkeletons"
	) as Node2D
	var spawn_points := dungeon.get_node_or_null("Level2Enemies/SpawnPoints") as Node2D
	_expect(level_2_enemies != null, "Dungeon has a Level2Enemies container")
	_expect(initial_skeletons != null and initial_skeletons.get_child_count() == 7,
		"Level 2 begins with exactly seven placed skeletons")
	_expect(spawn_points != null and spawn_points.get_child_count() == 8,
		"Level 2 has exactly eight second-wave spawn points")
	if initial_skeletons == null or spawn_points == null:
		dungeon.queue_free()
		await process_frame
		return
	for skeleton_node in initial_skeletons.get_children():
		_expect(skeleton_node.is_in_group("level2_enemy"),
			"every placed Level 2 skeleton belongs to level2_enemy")
		skeleton_node.queue_free()
	await process_frame
	await process_frame
	# Huang Wan Jun 2204536 - The second wave appears once after all seven placed skeletons die.
	_expect(dungeon.get("level_2_second_wave_spawned") == true,
		"defeating the first seven skeletons starts the second wave")
	var second_wave := dungeon.get_node_or_null("Level2Enemies/SecondWave") as Node2D
	_expect(second_wave != null and second_wave.get_child_count() == 8,
		"the Level 2 second wave contains exactly eight skeletons")
	if second_wave:
		for skeleton_node in second_wave.get_children():
			_expect(skeleton_node.is_in_group("level2_enemy"),
				"every spawned Level 2 skeleton belongs to level2_enemy")
	dungeon.call("_on_level_entrance_entered", 2)
	await process_frame
	var counter_label := dungeon.get_node_or_null("LevelClearUI/EnemyCounterLabel") as Label
	_expect(counter_label != null and "Enemies Killed: 7 / 15" in counter_label.text,
		"Level 2 counter includes the defeated first wave")
	_expect(counter_label != null and "Enemies Left: 8" in counter_label.text,
		"Level 2 counter includes the eight remaining enemies")
	if second_wave:
		for skeleton_node in second_wave.get_children():
			skeleton_node.queue_free()
	await process_frame
	await process_frame
	# Huang Wan Jun 2204536 - Clearing all fifteen Level 2 enemies announces and unlocks Level 3.
	_expect(dungeon.get("level_2_cleared") == true,
		"defeating both Level 2 waves completes Level 2 once")
	var clear_label := dungeon.get_node_or_null("LevelClearUI/ClearLabel") as Label
	_expect(clear_label != null and clear_label.visible
		and "LEVEL 2 CLEAR!" in clear_label.text,
		"Level 2 displays its clear message")
	_expect(counter_label != null and "Enemies Killed: 15 / 15" in counter_label.text
		and "Enemies Left: 0" in counter_label.text,
		"Level 2 counter reaches fifteen defeated and zero left")
	var level_3_gate := dungeon.get_node_or_null("ExitToLevel3") as TileMapLayer
	var level_3_entrance := dungeon.get_node_or_null("Level3Entrance")
	_expect(level_3_gate != null and level_3_gate.get_used_cells().is_empty(),
		"Level 2 completion removes the Level 3 blocking tiles")
	_expect(level_3_entrance != null and level_3_entrance.get("unlocked") == true,
		"Level 2 completion unlocks the Level 3 entrance")
	dungeon.queue_free()
	await process_frame


func _assert_level_2_routes_clear_permanent_hazards(dungeon: Node2D) -> void:
	var floor := dungeon.get_node_or_null("Floor") as TileMapLayer
	var safe_bridge := dungeon.get_node_or_null("Level2BridgeSystem/SafeBridge") as TileMapLayer
	var player_collision := dungeon.get_node_or_null("Player/CollisionShape2D") as CollisionShape2D
	var permanent_areas := dungeon.get_node_or_null("Level2BridgeSystem/PermanentFallAreas") as Node2D
	if floor == null or safe_bridge == null or player_collision == null or permanent_areas == null:
		_expect(false, "route-clearance geometry inputs exist")
		return
	var player_shape := player_collision.shape as RectangleShape2D
	if player_shape == null:
		_expect(false, "Player uses its expected rectangle collision shape")
		return
	var half_size := player_shape.size * 0.5
	for safe_cell in safe_bridge.get_used_cells():
		var safe_position := safe_bridge.position + safe_bridge.map_to_local(safe_cell)
		_expect(not _permanent_hazards_contain_point(dungeon, permanent_areas, safe_position),
			"safe bridge cell (%d,%d) logical position clears permanent hazards" % [
				safe_cell.x, safe_cell.y
			])
	var island_rows: Array[int] = [28, 30]
	for island_y in island_rows:
		for island_x in range(-13, 19):
			var island_position := floor.position + floor.map_to_local(Vector2i(island_x, island_y))
			_expect(not _permanent_hazards_contain_point(dungeon, permanent_areas, island_position),
				"solid island edge cell (%d,%d) clears permanent hazards" % [
					island_x, island_y
				])
	var hazardous_columns: Array[int] = [-13, -12, -8, -4, 1, 5, 11, 18]
	for hazard_y in [29]:
		for hazard_x in hazardous_columns:
			var hazard_position := floor.position + floor.map_to_local(Vector2i(hazard_x, hazard_y))
			_expect(_permanent_hazards_contain_point(dungeon, permanent_areas, hazard_position),
				"void cell (%d,%d) logical position remains hazardous" % [
					hazard_x, hazard_y
				])
	var route_columns: Array[int] = [-10, 3]
	for route_x in route_columns:
		for route_y in [29]:
			var body_position := floor.position + floor.map_to_local(Vector2i(route_x, route_y))
			var center := body_position + player_collision.position
			var player_polygon := PackedVector2Array([
				center + Vector2(-half_size.x, -half_size.y),
				center + Vector2(half_size.x, -half_size.y),
				center + Vector2(half_size.x, half_size.y),
				center + Vector2(-half_size.x, half_size.y),
			])
			for hazard_node in permanent_areas.get_children():
				var hazard := hazard_node as Node2D
				if hazard == null:
					continue
				for shape_node in hazard.get_children():
					var collision_polygon := shape_node as CollisionPolygon2D
					if collision_polygon == null:
						continue
					var hazard_polygon := PackedVector2Array()
					for point: Vector2 in collision_polygon.polygon:
						hazard_polygon.append(hazard.position + collision_polygon.position + point)
					_expect(Geometry2D.intersect_polygons(player_polygon, hazard_polygon).is_empty(),
						"Player footprint at route cell (%d,%d) clears %s/%s" % [
							route_x, route_y, hazard.name, collision_polygon.name
						])


func _permanent_hazards_contain_point(
	dungeon: Node2D, permanent_areas: Node2D, dungeon_local_position: Vector2
) -> bool:
	var global_position := dungeon.to_global(dungeon_local_position)
	for hazard_node in permanent_areas.get_children():
		var hazard := hazard_node as Node2D
		if hazard == null:
			continue
		for shape_node in hazard.get_children():
			var collision_polygon := shape_node as CollisionPolygon2D
			if collision_polygon == null or collision_polygon.disabled:
				continue
			if Geometry2D.is_point_in_polygon(
				collision_polygon.to_local(global_position), collision_polygon.polygon
			):
				return true
	return false


func _test_debug_clear_removes_level_one_enemies() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	if dungeon_scene == null:
		_expect(false, "Dungeon loads for the debug-clear test")
		return

	var dungeon := dungeon_scene.instantiate()
	root.add_child(dungeon)
	await process_frame

	var enemy := Node2D.new()
	enemy.add_to_group("level1_enemy")
	root.add_child(enemy)
	dungeon.set("spawning_finished", true)
	dungeon.set("level_1_total_enemies", 1)
	dungeon.set("current_level", 1)
	await process_frame
	var counter_label := dungeon.get_node_or_null("LevelClearUI/EnemyCounterLabel") as Label
	_expect(counter_label != null and "Enemies Killed: 0 / 1" in counter_label.text
		and "Enemies Left: 1" in counter_label.text,
		"Level 1 counter reports its active enemy")
	dungeon.call("debug_clear_level_one_enemies")
	await process_frame

	_expect(not is_instance_valid(enemy),
		"debug clear removes Level 1 enemies")
	_expect(counter_label != null and "Enemies Killed: 1 / 1" in counter_label.text
		and "Enemies Left: 0" in counter_label.text,
		"Level 1 counter reaches one defeated and zero left")
	dungeon.queue_free()
	await process_frame


# Huang Wan Jun 2204536 - The L debug shortcut must clear the active Level 2 encounter.
func _test_debug_clear_removes_level_two_enemies() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	if dungeon_scene == null:
		_expect(false, "Dungeon loads for the Level 2 debug-clear test")
		return

	var dungeon := dungeon_scene.instantiate()
	root.add_child(dungeon)
	await process_frame
	dungeon.set("current_level", 2)

	var enemies := dungeon.call("_get_level_two_enemy_nodes") as Array
	_expect(not enemies.is_empty(), "Level 2 starts with enemies for the debug-clear test")
	dungeon.call("debug_clear_current_level")
	await process_frame
	await process_frame

	_expect((dungeon.call("_get_level_two_enemy_nodes") as Array).is_empty(),
		"debug clear removes all active Level 2 enemies")
	_expect(dungeon.get("level_2_second_wave_spawned") == true,
		"debug clear also skips the unspawned Level 2 wave")
	_expect(dungeon.get("level_2_cleared") == true,
		"debug clear completes Level 2")
	dungeon.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
