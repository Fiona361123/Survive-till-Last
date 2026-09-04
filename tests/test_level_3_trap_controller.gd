extends SceneTree

const CONTROLLER_SCRIPT_PATH := "res://Level3Traps/level_3_trap_controller.gd"
const SPIKE_ROW_SCENE_PATH := "res://Level3Traps/SpikeRow.tscn"
const FIRE_SWEEP_SCENE_PATH := "res://Level3Traps/FireSweep.tscn"
const ROCK_STRIKE_SCENE_PATH := "res://Level3Traps/RockStrike.tscn"

var failures: int = 0
var phase_order: Array[String] = []
var stop_listener_triggered: bool = false
var configuration_warning_count: int = 0


func _initialize() -> void:
	await process_frame
	await _test_cycle_preserves_safe_lane_and_phase_order()
	await _test_second_spike_pattern_uses_one_row()
	await _test_stop_from_phase_listener_leaves_traps_safe()
	await _test_unsupported_safe_shape_skips_rock_phase()
	await _test_missing_references_warn_once_per_run()
	if failures == 0:
		print("Level 3 trap controller tests passed.")
	else:
		push_error("%d level 3 trap controller test(s) failed" % failures)
	quit(0 if failures == 0 else 1)


func _test_cycle_preserves_safe_lane_and_phase_order() -> void:
	var controller := _make_controller()
	if controller == null:
		return
	root.add_child(controller)
	await process_frame
	await physics_frame
	controller.connect("phase_started", _on_phase_started)
	controller.start_encounter()
	controller.start_encounter()
	_expect(controller.is_running, "start_encounter marks the encounter running")

	var maximum_simultaneous_rows := 0
	var deadline := Time.get_ticks_msec() + 1500
	while not phase_order.has("rocks") and Time.get_ticks_msec() < deadline:
		maximum_simultaneous_rows = maxi(maximum_simultaneous_rows, _busy_spike_count(controller))
		await process_frame
	maximum_simultaneous_rows = maxi(maximum_simultaneous_rows, _busy_spike_count(controller))

	_expect(maximum_simultaneous_rows == 2,
		"the first spike pattern activates exactly two rows and leaves one safe")
	_expect(phase_order.size() >= 3 and phase_order[0] == "spikes" and phase_order[1] == "fire" and phase_order[2] == "rocks",
		"the controller sequences spikes, then fire, then rocks")

	await process_frame
	var active_rocks := controller.get_node_or_null("ActiveRockStrikes")
	_expect(active_rocks != null and active_rocks.get_child_count() == 2,
		"the rock phase starts two transient strikes")
	if active_rocks != null:
		var targets: Array[Vector2] = []
		for rock in active_rocks.get_children():
			targets.append(rock.global_position)
		_expect(not targets.has(Vector2.ZERO), "rocks do not target the entrance safe area")
		_expect(targets.size() == 2 and targets[0] != targets[1], "rock phase uses two distinct authored targets")

	var phase_count_before_stop := phase_order.size()
	controller.stop_encounter()
	_expect(not controller.is_running, "stop_encounter clears the running state")
	for row in controller.get_node("SpikeRows").get_children():
		_expect(not row.get_node("TrapDamageArea").monitoring, "stop_encounter disables every spike damage area")
	_expect(not controller.get_node("FireSweep/TrapDamageArea").monitoring,
		"stop_encounter disables the fire damage area")
	if active_rocks != null:
		for rock in active_rocks.get_children():
			_expect(not rock.get_node("TrapDamageArea").monitoring,
				"stop_encounter forces each transient rock strike safe")
	await create_timer(0.25).timeout
	_expect(phase_order.size() == phase_count_before_stop,
		"stopping the encounter prevents a later phase from beginning")
	controller.queue_free()
	await process_frame


func _test_second_spike_pattern_uses_one_row() -> void:
	var controller := _make_controller()
	if controller == null:
		return
	phase_order.clear()
	root.add_child(controller)
	await process_frame
	controller.connect("phase_started", _on_phase_started)
	controller.start_encounter()
	var deadline := Time.get_ticks_msec() + 1500
	while phase_order.count("spikes") < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(phase_order.count("spikes") >= 2, "the controller reaches its alternating second spike phase")
	_expect(_busy_spike_count(controller) == 1, "the second spike pattern activates only the middle row")
	controller.stop_encounter()
	controller.queue_free()
	await process_frame


func _test_stop_from_phase_listener_leaves_traps_safe() -> void:
	var controller := _make_controller()
	if controller == null:
		return
	stop_listener_triggered = false
	root.add_child(controller)
	await process_frame
	controller.connect("phase_started", _stop_when_phase_starts.bind(controller))
	controller.start_encounter()
	await process_frame
	_expect(stop_listener_triggered, "a phase listener can stop the encounter synchronously")
	_expect(not controller.is_running, "phase listener stops the running encounter")
	for row in controller.get_node("SpikeRows").get_children():
		_expect(row.state == SpikeRow.State.SAFE and not row.get_node("TrapDamageArea").monitoring,
			"stopping from phase_started prevents spike rows from arming")
	_expect(controller.get_node("FireSweep").state == FireSweep.State.SAFE and not controller.get_node("FireSweep/TrapDamageArea").monitoring,
		"stopping from phase_started prevents fire from arming")
	var active_rocks := controller.get_node_or_null("ActiveRockStrikes")
	_expect(active_rocks == null or active_rocks.get_child_count() == 0,
		"stopping from phase_started prevents rocks from arming")
	controller.queue_free()
	await process_frame


