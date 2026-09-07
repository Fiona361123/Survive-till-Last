extends SceneTree

var failures: int = 0
var boss_ready_count: int = 0


func _initialize() -> void:
	await process_frame
	await _test_authored_scene_and_one_shot_wave_one()
	await _test_wave_progression_and_cleanup()
	await _test_missing_wave_two_scene_aborts_atomically()
	if failures == 0:
		print("Boss encounter tests passed.")
	quit(0 if failures == 0 else 1)


# Huang Wan Jun 2204536 - Verify the authored arena structure and one-shot Wave 1 contract.
func _test_authored_scene_and_one_shot_wave_one() -> void:
	var encounter := _make_encounter()
	if encounter == null:
		return
	root.add_child(encounter)
	await process_frame
	_expect(encounter.get_node("Wave1SpawnPoints").get_child_count() == 5, "authored scene has five slime markers")
	_expect(encounter.get_node("Wave2SkeletonSpawnPoints").get_child_count() == 3, "authored scene has three skeleton markers")
	_expect(encounter.get_node("Wave2RangedSpawnPoints").get_child_count() == 2, "authored scene has two ranged markers")
	_expect(not encounter.get_node("BossSpawnPoint").visible, "future boss marker starts hidden")
	encounter.start_encounter()
	encounter.start_encounter()
	await process_frame
	var minions := encounter.get_node("ActiveMinions").get_children()
	_expect(encounter.get_encounter_state() == BossEncounterController.State.WAVE_1, "trial enters Wave 1")
	_expect(minions.size() == 5, "Wave 1 creates exactly five slimes without duplicates")
	for minion in minions:
		_expect(minion.is_in_group("boss_minion") and minion.is_in_group("boss_enemy"), "Wave 1 minion has boss groups")
		_expect(not minion.is_in_group("level1_enemy") and not minion.is_in_group("level2_enemy") and not minion.is_in_group("level3_enemy"), "Wave 1 minion is isolated from earlier levels")
	_expect(encounter.get_node("FireSweep").state == FireSweep.State.SAFE, "fire stays safe in Wave 1")
	_cleanup(encounter)
	await process_frame


# Huang Wan Jun 2204536 - Exercise both waves, dead-animation counting, traps, and boss-ready cleanup.
func _test_wave_progression_and_cleanup() -> void:
	var encounter := _make_encounter()
	if encounter == null:
		return
	root.add_child(encounter)
	await process_frame
	encounter.boss_ready.connect(_on_boss_ready)
	encounter.start_encounter()
	await process_frame
	var wave_one := encounter.get_node("ActiveMinions").get_children()
	wave_one[0].set("current_health", 0)
	for index in range(1, wave_one.size()):
		wave_one[index].queue_free()
	await _wait_for_state(encounter, BossEncounterController.State.WAVE_2)
	_expect(encounter.get_encounter_state() == BossEncounterController.State.WAVE_2, "dead animating slime does not block Wave 2")
	_expect(_count_script(encounter, "res://skeleton.gd") == 3, "Wave 2 creates three skeletons")
	_expect(_count_script(encounter, "res://RangedEnemy.gd") == 2, "Wave 2 creates two ranged enemies")
	for row in encounter.get_node("SpikeRows").get_children():
		_expect(row.state == SpikeRow.State.SAFE, "spikes retract before Wave 2")
	var projectile := Node2D.new()
	encounter.get_node("ActiveProjectiles").add_child(projectile)
	for minion in encounter.get_node("ActiveMinions").get_children():
		minion.queue_free()
	await _wait_for_state(encounter, BossEncounterController.State.BOSS_READY)
	await process_frame
	_expect(encounter.is_boss_ready(), "Wave 2 completion readies the boss arena")
	_expect(encounter.get_node("FireSweep").state == FireSweep.State.SAFE, "fire stops after Wave 2")
	_expect(encounter.get_node("ActiveProjectiles").get_child_count() == 0, "owned projectiles are cleared")
	_expect(encounter.get_node("BossSpawnPoint").visible, "future boss marker becomes visible")
	_expect(boss_ready_count == 1, "boss_ready emits exactly once")
	encounter.start_encounter()
	_expect(encounter.get_node("ActiveMinions").get_child_count() == 0, "completed trial cannot restart")
	_cleanup(encounter)
	await process_frame


# Huang Wan Jun 2204536 - Missing Wave 2 configuration must not leave partial new actors behind.
func _test_missing_wave_two_scene_aborts_atomically() -> void:
	var encounter := _make_encounter()
	if encounter == null:
		return
	encounter.ranged_enemy_scene = null
	root.add_child(encounter)
	await process_frame
	encounter.start_encounter()
	await process_frame
	for minion in encounter.get_node("ActiveMinions").get_children():
		minion.queue_free()
	await create_timer(0.12).timeout
	_expect(encounter.get_encounter_state() == BossEncounterController.State.WAVE_1, "invalid Wave 2 does not advance state")
	_expect(encounter.get_node("ActiveMinions").get_child_count() == 0, "invalid Wave 2 creates no partial actors")
	_cleanup(encounter)
	await process_frame


func _make_encounter() -> BossEncounterController:
	var packed := load("res://BossEncounter/BossEncounter.tscn") as PackedScene
	_expect(packed != null, "BossEncounter scene loads")
	if packed == null:
		return null
	var encounter := packed.instantiate() as BossEncounterController
	encounter.trap_interval = 0.02
	for row in encounter.get_node("SpikeRows").get_children():
		row.warning_duration = 0.02
		row.active_duration = 0.02
	encounter.get_node("FireSweep").warning_duration = 0.02
	encounter.get_node("FireSweep").travel_duration = 0.02
	return encounter


func _wait_for_state(encounter: BossEncounterController, state: BossEncounterController.State) -> void:
	var deadline := Time.get_ticks_msec() + 1500
	while encounter.get_encounter_state() != state and Time.get_ticks_msec() < deadline:
		await process_frame


func _count_script(encounter: BossEncounterController, script_path: String) -> int:
	var count := 0
	for minion in encounter.get_node("ActiveMinions").get_children():
		var script := minion.get_script() as Script
		if script != null and script.resource_path == script_path:
			count += 1
	return count


func _cleanup(encounter: Node) -> void:
	for minion in encounter.get_node("ActiveMinions").get_children():
		minion.queue_free()
	encounter.queue_free()


func _on_boss_ready(_spawn_point: Marker2D) -> void:
	boss_ready_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
