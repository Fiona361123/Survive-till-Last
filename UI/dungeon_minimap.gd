class_name DungeonMinimap
extends Control

const PANEL_PADDING: float = 10.0
# Huang Wan Jun 2204536 - Share the fixed dungeon geometry without requiring constant expressions.
static var LEVEL_POLYGONS: Dictionary = {
	1: PackedVector2Array([Vector2(-6500, 300), Vector2(-3600, -1150), Vector2(-1800, -250), Vector2(-4550, 1500)]),
	2: PackedVector2Array([Vector2(-1850, -950), Vector2(850, -450), Vector2(2050, 700), Vector2(-750, 950)]),
	3: PackedVector2Array([Vector2(2200, -900), Vector2(4650, -350), Vector2(4750, 1450), Vector2(2450, 1050)]),
	4: PackedVector2Array([Vector2(700, 1250), Vector2(2600, 1550), Vector2(1550, 3300), Vector2(-200, 2600)]),
}

# Huang Wan Jun 2204536 - Store the dungeon extent and permanently discovered sections.
@export var world_bounds: Rect2 = Rect2(-7100, -1700, 12000, 6200)
var _revealed_levels: Array[int] = [1]

# Huang Wan Jun 2204536 - Permanently reveal one valid dungeon section.
func reveal_level(level_number: int) -> void:
	if LEVEL_POLYGONS.has(level_number) and not _revealed_levels.has(level_number):
		_revealed_levels.append(level_number)
		_revealed_levels.sort()
		queue_redraw()

# Huang Wan Jun 2204536 - Read reveal state without exposing internal storage.
func is_level_revealed(level_number: int) -> bool:
	return _revealed_levels.has(level_number)

func get_revealed_levels() -> Array[int]:
	return _revealed_levels.duplicate()

# Huang Wan Jun 2204536 - Keep map content inset from its decorative frame.
func get_drawable_rect() -> Rect2:
	return Rect2(Vector2.ONE * PANEL_PADDING, size - Vector2.ONE * PANEL_PADDING * 2.0)

# Huang Wan Jun 2204536 - Map world coordinates with one centered, aspect-preserving transform.
func world_to_minimap(world_position: Vector2) -> Vector2:
	var drawable := get_drawable_rect()
	var safe_world_size := Vector2(maxf(world_bounds.size.x, 1.0), maxf(world_bounds.size.y, 1.0))
	var scale_factor := minf(drawable.size.x / safe_world_size.x, drawable.size.y / safe_world_size.y)
	var fitted_size := safe_world_size * scale_factor
	var fitted_origin := drawable.position + (drawable.size - fitted_size) * 0.5
	var normalized := (world_position - world_bounds.position) / safe_world_size
	var mapped := fitted_origin + normalized * fitted_size
	return mapped.clamp(drawable.position, drawable.end)

# Huang Wan Jun 2204536 - Draw the panel and the dungeon regions discovered so far.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.08, 0.82), true)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color(0.85, 0.68, 0.25, 0.9), false, 1.0)

	for level_number in _revealed_levels:
		var world_polygon: PackedVector2Array = LEVEL_POLYGONS[level_number]
		var minimap_polygon := PackedVector2Array()
		for world_vertex in world_polygon:
			minimap_polygon.append(world_to_minimap(world_vertex))
		draw_colored_polygon(minimap_polygon, Color(0.26, 0.38, 0.56, 0.86))
		draw_polyline(minimap_polygon + PackedVector2Array([minimap_polygon[0]]), Color(0.85, 0.68, 0.25, 1.0), 1.5, true)
