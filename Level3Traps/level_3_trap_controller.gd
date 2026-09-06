class_name Level3TrapController
extends Node2D

signal phase_started(phase: String)
signal configuration_warning(message: String)

@export var spike_rows_path: NodePath = NodePath("SpikeRows")
@export var fire_sweep_path: NodePath = NodePath("FireSweep")
@export var fire_start_marker_path: NodePath = NodePath("FireStartMarker")
@export var fire_end_marker_path: NodePath = NodePath("FireEndMarker")
@export var rock_targets_path: NodePath = NodePath("RockTargets")
@export var entrance_safe_area_path: NodePath = NodePath("EntranceSafeArea")
@export var active_rock_strikes_path: NodePath = NodePath("ActiveRockStrikes")
@export var rock_strike_scene: PackedScene

var is_running: bool = false
var _run_serial: int = 0
var _next_spike_pattern: int = 0
var _active_rocks: Array[RockStrike] = []
var _disabled_phases: Dictionary = {}
var _warned_phases: Dictionary = {}

const SPIKE_PATTERNS := [[0, 2], [1]]


func _ready() -> void:
	if not Engine.is_editor_hint():
		var editor_visuals := get_node_or_null("SpikeEditorVisuals") as Node2D
		if editor_visuals != null:
			editor_visuals.visible = false


func start_encounter() -> void:
	if is_running:
		return
	is_running = true
	_run_serial += 1
	_disabled_phases.clear()
	_warned_phases.clear()
	_run_cycle.call_deferred(_run_serial)


func stop_encounter() -> void:
	is_running = false
	_run_serial += 1
	for row in _get_spike_rows():
		row.force_safe()
	var fire_sweep := _get_fire_sweep()
	if fire_sweep != null:
		fire_sweep.force_safe()
	for rock in _active_rocks:
		if is_instance_valid(rock):
			rock.force_safe()
			rock.queue_free()
	_active_rocks.clear()


func _run_cycle(serial: int) -> void:
	while _is_current_run(serial):
		await _run_spike_phase(serial)
		if not _is_current_run(serial):
			return
		await _run_fire_phase(serial)
		if not _is_current_run(serial):
			return
		await _run_rock_phase(serial)
		if _is_current_run(serial):
			await get_tree().process_frame


func _run_spike_phase(serial: int) -> void:
	var rows := _get_spike_rows()
	if rows.size() < 3:
		_disable_phase("spikes", "Level3TrapController needs three SpikeRow children.")
		return
	_enable_phase("spikes")
	var pattern: Array = SPIKE_PATTERNS[_next_spike_pattern]
	_next_spike_pattern = (_next_spike_pattern + 1) % SPIKE_PATTERNS.size()
	var selected_rows: Array[SpikeRow] = []
	for index in pattern:
		selected_rows.append(rows[index])
	phase_started.emit("spikes")
	if not _is_current_run(serial):
		return
	for row in selected_rows:
		row.activate()
	await _wait_until_safe(selected_rows, serial)


func _run_fire_phase(serial: int) -> void:
	var fire_sweep := _get_fire_sweep()
	var fire_start := get_node_or_null(fire_start_marker_path) as Marker2D
	var fire_end := get_node_or_null(fire_end_marker_path) as Marker2D
	if fire_sweep == null or fire_start == null or fire_end == null:
		_disable_phase("fire", "Level3TrapController needs FireSweep and both fire endpoint markers.")
		return
	_enable_phase("fire")
	phase_started.emit("fire")
	if not _is_current_run(serial):
		return
	fire_sweep.sweep(fire_start.global_position, fire_end.global_position)
	await _wait_until_safe([fire_sweep], serial)


