extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_bomb_tracks_a_moving_enemy()
	await _test_pull_and_explosion_state_machine()

	if failures == 0:
		print("Gravity Bomb tests passed.")
	else:
		push_error("%d Gravity Bomb test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _test_bomb_tracks_a_moving_enemy() -> void:
	var target := Node2D.new()
	target.set_script(load("res://tests/gravity_dummy_enemy.gd"))
	target.add_to_group("enemy")
	target.global_position = Vector2(260.0, 0.0)
	root.add_child(target)

	var bomb_scene := load("res://weapons/gravity/GravityBombProjectile.tscn") as PackedScene
	var bomb := bomb_scene.instantiate() as Node2D
	bomb.set("tracking_speed", 240.0)
	root.add_child(bomb)
	bomb.call("launch", Vector2.ZERO, target.global_position, 50, target)

	await physics_frame
	target.global_position = Vector2(260.0, 160.0)
	await physics_frame
	await physics_frame
	_expect(bomb.global_position.y > 0.0,
		"FLYING Gravity Bomb changes direction to follow a moving enemy")

	target.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_expect(not is_instance_valid(bomb),
		"Gravity Bomb disappears when its tracked enemy is removed")


func _test_pull_and_explosion_state_machine() -> void:
	var enemy := Node2D.new()
	enemy.set_script(load("res://tests/gravity_dummy_enemy.gd"))
	enemy.add_to_group("enemy")
	enemy.global_position = Vector2(100.0, 0.0)
	root.add_child(enemy)

	var bomb_scene := load("res://weapons/gravity/GravityBombProjectile.tscn") as PackedScene
	var bomb := bomb_scene.instantiate() as Node2D
	bomb.set("pull_duration", 0.12)
	bomb.set("pull_tick_interval", 0.02)
	bomb.set("pull_strength", 500.0)
	bomb.set("explosion_duration", 0.08)
	root.add_child(bomb)
	bomb.call("launch", Vector2.ZERO, Vector2.ZERO, 50)

	var initial_distance := enemy.global_position.distance_to(Vector2.ZERO)
	await physics_frame
	_expect(int(bomb.get("state")) == 1,
		"Gravity Bomb changes from FLYING to PULLING at its target")
	await create_timer(0.07).timeout
	_expect(enemy.global_position.distance_to(Vector2.ZERO) < initial_distance,
		"PULLING state moves nearby enemies toward the gravity core")
	_expect(int(enemy.get("damage_received")) > 0,
		"gravity pulses damage enemies while pulling")

	await create_timer(0.08).timeout
	_expect(int(enemy.get("damage_received")) >= 50,
		"EXPLODING state applies the configured blast damage")
	await create_timer(0.1).timeout
	_expect(not is_instance_valid(bomb),
		"Gravity Bomb removes itself after its explosion animation")

	enemy.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
