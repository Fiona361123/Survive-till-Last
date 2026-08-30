extends CharacterBody2D
class_name TemporalEcho

signal replay_finished

@export var replay_speed: float = 1.0
@export var fade_duration: float = 0.22
@export var ghost_opacity: float = 0.55
@export var attraction_radius: float = 500.0
@export var damage_radius: float = 90.0
@export var damage_interval: float = 0.5

var replay_snapshots: Array[Dictionary] = []
var replay_time: float = 0.0
var replay_duration: float = 0.0
var damage_per_tick: int = 10
var hits_absorbed: int = 0
var _source_start_time: float = 0.0
var _segment_index: int = 0
var _damage_timer: float = 0.0
var _finishing: bool = false
var _hit_tween: Tween = null

@onready var ghost_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("temporal_echo")
	add_to_group("temporal_decoy")


func begin_replay(
		snapshot_copy: Array[Dictionary],
		tick_damage: int,
		source_sprite: AnimatedSprite2D = null
	) -> void:
	replay_snapshots = snapshot_copy.duplicate(true)
	damage_per_tick = maxi(0, tick_damage)
	replay_time = 0.0
	_segment_index = 0
	_damage_timer = 0.0
	_copy_player_visual(source_sprite)

	if replay_snapshots.size() < 2:
		_finish_replay()
		return

	_source_start_time = float(replay_snapshots[0].get("time", 0.0))
	var source_end_time := float(replay_snapshots[-1].get("time", _source_start_time))
	replay_duration = maxf(0.0, source_end_time - _source_start_time)
	global_position = replay_snapshots[0].get("position", global_position) as Vector2
	_apply_visual_snapshot(replay_snapshots[0])

	if replay_duration <= 0.0:
		_finish_replay()


func _physics_process(delta: float) -> void:
	if _finishing or replay_snapshots.size() < 2:
		return

	replay_time += delta * maxf(replay_speed, 0.01)
	global_position = _get_interpolated_position(replay_time)
	var visual_index := _segment_index
	if replay_time >= replay_duration:
		visual_index = replay_snapshots.size() - 1
	_apply_visual_snapshot(replay_snapshots[visual_index])

	_damage_timer += delta
	var interval := maxf(damage_interval, 0.01)
	if _damage_timer >= interval:
		_damage_timer = fmod(_damage_timer, interval)
		_damage_nearby_enemies()

	if replay_time >= replay_duration:
		_finish_replay()


func _get_interpolated_position(elapsed: float) -> Vector2:
	var source_time := _source_start_time + clampf(elapsed, 0.0, replay_duration)
	while _segment_index < replay_snapshots.size() - 2:
		var next_time := float(replay_snapshots[_segment_index + 1].get("time", source_time))
		if source_time <= next_time:
			break
		_segment_index += 1

	var from_snapshot := replay_snapshots[_segment_index]
	var to_snapshot := replay_snapshots[_segment_index + 1]
	var from_time := float(from_snapshot.get("time", source_time))
	var to_time := float(to_snapshot.get("time", from_time))
	var weight := 1.0 if is_equal_approx(from_time, to_time) else clampf(
		(source_time - from_time) / (to_time - from_time),
		0.0,
		1.0
	)
	var from_position: Vector2 = from_snapshot.get("position", global_position)
	var to_position: Vector2 = to_snapshot.get("position", from_position)
	return from_position.lerp(to_position, weight)

func _copy_player_visual(source_sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(source_sprite) or not is_instance_valid(ghost_sprite):
		return
	ghost_sprite.sprite_frames = source_sprite.sprite_frames
	ghost_sprite.scale = source_sprite.scale
	ghost_sprite.offset = source_sprite.offset
	ghost_sprite.centered = source_sprite.centered
	ghost_sprite.texture_filter = source_sprite.texture_filter
	ghost_sprite.modulate = Color(1.0, 1.0, 1.0, clampf(ghost_opacity, 0.05, 1.0))
	ghost_sprite.pause()


func _apply_visual_snapshot(snapshot: Dictionary) -> void:
	if not is_instance_valid(ghost_sprite) or ghost_sprite.sprite_frames == null:
		return
	var animation := StringName(snapshot.get("animation", &""))
	if animation != &"" and ghost_sprite.sprite_frames.has_animation(animation):
		ghost_sprite.animation = animation
		var frame_count := ghost_sprite.sprite_frames.get_frame_count(animation)
		if frame_count > 0:
			var recorded_frame := clampi(int(snapshot.get("frame", 0)), 0, frame_count - 1)
			var progress := clampf(float(snapshot.get("frame_progress", 0.0)), 0.0, 1.0)
			ghost_sprite.set_frame_and_progress(recorded_frame, progress)
	ghost_sprite.flip_h = bool(snapshot.get("flip_h", false))
	ghost_sprite.position = snapshot.get("sprite_position", ghost_sprite.position) as Vector2
	ghost_sprite.pause()


func _damage_nearby_enemies() -> void:
	if _finishing or damage_per_tick <= 0:
		return
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	for node in scene_tree.get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > maxf(damage_radius, 0.0):
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_per_tick)


func can_attract_enemy(enemy: Node2D) -> bool:
	return not _finishing \
		and is_instance_valid(enemy) \
		and enemy.global_position.distance_to(global_position) <= maxf(attraction_radius, 0.0)


func take_damage(_amount: int) -> void:
	if _finishing or not is_instance_valid(ghost_sprite):
		return
	hits_absorbed += 1
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	var normal_alpha := clampf(ghost_opacity, 0.05, 1.0)
	ghost_sprite.modulate = Color(1.0, 1.0, 1.0, normal_alpha * 0.4)
	_hit_tween = ghost_sprite.create_tween()
	_hit_tween.tween_property(
		ghost_sprite,
		"modulate:a",
		normal_alpha,
		0.12
	)


func _finish_replay() -> void:
	if _finishing:
		return
	_finishing = true
	set_collision_layer_value(2, false)
	replay_finished.emit()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, maxf(fade_duration, 0.01))
	tween.tween_callback(queue_free)
