extends SceneTree

var failures: int = 0


class DummyBody extends CharacterBody2D:
	var damage_received: int = 0

	func take_damage(amount: int) -> void:
		damage_received += amount


func _initialize() -> void:
	await process_frame
	await _test_warning_travel_and_single_damage()
	await _test_force_safe_cancels_sweep()
	if failures == 0:
		print("Fire sweep tests passed.")
	else:
		push_error("%d fire sweep test(s) failed" % failures)
	quit(0 if failures == 0 else 1)


func _test_warning_travel_and_single_damage() -> void:
	var scene := load("res://Level3Traps/FireSweep.tscn") as PackedScene
	_expect(scene != null, "FireSweep scene loads")
	if scene == null:
		return
	var sweep := scene.instantiate()
	sweep.warning_duration = 0.08
	sweep.travel_duration = 0.12
	sweep.damage = 17
	root.add_child(sweep)
	var body := _make_dummy(2, Vector2(48, 0))
	root.add_child(body)
	await physics_frame
	_expect(not sweep.get_node("WarningStrip").visible, "warning starts hidden")
	sweep.sweep(Vector2.ZERO, Vector2(96, 0))
	_expect(sweep.get_node("WarningStrip").visible, "warning is visible immediately")
	_expect(not sweep.get_node("FireGraphics").visible, "fire is hidden during warning")
	_expect(sweep.position == Vector2.ZERO, "root starts at requested origin")
	await create_timer(0.03).timeout
	_expect(sweep.position == Vector2.ZERO, "root waits at origin during warning")
	await sweep.sweep_finished
	_expect(sweep.position == Vector2(96, 0), "root reaches requested destination")
	_expect(not sweep.get_node("WarningStrip").visible, "warning hides after sweep")
	_expect(not sweep.get_node("FireGraphics").visible, "fire hides after sweep")
	_expect(not sweep.get_node("TrapDamageArea").monitoring, "damage area is disabled after sweep")
	_expect(body.damage_received == 17, "overlapped body is damaged at most once")
	body.queue_free()
	sweep.queue_free()
	await process_frame


func _test_force_safe_cancels_sweep() -> void:
	var scene := load("res://Level3Traps/FireSweep.tscn") as PackedScene
	if scene == null:
		return
	var sweep := scene.instantiate()
	sweep.warning_duration = 0.2
	sweep.travel_duration = 0.2
	root.add_child(sweep)
	sweep.sweep(Vector2(10, 10), Vector2(100, 100))
	sweep.force_safe()
	await create_timer(0.25).timeout
	_expect(sweep.position == Vector2(10, 10), "force_safe leaves sweep at current position")
	_expect(not sweep.get_node("WarningStrip").visible, "force_safe hides warning")
	_expect(not sweep.get_node("FireGraphics").visible, "force_safe hides fire")
	_expect(not sweep.get_node("TrapDamageArea").monitoring, "force_safe disables damage")
	sweep.queue_free()
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
