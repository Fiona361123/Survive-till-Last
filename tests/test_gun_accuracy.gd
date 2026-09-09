extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	var player := Node2D.new()
	player.add_to_group("player")
	root.add_child(player)

	var gun_scene := load("res://weapons/gun/Gun.tscn") as PackedScene
	var gun := gun_scene.instantiate()
	player.add_child(gun)
	gun.set_physics_process(false)

	var enemy := CharacterBody2D.new()
	enemy.set_script(load("res://tests/moving_dummy_enemy.gd"))
	enemy.add_to_group("enemy")
	enemy.global_position = Vector2(200.0, 0.0)
	enemy.velocity = Vector2(0.0, 150.0)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape
	collision.position = Vector2(0.0, -16.0)
	enemy.add_child(collision)
	root.add_child(enemy)

	var current_aim := collision.global_position
	var predicted_aim: Vector2 = gun.call("_predict_target_position", enemy)
	_expect(predicted_aim.y > current_aim.y,
		"gun leads a moving enemy instead of aiming only at its old position")

	gun.do_attack(enemy)
	await process_frame
	var bullet := root.get_node_or_null("Bullet")
	_expect(bullet != null and bullet.target == enemy,
		"spawned bullet remembers the enemy it should track")
	if bullet != null:
		var hit_shape := bullet.get_node("HitArea/CollisionShape2D") as CollisionShape2D
		_expect(is_equal_approx((hit_shape.shape as CircleShape2D).radius, 8.0),
			"bullet uses a forgiving eight-pixel collision radius")
		bullet.global_position = Vector2.ZERO
		bullet.direction = Vector2.RIGHT
		enemy.global_position = Vector2(200.0, 120.0)
		bullet._physics_process(0.1)
		_expect(bullet.direction.y > 0.0,
			"bullet turns toward the enemy when the enemy changes direction")
		bullet.queue_free()

	var knife_scene := load("res://weapons/Knife.tscn") as PackedScene
	var knife := knife_scene.instantiate()
	_expect(knife.damage == 30,
		"Knife base damage is increased to thirty")
	knife.free()

	player.queue_free()
	enemy.queue_free()
	await process_frame

	if failures == 0:
		print("Gun accuracy and weapon balance tests passed.")
	else:
		push_error("%d gun accuracy or balance test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
