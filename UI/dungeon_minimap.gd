class_name DungeonMinimap
extends Control

# Huang Wan Jun 2204536 - Define minimap framing and the allowed enemy group per level.
const PANEL_PADDING: float = 10.0
const ENEMY_GROUP_BY_LEVEL := {1: "level1_enemy", 2: "level2_enemy", 3: "level3_enemy", 4: "boss_enemy"}
# Huang Wan Jun 2204536 - Match each enemy script's DEATH enum so animated corpses never receive markers.
const DEATH_STATE_BY_SCRIPT := {
	"res://skeleton.gd": 6,
	"res://Enemy/slime.gd": 3,
	"res://RangedEnemy.gd": 7,
}
# Huang Wan Jun 2204536 - Share root-adjusted Dungeon.tscn footprints without requiring constant expressions.
static var LEVEL_POLYGONS: Dictionary = {
	# Dungeon root (139, 71) plus Wall (-43, 6) and the Level 1 combat boundary.
	1: PackedVector2Array([Vector2(863, -468), Vector2(-1056, 465), Vector2(734, 1359), Vector2(2653, 401)]),
	# Dungeon-root adjusted Level 2 spawn arena and its transformed entrance around (-1397, 1591).
	2: PackedVector2Array([Vector2(-5400, 700), Vector2(-3500, 600), Vector2(-1100, 1450), Vector2(-1200, 2500), Vector2(-1800, 3450), Vector2(-3500, 3500), Vector2(-5400, 2700)]),
	# Dungeon-root adjusted Level 3 entrance around (3373, 71) and ranged-enemy arena.
	3: PackedVector2Array([Vector2(3150, -300), Vector2(4450, -450), Vector2(5200, 100), Vector2(5050, 850), Vector2(3800, 1000), Vector2(3150, 250)]),
	# Dungeon-root adjusted boss entrance around (960, -1420) and boss-room enemy.
	4: PackedVector2Array([Vector2(650, -1550), Vector2(850, -2550), Vector2(1550, -2550), Vector2(1750, -2100), Vector2(1300, -1200), Vector2(800, -1200)]),
}
# Huang Wan Jun 2204536 - Follow the actual Floor tile bends instead of drawing shortcut quadrilaterals between gates.
static var CORRIDOR_PATHS: Dictionary = {
	1: PackedVector2Array([
		Vector2(-32, 909), Vector2(-1396.75, 1591.25),
	]),
	2: PackedVector2Array([
		Vector2(1696, -19), Vector2(1633, -30), Vector2(1889, 98), Vector2(2401, -158),
		Vector2(2529, -222), Vector2(2913, -30), Vector2(3297, 34), Vector2(3372.75, 71),
	]),
	3: PackedVector2Array([
		Vector2(2976, -659), Vector2(2913, -670), Vector2(3169, -926), Vector2(2145, -1438),
		Vector2(865, -1438), Vector2(913.5, -1352.5),
	]),
}

# Huang Wan Jun 2204536 - Store the dungeon extent and permanently discovered sections.
@export var world_bounds: Rect2 = Rect2(-7100, -3300, 13000, 7500)
var _revealed_levels: Array[int] = [1]

# Huang Wan Jun 2204536 - Keep the active-level player and enemy marker snapshots.
var _current_level: int = 1
var _player_marker: Variant = null
var _enemy_markers: PackedVector2Array = PackedVector2Array()

# Huang Wan Jun 2204536 - Permanently reveal one valid dungeon section.
func reveal_level(level_number: int) -> void:
	if LEVEL_POLYGONS.has(level_number) and not _revealed_levels.has(level_number):
		_revealed_levels.append(level_number)
		_revealed_levels.sort()
		queue_redraw()

# Huang Wan Jun 2204536 - Read reveal state without exposing internal storage.
func is_level_revealed(level_number: int) -> bool:
	return _revealed_levels.has(level_number)

# Huang Wan Jun 2204536 - Return a copy of the permanently revealed dungeon sections.
func get_revealed_levels() -> Array[int]:
	return _revealed_levels.duplicate()


# Huang Wan Jun 2204536 - Reveal each road only after its destination level unlocks.
func get_revealed_corridors() -> Array[int]:
	var corridors: Array[int] = []
	for corridor_number in CORRIDOR_PATHS:
		if _revealed_levels.has(corridor_number + 1):
			corridors.append(corridor_number)
	corridors.sort()
	return corridors

# Huang Wan Jun 2204536 - Provide a safe copy of one authored floor route for minimap checks and drawing.
func get_corridor_path(corridor_number: int) -> PackedVector2Array:
	return (CORRIDOR_PATHS.get(corridor_number, PackedVector2Array()) as PackedVector2Array).duplicate()

# Huang Wan Jun 2204536 - Select the one enemy group allowed to appear on the map.
func set_current_level(level_number: int) -> void:
	_current_level = level_number
	refresh_markers()

# Huang Wan Jun 2204536 - Read the level used to filter enemy markers.
func get_current_level() -> int:
	return _current_level

