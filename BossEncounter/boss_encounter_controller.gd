class_name BossEncounterController
extends Node2D

signal boss_ready(spawn_point: Marker2D)
signal encounter_changed
signal configuration_error(message: String)

enum State { WAITING, WAVE_1, WAVE_2, BOSS_READY }

@export var slime_scene: PackedScene
@export var skeleton_scene: PackedScene
@export var ranged_enemy_scene: PackedScene
@export var entrance_safe_area_path := NodePath("EntranceSafeArea")
@export var wave_1_spawn_points_path := NodePath("Wave1SpawnPoints")
@export var wave_2_skeleton_spawn_points_path := NodePath("Wave2SkeletonSpawnPoints")
@export var wave_2_ranged_spawn_points_path := NodePath("Wave2RangedSpawnPoints")
@export var spike_rows_path := NodePath("SpikeRows")
@export var fire_sweep_path := NodePath("FireSweep")
@export var fire_start_marker_path := NodePath("FireStartMarker")
@export var fire_end_marker_path := NodePath("FireEndMarker")
@export var active_minions_path := NodePath("ActiveMinions")
@export var active_projectiles_path := NodePath("ActiveProjectiles")
@export var boss_spawn_point_path := NodePath("BossSpawnPoint")
@export var trap_interval: float = 0.65

var _state: State = State.WAITING
var _run_serial: int = 0
var _boss_ready_emitted: bool = false


func _ready() -> void:
	# Huang Wan Jun 2204536 - Keep the future boss marker hidden until both minion waves finish.
	var marker := get_boss_spawn_point()
	if marker != null:
		marker.visible = false


# Huang Wan Jun 2204536 - Start the one-shot preparation trial only from its waiting state.
func start_encounter() -> void:
	if _state != State.WAITING:
		return
	var error := _wave_1_configuration_error()
	if not error.is_empty():
		_abort_current_wave(error)
		return
	if not _spawn_species(slime_scene, _get_markers(wave_1_spawn_points_path), "Slime"):
		return
	_state = State.WAVE_1
	_run_serial += 1
	encounter_changed.emit()
	_run_wave_1_traps.call_deferred(_run_serial)
	_watch_current_wave.call_deferred(_run_serial)


# Huang Wan Jun 2204536 - Allow only the player to arm the entrance trigger.
func _on_entrance_trigger_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		start_encounter()


# Huang Wan Jun 2204536 - Expose stable state and counts for the HUD and future boss integration.
func get_encounter_state() -> State:
	return _state


func is_boss_ready() -> bool:
	return _state == State.BOSS_READY


func debug_complete_trial() -> int:
	if _state == State.BOSS_READY:
		return 0

	var removed_count := _living_minions().size()
	_run_serial += 1
	_force_all_traps_safe()
	var minion_container := get_node_or_null(active_minions_path)
	if minion_container != null:
		for minion in minion_container.get_children():
			minion.queue_free()
	_state = State.BOSS_READY
	var marker := get_boss_spawn_point()
	if marker != null:
		marker.visible = true
	encounter_changed.emit()
	if not _boss_ready_emitted:
		_boss_ready_emitted = true
		boss_ready.emit(marker)
	return removed_count


func get_boss_spawn_point() -> Marker2D:
	return get_node_or_null(boss_spawn_point_path) as Marker2D


func get_wave_total() -> int:
	return 5 if _state == State.WAVE_1 or _state == State.WAVE_2 else 0


func get_wave_remaining() -> int:
	return _living_minions().size()


# Huang Wan Jun 2204536 - Validate a complete wave before creating any combatants.
func _wave_1_configuration_error() -> String:
	if slime_scene == null:
		return "BossEncounter Wave 1 requires slime_scene."
	if _get_markers(wave_1_spawn_points_path).size() != 5:
		return "BossEncounter Wave 1 requires exactly five slime spawn markers."
	if _get_spike_rows().size() != 2:
		return "BossEncounter Wave 1 requires exactly two SpikeRow children."
	if get_node_or_null(active_minions_path) as Node2D == null:
		return "BossEncounter requires ActiveMinions."
	if get_node_or_null(entrance_safe_area_path) as Area2D == null:
		return "BossEncounter requires EntranceSafeArea."
	if get_boss_spawn_point() == null:
		return "BossEncounter requires BossSpawnPoint."
	return ""


