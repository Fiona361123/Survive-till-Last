extends SceneTree

var failures: int = 0

func _initialize() -> void:
	await process_frame
	await _test_halo_starts_active_and_full()
	await _test_halo_uses_energy_based_absorption_tiers()
	await _test_low_energy_partially_blocks_and_breaks()
	await _test_broken_halo_recharges_and_restores_orbs()
	await _test_orb_contact_damage_and_heat_effect()
	await _test_player_equips_once_and_uses_state_speed_penalty()

	if failures == 0:
		print("Guard Halo tests passed.")
	else:
		push_error("%d Guard Halo test(s) failed." % failures)

	paused = false
	quit(0 if failures == 0 else 1)

func _make_halo(
		break_time: float = 0.02,
		recharge_per_second: float = 5000.0
	) -> GuardHalo:
	var scene := load("res://weapons/halo/GuardHalo.tscn") as PackedScene
	var halo := scene.instantiate() as GuardHalo
	halo.broken_delay = break_time
	halo.recharge_rate = recharge_per_second
	root.add_child(halo)
	return halo

func _test_halo_starts_active_and_full() -> void:
	var halo := _make_halo()
	_expect(halo.state == GuardHalo.HaloState.ACTIVE,
		"new Halo starts ACTIVE")
	_expect(is_equal_approx(halo.current_energy, 100.0),
		"new Halo starts with full energy")
	_expect(halo.orbs.size() == 6,
		"GuardHalo scene creates six orbs")
	for orb in halo.orbs:
		_expect(orb.damage_enabled,
			"every new Halo orb starts enabled")
	halo.queue_free()
	await process_frame

func _test_halo_uses_energy_based_absorption_tiers() -> void:
	var halo := _make_halo()
	_expect(is_equal_approx(halo.get_current_absorption_ratio(), 0.70),
		"Halo absorbs seventy percent at full energy")
	var remaining_damage := halo.absorb_damage(10)
	_expect(remaining_damage == 3,
		"high-energy Halo lets three of ten damage reach HP")
	_expect(is_equal_approx(halo.current_energy, 93.0),
		"blocking seven damage consumes seven energy")

	halo.current_energy = 69.0
	_expect(is_equal_approx(halo.get_current_absorption_ratio(), 0.50),
		"Halo absorbs fifty percent below seventy energy")
	_expect(halo.absorb_damage(10) == 5,
		"middle-energy Halo lets five of ten damage reach HP")

	halo.current_energy = 30.0
	_expect(is_equal_approx(halo.get_current_absorption_ratio(), 0.30),
		"Halo absorbs thirty percent at thirty energy")
	_expect(halo.absorb_damage(10) == 7,
		"low-energy Halo lets seven of ten damage reach HP")
	_expect(halo.state == GuardHalo.HaloState.ACTIVE,
		"Halo stays ACTIVE while energy remains")
	halo.queue_free()
	await process_frame

func _test_low_energy_partially_blocks_and_breaks() -> void:
	var halo := _make_halo()
	halo.current_energy = 2.0
	var remaining_damage := halo.absorb_damage(10)
	_expect(remaining_damage == 8,
		"low-energy Halo blocks only the two damage it can afford")
	_expect(is_zero_approx(halo.current_energy),
		"partial absorption consumes the last energy")
	_expect(halo.state == GuardHalo.HaloState.BROKEN,
		"Halo enters BROKEN at zero energy")
	_expect(halo.absorb_damage(10) == 10,
		"BROKEN Halo lets all damage pass through")
	for orb in halo.orbs:
		_expect(not orb.damage_enabled,
			"BROKEN Halo immediately disables orb damage")
	halo.queue_free()
	await process_frame

func _test_broken_halo_recharges_and_restores_orbs() -> void:
	var halo := _make_halo(0.02, 1000.0)
	halo.current_energy = 1.0
	halo.absorb_damage(10)
	_expect(halo.state == GuardHalo.HaloState.BROKEN,
		"depleted Halo begins in BROKEN")

	await create_timer(0.03).timeout
	_expect(halo.state == GuardHalo.HaloState.RECHARGING,
		"broken timer advances Halo to RECHARGING")
	_expect(halo.absorb_damage(10) == 10,
		"RECHARGING Halo does not protect the player")

	await create_timer(0.12).timeout
	_expect(halo.state == GuardHalo.HaloState.ACTIVE,
		"full recharge returns Halo to ACTIVE")
	_expect(is_equal_approx(halo.current_energy, halo.max_energy),
		"restored Halo stops at maximum energy")
	for orb in halo.orbs:
		_expect(orb.damage_enabled,
			"restored Halo re-enables every orb")
	halo.queue_free()
	await process_frame