# Huang Wan Jun 2204536 - Snapshot valid player and active-level enemy positions safely.
func refresh_markers() -> void:
	_player_marker = null
	_enemy_markers.clear()
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	var player := scene_tree.get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and player.is_inside_tree():
		_player_marker = world_to_minimap(player.global_position)
	var group_name := StringName(ENEMY_GROUP_BY_LEVEL.get(_current_level, ""))
	if not group_name.is_empty():
		for candidate in scene_tree.get_nodes_in_group(group_name):
			var enemy := candidate as Node2D
			if _is_living_enemy(enemy):
				_enemy_markers.append(world_to_minimap(enemy.global_position))
	queue_redraw()

# Huang Wan Jun 2204536 - Exclude queued, zero-health, and DEATH-state actors before their animations free them.
func _is_living_enemy(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
		return false
	var health: Variant = enemy.get("current_health")
	if health is int or health is float:
		if health <= 0:
			return false
	var enemy_script := enemy.get_script() as Script
	if enemy_script != null:
		var death_state: Variant = DEATH_STATE_BY_SCRIPT.get(enemy_script.resource_path)
		if death_state != null and enemy.get("current_state") == death_state:
			return false
	return true

# Huang Wan Jun 2204536 - Return the latest player marker without exposing actor state.
func get_player_marker() -> Variant:
	return _player_marker

# Huang Wan Jun 2204536 - Return a copy of the active-level enemy marker snapshot.
func get_enemy_markers() -> PackedVector2Array:
	return _enemy_markers.duplicate()

# Huang Wan Jun 2204536 - Keep map content inset from its decorative frame.
func get_drawable_rect() -> Rect2:
	return Rect2(Vector2.ONE * PANEL_PADDING, size - Vector2.ONE * PANEL_PADDING * 2.0)

# Huang Wan Jun 2204536 - Frame only discovered sections so the visible map uses the available panel space.
func _get_visible_world_bounds() -> Rect2:
	var has_vertex := false
	var visible_bounds := Rect2()
	for level_number in _revealed_levels:
		var polygon: PackedVector2Array = LEVEL_POLYGONS.get(level_number, PackedVector2Array())
		for vertex in polygon:
			if not has_vertex:
				visible_bounds = Rect2(vertex, Vector2.ZERO)
				has_vertex = true
			else:
				visible_bounds = visible_bounds.expand(vertex)
	for corridor_number in get_revealed_corridors():
		for vertex in get_corridor_path(corridor_number):
			visible_bounds = visible_bounds.expand(vertex)
	if not has_vertex:
		return world_bounds
	var margin := maxf(visible_bounds.size.x, visible_bounds.size.y) * 0.08
	return visible_bounds.grow(margin)

# Huang Wan Jun 2204536 - Map world coordinates with one centered, aspect-preserving transform.
func world_to_minimap(world_position: Vector2) -> Vector2:
	var drawable := get_drawable_rect()
	var visible_world_bounds := _get_visible_world_bounds()
	var safe_world_size := Vector2(maxf(visible_world_bounds.size.x, 1.0), maxf(visible_world_bounds.size.y, 1.0))
	var scale_factor := minf(drawable.size.x / safe_world_size.x, drawable.size.y / safe_world_size.y)
	var fitted_size := safe_world_size * scale_factor
	var fitted_origin := drawable.position + (drawable.size - fitted_size) * 0.5
	var normalized := (world_position - visible_world_bounds.position) / safe_world_size
	var mapped := fitted_origin + normalized * fitted_size
	var drawable_interior_end := drawable.end - Vector2.ONE * 0.001
	return mapped.clamp(drawable.position, drawable_interior_end)

# Huang Wan Jun 2204536 - Keep marker snapshots synchronized with moving dungeon actors.
func _process(_delta: float) -> void:
	refresh_markers()

# Huang Wan Jun 2204536 - Draw the panel and the dungeon regions discovered so far.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.08, 0.82), true)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color(0.85, 0.68, 0.25, 0.9), false, 1.0)

	# Huang Wan Jun 2204536 - Draw unlocked roads underneath rooms to show the next-level route.
	for corridor_number in get_revealed_corridors():
		var corridor_path := PackedVector2Array()
		for world_point in get_corridor_path(corridor_number):
			corridor_path.append(world_to_minimap(world_point))
		draw_polyline(corridor_path, Color(0.46, 0.35, 0.22, 0.9), 8.0, true)
		draw_polyline(corridor_path, Color(0.85, 0.68, 0.25, 0.95), 1.3, true)

	for level_number in _revealed_levels:
		var world_polygon: PackedVector2Array = LEVEL_POLYGONS[level_number]
		var minimap_polygon := PackedVector2Array()
		for world_vertex in world_polygon:
			minimap_polygon.append(world_to_minimap(world_vertex))
		draw_colored_polygon(minimap_polygon, Color(0.58, 0.46, 0.30, 0.86))
		draw_polyline(minimap_polygon + PackedVector2Array([minimap_polygon[0]]), Color(0.85, 0.68, 0.25, 1.0), 1.5, true)

	# Huang Wan Jun 2204536 - Render active-level enemies and the player above the revealed map.
	for enemy_marker in _enemy_markers:
		draw_circle(enemy_marker, 3.0, Color(0.9, 0.16, 0.16, 1.0))
	if _player_marker is Vector2:
		var player_marker: Vector2 = _player_marker
		draw_circle(player_marker, 5.0, Color(0.2, 0.55, 1.0, 1.0))
		draw_circle(player_marker, 6.0, Color(0.85, 0.92, 1.0, 1.0), false, 1.0, true)