func _wave_2_configuration_error() -> String:
	if skeleton_scene == null:
		return "BossEncounter Wave 2 requires skeleton_scene."
	if ranged_enemy_scene == null:
		return "BossEncounter Wave 2 requires ranged_enemy_scene."
	if _get_markers(wave_2_skeleton_spawn_points_path).size() != 3:
		return "BossEncounter Wave 2 requires exactly three skeleton spawn markers."
	if _get_markers(wave_2_ranged_spawn_points_path).size() != 2:
		return "BossEncounter Wave 2 requires exactly two ranged spawn markers."
	if get_node_or_null(fire_sweep_path) as FireSweep == null:
		return "BossEncounter Wave 2 requires FireSweep."
	if get_node_or_null(fire_start_marker_path) as Marker2D == null:
		return "BossEncounter Wave 2 requires FireStartMarker."
	if get_node_or_null(fire_end_marker_path) as Marker2D == null:
		return "BossEncounter Wave 2 requires FireEndMarker."
	return ""


# Huang Wan Jun 2204536 - Spawn resolved minions under local ownership and isolate earlier level groups.
func _spawn_species(scene: PackedScene, markers: Array[Marker2D], prefix: String) -> bool:
	var container := get_node_or_null(active_minions_path) as Node2D
	if scene == null or container == null or markers.is_empty():
		return _abort_current_wave("BossEncounter cannot spawn %s: configuration is incomplete." % prefix)
	var prepared: Array[CollisionObject2D] = []
	for index in markers.size():
		var minion := scene.instantiate() as CollisionObject2D
		if minion == null:
			_free_prepared(prepared)
			return _abort_current_wave("BossEncounter %s scene must instantiate CollisionObject2D." % prefix)
		minion.name = "%s%d" % [prefix, index + 1]
		container.add_child(minion)
		minion.add_to_group("boss_minion")
		minion.add_to_group("boss_enemy")
		for old_group in [&"level1_enemy", &"level2_enemy", &"level3_enemy"]:
			if minion.is_in_group(old_group):
				minion.remove_from_group(old_group)
		var spawn_position := SpawnPositionResolver.place_clear_of_walls(
			minion, markers[index].global_position, get_boss_spawn_point().global_position
		)
		if _point_in_entrance_safe_area(spawn_position):
			_free_prepared(prepared + [minion])
			return _abort_current_wave("BossEncounter found no safe position for %s%d." % [prefix, index + 1])
		prepared.append(minion)
	return true


