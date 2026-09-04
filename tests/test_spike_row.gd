extends SceneTree

var failures: int = 0


class DummyBody extends CharacterBody2D:
	var damage_received: int = 0

	func take_damage(amount: int) -> void:
		damage_received += amount


func _initialize() -> void:
	await process_frame
	await _test_telegraphed_activation_and_single_damage()
	if failures == 0:
		print("Spike row tests passed.")
	else:
		push_error("%d spike row test(s) failed" % failures)
	quit(0 if failures == 0 else 1)


func _test_telegraphed_activation_and_single_damage() -> void:
	var scene := load("res://Level3Traps/SpikeRow.tscn") as PackedScene
	_expect(scene != null, "SpikeRow scene loads")
	if scene == null:
		return
	var row := scene.instantiate() as SpikeRow
	row.warning_duration = 0.05
	row.active_duration = 0.05
	root.add_child(row)
	var body := DummyBody.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(96, 24)
	body_shape.shape = body_rect
	body.add_child(body_shape)
	root.add_child(body)
	await physics_frame
	await physics_frame

	_expect(row.state == SpikeRow.State.SAFE, "row starts SAFE")
	_expect(not row.get_node("WarningPolygon").visible, "warning is hidden while SAFE")
	_expect(not row.get_node("SpikePolygon").visible, "spikes are hidden while SAFE")
	row.activate()
	_expect(row.state == SpikeRow.State.WARNING, "activate immediately enters WARNING")
	_expect(row.get_node("WarningPolygon").visible, "warning is shown during WARNING")
	_expect(not row.get_node("SpikePolygon").visible, "spikes remain hidden during WARNING")
	await create_timer(0.02).timeout
	_expect(row.state == SpikeRow.State.WARNING, "warning lasts for warning_duration")
	await create_timer(0.06).timeout
	_expect(row.state == SpikeRow.State.ACTIVE, "row enters ACTIVE after warning")
	_expect(not row.get_node("WarningPolygon").visible, "warning hides when ACTIVE begins")
	_expect(row.get_node("SpikePolygon").visible, "spikes show when ACTIVE begins")
	await row.activation_finished
	_expect(row.state == SpikeRow.State.SAFE, "row returns SAFE after activation")
	_expect(body.damage_received == 20, "body present throughout is damaged exactly once")
	_expect(not row.get_node("TrapDamageArea").monitoring, "damage area ends monitoring after activation")

	body.queue_free()
	row.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
