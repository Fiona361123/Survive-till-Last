extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_homing_prism_snare_lifecycle()

	if failures == 0:
		print("Astral Prism Snare tests passed.")
	else:
		push_error("%d Astral Prism Snare test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _test_homing_prism_snare_lifecycle() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)

	var weapon_scene := load("res://weapons/prism/PrismLatticeWeapon.tscn") as PackedScene
	var weapon := weapon_scene.instantiate()
	player.add_child(weapon)
	weapon.projectile_speed = 900.0
	weapon.homing_acceleration = 4000.0
	weapon.maximum_seek_time = 2.0
	weapon.capture_distance = 24.0
	weapon.trap_radius = 80.0
	weapon.trap_duration = 0.18
	weapon.damage_interval = 0.03
	weapon.collapse_duration = 0.04
	weapon.explosion_radius = 110.0

	var first_target := _make_enemy(Vector2(180.0, 0.0))
	var moving_target := _make_enemy(Vector2(260.0, 0.0))
	var outside := _make_enemy(Vector2(650.0, 420.0))

	_expect(weapon.call("_find_nearest_enemy", player.global_position, weapon.cast_range) == first_target,
		"Weapon 7 automatically selects the nearest enemy")
	weapon.trigger_attack()
	var field: PrismField = weapon.active_field as PrismField
	_expect(is_instance_valid(field),
		"pressing key 7 logic throws one autonomous prism")
	_expect(field.state == PrismField.FieldState.SEEKING,
		"the thrown prism begins in SEEKING state")
	_expect(field.global_position.is_equal_approx(player.global_position),
		"the prism is thrown from the player instead of appearing on the enemy")
	_expect(field.target == first_target,
		"the prism initially tracks the selected enemy")

	first_target.queue_free()
	await process_frame
	await physics_frame
	_expect(field.target == moving_target,
		"the prism retargets when its original enemy disappears")
	moving_target.global_position = Vector2(280.0, 110.0)
	for _frame in range(3):
		await physics_frame
	_expect(field.velocity.y > 0.0,
		"predictive homing turns toward a moving enemy's new position")

	var seek_frames := 0
	while is_instance_valid(field) and field.state == PrismField.FieldState.SEEKING and seek_frames < 120:
		await physics_frame
		seek_frames += 1
	_expect(is_instance_valid(field) and field.state == PrismField.FieldState.SNARING,
		"reaching the enemy changes the prism from SEEKING to SNARING")
	_expect(field.cage_prisms.size() == 4,
		"the snare deploys four orbiting prison nodes")
	_expect(field.beam_glows.size() == 4 and field.beam_cores.size() == 4,
		"the prison draws four glowing cage walls")
	_expect(moving_target.has_meta(&"prism_snared"),
		"captured enemies are marked as trapped")

	moving_target.global_position = field.cage_center + Vector2(field.trap_radius * 2.0, 0.0)
	await physics_frame
	_expect(moving_target.global_position.distance_to(field.cage_center) <= field.trap_radius * 0.59,
		"the cage prevents its captured enemy from escaping")

	for _frame in range(5):
		await physics_frame
	_expect(int(moving_target.get("damage_received")) > 0,
		"the trapped enemy receives repeated prison damage")
	_expect(int(outside.get("damage_received")) == 0,
		"enemies outside the prison and collapse radius are not damaged")

	var cleanup_frames := 0
	while is_instance_valid(field) and cleanup_frames < 120:
		await physics_frame
		cleanup_frames += 1
	_expect(not is_instance_valid(field) and weapon.active_field == null,
		"collapse explosion finishes and releases the active weapon slot")
	_expect(not moving_target.has_meta(&"prism_snared"),
		"the enemy is released when the prison ends")

	player.queue_free()
	moving_target.queue_free()
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
