extends Node2D

const LEVEL_2_SKELETON_SCENE: PackedScene = preload("res://skeleton.tscn")
const LEVEL_2_TOTAL_ENEMIES: int = 15

@onready var exit_to_level_2: TileMapLayer = $ExitToLevel2
@onready var exit_to_level_3: TileMapLayer = $ExitToLevel3
@onready var exit_to_boss: TileMapLayer = $ExitToBoss
@onready var level_2_entrance = $Level2Entrance
@onready var level_3_entrance = $Level3Entrance
@onready var boss_entrance = $BossEntrance
@onready var level_clear_ui: CanvasLayer = $LevelClearUI
@onready var clear_label: Label = $LevelClearUI/ClearLabel
@onready var enemy_counter_label: Label = $LevelClearUI/EnemyCounterLabel
@onready var enemy_spawner = $Wall/FirstLevelWallArea
@onready var level_2_enemies: Node2D = $Level2Enemies
@onready var level_2_second_wave: Node2D = $Level2Enemies/SecondWave
@onready var level_2_spawn_points: Node2D = $Level2Enemies/SpawnPoints
@onready var weapon_progress: Node = get_node("/root/WeaponProgress")

var level_cleared: bool = false
var spawning_finished: bool = false
var current_level: int = 1
var debug_clear_requested: bool = false
var level_2_second_wave_spawned: bool = false
var level_2_cleared: bool = false
var level_3_cleared: bool = false
var level_1_total_enemies: int = 0


func _ready() -> void:
	level_2_entrance.lock_exit()
	level_3_entrance.lock_exit()
	boss_entrance.lock_exit()
	level_clear_ui.show()
	clear_label.hide()
	enemy_counter_label.show()

	if enemy_spawner.has_signal("enemies_finished_spawning"):
		enemy_spawner.connect(
			"enemies_finished_spawning",
			Callable(self, "_on_enemies_finished_spawning")
		)
	else:
		push_error("FirstLevelWallArea needs enemies_finished_spawning.")

	# Huang Wan Jun 2204536 - Watch only skeletons inside the Level 2 enemy container.
	call_deferred("_watch_level_two_enemies")


func _process(_delta: float) -> void:
	_update_enemy_counter()


func _on_enemies_finished_spawning() -> void:
	if spawning_finished:
		return

	spawning_finished = true
	level_1_total_enemies = get_tree().get_nodes_in_group("level1_enemy").size()
	if debug_clear_requested:
		debug_clear_level_one_enemies()
	_watch_level_one_enemies()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode != KEY_L and key_event.physical_keycode != KEY_L:
		return

	var removed_count := debug_clear_current_level()
	print("Debug Level %d clear requested. Enemies removed: %d" % [current_level, removed_count])


# Huang Wan Jun 2204536 - L clears whichever combat level the player is currently inside.
func debug_clear_current_level() -> int:
	match current_level:
		1:
			debug_clear_requested = true
			return debug_clear_level_one_enemies()
		2:
			level_2_second_wave_spawned = true
			var enemies := _get_level_two_enemy_nodes()
			for enemy in enemies:
				enemy.queue_free()
			return enemies.size()
		3:
			_complete_level_three()
			return 0
		_:
			return 0


func debug_clear_level_one_enemies() -> int:
	var enemies := get_tree().get_nodes_in_group("level1_enemy")
	for enemy in enemies:
		enemy.queue_free()

	return enemies.size()


func _watch_level_one_enemies() -> void:
	while is_inside_tree() and not level_cleared:
		var scene_tree := get_tree()
		if scene_tree == null:
			return

		if scene_tree.get_nodes_in_group("level1_enemy").is_empty():
			_complete_level()
			return

		await scene_tree.process_frame


func _watch_level_two_enemies() -> void:
	while is_inside_tree() and not level_2_cleared:
		var scene_tree := get_tree()
		if scene_tree == null:
			return

		await scene_tree.process_frame
		# The Dungeon may have been removed while this coroutine was awaiting
		# the next frame (for example, during a game-over scene reload).
		if not is_inside_tree() or get_tree() == null:
			return

		if not _get_level_two_enemy_nodes().is_empty():
			continue

		if not level_2_second_wave_spawned:
			_spawn_level_two_second_wave()
			continue

		_complete_level_two()


