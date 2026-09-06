class_name SpawnPositionResolver
extends RefCounted

const SOLID_WORLD_MASK: int = 1
const CLEARANCE_STEP: float = 32.0
const MAX_CLEARANCE_STEPS: int = 8


static func place_clear_of_walls(
	body: CollisionObject2D,
	preferred_position: Vector2,
	toward_position: Vector2,
	require_direct_path: bool = false
) -> Vector2:
	var primary_direction := preferred_position.direction_to(toward_position)
	if primary_direction.is_zero_approx():
		primary_direction = Vector2.DOWN

	var directions: Array[Vector2] = [
		primary_direction,
		primary_direction.rotated(PI / 4.0),
		primary_direction.rotated(-PI / 4.0),
		primary_direction.rotated(PI / 2.0),
		primary_direction.rotated(-PI / 2.0),
		-primary_direction,
	]

	body.global_position = preferred_position
	if _position_is_usable(body, toward_position, require_direct_path):
		_update_home_position(body)
		return preferred_position

	for step_index in range(1, MAX_CLEARANCE_STEPS + 1):
		for direction in directions:
			var candidate := preferred_position + direction * CLEARANCE_STEP * step_index
			body.global_position = candidate
			if _position_is_usable(body, toward_position, require_direct_path):
				_update_home_position(body)
				return candidate

	body.global_position = preferred_position
	_update_home_position(body)
	push_warning("No clear wall-free position found near enemy spawn at %s." % preferred_position)
	return preferred_position


static func _position_is_usable(
	body: CollisionObject2D,
	toward_position: Vector2,
	require_direct_path: bool
) -> bool:
	if not _position_is_clear(body):
		return false
	return not require_direct_path or _path_is_clear(body, toward_position)


static func _position_is_clear(body: CollisionObject2D) -> bool:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return true
	body.force_update_transform()
	collision.force_update_transform()

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.margin = 2.0
	query.collision_mask = SOLID_WORLD_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [body.get_rid()]
	return body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


static func _path_is_clear(body: CollisionObject2D, toward_position: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		body.global_position,
		toward_position,
		SOLID_WORLD_MASK,
		[body.get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func _update_home_position(body: CollisionObject2D) -> void:
	if "home_position" in body:
		body.set("home_position", body.global_position)
