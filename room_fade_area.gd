extends Area2D

# Assign "Level 1 traps" to this field in the Inspector.
@export var changeable_walls: TileMapLayer
@export var enemy_scene: PackedScene
@export_range(1, 100, 1) var enemy_count: int = 15
@export_range(0.0, 5.0, 0.05) var spawn_delay: float = 0.15
@export_range(0.0, 128.0, 1.0) var spawn_inward_distance: float = 24.0

var aged_to_hole: Dictionary = {}
var original_tiles: Dictionary = {}
var players_inside: int = 0
var enemies_spawned: bool = false


func _ready() -> void:
	if changeable_walls == null:
		push_error("Assign 'Level 1 traps' to Changeable Walls.")
		return

	build_wall_source_map()
	remember_original_tiles()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Always begin with normal aged walls.
	restore_aged_walls()

	# Detect the player if the game starts with them inside.
	await get_tree().physics_frame
	sync_player_overlap()


func build_wall_source_map() -> void:
	aged_to_hole.clear()

	if changeable_walls.tile_set == null:
		push_error("Level 1 traps does not have a TileSet.")
		return

	var tile_set: TileSet = changeable_walls.tile_set
	var holes_by_direction: Dictionary = {}

	# Find all hole-wall sources.
	for index in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(index)
		var source := tile_set.get_source(source_id) as TileSetAtlasSource

		if source == null or source.texture == null:
			continue

		var filename: String = (
			source.texture.resource_path
			.get_file()
			.get_basename()
		)

		if filename.begins_with("stoneWallHole_"):
			var direction: String = filename.get_slice(
				"_",
				filename.get_slice_count("_") - 1
			)
			holes_by_direction[direction] = source_id

	# Match every aged wall with its corresponding hole wall.
	for index in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(index)
		var source := tile_set.get_source(source_id) as TileSetAtlasSource

		if source == null or source.texture == null:
			continue

		var filename: String = (
			source.texture.resource_path
			.get_file()
			.get_basename()
		)

		if filename.begins_with("stoneWallAged_"):
			var direction: String = filename.get_slice(
				"_",
				filename.get_slice_count("_") - 1
			)

			if holes_by_direction.has(direction):
				aged_to_hole[source_id] = holes_by_direction[direction]


func remember_original_tiles() -> void:
	original_tiles.clear()

	for cell in changeable_walls.get_used_cells():
		original_tiles[cell] = {
			"source_id": changeable_walls.get_cell_source_id(cell),
			"atlas_coords": changeable_walls.get_cell_atlas_coords(cell),
			"alternative": changeable_walls.get_cell_alternative_tile(cell)
		}


func sync_player_overlap() -> void:
	players_inside = 0

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			players_inside += 1

	if players_inside > 0:
		set_walls_to_holes()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		players_inside += 1

		if players_inside == 1:
			set_walls_to_holes()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		players_inside = maxi(players_inside - 1, 0)

		if players_inside == 0:
			restore_aged_walls()


func set_walls_to_holes() -> void:
	if changeable_walls == null:
		return

	for cell in original_tiles:
		var tile: Dictionary = original_tiles[cell]
		var aged_source: int = tile["source_id"]

		if aged_to_hole.has(aged_source):
			changeable_walls.set_cell(
				cell,
				aged_to_hole[aged_source],
				tile["atlas_coords"],
				tile["alternative"]
			)

	if not enemies_spawned:
		enemies_spawned = true
		spawn_enemies_from_holes.call_deferred()


func restore_aged_walls() -> void:
	if changeable_walls == null:
		return

	for cell in original_tiles:
		var tile: Dictionary = original_tiles[cell]

		changeable_walls.set_cell(
			cell,
			tile["source_id"],
			tile["atlas_coords"],
			tile["alternative"]
		)


func spawn_enemies_from_holes() -> void:
	if enemy_scene == null:
		push_error("Assign enemy.tscn to Enemy Scene on FirstLevelWallArea.")
		return

	var hole_cells: Array[Vector2i] = []
	for cell in original_tiles:
		var tile: Dictionary = original_tiles[cell]
		if aged_to_hole.has(int(tile["source_id"])):
			hole_cells.append(cell)

	if hole_cells.is_empty():
		push_error("Level 1 Traps has no aged wall tiles that can become holes.")
		return

	hole_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	var target := get_node_or_null("WallTarget") as Marker2D
	var spawn_parent := get_tree().current_scene

	for index in range(enemy_count):
		var cell: Vector2i = hole_cells[index % hole_cells.size()]
		var hole_position := changeable_walls.to_global(
			changeable_walls.map_to_local(cell)
		)
		var inward := Vector2.ZERO
		if target != null:
			inward = hole_position.direction_to(target.global_position)

		var row: int = floori(float(index) / float(hole_cells.size()))
		var sideways := inward.rotated(PI / 2.0) * float((row % 3) - 1) * 12.0
		var enemy := enemy_scene.instantiate() as Node2D
		if enemy == null:
			push_error("enemy.tscn must have a Node2D root.")
			return

		spawn_parent.add_child(enemy)
		enemy.global_position = hole_position + inward * spawn_inward_distance + sideways

		if spawn_delay > 0.0 and index < enemy_count - 1:
			await get_tree().create_timer(spawn_delay).timeout
