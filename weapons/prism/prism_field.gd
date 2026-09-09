extends Node2D
class_name PrismField

signal field_activated
signal collapse_exploded(position: Vector2, radius: float, damage: int)
signal field_finished

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

enum FieldState { IDLE, DEPLOYING, ACTIVE, WARNING, COLLAPSING, EXPLODING, FINISHED }

@export var prism_scene: PackedScene

var state: FieldState = FieldState.IDLE
var prisms: Array[PrismNode] = []
var beam_glows: Array[Line2D] = []
var beam_cores: Array[Line2D] = []
var target_center: Vector2 = Vector2.ZERO
var base_angle: float = 0.0
var orbit_angle: float = 0.0
var elapsed_time: float = 0.0
var deployed_count: int = 0

var deployment_radius: float = 130.0
var deployment_duration: float = 0.5
var field_duration: float = 6.0
var warning_duration: float = 0.65
var collapse_duration: float = 0.45
var explosion_visual_duration: float = 0.55
var orbit_speed: float = 0.55
var interior_damage: int = 10
var beam_damage: int = 6
var pulse_interval: float = 0.6
var beam_hit_interval: float = 0.3
var damage_check_interval: float = 0.08
var beam_hit_distance: float = 22.0
var collapse_min_damage: int = 35
var collapse_max_damage: int = 60

var phase_time_left: float = 0.0
var damage_check_left: float = 0.0
var interior_hit_times: Dictionary = {}
var beam_hit_times: Dictionary = {}
var collapse_centroid: Vector2 = Vector2.ZERO
var collapse_area: float = 0.0
var explosion_radius: float = 0.0
var explosion_elapsed: float = 0.0

@onready var field_fill: Polygon2D = $FieldFill
@onready var beam_container: Node2D = $BeamContainer
@onready var prism_container: Node2D = $PrismContainer


func _ready() -> void:
	field_fill.visible = false
	_create_beam_layers()
	set_physics_process(false)


func begin_field(caster_position: Vector2, center: Vector2, settings: Dictionary = {}) -> void:
	if state != FieldState.IDLE or prism_scene == null:
		return
	_apply_settings(settings)
	target_center = center
	base_angle = center.direction_to(caster_position).angle()
	state = FieldState.DEPLOYING
	set_physics_process(true)

	for index in range(3):
		var prism := prism_scene.instantiate() as PrismNode
		if prism == null:
			_finish_field()
			return
		prism_container.add_child(prism)
		prisms.append(prism)
		prism.deployment_completed.connect(_on_prism_deployed)
		var angle := base_angle + float(index) * TAU / 3.0
		var destination := target_center + Vector2.RIGHT.rotated(angle) * deployment_radius
		prism.deploy(caster_position, destination, deployment_duration)


func _apply_settings(settings: Dictionary) -> void:
	deployment_radius = float(settings.get("deployment_radius", deployment_radius))
	deployment_duration = float(settings.get("deployment_duration", deployment_duration))
	field_duration = float(settings.get("field_duration", field_duration))
	warning_duration = float(settings.get("warning_duration", warning_duration))
	collapse_duration = float(settings.get("collapse_duration", collapse_duration))
	explosion_visual_duration = float(settings.get("explosion_visual_duration", explosion_visual_duration))
	orbit_speed = float(settings.get("orbit_speed", orbit_speed))
	interior_damage = int(settings.get("interior_damage", interior_damage))
	beam_damage = int(settings.get("beam_damage", beam_damage))
	pulse_interval = float(settings.get("pulse_interval", pulse_interval))
	beam_hit_interval = float(settings.get("beam_hit_interval", beam_hit_interval))
	damage_check_interval = float(settings.get("damage_check_interval", damage_check_interval))
	beam_hit_distance = float(settings.get("beam_hit_distance", beam_hit_distance))
	collapse_min_damage = int(settings.get("collapse_min_damage", collapse_min_damage))
	collapse_max_damage = int(settings.get("collapse_max_damage", collapse_max_damage))


func _physics_process(delta: float) -> void:
	elapsed_time += delta
	match state:
		FieldState.DEPLOYING:
			_update_geometry()
		FieldState.ACTIVE:
			phase_time_left -= delta
			_update_orbit(delta)
			_update_geometry()
			damage_check_left -= delta
			if damage_check_left <= 0.0:
				damage_check_left = maxf(damage_check_interval, 0.01)
				_apply_field_damage()
			if phase_time_left <= 0.0:
				_begin_warning()
		FieldState.WARNING:
			phase_time_left -= delta
			_update_orbit(delta * 0.25)
			_update_geometry()
			if phase_time_left <= 0.0:
				_begin_collapse()
		FieldState.COLLAPSING:
			phase_time_left -= delta
			_update_geometry()
			if phase_time_left <= 0.0:
				_explode()
		FieldState.EXPLODING:
			explosion_elapsed += delta
			queue_redraw()
			if explosion_elapsed >= explosion_visual_duration:
				_finish_field()


