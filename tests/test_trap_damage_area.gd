extends SceneTree

var failures: int = 0


class DummyBody extends CharacterBody2D:
	var damage_received: int = 0

	func take_damage(amount: int) -> void:
		damage_received += amount


func _initialize() -> void:
	await process_frame
	await _test_damage_once_per_activation_for_player_and_enemy()

	if failures == 0:
		print("Trap Damage Area tests passed.")
	else:
		push_error("%d Trap Damage Area test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _test_damage_once_per_activation_for_player_and_enemy() -> void:
	var trap := TrapDamageArea.new()
	root.add_child(trap)
	var trap_shape := CollisionShape2D.new()
	var trap_circle := CircleShape2D.new()
	trap_circle.radius = 32.0
	trap_shape.shape = trap_circle
	trap.add_child(trap_shape)

	var player := _make_dummy(2)
	var enemy := _make_dummy(4)
	root.add_child(player)
	root.add_child(enemy)
	await physics_frame
	await physics_frame

	_expect(trap.collision_layer == 0, "TrapDamageArea does not occupy a collision layer")
	_expect(trap.collision_mask == 6, "TrapDamageArea detects player and enemy layers")
	trap.begin_activation(20)
	await physics_frame
	trap.damage_overlapping_bodies()
	trap.damage_overlapping_bodies()
	_expect(player.damage_received == 20, "player receives damage once per activation")
	_expect(enemy.damage_received == 20, "enemy receives damage once per activation")

	trap.end_activation()
	_expect(not trap.monitoring, "ending activation disables monitoring")
	trap.begin_activation(20)
	_expect(trap.monitoring, "beginning activation enables monitoring")
	await physics_frame
	trap.damage_overlapping_bodies()
	_expect(player.damage_received == 40, "player can be damaged again in a new activation")
	_expect(enemy.damage_received == 40, "enemy can be damaged again in a new activation")

	trap.end_activation()
	trap.begin_activation(-5)
	_expect(trap.activation_damage == 0, "activation damage clamps negative values to zero")

	trap.queue_free()
	player.queue_free()
	enemy.queue_free()
	await process_frame


func _make_dummy(layer: int) -> DummyBody:
	var body := DummyBody.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	body.add_child(shape)
	return body


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
