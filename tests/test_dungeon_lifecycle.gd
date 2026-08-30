extends SceneTree


func _initialize() -> void:
	await process_frame
	var dungeon_scene := load("res://Dungeon.tscn") as PackedScene
	var dungeon := dungeon_scene.instantiate()
	root.add_child(dungeon)
	await process_frame

	# Reproduce a scene reload while the Level 2 watcher is awaiting a frame.
	dungeon.queue_free()
	await process_frame
	await process_frame
	await process_frame

	print("Dungeon lifecycle watcher test passed.")
	quit(0)
