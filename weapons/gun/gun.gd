# gun.gd
extends Node2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

@export var damage: int = 30
@export var attack_cooldown: float = 0.6
@export var attack_range: float = 300.0   # much longer than knife
@export var bullet_speed: float = 400.0
@export_range(0.0, 1.0, 0.05) var prediction_strength: float = 0.8
@export var maximum_prediction_time: float = 0.65
@export var bullet_scene: PackedScene

var cooldown_left: float = 0.0
@onready var player = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	add_to_group("weapon")

func _physics_process(delta: float) -> void:
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	var target = _find_nearest_enemy_in_range()
	if target != null:
		do_attack(target)

func _find_nearest_enemy_in_range() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := attack_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not COMBAT_TARGET_SELECTOR.is_living_enemy(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func do_attack(target: Node2D = null) -> void:
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_cooldown

	var dir: Vector2
	if is_instance_valid(target):
		dir = (_predict_target_position(target) - global_position).normalized()
	elif player != null and "last_direction" in player:
		dir = player.last_direction.normalized()
	else:
		dir = Vector2.RIGHT

	_spawn_bullet(dir, target)
	if player != null and player.has_method("play_shoot_animation"):
		player.play_shoot_animation()


func _predict_target_position(target: Node2D) -> Vector2:
	var aim_position := _get_target_aim_position(target)
	if target is CharacterBody2D:
		var travel_time := minf(
			global_position.distance_to(aim_position) / maxf(bullet_speed, 1.0),
			maximum_prediction_time
		)
		aim_position += target.velocity * travel_time * prediction_strength
	return aim_position


func _get_target_aim_position(target: Node2D) -> Vector2:
	var body_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null and not body_shape.disabled:
		return body_shape.global_position
	return target.global_position


func _spawn_bullet(dir: Vector2, target: Node2D = null) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	bullet.damage = damage
	bullet.direction = dir.normalized()
	bullet.speed = bullet_speed
	bullet.target = target
	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	spawn_parent.add_child(bullet)
	bullet.global_position = global_position


var active: bool = true

func set_active(value: bool) -> void:
	active = value
	visible = value            # hide the weapon visual if it has one
	set_physics_process(value) # stop auto-attacking when inactive
