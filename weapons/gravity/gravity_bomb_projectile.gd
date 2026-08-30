extends Node2D
class_name GravityBombProjectile

signal state_changed(new_state: BombState)

enum BombState {
	FLYING,
	PULLING,
	EXPLODING,
}

@export var travel_speed: float = 420.0
@export var tracking_speed: float = 520.0
@export var pull_radius: float = 180.0
@export var pull_strength: float = 115.0
@export var pull_duration: float = 1.6
@export var pull_tick_interval: float = 0.4
@export var pull_tick_damage: int = 5
@export var explosion_duration: float = 0.28

var state: BombState = BombState.FLYING
var target_position: Vector2
var tracked_target: Node2D = null
var _requires_live_target: bool = false
var explosion_damage: int = 50
var _state_time: float = 0.0
var _damage_tick_time: float = 0.0
var _visual_rotation: float = 0.0


func launch(
		from: Vector2,
		target: Vector2,
		damage: int,
		target_enemy: Node2D = null
	) -> void:
	global_position = from
	target_position = target
	tracked_target = target_enemy
	_requires_live_target = target_enemy != null
	explosion_damage = damage
	if global_position.distance_to(target_position) <= 5.0:
		change_state(BombState.PULLING)
	else:
		change_state(BombState.FLYING)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_visual_rotation += delta * (5.0 if state == BombState.PULLING else 2.0)

	match state:
		BombState.FLYING:
			_update_flying(delta)
		BombState.PULLING:
			_update_pulling(delta)
		BombState.EXPLODING:
			if _state_time >= explosion_duration:
				queue_free()

	queue_redraw()


func _update_flying(delta: float) -> void:
	if not _update_tracked_target_position():
		return
	var current_speed := tracking_speed if is_instance_valid(tracked_target) else travel_speed
	global_position = global_position.move_toward(target_position, current_speed * delta)
	if global_position.distance_to(target_position) <= 5.0:
		change_state(BombState.PULLING)


func _update_pulling(delta: float) -> void:
	# Keep the active gravity field attached to its original target. If that
	# enemy dies, the last valid position is retained and the bomb still ends.
	if not _update_tracked_target_position():
		return
	if is_instance_valid(tracked_target):
		global_position = global_position.move_toward(target_position, tracking_speed * delta)

	_damage_tick_time += delta
	var should_damage := _damage_tick_time >= pull_tick_interval
	if should_damage:
		_damage_tick_time = 0.0

	for enemy in _get_enemies_in_radius():
		var distance := enemy.global_position.distance_to(global_position)
		var strength_scale := 1.0 - clampf(distance / pull_radius, 0.0, 1.0)
		enemy.global_position = enemy.global_position.move_toward(
			global_position,
			pull_strength * (0.35 + strength_scale) * delta
		)
		if should_damage and enemy.has_method("take_damage"):
			enemy.take_damage(pull_tick_damage)

	if _state_time >= pull_duration:
		change_state(BombState.EXPLODING)


func _update_tracked_target_position() -> bool:
	if is_instance_valid(tracked_target) and tracked_target.is_inside_tree():
		target_position = tracked_target.global_position
		return true
	if _requires_live_target:
		tracked_target = null
		queue_free()
		return false
	return true


func _get_enemies_in_radius() -> Array[Node2D]:
	var nearby: Array[Node2D] = []
	var scene_tree := get_tree()
	if scene_tree == null:
		return nearby

	for node in scene_tree.get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) <= pull_radius:
			nearby.append(enemy)
	return nearby


func change_state(new_state: BombState) -> void:
	state = new_state
	_state_time = 0.0
	_damage_tick_time = 0.0
	if state == BombState.EXPLODING:
		_apply_explosion_damage()
	state_changed.emit(state)
	queue_redraw()


func _apply_explosion_damage() -> void:
	for enemy in _get_enemies_in_radius():
		if enemy.has_method("take_damage"):
			enemy.take_damage(explosion_damage)


func _draw() -> void:
	var purple := Color(0.58, 0.24, 1.0, 1.0)
	var cyan := Color(0.3, 0.85, 1.0, 1.0)

	match state:
		BombState.FLYING:
			draw_circle(Vector2.ZERO, 13.0, Color(0.25, 0.05, 0.48, 0.9))
			draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, purple, 3.0)
			draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
		BombState.PULLING:
			var pulse := 0.84 + sin(_visual_rotation * 2.0) * 0.1
			draw_circle(Vector2.ZERO, pull_radius * pulse, Color(0.35, 0.08, 0.7, 0.08))
			draw_arc(Vector2.ZERO, pull_radius * pulse, 0.0, TAU, 64, Color(purple, 0.42), 2.0)
			draw_circle(Vector2.ZERO, 18.0, Color(0.18, 0.02, 0.35, 0.98))
			draw_arc(Vector2.ZERO, 26.0, _visual_rotation, _visual_rotation + PI * 1.4, 32, purple, 4.0)
			draw_arc(Vector2.ZERO, 34.0, -_visual_rotation, -_visual_rotation + PI, 28, cyan, 2.0)
			for index in range(3):
				var angle := _visual_rotation + TAU * float(index) / 3.0
				draw_circle(Vector2.from_angle(angle) * 29.0, 4.0, cyan)
			draw_circle(Vector2.ZERO, 7.0, Color.WHITE)
		BombState.EXPLODING:
			var progress := clampf(_state_time / maxf(explosion_duration, 0.01), 0.0, 1.0)
			var radius := lerpf(20.0, pull_radius, progress)
			draw_circle(Vector2.ZERO, radius, Color(0.5, 0.15, 1.0, (1.0 - progress) * 0.25))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(purple, 1.0 - progress), 6.0)
			draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, Color(cyan, 1.0 - progress), 3.0)
