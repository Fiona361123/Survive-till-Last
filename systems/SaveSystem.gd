extends Node

const SAVE_PATH = "user://savegame.save"

var profiles: Dictionary = {}
var current_profile: String = "Guest"

# Current Profile Stats
var gold_coins: int = 0
var upgrade_max_hp_level: int = 0
var upgrade_damage_level: int = 0
var upgrade_speed_level: int = 0

var saved_dungeon_state: Dictionary = {}

# Global flag to signal that Dungeon should load from save
var load_from_save: bool = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var dungeon = get_tree().current_scene
		if dungeon != null and dungeon.name.begins_with("Dungeon"):
			var player = get_tree().get_first_node_in_group("player")
			if player != null and player.current_hp > 0:
				var killed = dungeon.get_current_enemies_killed() if dungeon.has_method("get_current_enemies_killed") else 0
				var flags = {
					"level_cleared":   dungeon.get("level_cleared"),
					"level_2_cleared": dungeon.get("level_2_cleared"),
					"level_3_cleared": dungeon.get("level_3_cleared"),
					"level_2_second_wave_spawned": dungeon.get("level_2_second_wave_spawned")
				}
				save_dungeon_state(dungeon.get("current_level"), player.current_hp, player.max_hp, player.current_xp, player.current_level, killed, flags, player.global_position.x, player.global_position.y)

func _ready():
	load_game()

func _load_profile_data(profile_name: String):
	if profile_name == "":
		profile_name = "Guest"
	current_profile = profile_name
	
	if not profiles.has(current_profile):
		profiles[current_profile] = {
			"gold_coins": 0,
			"upgrade_max_hp_level": 0,
			"upgrade_damage_level": 0,
			"upgrade_speed_level": 0,
			"saved_dungeon_state": {}
		}
		
	var data = profiles[current_profile]
	gold_coins = data.get("gold_coins", 0)
	upgrade_max_hp_level = data.get("upgrade_max_hp_level", 0)
	upgrade_damage_level = data.get("upgrade_damage_level", 0)
	upgrade_speed_level = data.get("upgrade_speed_level", 0)
	saved_dungeon_state = data.get("saved_dungeon_state", {})

func switch_profile(profile_name: String):
	if current_profile != "":
		_save_current_profile_to_memory()
	current_profile = profile_name
	_load_profile_data(current_profile)
	save_game()

func _save_current_profile_to_memory():
	if current_profile != "":
		profiles[current_profile] = {
			"gold_coins": gold_coins,
			"upgrade_max_hp_level": upgrade_max_hp_level,
			"upgrade_damage_level": upgrade_damage_level,
			"upgrade_speed_level": upgrade_speed_level,
			"saved_dungeon_state": saved_dungeon_state
		}

func delete_profile(profile_name: String):
	if profiles.has(profile_name):
		profiles.erase(profile_name)
		if current_profile == profile_name:
			# If we deleted the current profile, fallback to Guest
			if profiles.is_empty() or not profiles.has("Guest"):
				profiles["Guest"] = {
					"gold_coins": 0,
					"upgrade_max_hp_level": 0,
					"upgrade_damage_level": 0,
					"upgrade_speed_level": 0,
					"saved_dungeon_state": {}
				}
			switch_profile("Guest")
		else:
			save_game()

func save_game():
	_save_current_profile_to_memory()
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"profiles": profiles,
			"last_profile": current_profile
		}
		file.store_string(JSON.stringify(data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		_load_profile_data("Guest")
		return # No save file yet
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				profiles = data.get("profiles", {})
				var last = data.get("last_profile", "Guest")
				_load_profile_data(last)

func add_gold_coins(amount: int):
	gold_coins += amount
	save_game()

func spend_gold_coins(amount: int) -> bool:
	if gold_coins >= amount:
		gold_coins -= amount
		save_game()
		return true
	return false

func save_dungeon_state(dungeon_level: int, hp: int, max_hp: int, xp: int, player_level: int, enemies_killed: int = 0, level_flags: Dictionary = {}, pos_x: float = 0.0, pos_y: float = 0.0):
	var wp = get_node_or_null("/root/WeaponProgress")
	var wp_state = {}
	if wp != null:
		wp_state = {
			"unlocked": wp.unlocked_weapon_ids,
			"unseen": wp.unseen_weapon_ids,
			"highest_level": wp.highest_dungeon_level,
			"total_xp": wp.total_xp_earned,
			"balance": wp.weapon_xp_balance
		}
	
	saved_dungeon_state = {
		"is_saved": true,
		"dungeon_level": dungeon_level,
		"hp": hp,
		"max_hp": max_hp,
		"xp": xp,
		"player_level": player_level,
		"enemies_killed": enemies_killed,
		"level_flags": level_flags,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"weapon_progress": wp_state
	}
	save_game()

func clear_dungeon_state():
	saved_dungeon_state = {}
	save_game()
