extends SceneTree

var failures: int = 0


class DamageDummy extends CharacterBody2D:
	var damage_received: int = 0

	func take_damage(amount: int) -> void:
		damage_received += amount


func _initialize() -> void:
	var bomb_scene := load("res://Level1Bomb/Level1Bomb.tscn") as PackedScene
	_expect(bomb_scene != null, "Level 1 explosive barrel scene exists")
	if bomb_scene == null:
		quit(1)
		return

	var bomb := bomb_scene.instantiate() as Node2D
	bomb.set("blast_damage", 25)
	root.add_child(bomb)
	var player := _make_damage_dummy(2)
	var enemy := _make_damage_dummy(4)
	root.add_child(player)
	root.add_child(enemy)
	await physics_frame
	await physics_frame

	# Huang Wan Jun 2204536 - A player attack must make the barrel damage both combat sides in its blast radius.
	bomb.call("take_damage", 1)
	await physics_frame
	await physics_frame
	_expect(player.damage_received == 25, "explosive barrel damages the player")
	_expect(enemy.damage_received == 25, "explosive barrel damages nearby enemies")
	_expect(not is_instance_valid(bomb), "explosive barrel removes itself after exploding")

	player.queue_free()
	enemy.queue_free()
	await process_frame
	await _test_bombs_replace_level_one_obstacles()
	quit(0 if failures == 0 else 1)


# Huang Wan Jun 2204536 - Build real collision bodies so the bomb test uses its actual overlap damage area.
func _make_damage_dummy(layer: int) -> DamageDummy:
	var dummy := DamageDummy.new()
	dummy.collision_layer = layer
	dummy.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	dummy.add_child(shape)
	return dummy


# Huang Wan Jun 2204536 - Ensure the playable Level 1 map replaces selected rock obstacles with bomb barrels.
func _test_bombs_replace_level_one_obstacles() -> void:
	var dungeon := (load("res://Dungeon.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(dungeon)
	await process_frame
	_expect(get_nodes_in_group("level1_bomb").size() == 2,
		"Level 1 replaces two obstacle tiles with explosive barrels")
	dungeon.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
