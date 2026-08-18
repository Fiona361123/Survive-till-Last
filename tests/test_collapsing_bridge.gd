# Huang Wan Jun 2204536
extends SceneTree

class FakePlayer extends CharacterBody2D:

	var damage_taken: int = 0

	func take_damage(amount: int) -> void:
		damage_taken += amount

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_player_damage_is_debounced()
	await _test_player_stays_in_place_after_fall_damage()
	await _test_enemy_is_removed_after_falling()
	await _test_polygon_gate_uses_logical_body_position()
	await _test_continuous_overlap_reaches_logical_hazard_position()
	await _test_section_gap_uses_its_polygon_gate()
	_test_section_direction_updates_in_editor()
	await _test_section_collapses_and_rebuilds_after_player_trigger()
	await _test_section_tile_data_and_collision_geometry()
	await _test_sections_are_independent()
	await _test_dungeon_bridge_cycle()
	await _test_section_ignores_ungrouped_body()

	if failures == 0:
		print("Collapsing-bridge tests passed.")
		quit(0)
	else:
		push_error("%d collapsing-bridge test(s) failed." % failures)
		quit(1)


func _test_section_direction_updates_in_editor() -> void:
	# Huang Wan Jun 2204536 - Direction overrides must update the editor preview.
	var section_script := load("res://collapsing_bridge_section.gd") as GDScript
	_expect(section_script != null and section_script.is_tool(),
		"collapsing bridge direction script runs safely in the editor")


func _new_hazard() -> Area2D:
	var hazard_script := load("res://fall_hazard.gd") as GDScript
	_expect(hazard_script != null, "fall_hazard.gd can be loaded")
	if hazard_script == null:
		return null
	var hazard := Area2D.new()
	hazard.set_script(hazard_script)
	root.add_child(hazard)
	await process_frame
	return hazard


func _test_player_damage_is_debounced() -> void:
	var hazard := await _new_hazard()
	if hazard == null:
		return
	var player := FakePlayer.new()
	player.add_to_group("player")
	hazard.call("_on_body_entered", player)
	hazard.call("_on_body_entered", player)
	_expect(player.damage_taken == 1, "same player overlap applies fall damage once")
	hazard.queue_free()


func _test_player_stays_in_place_after_fall_damage() -> void:
	var hazard := await _new_hazard()
	if hazard == null:
		return
	var left := Marker2D.new()
	left.global_position = Vector2(-20, 0)
	var right := Marker2D.new()
	right.global_position = Vector2(80, 0)
	hazard.add_child(left)
	hazard.add_child(right)
	hazard.call("configure_respawn_markers", left, right)
	var player := FakePlayer.new()
	player.add_to_group("player")
	player.global_position = Vector2(10, 0)
	hazard.call("_on_body_entered", player)
	# Huang Wan Jun 2204536 - Cliff damage must not teleport the player.
	_expect(player.damage_taken == 1,
		"player takes cliff damage")
	_expect(player.global_position == Vector2(10, 0),
		"player stays in place after cliff damage")
	hazard.queue_free()


func _test_enemy_is_removed_after_falling() -> void:
	var hazard := await _new_hazard()
	if hazard == null:
		return
	var enemy := Node2D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	hazard.call("_on_body_entered", enemy)
	await process_frame
	_expect(not is_instance_valid(enemy), "enemy group body is removed by fall hazard")
	hazard.queue_free()


