extends SceneTree

var failures: int = 0


class DummyBody extends CharacterBody2D:
	var damage_received: int = 0

	func take_damage(amount: int) -> void:
		damage_received += amount


func _initialize() -> void:
	await process_frame
	await _test_warning_and_strike_damage()
	await _test_force_safe_cancels_strike()
	if failures == 0:
		print("Rock strike tests passed.")
	else:
		push_error("%d rock strike test(s) failed" % failures)
	quit(0 if failures == 0 else 1)


func _test_warning_and_strike_damage() -> void:
	var scene := load("res://Level3Traps/RockStrike.tscn") as PackedScene
	_expect(scene != null, "RockStrike scene loads")
	if scene == null:
		return
	var strike := scene.instantiate() as RockStrike
	strike.warning_duration = 0.08
	strike.impact_duration = 0.08
	strike.damage = 17
	root.add_child(strike)
	var player := _make_dummy(2, Vector2(120, 80))
	var enemy := _make_dummy(4, Vector2(120, 80))
	root.add_child(player)
	root.add_child(enemy)
	await physics_frame
	strike.strike_at(Vector2(120, 80))
	_expect(strike.global_position == Vector2(120, 80), "strike is positioned at target")
	_expect(strike.get_node("WarningCircle").visible, "warning appears immediately at target")
	_expect(not strike.get_node("TrapDamageArea").monitoring, "damage is disabled during warning")
	await create_timer(0.03).timeout
	_expect(player.damage_received == 0 and enemy.damage_received == 0, "bodies remain unharmed during warning")
	await strike.strike_finished
	_expect(player.damage_received == 17, "player is damaged exactly once")
	_expect(enemy.damage_received == 17, "enemy is damaged exactly once")
	_expect(not strike.get_node("WarningCircle").visible, "warning is hidden after strike")
	_expect(not strike.get_node("RockGraphics").visible, "rock is hidden after strike")
	_expect(not strike.get_node("ImpactGraphics").visible, "impact is hidden after strike")
	_expect(not strike.get_node("TrapDamageArea").monitoring, "damage area is disabled after strike")
	player.queue_free()
	enemy.queue_free()
	strike.queue_free()
	await process_frame


func _test_force_safe_cancels_strike() -> void:
	var scene := load("res://Level3Traps/RockStrike.tscn") as PackedScene
	if scene == null:
		return
	var strike := scene.instantiate() as RockStrike
	strike.warning_duration = 0.2
	root.add_child(strike)
	strike.strike_at(Vector2(10, 10))
	strike.force_safe()
	await create_timer(0.25).timeout
	_expect(strike.state == RockStrike.State.SAFE, "force_safe leaves strike safe")
	_expect(not strike.get_node("WarningCircle").visible, "force_safe hides warning")
	_expect(not strike.get_node("RockGraphics").visible, "force_safe hides rock")
	_expect(not strike.get_node("ImpactGraphics").visible, "force_safe hides impact")
	_expect(not strike.get_node("TrapDamageArea").monitoring, "force_safe disables damage")
	strike.queue_free()
	await process_frame


func _make_dummy(layer: int, location: Vector2) -> DummyBody:
	var body := DummyBody.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = location
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	body.add_child(shape)
	return body


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