func _get_level_two_enemy_nodes() -> Array[Node]:
	var level_enemies: Array[Node] = []
	var scene_tree := get_tree()
	if scene_tree == null or not is_inside_tree() or not is_instance_valid(level_2_enemies):
		return level_enemies

	for enemy_node in scene_tree.get_nodes_in_group("level2_enemy"):
		if level_2_enemies.is_ancestor_of(enemy_node):
			level_enemies.append(enemy_node)
	return level_enemies


func _spawn_level_two_second_wave() -> void:
	if level_2_second_wave_spawned:
		return

	level_2_second_wave_spawned = true
	for spawn_point in level_2_spawn_points.get_children():
		var skeleton := LEVEL_2_SKELETON_SCENE.instantiate() as Node2D
		if skeleton == null:
			push_error("skeleton.tscn must have a Node2D root.")
			continue
		skeleton.add_to_group("level2_enemy")
		level_2_second_wave.add_child(skeleton)
		skeleton.global_position = (spawn_point as Node2D).global_position


func _complete_level_two() -> void:
	if level_2_cleared:
		return

	level_2_cleared = true
	weapon_progress.register_level_clear(2)
	unlock_path_after_level(2)
	await _show_level_clear_message(
		"LEVEL 2 CLEAR!\n通关啦！Level 3 Tunnel Unlocked!"
	)


func _complete_level() -> void:
	if level_cleared:
		return

	level_cleared = true
	weapon_progress.register_level_clear(1)
	unlock_path_after_level(1)
	await _show_level_clear_message(
		"LEVEL 1 CLEAR!\n通关啦！Level 2 Tunnel Unlocked!"
	)


# Level 3 combat can call this public completion hook when its objective is done.
func _complete_level_three() -> void:
	if level_3_cleared:
		return

	level_3_cleared = true
	weapon_progress.register_level_clear(3)
	unlock_path_after_level(3)
	await _show_level_clear_message(
		"LEVEL 3 CLEAR!\nBoss Tunnel and Chain Lightning Unlocked!"
	)


func _show_level_clear_message(message: String) -> void:
	clear_label.text = message
	clear_label.show()

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(clear_label):
		clear_label.hide()


func _update_enemy_counter() -> void:
	match current_level:
		1:
			enemy_counter_label.show()
			if not spawning_finished:
				enemy_counter_label.text = "LEVEL 1\nEnemies spawning..."
				return
			var remaining := get_tree().get_nodes_in_group("level1_enemy").size()
			var killed := maxi(level_1_total_enemies - remaining, 0)
			enemy_counter_label.text = (
				"LEVEL 1\nEnemies Killed: %d / %d\nEnemies Left: %d"
				% [killed, level_1_total_enemies, remaining]
			)
		2:
			enemy_counter_label.show()
			var unspawned := 0
			if not level_2_second_wave_spawned:
				unspawned = level_2_spawn_points.get_child_count()
			var remaining := _get_level_two_enemy_nodes().size() + unspawned
			var killed := clampi(LEVEL_2_TOTAL_ENEMIES - remaining, 0, LEVEL_2_TOTAL_ENEMIES)
			enemy_counter_label.text = (
				"LEVEL 2\nEnemies Killed: %d / %d\nEnemies Left: %d"
				% [killed, LEVEL_2_TOTAL_ENEMIES, remaining]
			)
		_:
			enemy_counter_label.hide()


func unlock_path_after_level(completed_level: int) -> void:
	match completed_level:
		1:
			exit_to_level_2.clear()
			level_2_entrance.unlock_exit()
		2:
			exit_to_level_3.clear()
			level_3_entrance.unlock_exit()
		3:
			exit_to_boss.clear()
			boss_entrance.unlock_exit()
		_:
			push_warning("No exit is configured after Level %d." % completed_level)


func _on_level_entrance_entered(level_number: int) -> void:
	current_level = level_number
