extends Node2D
class_name PrismLatticeWeapon

signal field_created(field: PrismField)
signal activation_failed(reason: String)

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

@export var attack_cooldown: float = 8.0
@export var cast_range: float = 620.0
@export var projectile_speed: float = 390.0
@export var homing_acceleration: float = 1050.0
@export var maximum_seek_time: float = 3.0
@export var capture_distance: float = 28.0
@export var trap_radius: float = 105.0
@export var trap_duration: float = 4.0
@export var trap_pull_strength: float = 340.0
@export var damage_interval: float = 0.45
@export var damage_per_tick: int = 35
@export var collapse_duration: float = 0.4
@export var explosion_radius: float = 145.0
@export var explosion_damage: int = 60
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


# Weapon 7 is manual: pressing key 7 throws one autonomous prism. It may be
# launched without a target and will acquire the first valid enemy it finds.
func trigger_attack() -> void:
	if not active:
		activation_failed.emit("PRISM SNARE IS NOT ACTIVE")
		return
	if cooldown_left > 0.0:
		activation_failed.emit("PRISM SNARE IS RECHARGING")
		return
	if is_instance_valid(active_field):
		activation_failed.emit("A PRISM SNARE IS ALREADY ACTIVE")
		return
	if prism_field_scene == null:
		activation_failed.emit("PRISM SNARE SCENE IS MISSING")
		return
	if not is_instance_valid(player):
		player = _find_player()
	if player == null:
		activation_failed.emit("PLAYER NOT FOUND")
		return

	var initial_target := _find_nearest_enemy(player.global_position, cast_range)
	var field := prism_field_scene.instantiate() as PrismField
	if field == null:
		activation_failed.emit("PRISM SNARE SCENE IS INVALID")
		return

	var scene_tree := get_tree()
	var spawn_parent: Node = scene_tree.current_scene
	if spawn_parent == null:
		spawn_parent = scene_tree.root
	spawn_parent.add_child(field)
	active_field = field
	field.field_finished.connect(_on_field_finished.bind(field))
	field.begin_hunt(
		player.global_position,
		initial_target,
		_get_launch_direction(initial_target),
		{
			"acquisition_range": cast_range,
			"projectile_speed": projectile_speed,
			"homing_acceleration": homing_acceleration,
			"maximum_seek_time": maximum_seek_time,
			"capture_distance": capture_distance,
			"trap_radius": trap_radius,
			"trap_duration": trap_duration,
			"trap_pull_strength": trap_pull_strength,
			"damage_interval": damage_interval,
			"damage_per_tick": damage_per_tick,
			"collapse_duration": collapse_duration,
			"explosion_radius": explosion_radius,
			"explosion_damage": explosion_damage,
		}
	)
	cooldown_left = attack_cooldown
	field_created.emit(field)


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


func _get_launch_direction(initial_target: Node2D) -> Vector2:
	if is_instance_valid(initial_target):
		var target_direction := player.global_position.direction_to(initial_target.global_position)
		if target_direction != Vector2.ZERO:
			return target_direction
	if "last_direction" in player:
		var facing := player.get("last_direction") as Vector2
		if facing != Vector2.ZERO:
			return facing.normalized()
	return Vector2.RIGHT


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
