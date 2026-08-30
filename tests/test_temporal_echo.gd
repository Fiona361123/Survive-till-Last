extends SceneTree

var failures: int = 0


func _initialize() -> void:
	await process_frame
	await _test_player_visual_recording_and_activation()
	await _test_replay_animation_and_nearby_damage()

	if failures == 0:
		print("Temporal Echo tests passed.")
	else:
		push_error("%d Temporal Echo test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _test_player_visual_recording_and_activation() -> void:
	var player := Node2D.new()
	player.name = "TemporalTestPlayer"
	player.add_to_group("player")
	var player_sprite := _create_test_sprite()
	player.add_child(player_sprite)
	root.add_child(player)

	var weapon_scene := load("res://weapons/temporal/TemporalEchoWeapon.tscn") as PackedScene
	var weapon := weapon_scene.instantiate() as TemporalEchoWeapon
	weapon.sample_interval = 0.01
	weapon.record_duration = 0.12
	weapon.minimum_recording_time = 0.04
	root.add_child(weapon)
	weapon.set_active(false)

	for step in range(7):
		player.global_position = Vector2(float(step) * 18.0, float(step % 2) * 12.0)
		player_sprite.flip_h = step >= 3
		player_sprite.position = Vector2(4.0, -float(step))
		await create_timer(0.025).timeout

	_expect(not weapon.active and weapon.snapshots.size() >= 3,
		"Temporal Echo records while it is not the selected weapon")
	_expect(weapon.get_recorded_duration() <= weapon.record_duration + 0.04,
		"the rolling buffer removes history older than its recording window")
	var latest_snapshot: Dictionary = weapon.snapshots[-1]
	_expect(latest_snapshot.get("animation") == &"run_down"
		and bool(latest_snapshot.get("flip_h")),
		"movement snapshots include the Player animation and facing direction")
	_expect(latest_snapshot.get("sprite_position") == player_sprite.position,
		"movement snapshots include the Player sprite offset used by jumping")

	weapon.set_active(true)
	weapon.trigger_attack()
	var echoes := get_nodes_in_group("temporal_echo")
	_expect(weapon.cooldown_left > 0.0 and echoes.size() == 1,
		"a valid history creates one Player-shaped Echo and starts cooldown")
	if not echoes.is_empty():
		var echo := echoes[0] as TemporalEcho
		var ghost_sprite := echo.get_node("AnimatedSprite2D") as AnimatedSprite2D
		_expect(ghost_sprite.sprite_frames == player_sprite.sprite_frames,
			"the ghost reuses the exact Player SpriteFrames resource")
		_expect(echo.get_node_or_null("Trail") == null,
			"the old snake-like Line2D trail is removed")
		_expect(is_equal_approx(ghost_sprite.modulate.r, 1.0)
			and is_equal_approx(ghost_sprite.modulate.g, 1.0)
			and is_equal_approx(ghost_sprite.modulate.b, 1.0),
			"the ghost keeps the Player's original colours without a tint")

	weapon.queue_free()
	player.queue_free()
	for echo in get_nodes_in_group("temporal_echo"):
		echo.queue_free()
	await process_frame


func _test_replay_animation_and_nearby_damage() -> void:
	var source_sprite := _create_test_sprite()
	root.add_child(source_sprite)
	var source_snapshots: Array[Dictionary] = [
		_create_snapshot(0.0, Vector2.ZERO, false, Vector2(4.0, 3.0)),
		_create_snapshot(0.16, Vector2(80.0, 0.0), true, Vector2(4.0, -8.0)),
		_create_snapshot(0.32, Vector2(160.0, 0.0), true, Vector2(4.0, 3.0)),
	]

	var echo_scene := load("res://weapons/temporal/TemporalEcho.tscn") as PackedScene
	var echo := echo_scene.instantiate() as TemporalEcho
	echo.fade_duration = 0.02
	echo.damage_interval = 0.04
	echo.damage_radius = 100.0
	root.add_child(echo)
	echo.begin_replay(source_snapshots, 10, source_sprite)

	# The Echo must own its history instead of reading a mutable live array.
	source_snapshots[0]["position"] = Vector2(900.0, 900.0)
	_expect(echo.replay_snapshots[0].get("position") == Vector2.ZERO,
		"the Echo owns a deep copy of the recorded movement and action data")

	var nearby_enemy := _create_enemy(Vector2(70.0, 0.0))
	var second_nearby_enemy := _create_enemy(Vector2(120.0, 0.0))
	var distant_enemy := _create_enemy(Vector2(600.0, 0.0))

	await create_timer(0.13).timeout
	_expect(echo.global_position.x > 10.0 and echo.global_position.x < 100.0,
		"the Player-shaped ghost interpolates through snapshots chronologically")
	_expect((echo.get_node("AnimatedSprite2D") as AnimatedSprite2D).animation == &"run_down",
		"the ghost replays the recorded Player animation")
	_expect(int(nearby_enemy.get("damage_received")) >= 20
		and int(second_nearby_enemy.get("damage_received")) >= 10,
		"every enemy near the ghost receives repeated radius damage")
	_expect(int(distant_enemy.get("damage_received")) == 0,
		"enemies outside the ghost damage radius are not damaged")

	echo.take_damage(99)
	_expect(echo.hits_absorbed == 1 and is_instance_valid(echo),
		"the ghost absorbs enemy attacks without ending the replay")

	await create_timer(0.25).timeout
	_expect(not is_instance_valid(echo),
		"the ghost fades and removes itself after replaying the complete route")

	source_sprite.queue_free()
	nearby_enemy.queue_free()
	second_nearby_enemy.queue_free()
	distant_enemy.queue_free()
	await process_frame


func _create_test_sprite() -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	var frames := SpriteFrames.new()
	frames.add_animation(&"run_down")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	frames.add_frame(&"run_down", ImageTexture.create_from_image(image))
	sprite.sprite_frames = frames
	sprite.play(&"run_down")
	return sprite


func _create_snapshot(
		time: float,
		position: Vector2,
		flip_h: bool,
		sprite_position: Vector2
	) -> Dictionary:
	return {
		"time": time,
		"position": position,
		"animation": &"run_down",
		"frame": 0,
		"frame_progress": 0.0,
		"flip_h": flip_h,
		"sprite_position": sprite_position,
	}


func _create_enemy(position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.set_script(load("res://tests/gravity_dummy_enemy.gd"))
	enemy.add_to_group("enemy")
	enemy.global_position = position
	root.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

