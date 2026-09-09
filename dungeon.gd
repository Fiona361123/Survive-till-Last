extends Node2D

const LEVEL_2_SKELETON_SCENE: PackedScene = preload("res://skeleton.tscn")
const LEVEL_1_BOMB_SCENE: PackedScene = preload("res://Level1Bomb/Level1Bomb.tscn")
const FINAL_BOSS_SCENE: PackedScene = preload("res://final_boss.tscn")
const LEVEL_2_TOTAL_ENEMIES: int = 15
const LEVEL_3_TOTAL_ENEMIES: int = 6
const ENEMY_COUNTER_NORMAL_Y: float = 85.0
const ENEMY_COUNTER_LEVEL_3_Y: float = 185.0

@onready var exit_to_level_2: TileMapLayer = $ExitToLevel2
@onready var exit_to_level_3: TileMapLayer = $ExitToLevel3
@onready var exit_to_boss: TileMapLayer = $ExitToBoss
@onready var level_2_entrance = $Level2Entrance
@onready var level_3_entrance = $Level3Entrance
@onready var boss_entrance = $BossEntrance
@onready var level_clear_ui: CanvasLayer = $LevelClearUI
@onready var clear_label: Label = $LevelClearUI/ClearLabel
@onready var enemy_counter_label: Label = $LevelClearUI/EnemyCounterLabel
@onready var dungeon_minimap: DungeonMinimap = $LevelClearUI/DungeonMinimap
@onready var enemy_spawner = $Wall/FirstLevelWallArea
@onready var level_2_enemies: Node2D = $Level2Enemies
@onready var level_2_second_wave: Node2D = $Level2Enemies/SecondWave
@onready var level_2_spawn_points: Node2D = $Level2Enemies/SpawnPoints
@onready var level_3_enemies: Node2D = $Level3Enemies
@onready var level_3_traps: Level3TrapController = $Level3Traps
@onready var boss_encounter: BossEncounterController = $BossEncounter
@onready var weapon_progress: Node = get_node("/root/WeaponProgress")

var level_cleared: bool = false
var spawning_finished: bool = false
var current_level: int = 1
var debug_clear_requested: bool = false
var level_2_second_wave_spawned: bool = false
var level_2_cleared: bool = false
var level_3_cleared: bool = false
var level_1_total_enemies: int = 0
var run_completed: bool = false
var win_screen_shown: bool = false
var active_final_boss: Node2D = null


func _ready() -> void:
	level_2_entrance.lock_exit()
	level_3_entrance.lock_exit()
	boss_entrance.lock_exit()
	level_clear_ui.show()
	clear_label.hide()
	enemy_counter_label.show()
	# Huang Wan Jun 2204536 - A death reload returns to Level 1, so keep its counter below the persistent Guard Halo panel.
	enemy_counter_label.position.y = ENEMY_COUNTER_LEVEL_3_Y
	
	# Add on-screen Menu/Pause button
	var menu_btn = Button.new()
	menu_btn.text = "Menu"
	var font = load("res://UI/Milky Cream.otf")
	if font: menu_btn.add_theme_font_override("font", font)
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.offset_left = 20
	menu_btn.offset_top = 20
	menu_btn.offset_right = 120
	menu_btn.offset_bottom = 60
	menu_btn.pressed.connect(PauseMenu._toggle_pause)
	menu_btn.focus_mode = Control.FOCUS_NONE
	level_clear_ui.add_child(menu_btn)
	
	# Gold Coin HUD counter display
	var gold_hud = Label.new()
	gold_hud.name = "GoldHUDLabel"
	if font: gold_hud.add_theme_font_override("font", font)
	gold_hud.add_theme_font_size_override("font_size", 20)
	gold_hud.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	gold_hud.offset_left = 130
	gold_hud.offset_top = 20
	gold_hud.offset_right = 330
	gold_hud.offset_bottom = 60
	level_clear_ui.add_child(gold_hud)
	
	_spawn_level_one_bombs()

	# Huang Wan Jun 2204536 - Start the dungeon HUD on the active, discovered level.
	dungeon_minimap.reveal_level(1)
	dungeon_minimap.set_current_level(current_level)

	if enemy_spawner.has_signal("enemies_finished_spawning"):
		enemy_spawner.connect(
			"enemies_finished_spawning",
			Callable(self, "_on_enemies_finished_spawning")
		)
	else:
		push_error("FirstLevelWallArea needs enemies_finished_spawning.")

	# Huang Wan Jun 2204536 - Watch only skeletons inside the Level 2 enemy container.
	call_deferred("_ensure_initial_level_two_enemies_are_clear")
	call_deferred("_watch_level_two_enemies")
	call_deferred("_watch_level_three_enemies")
	
	if SaveSystem.load_from_save and SaveSystem.saved_dungeon_state.has("is_saved"):
		var state = SaveSystem.saved_dungeon_state
		var saved_level = state.get("dungeon_level", 1)
		
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			player = get_node_or_null("Player")
			
		if player != null:
			player.max_hp = state.get("max_hp", player.max_hp)
			player.current_hp = state.get("hp", player.max_hp)
			player.current_xp = state.get("xp", 0)
			player.current_level = state.get("player_level", 1)
			
			if player.has_node("HealthBarAnchor/HealthBar"):
				var hb = player.get_node("HealthBarAnchor/HealthBar")
				hb.max_value = player.max_hp
				hb.value = player.current_hp
			
			var wp = get_node_or_null("/root/WeaponProgress")
			var wp_state = state.get("weapon_progress", {})
			if wp != null and wp_state.size() > 0:
				var unl: Array = wp_state.get("unlocked", [])
				var unl_names: Array[StringName] = []
				for u in unl: unl_names.append(StringName(u))
				wp.unlocked_weapon_ids = unl_names
				
				var uns: Array = wp_state.get("unseen", [])
				var uns_names: Array[StringName] = []
				for u in uns: uns_names.append(StringName(u))
				wp.unseen_weapon_ids = uns_names
				
				wp.highest_dungeon_level = wp_state.get("highest_level", 1)
				wp.total_xp_earned = wp_state.get("total_xp", 0)
				wp.weapon_xp_balance = wp_state.get("balance", 0)
			
			var flags = state.get("level_flags", {})
			var enemies_killed = state.get("enemies_killed", 0)
			call_deferred("_restore_saved_level_state", saved_level, player, flags, enemies_killed)
			
		SaveSystem.load_from_save = false
	
	if is_instance_valid(boss_encounter):
		boss_encounter.boss_ready.connect(_on_boss_ready)

