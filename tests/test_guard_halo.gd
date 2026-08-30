extends SceneTree

var failures: int = 0

func _initialize() -> void:
	await process_frame
	await _test_halo_starts_active_and_full()
	await _test_halo_blocks_thirty_percent()
	await _test_low_energy_partially_blocks_and_breaks()
	await _test_broken_halo_recharges_and_restores_orbs()
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

func _test_halo_blocks_thirty_percent() -> void:
	var halo := _make_halo()
	var remaining_damage := halo.absorb_damage(10)
	_expect(remaining_damage == 7,
		"full-energy Halo lets seven of ten damage reach HP")
	_expect(is_equal_approx(halo.current_energy, 97.0),
		"blocking three damage consumes three energy")
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

	player.equip_halo()
	await process_frame
	_expect(is_instance_valid(player.equipped_halo),
		"equip_halo creates the wearable Halo")
	_expect(player.halo_energy_ui.visible,
		"equipping Halo reveals its energy UI")
	_expect(is_equal_approx(player.speed, starting_speed - player.halo_speed_penalty),
		"ACTIVE Halo applies its speed penalty")

	player.take_damage(10)
	_expect(player.current_hp == 93,
		"player HP receives the seven damage left after Halo absorption")
	_expect(is_equal_approx(player.equipped_halo.current_energy, 97.0),
		"player damage path consumes three Halo energy")
	_expect(player.is_invincible,
		"a Halo-protected hit starts the player's invincibility window")

	var halo_count_before := player.get_children().filter(
		func(child: Node) -> bool: return child is GuardHalo
	).size()
	player.equip_halo()
	var halo_count_after := player.get_children().filter(
		func(child: Node) -> bool: return child is GuardHalo
	).size()
	_expect(halo_count_before == 1 and halo_count_after == 1,
		"calling equip_halo twice does not create a duplicate")

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
