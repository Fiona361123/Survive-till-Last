extends SceneTree

var failures: int = 0
var weapon_progress: Node


func _initialize() -> void:
	await process_frame
	weapon_progress = root.get_node_or_null("WeaponProgress")
	if weapon_progress == null:
		weapon_progress = load("res://weapons/weapon_progress.gd").new()
		weapon_progress.name = "WeaponProgress"
		root.add_child(weapon_progress)
	weapon_progress.reset_progress()

	_test_starting_progression()
	await _test_player_store_and_number_keys()

	if failures == 0:
		print("Weapon progression and Store tests passed.")
	else:
		push_error("%d weapon progression test(s) failed." % failures)

	paused = false
	quit(0 if failures == 0 else 1)


func _test_starting_progression() -> void:
	_expect(weapon_progress.is_weapon_unlocked(&"knife"),
		"Knife starts unlocked")
	_expect(not weapon_progress.is_weapon_unlocked(&"gun"),
		"Gun starts locked")
	_expect(not weapon_progress.is_weapon_unlocked(&"guard_halo"),
		"Guard Halo starts locked")
	_expect(not weapon_progress.is_weapon_unlocked(&"chain_lightning"),
		"Chain Lightning starts locked")
	_expect(not weapon_progress.is_weapon_unlocked(&"gravity_bomb"),
		"Gravity Bomb starts locked")
	_expect(weapon_progress.get_requirement_text(&"gun") == "UNLOCKS IN LEVEL 2",
		"Gun card explains its Level 2 requirement")
	_expect(weapon_progress.get_requirement_text(&"chain_lightning") == "UNLOCKS IN LEVEL 4",
		"Chain Lightning card explains its Level 4 requirement")
	_expect(weapon_progress.get_requirement_text(&"gravity_bomb") == "BUY FOR 500 WEAPON XP",
		"Gravity Bomb card explains its 500 Weapon XP price")


func _test_player_store_and_number_keys() -> void:
	var player_scene := load("res://Character/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var manager = player.get_node("WeaponManager")
	var store := player.get_node("HUD/WeaponStoreUI") as WeaponStoreUI
	_expect(manager.get_weapon_id_for_action(&"weapon_1") == &"knife",
		"number key 1 maps to Knife")
	_expect(manager.get_weapon_id_for_action(&"weapon_2") == &"gun",
		"number key 2 maps to Gun")
	_expect(manager.get_weapon_id_for_action(&"weapon_3") == &"",
		"number key 3 is not assigned to an active weapon")
	_expect(manager.get_weapon_id_for_action(&"weapon_4") == &"chain_lightning",
		"number key 4 maps to Chain Lightning")
	_expect(manager.get_weapon_id_for_action(&"weapon_5") == &"gravity_bomb",
		"number key 5 maps to Gravity Bomb")
	_expect(manager.active_weapon_id == &"knife",
		"Knife is active at the start")
	_expect(not manager.switch_to_weapon_id(&"gun"),
		"WeaponManager rejects a locked Gun")
	_expect(not manager.switch_to_weapon_id(&"gravity_bomb"),
		"WeaponManager rejects a Gravity Bomb before purchase")

	store.open_store()
	await process_frame
	var locked_gun := store.cards.get(&"gun") as WeaponCard
	_expect(locked_gun != null and locked_gun._locked,
		"Store displays Gun as a locked card")
	_expect(locked_gun != null and locked_gun.get_node_or_null("EquipButton") == null,
		"Store card has no equip button")
	var gravity_card := store.cards.get(&"gravity_bomb") as WeaponCard
	_expect(gravity_card != null and gravity_card.buy_button.visible,
		"locked Gravity Bomb card displays its purchase button")
	store.close_store()

	weapon_progress.register_level_clear(1)
	_expect(weapon_progress.is_weapon_unlocked(&"gun"),
		"clearing Level 1 unlocks Gun")
	_expect(manager.switch_to_weapon_id(&"gun"),
		"number-key manager can switch to unlocked Gun")

	weapon_progress.register_level_clear(2)
	await process_frame
	_expect(weapon_progress.is_weapon_unlocked(&"guard_halo"),
		"clearing Level 2 unlocks Guard Halo")
	_expect(is_instance_valid(player.equipped_halo),
		"unlocked Guard Halo equips automatically")
	_expect(manager.active_weapon_id == &"gun",
		"passive Halo does not replace the active Gun")

	Input.action_press("weapon_3")
	await process_frame
	Input.action_release("weapon_3")
	_expect(manager.active_weapon_id == &"gun",
		"number key 3 remains unused")

	weapon_progress.register_level_clear(3)
	_expect(weapon_progress.is_weapon_unlocked(&"chain_lightning"),
		"clearing Level 3 unlocks Chain Lightning")
	Input.action_press("weapon_4")
	await process_frame
	Input.action_release("weapon_4")
	_expect(manager.active_weapon_id == &"chain_lightning",
		"number key 4 switches to Chain Lightning")

	weapon_progress.register_xp(499)
	_expect(weapon_progress.weapon_xp_balance == 499,
		"collected XP increases the Weapon XP wallet")
	_expect(not weapon_progress.purchase_weapon(&"gravity_bomb"),
		"purchase is rejected when one Weapon XP is missing")
	_expect(not weapon_progress.is_weapon_unlocked(&"gravity_bomb")
		and weapon_progress.weapon_xp_balance == 499,
		"failed purchase neither unlocks nor spends XP")
	weapon_progress.register_xp(1)
	_expect(weapon_progress.purchase_weapon(&"gravity_bomb"),
		"500 Weapon XP purchases Gravity Bomb")
	_expect(weapon_progress.weapon_xp_balance == 0,
		"successful purchase deducts exactly 500 Weapon XP")

	manager.switch_to_weapon_id(&"gravity_bomb")
	var manual_target := Node2D.new()
	manual_target.set_script(load("res://tests/gravity_dummy_enemy.gd"))
	manual_target.add_to_group("enemy")
	manual_target.global_position = player.global_position + Vector2(80.0, 0.0)
	root.add_child(manual_target)
	var gravity_index: int = manager.weapon_ids.find(&"gravity_bomb")
	var gravity_weapon = manager.weapons[gravity_index]
	await physics_frame
	await physics_frame
	_expect(float(gravity_weapon.cooldown_left) <= 0.0,
		"Gravity Bomb does not auto-attack when an enemy is nearby")
	Input.action_press("weapon_5")
	await process_frame
	await process_frame
	Input.action_release("weapon_5")
	_expect(manager.active_weapon_id == &"gravity_bomb",
		"number key 5 switches to purchased Gravity Bomb")
	_expect(float(gravity_weapon.cooldown_left) > 0.0,
		"pressing number key 5 triggers one Gravity Bomb attack")
	manual_target.queue_free()
	await process_frame
	_expect(store.new_badge.visible,
		"Store button shows NEW while unlocks are unseen")

	store.open_store()
	await create_timer(0.9, true).timeout
	_expect(weapon_progress.unseen_weapon_ids.is_empty(),
		"viewing the Store marks all new cards as seen")
	_expect(not store.new_badge.visible,
		"Store NEW badge disappears after new cards are viewed")
	_expect(manager.active_weapon_id == &"gravity_bomb",
		"opening the Store does not switch weapons")
	store.close_store()

	player.queue_free()
	var game_over_ui := root.get_node_or_null("GameOverUI")
	if game_over_ui:
		game_over_ui.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