func _free_prepared(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()


# Huang Wan Jun 2204536 - Reject authored or resolved spawns inside the protected entrance.
func _point_in_entrance_safe_area(point: Vector2) -> bool:
	var area := get_node_or_null(entrance_safe_area_path) as Area2D
	if area == null:
		return true
	for child in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var local := shape_node.to_local(point)
			var half_size: Vector2 = (shape_node.shape as RectangleShape2D).size * 0.5
			if absf(local.x) <= half_size.x and absf(local.y) <= half_size.y:
				return true
		var polygon := child as CollisionPolygon2D
		if polygon != null and Geometry2D.is_point_in_polygon(polygon.to_local(point), polygon.polygon):
			return true
	return false


# Huang Wan Jun 2204536 - Count only living minions owned beneath this encounter.
func _living_minions() -> Array[Node]:
	var result: Array[Node] = []
	var container := get_node_or_null(active_minions_path)
	if container == null:
		return result
	for child in container.get_children():
		if child.is_queued_for_deletion():
			continue
		var health: Variant = child.get("current_health")
		if (health is int or health is float) and health <= 0:
			continue
		result.append(child)
	return result


# Huang Wan Jun 2204536 - Progress only after every locally owned minion is defeated.
func _watch_current_wave(serial: int) -> void:
	while serial == _run_serial and _state in [State.WAVE_1, State.WAVE_2]:
		await get_tree().process_frame
		if serial != _run_serial or not is_inside_tree():
			return
		encounter_changed.emit()
		if not _living_minions().is_empty():
			continue
		if _state == State.WAVE_1:
			_begin_wave_2()
		else:
			_finish_trial()
		return


func _begin_wave_2() -> void:
	_run_serial += 1
	_force_spikes_safe()
	var error := _wave_2_configuration_error()
	if not error.is_empty():
		_abort_current_wave(error)
		return
	var before := get_node(active_minions_path).get_child_count()
	if not _spawn_species(skeleton_scene, _get_markers(wave_2_skeleton_spawn_points_path), "Skeleton"):
		return
	if not _spawn_species(ranged_enemy_scene, _get_markers(wave_2_ranged_spawn_points_path), "Ranged"):
		_free_children_from_index(get_node(active_minions_path), before)
		return
	_state = State.WAVE_2
	_run_serial += 1
	encounter_changed.emit()
	_run_wave_2_fire.call_deferred(_run_serial)
	_watch_current_wave.call_deferred(_run_serial)


func _free_children_from_index(container: Node, start_index: int) -> void:
	var children := container.get_children()
	for index in range(start_index, children.size()):
		children[index].queue_free()


# Huang Wan Jun 2204536 - Alternate one warned spike row at a time during Wave 1.
func _run_wave_1_traps(serial: int) -> void:
	var rows := _get_spike_rows()
	var index := 0
	while serial == _run_serial and _state == State.WAVE_1:
		rows[index].activate()
		await rows[index].activation_finished
		if serial != _run_serial or _state != State.WAVE_1:
			return
		index = 1 - index
		await get_tree().create_timer(trap_interval).timeout


# Huang Wan Jun 2204536 - Repeat the warned fire crossing only during Wave 2.
func _run_wave_2_fire(serial: int) -> void:
	var fire := get_node(fire_sweep_path) as FireSweep
	var start := get_node(fire_start_marker_path) as Marker2D
	var finish := get_node(fire_end_marker_path) as Marker2D
	while serial == _run_serial and _state == State.WAVE_2:
		fire.sweep(start.global_position, finish.global_position)
		await fire.sweep_finished
		if serial != _run_serial or _state != State.WAVE_2:
			return
		await get_tree().create_timer(trap_interval).timeout


# Huang Wan Jun 2204536 - Finish with a clean arena and one future-boss notification.
func _finish_trial() -> void:
	if _state != State.WAVE_2:
		return
	_run_serial += 1
	_force_all_traps_safe()
	var projectiles := get_node_or_null(active_projectiles_path)
	if projectiles != null:
		for projectile in projectiles.get_children():
			projectile.queue_free()
	_state = State.BOSS_READY
	var marker := get_boss_spawn_point()
	if marker != null:
		marker.visible = true
	encounter_changed.emit()
	if not _boss_ready_emitted:
		_boss_ready_emitted = true
		boss_ready.emit(marker)


func _force_spikes_safe() -> void:
	for row in _get_spike_rows():
		row.force_safe()


func _force_all_traps_safe() -> void:
	_force_spikes_safe()
	var fire := get_node_or_null(fire_sweep_path) as FireSweep
	if fire != null:
		fire.force_safe()


# Huang Wan Jun 2204536 - Abort invalid waves without leaving hazards or partial enemies active.
func _abort_current_wave(message: String) -> bool:
	_run_serial += 1
	_force_all_traps_safe()
	push_error(message)
	configuration_error.emit(message)
	return false


func _get_markers(path: NodePath) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	var root_node := get_node_or_null(path)
	if root_node == null:
		return markers
	for child in root_node.get_children():
		var marker := child as Marker2D
		if marker == null:
			return []
		markers.append(marker)
	return markers


func _get_spike_rows() -> Array[SpikeRow]:
	var rows: Array[SpikeRow] = []
	var root_node := get_node_or_null(spike_rows_path)
	if root_node == null:
		return rows
	for child in root_node.get_children():
		if child is SpikeRow:
			rows.append(child)
	return rows
