# chain_lightning.gd
extends Node2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")
const WEAPON_DAMAGE = preload("res://systems/weapon_damage.gd")

@export var damage: int = 15
@export var attack_cooldown: float = 1.2
@export var attack_range: float = 400.0   # range to find the FIRST target
@export var jump_range: float = 300.0     # search radius around the first target
@export var max_jumps: int = 5            # total enemies hit, including the first
@export var bolt_duration: float = 0.45
@export var secondary_glow_width: float = 12.0
@export var secondary_core_width: float = 4.5

# --- branch (fork) settings ---
@export var branch_count: int = 4         # how many random forks per zap
@export var branch_min_length: float = 20.0
@export var branch_max_length: float = 50.0

var cooldown_left: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var line: Line2D = $Line2D
@onready var glow_line: Line2D = $GlowLine
@onready var secondary_bolts: Node2D = $SecondaryBolts
@onready var branches: Node2D = $Branches

func _ready() -> void:
	add_to_group("weapon")
	line.clear_points()

func _physics_process(delta: float) -> void:
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	var first = _find_nearest_enemy(global_position, attack_range, [])
	if first != null:
		do_attack(first)

# The first enemy is the hub. Every additional target is selected around that
# enemy so one cast can visibly branch into a nearby group.
func do_attack(first_target: Node2D) -> void:
	if not COMBAT_TARGET_SELECTOR.is_living_enemy(first_target):
		return

	cooldown_left = attack_cooldown

	var hit_targets: Array[Node2D] = [first_target]
	var secondary_limit := maxi(max_jumps - 1, 0)
	hit_targets.append_array(_find_enemies_around(
		first_target.global_position,
		jump_range,
		hit_targets,
		secondary_limit
	))

	# Capture every endpoint before damage in case an enemy dies immediately.
	var bolt_segments: Array[PackedVector2Array] = [PackedVector2Array([
		global_position,
		first_target.global_position,
	])]
	for index in range(1, hit_targets.size()):
		bolt_segments.append(PackedVector2Array([
			first_target.global_position,
			hit_targets[index].global_position,
		]))

	for target in hit_targets:
		if COMBAT_TARGET_SELECTOR.is_living_enemy(target):
			target.take_damage(WEAPON_DAMAGE.calculate(damage, self))

	_draw_bolts(bolt_segments)


# Returns the closest unhit enemies around the primary target. Sorting makes
# the result deterministic and keeps the visible branches compact.
func _find_enemies_around(
	origin: Vector2,
	max_dist: float,
	exclude: Array[Node2D],
	limit: int
) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if limit <= 0:
		return candidates

	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or enemy in exclude:
			continue
		if not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		if origin.distance_to(enemy.global_position) <= max_dist:
			candidates.append(enemy)

	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates

# Finds the closest enemy to `from`, within `max_dist`, excluding `exclude`
func _find_nearest_enemy(from: Vector2, max_dist: float, exclude: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := max_dist
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in exclude:
			continue
		if not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		var dist = from.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

# Draw the player-to-primary bolt plus a separate, brighter bolt for every
# secondary enemy. Separate Line2D nodes prevent later jumps from blending
# into one hard-to-read zigzag.
func _draw_bolts(segments: Array[PackedVector2Array]) -> void:
	line.clear_points()
	glow_line.clear_points()
	_clear_secondary_bolts()
	_clear_branches()
	if segments.is_empty():
		return

	var primary := segments[0]
	var all_visual_points: Array = _jagged_points(
		to_local(primary[0]),
		to_local(primary[1])
	)

	for p in all_visual_points:
		glow_line.add_point(p)
		line.add_point(p)

	for index in range(1, segments.size()):
		var segment := segments[index]
		var secondary_points := _jagged_points(
			to_local(segment[0]),
			to_local(segment[1])
		)
		_spawn_secondary_bolt(secondary_points)
		all_visual_points.append_array(secondary_points)

	_spawn_branches(all_visual_points)

	var tween = create_tween().set_parallel(true)
	line.modulate.a = 1.0
	glow_line.modulate.a = 1.0
	tween.tween_property(line, "modulate:a", 0.0, bolt_duration)
	tween.tween_property(glow_line, "modulate:a", 0.0, bolt_duration)


func _spawn_secondary_bolt(points: Array) -> void:
	var jump_glow := Line2D.new()
	jump_glow.width = secondary_glow_width
	jump_glow.default_color = Color(0.15, 0.65, 1.0, 0.95)
	jump_glow.antialiased = true
	secondary_bolts.add_child(jump_glow)

	var jump_core := Line2D.new()
	jump_core.width = secondary_core_width
	jump_core.default_color = Color(0.88, 0.98, 1.0, 1.0)
	jump_core.antialiased = true
	secondary_bolts.add_child(jump_core)

	for point in points:
		jump_glow.add_point(point)
		jump_core.add_point(point)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(jump_glow, "modulate:a", 0.0, bolt_duration)
	tween.tween_property(jump_core, "modulate:a", 0.0, bolt_duration)

# Returns jagged points between start and end
func _jagged_points(start: Vector2, end: Vector2) -> Array:
	var result: Array = []
	var segments := 8          # more = finer jaggedness
	var jaggedness := 28.0     # bigger = wilder bolt
	var direction = (end - start)
	var normal = direction.orthogonal().normalized()
	result.append(start)
	for s in range(1, segments):
		var t = float(s) / segments
		var point_on_line = start.lerp(end, t)
		var offset = normal * randf_range(-jaggedness, jaggedness)
		result.append(point_on_line + offset)
	result.append(end)
	return result

# Grows forks from random points on the main bolt (each fork also has glow + core)
func _spawn_branches(main_points: Array) -> void:
	for b in range(branch_count):
		if main_points.size() < 2:
			return
		var idx = randi() % main_points.size()
		var start = main_points[idx]
		var angle = randf_range(0, TAU)
		var length = randf_range(branch_min_length, branch_max_length)
		var end = start + Vector2(cos(angle), sin(angle)) * length
		var fork_points = _jagged_points(start, end)

		# Glow layer for the fork
		var fork_glow = Line2D.new()
		fork_glow.width = 4.0
		fork_glow.default_color = glow_line.default_color
		branches.add_child(fork_glow)
		# Core layer for the fork
		var fork_core = Line2D.new()
		fork_core.width = 1.5
		fork_core.default_color = line.default_color
		branches.add_child(fork_core)

		for p in fork_points:
			fork_glow.add_point(p)
			fork_core.add_point(p)

		# Fade both fork layers
		var tw = create_tween().set_parallel(true)
		fork_glow.modulate.a = 0.8
		fork_core.modulate.a = 0.9
		tw.tween_property(fork_glow, "modulate:a", 0.0, 0.2)
		tw.tween_property(fork_core, "modulate:a", 0.0, 0.2)

func _clear_branches() -> void:
	for child in branches.get_children():
		child.queue_free()


func _clear_secondary_bolts() -> void:
	for child in secondary_bolts.get_children():
		child.queue_free()



# --- WeaponManager interface ---
var active: bool = true

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