func _on_boss_ready(spawn_point: Marker2D) -> void:
	if is_instance_valid(active_final_boss) or spawn_point == null:
		return

	active_final_boss = FINAL_BOSS_SCENE.instantiate() as Node2D
	if active_final_boss == null:
		push_error("final_boss.tscn must have a Node2D root.")
		return

	add_child(active_final_boss)
	active_final_boss.global_position = spawn_point.global_position
	if active_final_boss.has_signal("boss_defeated"):
		active_final_boss.connect("boss_defeated", Callable(self, "_on_final_boss_defeated"))


func _on_final_boss_defeated() -> void:
	_show_win_screen()

func _show_win_screen() -> void:
	if win_screen_shown:
		return
	win_screen_shown = true
	run_completed = true
	SaveSystem.clear_dungeon_state()
	var win_ui_script = load("res://UI/game_win_ui.gd")
	if win_ui_script:
		var win_ui = win_ui_script.new()
		get_tree().root.add_child(win_ui)
		win_ui.show_game_win()

var pending_enemies_killed_level1: int = 0

func _restore_saved_level_state(saved_level: int, player: Node2D, _flags: Dictionary = {}, enemies_killed: int = 0):
	current_level = saved_level
	dungeon_minimap.set_current_level(saved_level)
	
	# Restore level 1 mid-progress: store killed count so it is applied after spawning finishes
	if saved_level == 1 and enemies_killed > 0:
		pending_enemies_killed_level1 = enemies_killed
		if spawning_finished:
			_apply_pending_level_1_kills()
	
	if saved_level >= 2:
		debug_clear_level_one_enemies()
		level_cleared = true
		weapon_progress.register_level_clear(1)
		unlock_path_after_level(1)
		
	if saved_level == 2 and enemies_killed > 0:
		var enemies = _get_level_two_enemy_nodes()
		if enemies_killed > enemies.size() and not level_2_second_wave_spawned:
			_spawn_level_two_second_wave()
			enemies = _get_level_two_enemy_nodes()
		var to_kill = mini(enemies_killed, enemies.size())
		for i in range(to_kill):
			if is_instance_valid(enemies[i]): enemies[i].queue_free()
			
	if saved_level >= 3:
		var enemies = _get_level_two_enemy_nodes()
		for e in enemies: e.queue_free()
		level_2_second_wave_spawned = true
		level_2_cleared = true
		weapon_progress.register_level_clear(2)
		unlock_path_after_level(2)
		enemy_counter_label.position.y = ENEMY_COUNTER_LEVEL_3_Y
		
	if saved_level == 3 and enemies_killed > 0:
		var enemies = _get_level_three_enemy_nodes()
		var to_kill = mini(enemies_killed, enemies.size())
		for i in range(to_kill):
			if is_instance_valid(enemies[i]): enemies[i].queue_free()
			
	if saved_level >= 4:
		var enemies = _get_level_three_enemy_nodes()
		for e in enemies: e.queue_free()
		_complete_level_three()

	# Restore exact player position if recorded, otherwise fallback to entrance nodes
	var state = SaveSystem.saved_dungeon_state
	var saved_pos_x: float = state.get("pos_x", 0.0)
	var saved_pos_y: float = state.get("pos_y", 0.0)
	if saved_pos_x != 0.0 or saved_pos_y != 0.0:
		player.global_position = Vector2(saved_pos_x, saved_pos_y)
	else:
		if saved_level == 2 and is_instance_valid(level_2_entrance):
			player.global_position = level_2_entrance.global_position
		elif saved_level == 3 and is_instance_valid(level_3_entrance):
			player.global_position = level_3_entrance.global_position
		elif saved_level >= 4 and is_instance_valid(boss_entrance):
			player.global_position = boss_entrance.global_position

	SaveSystem.clear_dungeon_state()