func _on_prism_deployed(_prism: PrismNode) -> void:
	deployed_count += 1
	if deployed_count < 3 or state != FieldState.DEPLOYING:
		return
	state = FieldState.ACTIVE
	phase_time_left = maxf(field_duration, 0.01)
	damage_check_left = 0.0
	field_fill.visible = true
	_update_geometry()
	field_activated.emit()


func _update_orbit(delta: float) -> void:
	orbit_angle += orbit_speed * delta
	var breathing_radius := deployment_radius * (1.0 + sin(elapsed_time * 1.8) * 0.08)
	for index in range(prisms.size()):
		var prism := prisms[index]
		if not is_instance_valid(prism) or prism.collapsing:
			continue
		var angle := base_angle + orbit_angle + float(index) * TAU / 3.0
		prism.global_position = target_center + Vector2.RIGHT.rotated(angle) * breathing_radius


func _create_beam_layers() -> void:
	for _index in range(3):
		var glow := Line2D.new()
		glow.width = 13.0
		glow.default_color = Color(0.28, 0.12, 1.0, 0.34)
		glow.antialiased = true
		glow.z_index = 20
		beam_container.add_child(glow)
		beam_glows.append(glow)

		var core := Line2D.new()
		core.width = 3.2
		core.default_color = Color(0.55, 0.92, 1.0, 0.96)
		core.antialiased = true
		core.z_index = 21
		beam_container.add_child(core)
		beam_cores.append(core)


func _update_geometry() -> void:
	var vertices := get_triangle_vertices()
	if vertices.size() != 3:
		return
	var local_vertices := PackedVector2Array()
	for vertex in vertices:
		local_vertices.append(to_local(vertex))
	field_fill.polygon = local_vertices
	field_fill.color = Color(0.18, 0.06, 0.55, 0.11 + sin(elapsed_time * 4.0) * 0.035)

	for index in range(3):
		var edge := PackedVector2Array([
			local_vertices[index],
			local_vertices[(index + 1) % 3],
		])
		beam_glows[index].points = edge
		beam_cores[index].points = edge
		var warning_boost := 0.45 if state == FieldState.WARNING else 0.0
		beam_glows[index].modulate.a = 0.72 + warning_boost * absf(sin(elapsed_time * 16.0))
		beam_cores[index].modulate.a = 0.82 + 0.18 * absf(sin(elapsed_time * 9.0 + index))
	queue_redraw()


func get_triangle_vertices() -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for prism in prisms:
		if is_instance_valid(prism):
			vertices.append(prism.global_position)
	return vertices


func _apply_field_damage() -> void:
	var vertices := get_triangle_vertices()
	if vertices.size() != 3:
		return
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		var enemy_id := enemy.get_instance_id()
		var edge_distance := distance_to_edges(enemy.global_position, vertices)
		if edge_distance <= beam_hit_distance:
			if elapsed_time >= float(beam_hit_times.get(enemy_id, -1000.0)):
				enemy.take_damage(beam_damage)
				beam_hit_times[enemy_id] = elapsed_time + beam_hit_interval
				_flash_prisms()
		elif contains_point(enemy.global_position, vertices):
			if elapsed_time >= float(interior_hit_times.get(enemy_id, -1000.0)):
				enemy.take_damage(interior_damage)
				interior_hit_times[enemy_id] = elapsed_time + pulse_interval
	_prune_damage_memory()


func _flash_prisms() -> void:
	for prism in prisms:
		if is_instance_valid(prism):
			prism.flash()


func _prune_damage_memory() -> void:
	for enemy_id in interior_hit_times.keys():
		if not is_instance_valid(instance_from_id(int(enemy_id))):
			interior_hit_times.erase(enemy_id)
	for enemy_id in beam_hit_times.keys():
		if not is_instance_valid(instance_from_id(int(enemy_id))):
			beam_hit_times.erase(enemy_id)


func _begin_warning() -> void:
	state = FieldState.WARNING
	phase_time_left = maxf(warning_duration, 0.01)
	_flash_prisms()