func _test_polygon_gate_uses_logical_body_position() -> void:
	var hazard := await _new_hazard()
	if hazard == null:
		return
	hazard.global_position = Vector2(100, 200)
	var polygon := CollisionPolygon2D.new()
	polygon.position = Vector2(20, 10)
	polygon.polygon = PackedVector2Array([
		Vector2(-40, -30),
		Vector2(40, -30),
		Vector2(40, 30),
		Vector2(-40, 30),
	])
	hazard.add_child(polygon)

	var player := FakePlayer.new()
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = Vector2(180, 210)
	hazard.call("_on_body_entered", player)
	_expect(player.damage_taken == 0,
		"polygon hazard ignores a player whose logical origin is outside")
	player.global_position = Vector2(120, 210)
	hazard.call("_on_body_entered", player)
	_expect(player.damage_taken == 1,
		"outside signal does not debounce a later logical entry")

	var enemy := Node2D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	enemy.global_position = Vector2(180, 210)
	hazard.call("_on_body_entered", enemy)
	_expect(is_instance_valid(enemy),
		"polygon hazard ignores an enemy whose logical origin is outside")
	enemy.global_position = Vector2(120, 210)
	hazard.call("_on_body_entered", enemy)
	await process_frame
	_expect(not is_instance_valid(enemy),
		"polygon hazard removes an enemy whose logical origin is inside")
	player.queue_free()
	hazard.queue_free()


func _test_continuous_overlap_reaches_logical_hazard_position() -> void:
	var hazard := await _new_hazard()
	if hazard == null:
		return
	hazard.collision_layer = 0
	hazard.collision_mask = 2
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-40, -30),
		Vector2(40, -30),
		Vector2(40, 30),
		Vector2(-40, 30),
	])
	hazard.add_child(polygon)
	var player := FakePlayer.new()
	player.collision_layer = 2
	player.add_to_group("player")
	var player_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(80, 20)
	player_shape.shape = rectangle
	player.add_child(player_shape)
	root.add_child(player)
	player.global_position = Vector2(70, 0)
	await physics_frame
	_expect(player.damage_taken == 0,
		"hazard waits while only the edge of the player overlaps")
	player.global_position = Vector2(30, 0)
	await physics_frame
	await physics_frame
	# Huang Wan Jun 2204536 - A continuous overlap is rechecked when the body center enters the hole.
	_expect(player.damage_taken == 1,
		"hazard handles a continuously overlapping player after its center enters")
	player.queue_free()
	hazard.queue_free()


func _test_section_gap_uses_its_polygon_gate() -> void:
	var section := await _new_section()
	if section == null:
		return
	section.global_position = Vector2(300, 400)
	var gap_area := section.get_node("GapArea") as Area2D
	var player := _new_player()
	player.global_position = Vector2(560, 464)
	gap_area.call("_on_body_entered", player)
	_expect(player.damage_taken == 0,
		"section gap ignores logical origins outside its polygon")
	player.global_position = Vector2(428, 464)
	gap_area.call("_on_body_entered", player)
	_expect(player.damage_taken == 1,
		"section gap handles logical origins inside its polygon")
	player.queue_free()
	section.queue_free()


func _new_section() -> CollapsingBridgeSection:
	var section_scene := load("res://CollapsingBridgeSection.tscn") as PackedScene
	_expect(section_scene != null, "CollapsingBridgeSection scene can be loaded")
	if section_scene == null:
		return null
	var section := section_scene.instantiate() as CollapsingBridgeSection
	section.warning_duration = 0.02
	section.rebuild_delay = 0.03
	root.add_child(section)
	await process_frame
	return section


func _new_player() -> FakePlayer:
	var player := FakePlayer.new()
	player.add_to_group("player")
	root.add_child(player)
	return player