func _apply_pending_level_1_kills() -> void:
	if pending_enemies_killed_level1 > 0:
		var alive = get_tree().get_nodes_in_group("level1_enemy")
		var to_kill = mini(pending_enemies_killed_level1, alive.size())
		for i in range(to_kill):
			if is_instance_valid(alive[i]):
				alive[i].queue_free()
		pending_enemies_killed_level1 = 0


# Huang Wan Jun 2204536 - Replace two existing Level 1 rock tiles with attack-triggered barrel bombs at the same locations.
func _spawn_level_one_bombs() -> void:
	var spawn_points := $BombSpawnPoints.get_children()

	if spawn_points.is_empty():
		push_error("No Level 1 bomb spawn points found.")
		return

	var bomb_count := randi_range(4, 8)

	spawn_points.shuffle()

	bomb_count = min(bomb_count, spawn_points.size())

	for i in range(bomb_count):
		var spawn_point := spawn_points[i] as Marker2D

		if spawn_point == null:
			continue

		var bomb := LEVEL_1_BOMB_SCENE.instantiate() as Level1Bomb

		if bomb == null:
			continue

		bomb.global_position = spawn_point.global_position

		# Randomly make the bomb real or fake.
		bomb.is_real_bomb = randf() < 0.5

		add_child(bomb)


func _process(_delta: float) -> void:
	_update_enemy_counter()
	var gold_label = level_clear_ui.get_node_or_null("GoldHUDLabel")
	if gold_label:
		gold_label.text = "🪙 Gold: " + str(SaveSystem.gold_coins)


func _on_enemies_finished_spawning() -> void:
	if spawning_finished:
		return

	spawning_finished = true
	level_1_total_enemies = get_tree().get_nodes_in_group("level1_enemy").size()
	if level_cleared or current_level >= 2:
		debug_clear_level_one_enemies()
		return
	if pending_enemies_killed_level1 > 0:
		_apply_pending_level_1_kills()
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
			var enemies := _get_level_three_enemy_nodes()
			for enemy in enemies:
				enemy.queue_free()
			return enemies.size()
		4:
			if is_instance_valid(boss_encounter):
				return boss_encounter.debug_complete_trial()
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


func _get_level_three_enemy_nodes() -> Array[Node]:
	var level_enemies: Array[Node] = []
	var scene_tree := get_tree()
	if scene_tree == null or not is_inside_tree() or not is_instance_valid(level_3_enemies):
		return level_enemies
	for enemy_node in scene_tree.get_nodes_in_group("level3_enemy"):
		if level_3_enemies.is_ancestor_of(enemy_node):
			level_enemies.append(enemy_node)
	return level_enemies


func _watch_level_three_enemies() -> void:
	while is_inside_tree() and not level_3_cleared:
		var scene_tree := get_tree()
		if scene_tree == null:
			return
		await scene_tree.process_frame
		if not is_inside_tree() or get_tree() == null:
			return
		if current_level == 3 and _get_level_three_enemy_nodes().is_empty():
			_complete_level_three()
			return


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
		SpawnPositionResolver.place_clear_of_walls(
			skeleton,
			(spawn_point as Node2D).global_position,
			level_2_spawn_points.global_position
		)


func _ensure_initial_level_two_enemies_are_clear() -> void:
	await get_tree().physics_frame
	var initial_skeletons := $Level2Enemies/InitialSkeletons as Node2D
	for enemy_node in initial_skeletons.get_children():
		var enemy := enemy_node as CollisionObject2D
		if enemy == null:
			continue
		SpawnPositionResolver.place_clear_of_walls(
			enemy,
			enemy.global_position,
			level_2_spawn_points.global_position
		)


