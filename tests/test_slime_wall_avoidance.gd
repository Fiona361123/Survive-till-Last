extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_slime_steers_sideways_when_wall_blocks_player()
	await _test_trapped_slime_is_relocated_to_player_side_of_wall()
	if failures == 0:
		print("Slime wall-avoidance tests passed.")
		quit(0)
	else:
		push_error("%d slime wall-avoidance test(s) failed." % failures)
		quit(1)


func _test_slime_steers_sideways_when_wall_blocks_player() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(24.0, 240.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	# The slime scene's body shape is offset from its visual origin.
	wall.position = Vector2(125.0, 76.0)
	world.add_child(wall)

	var slime_scene := load("res://Enemy/slime.tscn") as PackedScene
	var slime := slime_scene.instantiate() as CharacterBody2D
	world.add_child(slime)
	slime.global_position = Vector2.ZERO
	await physics_frame

	var direction := slime.call(
		"_get_obstacle_aware_direction", Vector2.RIGHT, 0.1
	) as Vector2
	_expect(absf(direction.y) > 0.7,
		"slime steers sideways instead of pushing directly into a wall")
	_expect(direction.x > 0.0,
		"slime keeps making some forward progress while avoiding a wall")

	world.queue_free()
	await process_frame


func _test_trapped_slime_is_relocated_to_player_side_of_wall() -> void:
	var world := Node2D.new()
	root.add_child(world)

	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(320.0, 76.0)
	world.add_child(player)

	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(40.0, 800.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector2(140.0, 76.0)
	world.add_child(wall)

	var slime_scene := load("res://Enemy/slime.tscn") as PackedScene
	var slime := slime_scene.instantiate() as CharacterBody2D
	world.add_child(slime)
	slime.global_position = Vector2.ZERO
	slime.set("current_state", 1)
	await physics_frame

	# Reproduce the real failure: the slime shuffles along the wall, but never
	# makes useful progress toward the player on the other side.
	for sample in range(4):
		slime.global_position.y += 10.0
		slime.call("_update_stuck_recovery", 0.5)

	_expect(slime.global_position.x > wall.global_position.x,
		"a persistently trapped slime is relocated to the player's side of the wall")
	_expect(not _body_overlaps_solid_world(slime),
		"the recovered slime does not overlap the boundary wall")

	world.queue_free()
	await process_frame


func _body_overlaps_solid_world(body: CollisionObject2D) -> bool:
	var collision := body.get_node("CollisionShape2D") as CollisionShape2D
	body.force_update_transform()
	collision.force_update_transform()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = 1
	query.exclude = [body.get_rid()]
	return not body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
