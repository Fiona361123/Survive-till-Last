extends SceneTree

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_decoy_priority_and_fallback()
	await _test_enemy_projectile_hits_decoy()

	if failures == 0:
		print("Enemy decoy targeting tests passed.")
	else:
		push_error("%d enemy decoy targeting test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _test_decoy_priority_and_fallback() -> void:
	var real_player := Node2D.new()
	real_player.add_to_group("player")
	real_player.global_position = Vector2(700.0, 0.0)
	root.add_child(real_player)
	var enemy := Node2D.new()
	enemy.global_position = Vector2.ZERO
	root.add_child(enemy)
	var echo := _create_echo(Vector2(80.0, 0.0), 0.8)

	_expect(COMBAT_TARGET_SELECTOR.choose_target(enemy, real_player) == echo,
		"an enemy selects a valid nearby Temporal Echo before the real Player")
	echo.global_position = Vector2(650.0, 0.0)
	_expect(COMBAT_TARGET_SELECTOR.choose_target(enemy, real_player) == real_player,
		"an enemy keeps the real Player when the ghost is outside attraction range")
	echo.global_position = Vector2(80.0, 0.0)
	echo.call("_finish_replay")
	_expect(COMBAT_TARGET_SELECTOR.choose_target(enemy, real_player) == real_player,
		"an enemy safely returns to the real Player when the ghost finishes")

	real_player.queue_free()
	enemy.queue_free()
	await create_timer(0.04).timeout


func _test_enemy_projectile_hits_decoy() -> void:
	var echo := _create_echo(Vector2.ZERO, 0.8)
	var projectile_scene := load("res://Projectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate()
	# This unit call does not add the projectile to the tree, avoiding its normal
	# three-second lifetime timer while still testing collision target handling.
	projectile.call("_on_body_entered", echo)
	_expect(echo.hits_absorbed == 1,
		"a ranged enemy projectile recognizes and damages the ghost decoy")
	_expect(bool(projectile.get("has_hit")),
		"the projectile is consumed after striking the ghost")

	projectile.free()
	echo.queue_free()
	await process_frame


func _create_echo(position: Vector2, duration: float) -> TemporalEcho:
	var echo_scene := load("res://weapons/temporal/TemporalEcho.tscn") as PackedScene
	var echo := echo_scene.instantiate() as TemporalEcho
	echo.fade_duration = 0.02
	root.add_child(echo)
	var snapshots: Array[Dictionary] = [
		{"time": 0.0, "position": position},
		{"time": duration, "position": position},
	]
	echo.begin_replay(snapshots, 0)
	return echo


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
