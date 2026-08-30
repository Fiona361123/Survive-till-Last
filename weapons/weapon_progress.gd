extends Node

signal weapon_unlocked(weapon_id: StringName)
signal weapon_seen(weapon_id: StringName)
signal weapon_xp_changed(new_balance: int)
signal purchase_succeeded(weapon_id: StringName)
signal purchase_failed(weapon_id: StringName, reason: String)
signal progression_changed

const WEAPON_ORDER: Array[StringName] = [
	&"knife",
	&"gun",
	&"guard_halo",
	&"chain_lightning",
	&"gravity_bomb",
	&"temporal_echo",
]

# One data table drives unlock checks, number-key hints, and Store cards.
const WEAPON_DATA := {
	&"knife": {
		"name": "KNIFE",
		"short_name": "KNF",
		"description": "A fast close-range blade for dependable melee damage.",
		"icon_path": "res://weapons/knife_sprites/01.png",
		"slot": 1,
		"required_level": 1,
		"required_xp": 0,
		"passive": false,
		"accent": "e7c56b",
	},
	&"gun": {
		"name": "GUN",
		"short_name": "GUN",
		"description": "A ranged weapon that fires quickly toward the cursor.",
		"icon_path": "res://weapons/gun/gun_07.png",
		"slot": 2,
		"required_level": 2,
		"required_xp": 0,
		"passive": false,
		"accent": "ff9c55",
	},
	&"guard_halo": {
		"name": "GUARD HALO",
		"short_name": "HALO",
		"description": "Passive protection that absorbs 30% of incoming damage.",
		"icon_path": "res://weapons/halo/blaze_rod_glow_bright.png",
		"slot": 0,
		"required_level": 3,
		"required_xp": 0,
		"passive": true,
		"accent": "35d9ff",
	},
	&"chain_lightning": {
		"name": "CHAIN LIGHTNING",
		"short_name": "ARC",
		"description": "Electric energy jumps between several nearby enemies.",
		"icon_path": "res://weapons/gun/chain_lightning.png",
		"slot": 4,
		"required_level": 4,
		"required_xp": 0,
		"passive": false,
		"accent": "a981ff",
	},
	&"gravity_bomb": {
		"name": "GRAVITY BOMB",
		"short_name": "GRAV",
		"description": "Pulls nearby enemies into a gravity field, then explodes.",
		"icon_path": "",
		"slot": 5,
		"required_level": 99,
		"required_xp": 0,
		"xp_price": 500,
		"purchase_only": true,
		"passive": false,
		"accent": "a14dff",
	},
	&"temporal_echo": {
		"name": "TEMPORAL ECHO",
		"short_name": "ECHO",
		"description": "Creates a player-shaped ghost that replays movement, attracts enemies, and damages nearby targets.",
		"icon_path": "",
		"slot": 6,
		"required_level": 99,
		"required_xp": 0,
		"xp_price": 750,
		"purchase_only": true,
		"passive": false,
		"accent": "59e7ff",
	},
}

var unlocked_weapon_ids: Array[StringName] = [&"knife"]
var unseen_weapon_ids: Array[StringName] = []
var highest_dungeon_level: int = 1
var total_xp_earned: int = 0
# Temporary test balance: enough to buy Gravity Bomb (500) and Temporal Echo
# (750) during the same gameplay test.
var weapon_xp_balance: int = 1250


func get_weapon_data(weapon_id: StringName) -> Dictionary:
	return WEAPON_DATA.get(weapon_id, {})


func is_weapon_unlocked(weapon_id: StringName) -> bool:
	return weapon_id in unlocked_weapon_ids


func register_level_clear(completed_level: int) -> void:
	if completed_level < 1:
		return

	highest_dungeon_level = maxi(highest_dungeon_level, completed_level + 1)
	check_weapon_unlocks()


func register_xp(amount: int) -> void:
	if amount <= 0:
		return

	total_xp_earned += amount
	weapon_xp_balance += amount
	weapon_xp_changed.emit(weapon_xp_balance)
	check_weapon_unlocks()


func check_weapon_unlocks() -> void:
	var changed := false
	for weapon_id in WEAPON_ORDER:
		if is_weapon_unlocked(weapon_id):
			continue

		var data := get_weapon_data(weapon_id)
		if bool(data.get("purchase_only", false)):
			continue
		var required_level := int(data.get("required_level", 1))
		var required_xp := int(data.get("required_xp", 0))
		var level_met := highest_dungeon_level >= required_level
		var xp_met := required_xp > 0 and total_xp_earned >= required_xp
		if not level_met and not xp_met:
			continue

		unlocked_weapon_ids.append(weapon_id)
		unseen_weapon_ids.append(weapon_id)
		weapon_unlocked.emit(weapon_id)
		changed = true

	if changed:
		progression_changed.emit()


func purchase_weapon(weapon_id: StringName) -> bool:
	if is_weapon_unlocked(weapon_id):
		purchase_failed.emit(weapon_id, "WEAPON ALREADY UNLOCKED")
		return false

	var data := get_weapon_data(weapon_id)
	if data.is_empty() or not bool(data.get("purchase_only", false)):
		purchase_failed.emit(weapon_id, "THIS WEAPON CANNOT BE PURCHASED")
		return false

	var price := int(data.get("xp_price", 0))
	if price <= 0:
		purchase_failed.emit(weapon_id, "INVALID WEAPON PRICE")
		return false
	if weapon_xp_balance < price:
		purchase_failed.emit(
			weapon_id,
			"NEED %d MORE WEAPON XP" % (price - weapon_xp_balance)
		)
		return false

	weapon_xp_balance -= price
	unlocked_weapon_ids.append(weapon_id)
	unseen_weapon_ids.append(weapon_id)
	weapon_xp_changed.emit(weapon_xp_balance)
	purchase_succeeded.emit(weapon_id)
	weapon_unlocked.emit(weapon_id)
	progression_changed.emit()
	return true


func mark_weapon_seen(weapon_id: StringName) -> void:
	if weapon_id not in unseen_weapon_ids:
		return

	unseen_weapon_ids.erase(weapon_id)
	weapon_seen.emit(weapon_id)
	progression_changed.emit()


func mark_all_weapons_seen() -> void:
	for weapon_id in unseen_weapon_ids.duplicate():
		mark_weapon_seen(weapon_id)


func has_unseen_weapons() -> bool:
	return not unseen_weapon_ids.is_empty()


func get_requirement_text(weapon_id: StringName) -> String:
	var data := get_weapon_data(weapon_id)
	if data.is_empty():
		return "UNKNOWN REQUIREMENT"

	var required_level := int(data.get("required_level", 1))
	var required_xp := int(data.get("required_xp", 0))
	var xp_price := int(data.get("xp_price", 0))
	if bool(data.get("purchase_only", false)) and xp_price > 0:
		return "BUY FOR %d WEAPON XP" % xp_price
	if required_level <= 1 and required_xp <= 0:
		return "STARTER WEAPON"
	if required_xp > 0:
		return "EARN %d TOTAL XP" % required_xp
	return "UNLOCKS IN LEVEL %d" % required_level


# Used by automated tests and by a future New Game button.
func reset_progress() -> void:
	unlocked_weapon_ids.assign([&"knife"])
	unseen_weapon_ids.clear()
	highest_dungeon_level = 1
	total_xp_earned = 0
	weapon_xp_balance = 0
	weapon_xp_changed.emit(weapon_xp_balance)
	progression_changed.emit()
