extends SceneTree

var failures: int = 0


class DummyBody extends CharacterBody2D:
	var damage_received: int = 0

	func take_damage(amount: int) -> void:
		damage_received += amount


func _initialize() -> void:
	await process_frame
	await _test_isometric_tile_presentation()
	await _test_telegraphed_activation_and_single_damage()
	await _test_active_spikes_freeze_enemies_until_retracted()
	if failures == 0:
		print("Spike row tests passed.")
	else:
		push_error("%d spike row test(s) failed" % failures)
	quit(0 if failures == 0 else 1)


func _test_isometric_tile_presentation() -> void:
	var scene := load("res://Level3Traps/SpikeRow.tscn") as PackedScene
	_expect(scene != null, "SpikeRow scene loads for visual test")
	if scene == null:
		return
	var row := scene.instantiate() as SpikeRow
	row.tile_count = 3
	var editor_preview := row.get_node_or_null("EditorPreview")
	_expect(editor_preview != null and editor_preview.get_child_count() == 3,
		"scene stores three authored spike tiles for reliable editor visibility")
	if editor_preview != null:
		_expect(editor_preview.find_children("*", "Polygon2D", true, false).size() >= 3,
			"authored editor preview contains visible polygon artwork")
	root.add_child(row)
	await process_frame

	var warning_tiles := row.get_node("WarningTiles")
	var spike_tiles := row.get_node("SpikeTiles")
	var collision_shapes := row.get_node("TrapDamageArea").get_children().filter(
		func(child: Node) -> bool: return child is CollisionPolygon2D
	)
	_expect(warning_tiles.get_child_count() == 3, "row draws one warning diamond per isometric tile")
	_expect(spike_tiles.get_child_count() == 3, "row draws one spike cluster per isometric tile")
	_expect(collision_shapes.size() == 3, "row has one matching hit area per isometric tile")
	var first_warning := warning_tiles.get_child(0) as Polygon2D
	_expect(first_warning != null and first_warning.polygon == PackedVector2Array([
		Vector2(-128, 0), Vector2(0, -64), Vector2(128, 0), Vector2(0, 64)
	]), "warning presentation follows the 256x128 isometric floor diamond")
	_expect(row.scale == Vector2.ONE, "spike tiles do not depend on giant node scaling")

	row.queue_free()
	await process_frame


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
	_expect(not row.get_node("WarningTiles").visible, "warning is hidden while SAFE")
	_expect(not row.get_node("SpikeTiles").visible, "spikes are hidden while SAFE")
	row.activate()
	_expect(row.state == SpikeRow.State.WARNING, "activate immediately enters WARNING")
	_expect(row.get_node("WarningTiles").visible, "warning is shown during WARNING")
	_expect(not row.get_node("SpikeTiles").visible, "spikes remain hidden during WARNING")
	await create_timer(0.02).timeout
	_expect(row.state == SpikeRow.State.WARNING, "warning lasts for warning_duration")
	await create_timer(0.06).timeout
	_expect(row.state == SpikeRow.State.ACTIVE, "row enters ACTIVE after warning")
	_expect(not row.get_node("WarningTiles").visible, "warning hides when ACTIVE begins")
	_expect(row.get_node("SpikeTiles").visible, "spikes show when ACTIVE begins")
	await row.activation_finished
	_expect(row.state == SpikeRow.State.SAFE, "row returns SAFE after activation")
	_expect(body.damage_received == 20, "body present throughout is damaged exactly once")
	_expect(not row.get_node("TrapDamageArea").monitoring, "damage area ends monitoring after activation")

	body.queue_free()
	row.queue_free()
	await process_frame


# Huang Wan Jun 2204536 - Active spikes hold an enemy in place, then release it when the hazard retracts.
func _test_active_spikes_freeze_enemies_until_retracted() -> void:
	var scene := load("res://Level3Traps/SpikeRow.tscn") as PackedScene
	if scene == null:
		return
	var row := scene.instantiate() as SpikeRow
	row.warning_duration = 0.01
	row.active_duration = 0.12
	root.add_child(row)
	var enemy := DummyBody.new()
	enemy.collision_layer = 4
	enemy.collision_mask = 0
	enemy.add_to_group("enemy")
	var enemy_shape := CollisionShape2D.new()
	var enemy_circle := CircleShape2D.new()
	enemy_circle.radius = 8.0
	enemy_shape.shape = enemy_circle
	enemy.add_child(enemy_shape)
	root.add_child(enemy)
	await physics_frame
	await physics_frame

	row.activate()
	await create_timer(0.03).timeout
	_expect(enemy.process_mode == Node.PROCESS_MODE_DISABLED,
		"active spikes freeze overlapping enemies")
	await row.activation_finished
	_expect(enemy.process_mode == Node.PROCESS_MODE_INHERIT,
		"retracted spikes restore enemy movement")

	enemy.queue_free()
	row.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
