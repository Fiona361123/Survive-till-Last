extends Node2D
class_name PrismLatticeWeapon

signal field_created(field: PrismField)
signal activation_failed(reason: String)

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

@export var attack_cooldown: float = 8.0
@export var cast_range: float = 450.0
@export var cluster_radius: float = 220.0
@export var deployment_radius: float = 130.0
@export var deployment_duration: float = 0.5
@export var field_duration: float = 6.0
@export var warning_duration: float = 0.65
@export var collapse_duration: float = 0.45
@export var interior_damage: int = 10
@export var beam_damage: int = 6
@export var collapse_min_damage: int = 35
@export var collapse_max_damage: int = 60
@export var prism_field_scene: PackedScene

var cooldown_left: float = 0.0
var active: bool = true
var active_field: PrismField = null
var player: Node2D = null


func _ready() -> void:
	add_to_group("weapon")
	player = _find_player()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)


func trigger_attack() -> void:
	if not active:
		activation_failed.emit("PRISM LATTICE IS NOT ACTIVE")
		return
	if cooldown_left > 0.0:
		activation_failed.emit("PRISM LATTICE IS RECHARGING")
		return
	if is_instance_valid(active_field):
		activation_failed.emit("A PRISM FIELD IS ALREADY ACTIVE")
		return
	if prism_field_scene == null:
		activation_failed.emit("PRISM FIELD SCENE IS MISSING")
		return
	if not is_instance_valid(player):
		player = _find_player()
	if player == null:
		activation_failed.emit("PLAYER NOT FOUND")
		return

	var cluster := _find_best_cluster()
	if cluster.is_empty():
		activation_failed.emit("NO ENEMY CLUSTER IN RANGE")
		return

	var field := prism_field_scene.instantiate() as PrismField
	if field == null:
		activation_failed.emit("PRISM FIELD SCENE IS INVALID")
		return
	var scene_tree := get_tree()
	var spawn_parent: Node = scene_tree.current_scene
	if spawn_parent == null:
		spawn_parent = scene_tree.root
	spawn_parent.add_child(field)
	field.global_position = Vector2.ZERO
	active_field = field
	field.field_finished.connect(_on_field_finished.bind(field))
	field.begin_field(player.global_position, cluster["center"], {
		"deployment_radius": deployment_radius,
		"deployment_duration": deployment_duration,
		"field_duration": field_duration,
		"warning_duration": warning_duration,
		"collapse_duration": collapse_duration,
		"interior_damage": interior_damage,
		"beam_damage": beam_damage,
		"collapse_min_damage": collapse_min_damage,
		"collapse_max_damage": collapse_max_damage,
	})
	cooldown_left = attack_cooldown
	field_created.emit(field)


func _find_best_cluster() -> Dictionary:
	if not is_instance_valid(player):
		player = _find_player()
	if player == null:
		return {}

	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= cast_range:
			candidates.append(enemy)
	if candidates.is_empty():
		return {}

	var best_score := -1
	var best_distance := INF
	var best_center := Vector2.ZERO
	var best_target: Node2D = null
	for candidate in candidates:
		var nearby_count := 0
		var position_sum := Vector2.ZERO
		for other in candidates:
			if candidate.global_position.distance_to(other.global_position) <= cluster_radius:
				nearby_count += 1
				position_sum += other.global_position
		var distance_to_player := player.global_position.distance_squared_to(candidate.global_position)
		if nearby_count > best_score or (nearby_count == best_score and distance_to_player < best_distance):
			best_score = nearby_count
			best_distance = distance_to_player
			best_center = position_sum / float(maxi(nearby_count, 1))
			best_target = candidate

	return {
		"target": best_target,
		"center": best_center,
		"score": best_score,
	}


func _find_player() -> Node2D:
	var grouped_player := get_tree().get_first_node_in_group("player") as Node2D
	if grouped_player != null:
		return grouped_player
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Node2D and ("current_hp" in ancestor or "last_direction" in ancestor):
			return ancestor as Node2D
		ancestor = ancestor.get_parent()
	return null


func _on_field_finished(field: PrismField) -> void:
	if active_field == field:
		active_field = null


func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
