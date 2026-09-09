extends Node2D
class_name PrismField

signal target_changed(target: Node2D)
signal field_activated
signal collapse_exploded(position: Vector2, radius: float, damage: int)
signal field_finished

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")
const WEAPON_DAMAGE = preload("res://systems/weapon_damage.gd")

enum FieldState { IDLE, SEEKING, SNARING, COLLAPSING, EXPLODING, FINISHED }

@export var prism_scene: PackedScene

var state: FieldState = FieldState.IDLE
var target: Node2D = null
var travelling_core: PrismNode = null
var cage_prisms: Array[PrismNode] = []
var beam_glows: Array[Line2D] = []
var beam_cores: Array[Line2D] = []
var trapped_enemies: Array[Node2D] = []
var trail_points: Array[Vector2] = []

var acquisition_range: float = 620.0
var projectile_speed: float = 390.0
var homing_acceleration: float = 1050.0
var maximum_seek_time: float = 3.0
var capture_distance: float = 28.0
var trap_radius: float = 105.0
var trap_duration: float = 4.0
var trap_pull_strength: float = 340.0
var damage_interval: float = 0.45
var damage_per_tick: int = 35
var collapse_duration: float = 0.4
var explosion_radius: float = 145.0
var explosion_damage: int = 60
var explosion_visual_duration: float = 0.42

var velocity: Vector2 = Vector2.ZERO
var cage_center: Vector2 = Vector2.ZERO
var state_time: float = 0.0
var damage_time: float = 0.0
var visual_time: float = 0.0
var cage_angle: float = 0.0

@onready var field_fill: Polygon2D = $FieldFill
@onready var beam_container: Node2D = $BeamContainer
@onready var prism_container: Node2D = $PrismContainer


func _ready() -> void:
	field_fill.visible = false
	set_physics_process(false)


func begin_hunt(
		start_position: Vector2,
		initial_target: Node2D,
		launch_direction: Vector2,
		settings: Dictionary = {}
	) -> void:
	if state != FieldState.IDLE or prism_scene == null:
		return
	_apply_settings(settings)
	global_position = start_position
	var safe_direction := launch_direction.normalized()
	if safe_direction == Vector2.ZERO:
		safe_direction = Vector2.RIGHT
	velocity = safe_direction * projectile_speed * 0.55
	state = FieldState.SEEKING
	state_time = 0.0
	trail_points = [global_position]
	_spawn_travelling_core()
	_set_target(initial_target if COMBAT_TARGET_SELECTOR.is_living_enemy(initial_target) else null)
	set_physics_process(true)
	queue_redraw()


func _apply_settings(settings: Dictionary) -> void:
	acquisition_range = float(settings.get("acquisition_range", acquisition_range))
	projectile_speed = float(settings.get("projectile_speed", projectile_speed))
	homing_acceleration = float(settings.get("homing_acceleration", homing_acceleration))
	maximum_seek_time = float(settings.get("maximum_seek_time", maximum_seek_time))
	capture_distance = float(settings.get("capture_distance", capture_distance))
	trap_radius = float(settings.get("trap_radius", trap_radius))
	trap_duration = float(settings.get("trap_duration", trap_duration))
	trap_pull_strength = float(settings.get("trap_pull_strength", trap_pull_strength))
	damage_interval = float(settings.get("damage_interval", damage_interval))
	damage_per_tick = int(settings.get("damage_per_tick", damage_per_tick))
	collapse_duration = float(settings.get("collapse_duration", collapse_duration))
	explosion_radius = float(settings.get("explosion_radius", explosion_radius))
	explosion_damage = int(settings.get("explosion_damage", explosion_damage))
	explosion_visual_duration = float(settings.get("explosion_visual_duration", explosion_visual_duration))


func _physics_process(delta: float) -> void:
	visual_time += delta
	state_time += delta
	match state:
		FieldState.SEEKING:
			_update_seeking(delta)
		FieldState.SNARING:
			_update_snaring(delta)
		FieldState.COLLAPSING:
			_update_collapsing(delta)
		FieldState.EXPLODING:
			if state_time >= explosion_visual_duration:
				_finish_field()
	queue_redraw()


# Predictive homing leads moving CharacterBody2D targets. If a target dies or
# leaves the tree, the prism searches again instead of disappearing immediately.
func _update_seeking(delta: float) -> void:
	if not COMBAT_TARGET_SELECTOR.is_living_enemy(target):
		_set_target(_find_nearest_enemy(global_position, acquisition_range))

	if is_instance_valid(target):
		var target_position := _get_predicted_target_position(target)
		var desired_direction := global_position.direction_to(target_position)
		if desired_direction != Vector2.ZERO:
			velocity = velocity.move_toward(
				desired_direction * projectile_speed,
				homing_acceleration * delta
			)
		if global_position.distance_to(target.global_position) <= capture_distance:
			_begin_snare(target)
			return
	else:
		velocity = velocity.move_toward(
			velocity.normalized() * projectile_speed,
			homing_acceleration * 0.25 * delta
		)

	global_position += velocity * delta
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	trail_points.append(global_position)
	if trail_points.size() > 14:
		trail_points.pop_front()

	if state_time >= maximum_seek_time:
		_finish_field()