func _test_section_collapses_and_rebuilds_after_player_trigger() -> void:
	var section := await _new_section()
	if section == null:
		return
	var player := _new_player()
	section.call("_on_trigger_body_entered", player)
	_expect(section.state == CollapsingBridgeSection.SectionState.WARNING,
		"player entry immediately puts a section into WARNING")
	var bridge_tile := section.get_node("BridgeTile") as TileMapLayer
	_expect(bridge_tile.z_index < 0,
		"unstable bridge surface renders below characters")
	_expect(bridge_tile.visible, "bridge tile remains visible during WARNING")
	_expect(bridge_tile.enabled, "bridge tile remains enabled during WARNING")
	await create_timer(0.03).timeout
	var gap_area := section.get_node("GapArea") as Area2D
	_expect(section.state == CollapsingBridgeSection.SectionState.COLLAPSED,
		"warning timeout puts section into COLLAPSED")
	_expect(not bridge_tile.visible, "bridge tile is hidden while collapsed")
	_expect(not bridge_tile.enabled, "bridge tile is disabled while collapsed")
	_expect(gap_area.monitoring, "gap area monitors while collapsed")
	await create_timer(0.04).timeout
	_expect(section.state == CollapsingBridgeSection.SectionState.READY,
		"rebuild timeout returns section to READY")
	_expect(bridge_tile.visible, "bridge tile is visible after rebuilding")
	_expect(bridge_tile.enabled, "bridge tile is enabled after rebuilding")
	_expect(not gap_area.monitoring, "gap area stops monitoring after rebuilding")
	player.queue_free()
	section.queue_free()


func _test_section_tile_data_and_collision_geometry() -> void:
	var section := await _new_section()
	if section == null:
		return
	var bridge_tile := section.get_node("BridgeTile") as TileMapLayer
	_expect(bridge_tile.get_used_cells().size() == 1,
		"bridge section serializes exactly one tile cell")
	# Huang Wan Jun 2204536 - New unstable bridge sections use N unless a Dungeon instance overrides them.
	_expect(section.bridge_direction == 1,
		"reusable unstable bridge section defaults to N")
	_expect(bridge_tile.get_cell_source_id(Vector2i.ZERO) == 1,
		"reusable unstable bridge section displays the N tile")
	# Huang Wan Jun 2204536 - Unstable sections use the same broad art as SafeBridge.
	var bridge_texture_paths: Array[String] = []
	for source_index in bridge_tile.tile_set.get_source_count():
		var source_id := bridge_tile.tile_set.get_source_id(source_index)
		var atlas := bridge_tile.tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas != null and atlas.texture != null:
			bridge_texture_paths.append(atlas.texture.resource_path)
	for direction in ["E", "N", "S", "W"]:
		_expect(
			"res://Isometric/bridgeWide_%s.png" % direction in bridge_texture_paths,
			"unstable section includes the broad %s bridge direction" % direction
		)
	# Huang Wan Jun 2204536 - Named directions explicitly map to matching sources.
	var script_constants: Dictionary = section.get_script().get_script_constant_map()
	var direction_source: Dictionary = script_constants.get("DIRECTION_SOURCE", {})
	_expect(direction_source == {0: 0, 1: 1, 2: 2, 3: 3},
		"E/N/S/W explicitly map to TileSet sources 0/1/2/3")
	# Huang Wan Jun 2204536 - Inspector direction selects the matching TileSet source.
	for source_id in range(4):
		section.set("bridge_direction", source_id)
		_expect(
			bridge_tile.get_cell_source_id(Vector2i.ZERO) == source_id,
			"unstable section direction %d selects source %d" % [source_id, source_id]
		)
	var trigger_shape := section.get_node("TriggerShape") as CollisionPolygon2D
	var gap_area := section.get_node("GapArea") as Area2D
	var gap_shape := section.get_node("GapArea/GapShape") as CollisionPolygon2D
	# Huang Wan Jun 2204536 - Bridge triggers and gaps detect player layer 2 and enemy layer 4.
	_expect((section.collision_mask & 2) != 0,
		"unstable bridge trigger detects the player collision layer")
	_expect((section.collision_mask & 4) != 0,
		"unstable bridge trigger detects the enemy collision layer")
	_expect((gap_area.collision_mask & 2) != 0,
		"collapsed bridge gap detects the player collision layer")
	_expect((gap_area.collision_mask & 4) != 0,
		"collapsed bridge gap detects the enemy collision layer")
	var bridge_diamond := PackedVector2Array([
		Vector2(0, -64),
		Vector2(120, 0),
		Vector2(0, 64),
		Vector2(-120, 0),
	])
	var cell_center := Vector2(128, 64)
	_expect(trigger_shape.polygon == bridge_diamond,
		"trigger uses the cell-centered bridge diamond")
	_expect(gap_shape.polygon == bridge_diamond,
		"gap uses the same cell-centered bridge diamond")
	_expect(trigger_shape.position == cell_center,
		"trigger diamond is offset to the bridge cell center")
	_expect(gap_area.position == cell_center,
		"gap diamond is offset to the bridge cell center once")
	section.queue_free()


