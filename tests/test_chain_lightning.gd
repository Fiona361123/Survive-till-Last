extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	var player := Node2D.new()
	player.set_script(load("res://tests/weapon_animation_spy_player.gd"))
	player.add_to_group("player")
	root.add_child(player)

	var weapon_scene := load("res://weapons/lightning/ChainLightning.tscn") as PackedScene
	var weapon := weapon_scene.instantiate()
	player.add_child(weapon)
	weapon.set_physics_process(false)
	weapon.max_jumps = 4
	_expect(is_equal_approx(weapon.attack_range, 400.0),
		"Chain Lightning first-target range is increased to 400 pixels")
	_expect(is_equal_approx(weapon.jump_range, 300.0),
		"Chain Lightning secondary search range is increased to 300 pixels")
	_expect(weapon.damage == 15,
		"Chain Lightning base damage is increased to fifteen")

	var primary := _make_enemy(Vector2(180.0, 0.0))
	var secondary_a := _make_enemy(Vector2(360.0, 0.0))
	var secondary_b := _make_enemy(Vector2(180.0, 170.0))
	var outside := _make_enemy(Vector2(500.0, 300.0))

	weapon.do_attack(primary)
	_expect(primary.damage_received == weapon.damage,
		"primary target is damaged once")
	_expect(secondary_a.damage_received == weapon.damage,
		"enemy outside player range but near the primary target is chained")
	_expect(secondary_b.damage_received == weapon.damage,
		"another enemy around the primary target is chained")
	_expect(outside.damage_received == 0,
		"enemy outside the primary jump radius is not damaged")
	_expect(weapon.secondary_bolts.get_child_count() == 4,
		"two secondary hits each receive a visible glow and core bolt")
	_expect(player.shoot_animation_calls == 0,
		"Chain Lightning does not trigger the gun attack animation")

	player.queue_free()
	primary.queue_free()
	secondary_a.queue_free()
	secondary_b.queue_free()
	outside.queue_free()
	await process_frame

	if failures == 0:
		print("Chain Lightning tests passed.")
	else:
		push_error("%d Chain Lightning test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


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
