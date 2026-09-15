# Huang Wan Jun 2204536
extends Area2D
class_name FallHazard

@export var fall_damage: int = 1

var _left_marker: Marker2D
var _right_marker: Marker2D
var _handled_bodies: Dictionary[int, bool] = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	# Huang Wan Jun 2204536 - Keep checking overlaps until the body's center enters the hole.
	for overlapping_body in get_overlapping_bodies():
		_on_body_entered(overlapping_body)


func configure_respawn_markers(left: Marker2D, right: Marker2D) -> void:
	_left_marker = left
	_right_marker = right


func _on_body_entered(body: Node2D) -> void:
	if not _contains_logical_body_position(body.global_position):
		return
	var body_id := body.get_instance_id()
	if _handled_bodies.has(body_id):
		return
	_handled_bodies[body_id] = true

	if body.is_in_group("enemy") or body.is_in_group("level1_enemy"):
		body.queue_free()
		return

	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	body.take_damage(fall_damage)


func _contains_logical_body_position(global_body_position: Vector2) -> bool:
	var has_collision_polygon := false
	for child in find_children("*", "CollisionPolygon2D", true, false):
		var collision_polygon := child as CollisionPolygon2D
		if collision_polygon == null:
			continue
		has_collision_polygon = true
		if collision_polygon.disabled or collision_polygon.polygon.size() < 3:
			continue
		var polygon_local_position := collision_polygon.to_local(global_body_position)
		if Geometry2D.is_point_in_polygon(polygon_local_position, collision_polygon.polygon):
			return true
	return not has_collision_polygon


func _on_body_exited(body: Node2D) -> void:
	_handled_bodies.erase(body.get_instance_id())


func reset_handled_bodies() -> void:
	_handled_bodies.clear()


func _move_player_to_closest_marker(player: Node2D) -> void:
	var left_is_valid := is_instance_valid(_left_marker)
	var right_is_valid := is_instance_valid(_right_marker)
	if not left_is_valid and not right_is_valid:
		return
	if not right_is_valid:
		player.global_position = _left_marker.global_position
		return
	if not left_is_valid:
		player.global_position = _right_marker.global_position
		return

	var left_distance := player.global_position.distance_squared_to(_left_marker.global_position)
	var right_distance := player.global_position.distance_squared_to(_right_marker.global_position)
	if left_distance <= right_distance:
		player.global_position = _left_marker.global_position
	else:
		player.global_position = _right_marker.global_position