func _run_rock_phase(serial: int) -> void:
	var target_root := get_node_or_null(rock_targets_path)
	var entrance_safe_area := get_node_or_null(entrance_safe_area_path) as Area2D
	if rock_strike_scene == null or target_root == null or entrance_safe_area == null:
		_disable_phase("rocks", "Level3TrapController needs RockStrike, RockTargets, and EntranceSafeArea.")
		return
	if not _safe_area_has_supported_geometry(entrance_safe_area):
		_disable_phase("rocks", "Level3TrapController EntranceSafeArea needs supported rectangle, circle, or polygon geometry.")
		return
	var targets := _safe_rock_targets(target_root, entrance_safe_area)
	if targets.size() < 2:
		_disable_phase("rocks", "Level3TrapController needs two rock targets outside EntranceSafeArea.")
		return
	var container := _get_rock_container()
	if container == null:
		_disable_phase("rocks", "Level3TrapController could not create ActiveRockStrikes.")
		return
	_enable_phase("rocks")
	phase_started.emit("rocks")
	if not _is_current_run(serial):
		return
	_active_rocks.clear()
	for target in targets.slice(0, 2):
		if not _is_current_run(serial):
			return
		var rock := rock_strike_scene.instantiate() as RockStrike
		if rock == null:
			_disable_phase("rocks", "Level3TrapController RockStrike scene must instantiate RockStrike.")
			return
		container.add_child(rock)
		_active_rocks.append(rock)
		if not _is_current_run(serial):
			rock.force_safe()
			rock.queue_free()
			return
		rock.strike_at(target.global_position)
	if _active_rocks.is_empty():
		return
	await _wait_until_safe(_active_rocks, serial)
	if not _is_current_run(serial):
		return
	for rock in _active_rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	_active_rocks.clear()


func _wait_until_safe(traps: Array, serial: int) -> void:
	while _is_current_run(serial):
		var has_busy_trap := false
		for trap in traps:
			if is_instance_valid(trap) and trap.state != 0:
				has_busy_trap = true
				break
		if not has_busy_trap:
			return
		await get_tree().process_frame


func _get_spike_rows() -> Array[SpikeRow]:
	var rows_root := get_node_or_null(spike_rows_path)
	if rows_root == null:
		return []
	var rows: Array[SpikeRow] = []
	for child in rows_root.get_children():
		if child is SpikeRow:
			rows.append(child)
	return rows


func _get_fire_sweep() -> FireSweep:
	return get_node_or_null(fire_sweep_path) as FireSweep


func _get_rock_container() -> Node2D:
	var existing := get_node_or_null(active_rock_strikes_path) as Node2D
	if existing != null:
		return existing
	if active_rock_strikes_path != NodePath("ActiveRockStrikes"):
		return null
	var container := Node2D.new()
	container.name = "ActiveRockStrikes"
	add_child(container)
	return container


func _safe_rock_targets(target_root: Node, entrance_safe_area: Area2D) -> Array[Marker2D]:
	var targets: Array[Marker2D] = []
	var occupied_positions: Array[Vector2] = []
	for child in target_root.get_children():
		var marker := child as Marker2D
		if marker == null or _point_is_in_safe_area(marker.global_position, entrance_safe_area):
			continue
		if occupied_positions.has(marker.global_position):
			continue
		targets.append(marker)
		occupied_positions.append(marker.global_position)
	return targets


func _point_is_in_safe_area(point: Vector2, safe_area: Area2D) -> bool:
	for child in safe_area.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape != null and _shape_contains_point(point, collision_shape):
			return true
		var collision_polygon := child as CollisionPolygon2D
		if collision_polygon != null and Geometry2D.is_point_in_polygon(collision_polygon.to_local(point), collision_polygon.polygon):
			return true
	return false


func _safe_area_has_supported_geometry(safe_area: Area2D) -> bool:
	var has_geometry := false
	for child in safe_area.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape != null:
			if collision_shape.shape == null:
				return false
			if not (collision_shape.shape is RectangleShape2D or collision_shape.shape is CircleShape2D):
				return false
			has_geometry = true
			continue
		var collision_polygon := child as CollisionPolygon2D
		if collision_polygon != null:
			if collision_polygon.polygon.size() < 3:
				return false
			has_geometry = true
	return has_geometry


func _shape_contains_point(point: Vector2, collision_shape: CollisionShape2D) -> bool:
	var shape := collision_shape.shape
	if shape == null:
		return false
	var local_point := collision_shape.to_local(point)
	if shape is RectangleShape2D:
		return absf(local_point.x) <= shape.size.x * 0.5 and absf(local_point.y) <= shape.size.y * 0.5
	if shape is CircleShape2D:
		return local_point.length_squared() <= shape.radius * shape.radius
	return false


func _is_current_run(serial: int) -> bool:
	return is_running and serial == _run_serial


func _disable_phase(phase: String, message: String) -> void:
	_disabled_phases[phase] = true
	if _warned_phases.has(phase):
		return
	_warned_phases[phase] = true
	push_warning(message)
	configuration_warning.emit(message)


func _enable_phase(phase: String) -> void:
	_disabled_phases.erase(phase)
	_warned_phases.erase(phase)