func _get_predicted_target_position(enemy: Node2D) -> Vector2:
	var predicted_position := enemy.global_position
	if enemy is CharacterBody2D:
		var travel_time := minf(
			global_position.distance_to(enemy.global_position) / maxf(projectile_speed, 1.0),
			0.45
		)
		predicted_position += enemy.velocity * travel_time * 0.75
	return predicted_position


func _find_nearest_enemy(origin: Vector2, maximum_distance: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_squared := maximum_distance * maximum_distance
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		var distance_squared := origin.distance_squared_to(enemy.global_position)
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = enemy
	return nearest


func _set_target(new_target: Node2D) -> void:
	if target == new_target:
		return
	target = new_target
	target_changed.emit(target)


func _begin_snare(captured_target: Node2D) -> void:
	state = FieldState.SNARING
	state_time = 0.0
	damage_time = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0
	cage_center = captured_target.global_position
	global_position = cage_center
	trail_points.clear()
	_mark_enemy_trapped(captured_target)
	_spawn_cage()
	field_activated.emit()


func _spawn_travelling_core() -> void:
	travelling_core = prism_scene.instantiate() as PrismNode
	if travelling_core == null:
		return
	prism_container.add_child(travelling_core)
	travelling_core.position = Vector2.ZERO
	travelling_core.scale = Vector2.ONE * 0.78


func _spawn_cage() -> void:
	field_fill.visible = true
	field_fill.polygon = _make_circle_polygon(trap_radius * 0.78, 32)
	field_fill.color = Color(0.18, 0.06, 0.55, 0.16)
	if is_instance_valid(travelling_core):
		travelling_core.scale = Vector2.ONE * 1.15

	for index in range(4):
		var prism := prism_scene.instantiate() as PrismNode
		if prism == null:
			continue
		prism_container.add_child(prism)
		prism.scale = Vector2.ONE * 0.1
		cage_prisms.append(prism)
		var appear_tween := prism.create_tween()
		appear_tween.tween_property(prism, "scale", Vector2.ONE, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		var glow := Line2D.new()
		glow.width = 13.0
		glow.default_color = Color(0.36, 0.12, 1.0, 0.42)
		glow.antialiased = true
		beam_container.add_child(glow)
		beam_glows.append(glow)

		var core := Line2D.new()
		core.width = 3.4
		core.default_color = Color(0.65, 0.94, 1.0, 0.98)
		core.antialiased = true
		beam_container.add_child(core)
		beam_cores.append(core)

	_update_cage_geometry(0.0)


func _update_snaring(delta: float) -> void:
	_update_cage_geometry(delta)
	var enemies := _get_enemies_in_radius(cage_center, trap_radius)
	if COMBAT_TARGET_SELECTOR.is_living_enemy(target) and target not in enemies:
		enemies.append(target)
	for enemy in enemies:
		_mark_enemy_trapped(enemy)
	for enemy in trapped_enemies.duplicate():
		if not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			trapped_enemies.erase(enemy)
			continue
		_restrain_enemy(enemy, delta)

	damage_time -= delta
	if damage_time <= 0.0:
		damage_time = maxf(damage_interval, 0.01)
		_damage_trapped_enemies()

	if state_time >= trap_duration:
		_begin_collapse()


func _mark_enemy_trapped(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or enemy in trapped_enemies:
		return
	trapped_enemies.append(enemy)
	enemy.set_meta(&"prism_snared", true)
	enemy.set_meta(&"prism_snare_center", cage_center)


# The cage clamps escape attempts at its inner wall and continuously pulls
# enemies inward. It does not disable their scripts, so boss phases and timers
# continue running normally while movement is restrained.
func _restrain_enemy(enemy: Node2D, delta: float) -> void:
	if not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
		return
	var offset := enemy.global_position - cage_center
	var hold_radius := trap_radius * 0.58
	if offset.length() > hold_radius:
		enemy.global_position = cage_center + offset.normalized() * hold_radius
	enemy.global_position = enemy.global_position.move_toward(
		cage_center,
		trap_pull_strength * 0.22 * delta
	)
	if enemy is CharacterBody2D:
		enemy.velocity = Vector2.ZERO


func _damage_trapped_enemies() -> void:
	for enemy in trapped_enemies.duplicate():
		if not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			trapped_enemies.erase(enemy)
			continue
		enemy.take_damage(WEAPON_DAMAGE.calculate(damage_per_tick, self))
	for prism in cage_prisms:
		if is_instance_valid(prism):
			prism.flash()


func _update_cage_geometry(delta: float) -> void:
	if cage_prisms.is_empty():
		return
	cage_angle += delta * 0.72
	var cage_node_radius := trap_radius * 0.82
	for index in range(cage_prisms.size()):
		var angle := cage_angle + TAU * float(index) / float(cage_prisms.size())
		cage_prisms[index].position = Vector2.from_angle(angle) * cage_node_radius

	for index in range(cage_prisms.size()):
		var next_index := (index + 1) % cage_prisms.size()
		var points := PackedVector2Array([
			cage_prisms[index].position,
			cage_prisms[next_index].position,
		])
		beam_glows[index].points = points
		beam_cores[index].points = points
		var pulse := 0.72 + absf(sin(visual_time * 7.0 + float(index))) * 0.28
		beam_glows[index].modulate.a = pulse


func _begin_collapse() -> void:
	state = FieldState.COLLAPSING
	state_time = 0.0
	field_fill.visible = false
	for prism in cage_prisms:
		if is_instance_valid(prism):
			prism.collapse_to(global_position, collapse_duration)


func _update_collapsing(delta: float) -> void:
	for enemy in trapped_enemies:
		if is_instance_valid(enemy):
			_restrain_enemy(enemy, delta)
	var fade := 1.0 - clampf(state_time / maxf(collapse_duration, 0.01), 0.0, 1.0)
	beam_container.modulate.a = fade
	if state_time >= collapse_duration:
		_explode()


func _explode() -> void:
	state = FieldState.EXPLODING
	state_time = 0.0
	var final_damage := WEAPON_DAMAGE.calculate(explosion_damage, self)
	for enemy in _get_enemies_in_radius(cage_center, explosion_radius):
		enemy.take_damage(final_damage)
	beam_container.visible = false
	prism_container.visible = false
	_release_trapped_enemies()
	collapse_exploded.emit(cage_center, explosion_radius, final_damage)


func _get_enemies_in_radius(origin: Vector2, radius: float) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		if enemy.global_position.distance_to(origin) <= radius:
			enemies.append(enemy)
	return enemies


func _release_trapped_enemies() -> void:
	for enemy in trapped_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_meta(&"prism_snared"):
			enemy.remove_meta(&"prism_snared")
		if enemy.has_meta(&"prism_snare_center"):
			enemy.remove_meta(&"prism_snare_center")
	trapped_enemies.clear()


func _finish_field() -> void:
	if state == FieldState.FINISHED:
		return
	state = FieldState.FINISHED
	set_physics_process(false)
	_release_trapped_enemies()
	field_finished.emit()
	queue_free()


func _exit_tree() -> void:
	_release_trapped_enemies()


func _make_circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_count := maxi(point_count, 3)
	for index in range(safe_count):
		points.append(Vector2.from_angle(TAU * float(index) / float(safe_count)) * radius)
	return points


func _draw() -> void:
	match state:
		FieldState.SEEKING:
			if trail_points.size() >= 2:
				var local_trail := PackedVector2Array()
				for world_point in trail_points:
					local_trail.append(to_local(world_point))
				draw_polyline(local_trail, Color(0.45, 0.18, 1.0, 0.58), 8.0, true)
			draw_circle(Vector2.ZERO, 25.0 + sin(visual_time * 10.0) * 4.0, Color(0.25, 0.08, 0.8, 0.18))
			draw_arc(Vector2.ZERO, 34.0, visual_time * 3.0, visual_time * 3.0 + PI * 1.55, 32, Color(0.55, 0.92, 1.0, 0.9), 3.0, true)
			if is_instance_valid(target):
				draw_line(Vector2.ZERO, to_local(target.global_position), Color(0.7, 0.4, 1.0, 0.28), 1.5, true)
		FieldState.SNARING:
			var pulse_radius := trap_radius * (0.88 + sin(visual_time * 5.0) * 0.04)
			draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 64, Color(0.48, 0.82, 1.0, 0.72), 2.5, true)
			for mote_index in range(8):
				var angle := visual_time * (1.2 + float(mote_index % 3) * 0.2) + TAU * float(mote_index) / 8.0
				draw_circle(Vector2.from_angle(angle) * trap_radius * 0.65, 3.5, Color(0.72, 0.45, 1.0, 0.82))
		FieldState.COLLAPSING:
			var progress := clampf(state_time / maxf(collapse_duration, 0.01), 0.0, 1.0)
			draw_arc(Vector2.ZERO, lerpf(trap_radius, 12.0, progress), 0.0, TAU, 48, Color(0.75, 0.92, 1.0, 1.0 - progress), 5.0, true)
		FieldState.EXPLODING:
			var progress := clampf(state_time / maxf(explosion_visual_duration, 0.01), 0.0, 1.0)
			var blast_radius := lerpf(18.0, explosion_radius, progress)
			var alpha := 1.0 - progress
			draw_circle(Vector2.ZERO, blast_radius * 0.62, Color(0.35, 0.1, 0.95, alpha * 0.24))
			draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 64, Color(0.72, 0.95, 1.0, alpha), 6.0, true)