func _test_unsupported_safe_shape_skips_rock_phase() -> void:
	var controller := _make_controller()
	if controller == null:
		return
	phase_order.clear()
	root.add_child(controller)
	await process_frame
	var safe_shape := controller.get_node("EntranceSafeArea").get_child(0) as CollisionShape2D
	var capsule := CapsuleShape2D.new()
	capsule.radius = 20.0
	capsule.height = 80.0
	safe_shape.shape = capsule
	controller.connect("phase_started", _on_phase_started)
	controller.start_encounter()
	await create_timer(0.25).timeout
	_expect(phase_order.has("spikes") and phase_order.has("fire"), "supported phases continue with an unsupported safe shape")
	_expect(not phase_order.has("rocks"), "unsupported entrance-safe geometry skips the rock phase")
	var active_rocks := controller.get_node_or_null("ActiveRockStrikes")
	_expect(active_rocks == null or active_rocks.get_child_count() == 0,
		"unsupported entrance-safe geometry never arms a rock")
	controller.stop_encounter()
	controller.queue_free()
	await process_frame


func _test_missing_references_warn_once_per_run() -> void:
	var controller := _make_controller()
	if controller == null:
		return
	configuration_warning_count = 0
	root.add_child(controller)
	await process_frame
	var spike_rows := controller.get_node("SpikeRows")
	for row in spike_rows.get_children():
		spike_rows.remove_child(row)
		row.queue_free()
	controller.connect("configuration_warning", _on_configuration_warning)
	controller.start_encounter()
	await create_timer(0.25).timeout
	_expect(configuration_warning_count == 1,
		"missing spike rows emit one warning instead of warning once per cycle")
	controller.stop_encounter()
	controller.queue_free()
	await process_frame


func _make_controller() -> Variant:
	var controller_script := load(CONTROLLER_SCRIPT_PATH) as Script
	_expect(controller_script != null, "Level3TrapController script loads")
	if controller_script == null:
		return null
	var spike_scene := load(SPIKE_ROW_SCENE_PATH) as PackedScene
	var fire_scene := load(FIRE_SWEEP_SCENE_PATH) as PackedScene
	var rock_scene := load(ROCK_STRIKE_SCENE_PATH) as PackedScene
	_expect(spike_scene != null and fire_scene != null and rock_scene != null, "real trap scenes load")
	if spike_scene == null or fire_scene == null or rock_scene == null:
		return null

	var controller: Variant = Node2D.new()
	controller.set_script(controller_script)
	controller.rock_strike_scene = rock_scene

	var spike_rows := Node2D.new()
	spike_rows.name = "SpikeRows"
	controller.add_child(spike_rows)
	for index in 3:
		var row := spike_scene.instantiate()
		row.name = "SpikeRow%d" % index
		row.warning_duration = 0.04
		row.active_duration = 0.04
		spike_rows.add_child(row)

	var fire_sweep := fire_scene.instantiate()
	fire_sweep.name = "FireSweep"
	fire_sweep.warning_duration = 0.04
	fire_sweep.travel_duration = 0.04
	controller.add_child(fire_sweep)

	var fire_start := Marker2D.new()
	fire_start.name = "FireStartMarker"
	fire_start.position = Vector2(-120, 40)
	controller.add_child(fire_start)
	var fire_end := Marker2D.new()
	fire_end.name = "FireEndMarker"
	fire_end.position = Vector2(120, 40)
	controller.add_child(fire_end)

	var rock_targets := Node2D.new()
	rock_targets.name = "RockTargets"
	controller.add_child(rock_targets)
	for target in [Vector2.ZERO, Vector2(-160, -20), Vector2(160, -20)]:
		var marker := Marker2D.new()
		marker.position = target
		rock_targets.add_child(marker)

	var entrance_safe_area := Area2D.new()
	entrance_safe_area.name = "EntranceSafeArea"
	var safe_shape := CollisionShape2D.new()
	var safe_rectangle := RectangleShape2D.new()
	safe_rectangle.size = Vector2(100, 100)
	safe_shape.shape = safe_rectangle
	entrance_safe_area.add_child(safe_shape)
	controller.add_child(entrance_safe_area)
	return controller


func _busy_spike_count(controller: Node) -> int:
	var count := 0
	for row in controller.get_node("SpikeRows").get_children():
		if row.state != SpikeRow.State.SAFE:
			count += 1
	return count


func _on_phase_started(phase: String) -> void:
	phase_order.append(phase)


func _stop_when_phase_starts(_phase: String, controller: Variant) -> void:
	stop_listener_triggered = true
	controller.stop_encounter()


func _on_configuration_warning(_message: String) -> void:
	configuration_warning_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