func _test_sections_are_independent() -> void:
	var first := await _new_section()
	var second := await _new_section()
	if first == null or second == null:
		return
	var player := _new_player()
	first.call("_on_trigger_body_entered", player)
	_expect(first.state == CollapsingBridgeSection.SectionState.WARNING,
		"triggered section enters WARNING")
	_expect(second.state == CollapsingBridgeSection.SectionState.READY,
		"untriggered section remains READY")
	player.queue_free()
	first.queue_free()
	second.queue_free()


func _test_dungeon_bridge_cycle() -> void:
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	_expect(dungeon_scene != null, "Dungeon scene loads for the complete bridge cycle")
	if dungeon_scene == null:
		return
	var dungeon := dungeon_scene.instantiate() as Node2D
	root.add_child(dungeon)
	await process_frame

	var section_paths: Array[NodePath] = [
		NodePath("Level2BridgeSystem/UnstableSection1"),
		NodePath("Level2BridgeSystem/UnstableSection2"),
		NodePath("Level2BridgeSystem/UnstableSection3"),
	]
	var sections: Array[CollapsingBridgeSection] = []
	for section_path in section_paths:
		var section := dungeon.get_node_or_null(section_path) as CollapsingBridgeSection
		_expect(section != null, "Dungeon has bridge section at " + str(section_path))
		if section != null:
			section.warning_duration = 0.02
			section.rebuild_delay = 0.03
			sections.append(section)
	if sections.size() != 3:
		dungeon.queue_free()
		await process_frame
		return
	# Huang Wan Jun 2204536 - Only the two selected Dungeon sections remain E; every other section is N.
	_expect(sections[0].bridge_direction == 0,
		"Dungeon first selected unstable section remains E")
	_expect(sections[1].bridge_direction == 0,
		"Dungeon second selected unstable section remains E")
	_expect(sections[2].bridge_direction == 1,
		"Dungeon remaining unstable section uses N")

	var enemy := CharacterBody2D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	sections[1]._on_trigger_body_entered(enemy)
	_expect(sections[0].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon first section stays READY when the middle section triggers")
	_expect(sections[2].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon third section stays READY when the middle section triggers")
	await create_timer(0.03).timeout
	_expect(sections[1].state == CollapsingBridgeSection.SectionState.COLLAPSED,
		"Dungeon middle section collapses alone")
	_expect(sections[0].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon first section remains READY while the middle section is collapsed")
	_expect(sections[2].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon third section remains READY while the middle section is collapsed")
	await create_timer(0.04).timeout
	_expect(sections[1].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon middle section rebuilds to READY")
	_expect(sections[0].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon first section remains READY after the middle section rebuilds")
	_expect(sections[2].state == CollapsingBridgeSection.SectionState.READY,
		"Dungeon third section remains READY after the middle section rebuilds")
	enemy.queue_free()
	dungeon.queue_free()
	await process_frame


func _test_section_ignores_ungrouped_body() -> void:
	var section := await _new_section()
	if section == null:
		return
	var visitor := Node2D.new()
	root.add_child(visitor)
	section.call("_on_trigger_body_entered", visitor)
	_expect(section.state == CollapsingBridgeSection.SectionState.READY,
		"body outside required groups does not trigger a section")
	visitor.queue_free()
	section.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
