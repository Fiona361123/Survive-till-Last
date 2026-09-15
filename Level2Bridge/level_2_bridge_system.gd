# Huang Wan Jun 2204536
extends Node2D

const CHASM_X_MIN := -13
const CHASM_X_MAX := 18
const CHASM_Y := 29
const LEFT_RESPAWN_CELL := Vector2i(3, 28)
const RIGHT_RESPAWN_CELL := Vector2i(3, 30)

@onready var safe_bridge: TileMapLayer = $SafeBridge
@onready var safe_respawn_left: Marker2D = $SafeRespawnLeft
@onready var safe_respawn_right: Marker2D = $SafeRespawnRight
@onready var permanent_fall_areas: Node2D = $PermanentFallAreas


func _ready() -> void:
	var floor := get_node_or_null("../Floor") as TileMapLayer
	var obstacles := get_node_or_null("../Level2Obstacles") as TileMapLayer
	if floor:
		_carve_dry_chasm(floor)
		_align_safe_route(floor)
	if obstacles:
		_move_chasm_obstacles(obstacles)

	for child in permanent_fall_areas.get_children():
		if child is FallHazard:
			child.configure_respawn_markers(safe_respawn_left, safe_respawn_right)


func _carve_dry_chasm(floor: TileMapLayer) -> void:
	for x in range(CHASM_X_MIN, CHASM_X_MAX + 1):
		floor.erase_cell(Vector2i(x, CHASM_Y))


func _align_safe_route(floor: TileMapLayer) -> void:
	safe_bridge.global_transform = floor.global_transform
	safe_respawn_left.global_position = floor.to_global(floor.map_to_local(LEFT_RESPAWN_CELL))
	safe_respawn_right.global_position = floor.to_global(floor.map_to_local(RIGHT_RESPAWN_CELL))


func _move_chasm_obstacles(obstacles: TileMapLayer) -> void:
	_move_obstacle(obstacles, Vector2i(11, 29), Vector2i(13, 27))


func _move_obstacle(obstacles: TileMapLayer, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var source_id := obstacles.get_cell_source_id(from_cell)
	if source_id < 0:
		return
	var atlas_coords := obstacles.get_cell_atlas_coords(from_cell)
	var alternative_tile := obstacles.get_cell_alternative_tile(from_cell)
	obstacles.erase_cell(from_cell)
	obstacles.set_cell(to_cell, source_id, atlas_coords, alternative_tile)