func _test_orb_contact_damage_and_heat_effect() -> void:
	var halo := _make_halo()
	var enemy := CharacterBody2D.new()
	enemy.set_script(load("res://tests/moving_dummy_enemy.gd"))
	enemy.add_to_group("enemy")
	root.add_child(enemy)

	var orb := halo.orbs[0]
	var original_color: Color = enemy.modulate
	orb.call("_try_damage", enemy)
	_expect(enemy.damage_received == 15,
		"one Blaze Rod contact deals fifteen damage")
	_expect(enemy.modulate.r > enemy.modulate.g * 2.0,
		"Blaze Rod contact immediately gives the enemy a red heat flash")
	_expect(root.get_node_or_null("BlazeHeatRing") != null,
		"Blaze Rod contact creates a visible heat ring")

	await create_timer(0.32).timeout
	_expect(enemy.modulate.is_equal_approx(original_color),
		"enemy colour returns to normal after the heat flash")
	halo.queue_free()
	enemy.queue_free()
	await process_frame

func _test_player_equips_once_and_uses_state_speed_penalty() -> void:
	var player_scene := load("res://Character/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var starting_speed: float = player.speed
	_expect(player.equipped_halo == null,
		"player starts without a Guard Halo")
	_expect(not player.halo_energy_ui.visible,
		"Halo energy UI starts hidden")
	_expect(player.halo_energy_ui.scale.is_equal_approx(Vector2(0.85, 0.85)),
		"Halo energy UI uses a compact scale that covers less gameplay view")

	player.equip_halo()
	await process_frame
	_expect(is_instance_valid(player.equipped_halo),
		"equip_halo creates the wearable Halo")
	_expect(player.equipped_halo.get_parent() == player.halo_anchor,
		"wearable Halo is attached to the visible-player anchor")
	_expect(player.equipped_halo.global_position.is_equal_approx(player.sprite.global_position),
		"wearable Halo starts centred on the visible player sprite")
	_expect(player.halo_energy_ui.visible,
		"equipping Halo reveals its energy UI")
	_expect(is_equal_approx(player.speed, starting_speed - player.halo_speed_penalty),
		"ACTIVE Halo applies its speed penalty")

	player.take_damage(10)
	_expect(player.current_hp == 97,
		"player HP receives the three damage left at high Halo energy")
	_expect(is_equal_approx(player.equipped_halo.current_energy, 93.0),
		"player damage path consumes seven Halo energy")
	_expect(player.is_invincible,
		"a Halo-protected hit starts the player's invincibility window")

	var halo_count_before: int = player.halo_anchor.get_children().filter(
		func(child: Node) -> bool: return child is GuardHalo
	).size()
	player.equip_halo()
	var halo_count_after: int = player.halo_anchor.get_children().filter(
		func(child: Node) -> bool: return child is GuardHalo
	).size()
	_expect(halo_count_before == 1 and halo_count_after == 1,
		"calling equip_halo twice does not create a duplicate")

	var authored_sprite_position: Vector2 = player.sprite.position
	player.is_jumping = true
	player.jump_time = 0.0
	player.handle_jump(0.5 / player.jump_speed)
	_expect(player.equipped_halo.global_position.is_equal_approx(player.sprite.global_position),
		"Halo remains centred on the visible sprite during a jump")
	player.handle_jump(0.6 / player.jump_speed)
	_expect(player.sprite.position.is_equal_approx(authored_sprite_position),
		"jump completion restores the authored sprite position")
	_expect(player.equipped_halo.global_position.is_equal_approx(player.sprite.global_position),
		"Halo remains centred after the jump finishes")

	player.equipped_halo.change_state(GuardHalo.HaloState.BROKEN)
	_expect(is_equal_approx(player.speed, starting_speed),
		"BROKEN Halo removes its speed penalty")
	player.equipped_halo.change_state(GuardHalo.HaloState.ACTIVE)
	_expect(is_equal_approx(player.speed, starting_speed - player.halo_speed_penalty),
		"restored ACTIVE Halo reapplies its speed penalty")

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