func _complete_level_two() -> void:
	if level_2_cleared:
		return

	level_2_cleared = true
	if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").play_level_up()
	enemy_counter_label.position.y = ENEMY_COUNTER_LEVEL_3_Y
	weapon_progress.register_level_clear(2)
	unlock_path_after_level(2)
	current_level = 3
	dungeon_minimap.set_current_level(3)
	await _show_level_clear_message(
		"LEVEL 2 CLEAR!\n通关啦！Level 3 Tunnel Unlocked!"
	)


func _complete_level() -> void:
	if level_cleared:
		return

	level_cleared = true
	if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").play_level_up()
	weapon_progress.register_level_clear(1)
	unlock_path_after_level(1)
	current_level = 2
	dungeon_minimap.set_current_level(2)
	await _show_level_clear_message(
		"LEVEL 1 CLEAR!\n通关啦！Level 2 Tunnel Unlocked!"
	)


# Level 3 combat can call this public completion hook when its objective is done.
func _complete_level_three() -> void:
	level_3_traps.stop_encounter()
	if level_3_cleared:
		return

	level_3_cleared = true
	if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").play_level_up()
	weapon_progress.register_level_clear(3)
	unlock_path_after_level(3)
	current_level = 4
	dungeon_minimap.set_current_level(4)
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
		3:
			enemy_counter_label.show()
			var remaining := _get_level_three_enemy_nodes().size()
			var killed := clampi(LEVEL_3_TOTAL_ENEMIES - remaining, 0, LEVEL_3_TOTAL_ENEMIES)
			enemy_counter_label.text = (
				"LEVEL 3\nEnemies Killed: %d / %d\nEnemies Left: %d"
				% [killed, LEVEL_3_TOTAL_ENEMIES, remaining]
			)
		4:
			# Huang Wan Jun 2204536 - Show preparation-wave progress without claiming the boss is defeated.
			enemy_counter_label.show()
			var remaining := boss_encounter.get_wave_remaining()
			match boss_encounter.get_encounter_state():
				BossEncounterController.State.WAVE_1:
					enemy_counter_label.text = "BOSS TRIAL - WAVE 1\nEnemies Defeated: %d / 5\nEnemies Left: %d" % [5 - remaining, remaining]
				BossEncounterController.State.WAVE_2:
					enemy_counter_label.text = "BOSS TRIAL - WAVE 2\nEnemies Defeated: %d / 5\nEnemies Left: %d" % [5 - remaining, remaining]
				BossEncounterController.State.BOSS_READY:
					enemy_counter_label.text = (
						"FINAL BOSS" if is_instance_valid(active_final_boss)
						else "BOSS ARENA READY"
					)
				_:
					enemy_counter_label.text = "BOSS TRIAL"
		_:
			enemy_counter_label.hide()


func get_current_enemies_killed() -> int:
	match current_level:
		1:
			if level_1_total_enemies > 0:
				return maxi(0, level_1_total_enemies - get_tree().get_nodes_in_group("level1_enemy").size())
			return 0
		2:
			var remaining := _get_level_two_enemy_nodes().size()
			if not level_2_second_wave_spawned:
				remaining += level_2_spawn_points.get_child_count()
			return clampi(LEVEL_2_TOTAL_ENEMIES - remaining, 0, LEVEL_2_TOTAL_ENEMIES)
		3:
			return clampi(LEVEL_3_TOTAL_ENEMIES - _get_level_three_enemy_nodes().size(), 0, LEVEL_3_TOTAL_ENEMIES)
		_:
			return 0


func unlock_path_after_level(completed_level: int) -> void:
	# Huang Wan Jun 2204536 - Reveal only the section unlocked by this completion.
	if completed_level >= 1 and completed_level <= 3:
		dungeon_minimap.reveal_level(completed_level + 1)
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
	# Huang Wan Jun 2204536 - Keep the HUD minimap aligned with the entered dungeon level.
	dungeon_minimap.set_current_level(level_number)
	# Huang Wan Jun 2204536 - Keep Level 1, Level 3, and the boss trial below the Guard Halo panel.
	enemy_counter_label.position.y = (
		ENEMY_COUNTER_LEVEL_3_Y if level_number in [1, 2, 3, 4] else ENEMY_COUNTER_NORMAL_Y
	)
	if level_number == 3:
		level_3_traps.start_encounter()
	elif level_number == 4:
		# Huang Wan Jun 2204536 - Arm the boss-room trial once when its entrance becomes current.
		boss_encounter.start_encounter()
