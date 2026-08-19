# gun.gd
extends Node2D

@export var damage: int = 15
@export var attack_cooldown: float = 0.6
@export var attack_range: float = 300.0   # much longer than knife
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
	if target != null:
		dir = (target.global_position - global_position).normalized()
	else:
		dir = player.last_direction.normalized()

	_spawn_bullet(dir)
	player.play_shoot_animation()

func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.damage = damage
	bullet.direction = dir
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position


var active: bool = true

func set_active(value: bool) -> void:
	active = value
	visible = value            # hide the weapon visual if it has one
	set_physics_process(value) # stop auto-attacking when inactive
