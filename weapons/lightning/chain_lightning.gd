# chain_lightning.gd
extends Node2D

@export var damage: int = 8
@export var attack_cooldown: float = 1.2
@export var attack_range: float = 250.0   # range to find the FIRST target
@export var jump_range: float = 150.0     # max distance between chain jumps
@export var max_jumps: int = 3            # how many enemies the bolt hits

# --- branch (fork) settings ---
@export var branch_count: int = 4         # how many random forks per zap
@export var branch_min_length: float = 20.0
@export var branch_max_length: float = 50.0

var cooldown_left: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var line: Line2D = $Line2D
@onready var glow_line: Line2D = $GlowLine
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

# --- THE CHAINING ALGORITHM ---
func do_attack(first_target: Node2D) -> void:
	cooldown_left = attack_cooldown

	var hit_chain: Array = []        # enemies already zapped this cast
	var current = first_target
	var points: Array = [global_position]   # start the bolt at the player

	while current != null and hit_chain.size() < max_jumps:
		current.take_damage(damage)
		hit_chain.append(current)
		points.append(current.global_position)
		# find the next nearest enemy NOT already hit, within jump_range
		current = _find_nearest_enemy(current.global_position, jump_range, hit_chain)

	_draw_bolt(points)
	if player.has_method("play_shoot_animation"):
		player.play_shoot_animation()

# Finds the closest enemy to `from`, within `max_dist`, excluding `exclude`
func _find_nearest_enemy(from: Vector2, max_dist: float, exclude: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := max_dist
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in exclude:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var dist = from.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

# --- Draw the main bolt plus random forks, then fade out ---
func _draw_bolt(points: Array) -> void:
	line.clear_points()
	glow_line.clear_points()
	_clear_branches()

	# Build the jagged main path once, share it between glow and core
	var all_main_points: Array = []
	for i in range(points.size() - 1):
		var start = to_local(points[i])
		var end = to_local(points[i + 1])
		var seg_points = _jagged_points(start, end)
		for p in seg_points:
			all_main_points.append(p)

	# Feed the same points to both the glow layer and the white core
	for p in all_main_points:
		glow_line.add_point(p)
		line.add_point(p)

	# Grow forks off the main bolt
	_spawn_branches(all_main_points)

	# Fade both layers out
	var tween = create_tween().set_parallel(true)
	line.modulate.a = 1.0
	glow_line.modulate.a = 1.0
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_property(glow_line, "modulate:a", 0.0, 0.25)

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



# --- WeaponManager interface ---
var active: bool = true

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
