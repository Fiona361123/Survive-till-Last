extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	_test_triangle_geometry()
	await _test_density_selection_and_field_lifecycle()

	if failures == 0:
		print("Prism Lattice tests passed.")
	else:
		push_error("%d Prism Lattice test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _test_triangle_geometry() -> void:
	var vertices := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(100.0, 0.0),
		Vector2(0.0, 100.0),
	])
	_expect(PrismField.contains_point(Vector2(20.0, 20.0), vertices),
		"point-in-polygon detects an enemy inside the prism triangle")
	_expect(not PrismField.contains_point(Vector2(90.0, 90.0), vertices),
		"point-in-polygon rejects an enemy outside the prism triangle")
	_expect(is_equal_approx(PrismField.calculate_area(vertices), 5000.0),
		"cross-product calculation returns the triangle area")
	_expect(PrismField.calculate_centroid(vertices).is_equal_approx(Vector2(33.333332, 33.333332)),
		"centroid calculation finds the collapse position")
	_expect(is_equal_approx(PrismField.distance_to_edges(Vector2(50.0, 5.0), vertices), 5.0),
		"point-to-segment calculation measures beam contact distance")


func _test_density_selection_and_field_lifecycle() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)

	var weapon_scene := load("res://weapons/prism/PrismLatticeWeapon.tscn") as PackedScene
	var weapon := weapon_scene.instantiate()
	player.add_child(weapon)
	weapon.deployment_duration = 0.03
	weapon.field_duration = 0.15
	weapon.warning_duration = 0.04
	weapon.collapse_duration = 0.04

	var cluster_left := _make_enemy(Vector2(170.0, 0.0))
	var cluster_center := _make_enemy(Vector2(200.0, 0.0))
	var cluster_right := _make_enemy(Vector2(230.0, 0.0))
	var lonely := _make_enemy(Vector2(0.0, 420.0))
	var outside := _make_enemy(Vector2(700.0, 700.0))

	var selection: Dictionary = weapon.call("_find_best_cluster")
	_expect(int(selection.get("score", 0)) == 3,
		"density scoring selects the three-enemy group")
	_expect((selection.get("center", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(200.0, 0.0)),
		"selected field centre is the average position of the dense group")

	weapon.trigger_attack()
	var field: PrismField = weapon.active_field as PrismField
	_expect(is_instance_valid(field),
		"manual activation creates one Prism field")
	var deployment_frames := 0
	while is_instance_valid(field) and field.state == PrismField.FieldState.DEPLOYING and deployment_frames < 30:
		await physics_frame
		deployment_frames += 1
	_expect(field.state == PrismField.FieldState.ACTIVE,
		"three deployment signals activate the field")
	await physics_frame
	_expect(field.prisms.size() == 3,
		"field deploys exactly three independent prism nodes")
	_expect(field.beam_glows.size() == 3 and field.beam_cores.size() == 3,
		"triangle renders three glow beams and three bright cores")
	_expect(int(cluster_center.get("damage_received")) > 0,
		"enemy inside the triangle receives pulse damage")
	_expect(int(outside.get("damage_received")) == 0,
		"enemy outside the field receives no active-field damage")

	var damage_before := int(cluster_center.get("damage_received"))
	field.call("_apply_field_damage")
	field.call("_apply_field_damage")
	_expect(int(cluster_center.get("damage_received")) == damage_before,
		"per-enemy damage memory prevents duplicate damage inside one interval")

	var cleanup_frames := 0
	while is_instance_valid(field) and cleanup_frames < 120:
		await physics_frame
		cleanup_frames += 1
	_expect(not is_instance_valid(field) and weapon.active_field == null,
		"warning, collapse, explosion and cleanup complete without leaving a field")
	_expect(int(cluster_center.get("damage_received")) > damage_before,
		"centroid collapse applies its finishing explosion damage")
	_expect(int(lonely.get("damage_received")) == 0,
		"enemy outside the collapse radius remains unharmed")

	player.queue_free()
	cluster_left.queue_free()
	cluster_center.queue_free()
	cluster_right.queue_free()
	lonely.queue_free()
	outside.queue_free()
	await process_frame


func _make_enemy(position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.set_script(load("res://tests/gravity_dummy_enemy.gd"))
	enemy.add_to_group("enemy")
	enemy.global_position = position
	root.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