func _begin_collapse() -> void:
	var vertices := get_triangle_vertices()
	if vertices.size() != 3:
		_finish_field()
		return
	collapse_centroid = calculate_centroid(vertices)
	collapse_area = calculate_area(vertices)
	state = FieldState.COLLAPSING
	phase_time_left = maxf(collapse_duration, 0.01)
	field_fill.color = Color(0.5, 0.18, 1.0, 0.25)
	for prism in prisms:
		if is_instance_valid(prism):
			prism.collapse_to(collapse_centroid, collapse_duration)


func _explode() -> void:
	var reference_area := maxf(deployment_radius * deployment_radius * 1.299, 1.0)
	var area_ratio := clampf(collapse_area / reference_area, 0.0, 1.0)
	explosion_radius = lerpf(105.0, 215.0, area_ratio)
	var explosion_damage := roundi(lerpf(float(collapse_max_damage), float(collapse_min_damage), area_ratio))

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		if enemy.global_position.distance_to(collapse_centroid) <= explosion_radius:
			enemy.take_damage(explosion_damage)

	for glow in beam_glows:
		glow.visible = false
	for core in beam_cores:
		core.visible = false
	field_fill.visible = false
	for prism in prisms:
		if is_instance_valid(prism):
			prism.visible = false
	state = FieldState.EXPLODING
	explosion_elapsed = 0.0
	_play_screen_shake()
	collapse_exploded.emit(collapse_centroid, explosion_radius, explosion_damage)
	queue_redraw()


func _play_screen_shake() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var original_offset := camera.offset
	var strength := clampf(explosion_radius * 0.035, 4.0, 8.0)
	var tween := create_tween()
	for direction in [
		Vector2(1.0, -0.6),
		Vector2(-0.8, 0.8),
		Vector2(0.6, 0.4),
		Vector2(-0.35, -0.25),
	]:
		tween.tween_property(camera, "offset", original_offset + direction * strength, 0.045)
	tween.tween_property(camera, "offset", original_offset, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _finish_field() -> void:
	if state == FieldState.FINISHED:
		return
	state = FieldState.FINISHED
	set_physics_process(false)
	field_finished.emit()
	queue_free()


func _draw() -> void:
	if state in [FieldState.ACTIVE, FieldState.WARNING]:
		var vertices := get_triangle_vertices()
		if vertices.size() == 3:
			var centroid := calculate_centroid(vertices)
			var pulse_radius := 14.0 + absf(sin(elapsed_time * 5.0)) * 16.0
			draw_arc(to_local(centroid), pulse_radius, 0.0, TAU, 32, Color(0.55, 0.85, 1.0, 0.55), 2.0, true)
			for edge_index in range(3):
				for mote_index in range(2):
					var progress := fmod(elapsed_time * 0.7 + float(mote_index) * 0.5 + float(edge_index) * 0.17, 1.0)
					var point := vertices[edge_index].lerp(vertices[(edge_index + 1) % 3], progress)
					draw_circle(to_local(point), 4.0, Color(0.75, 0.98, 1.0, 0.9))
	elif state == FieldState.EXPLODING:
		var progress := clampf(explosion_elapsed / maxf(explosion_visual_duration, 0.01), 0.0, 1.0)
		var radius := lerpf(18.0, explosion_radius, progress)
		var alpha := 1.0 - progress
		draw_circle(to_local(collapse_centroid), radius * 0.55, Color(0.35, 0.12, 0.9, alpha * 0.22))
		draw_arc(to_local(collapse_centroid), radius, 0.0, TAU, 64, Color(0.7, 0.95, 1.0, alpha), 6.0, true)
		draw_arc(to_local(collapse_centroid), radius * 0.72, 0.0, TAU, 64, Color(0.75, 0.35, 1.0, alpha), 3.0, true)


static func contains_point(point: Vector2, vertices: PackedVector2Array) -> bool:
	return vertices.size() == 3 and Geometry2D.is_point_in_polygon(point, vertices)


static func distance_to_edges(point: Vector2, vertices: PackedVector2Array) -> float:
	if vertices.size() != 3:
		return INF
	var nearest := INF
	for index in range(3):
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			vertices[index],
			vertices[(index + 1) % 3]
		)
		nearest = minf(nearest, point.distance_to(closest))
	return nearest


static func calculate_centroid(vertices: PackedVector2Array) -> Vector2:
	if vertices.size() != 3:
		return Vector2.ZERO
	return (vertices[0] + vertices[1] + vertices[2]) / 3.0


static func calculate_area(vertices: PackedVector2Array) -> float:
	if vertices.size() != 3:
		return 0.0
	return absf((vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])) * 0.5
