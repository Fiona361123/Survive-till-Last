# Knife.gd
extends Node2D

@export var damage: int = 10
@export var attack_cooldown: float = 0.8
@export var attack_range: float = 120.0   # how near an enemy must be to trigger a swing
@export var knife_slash_scene: PackedScene

var cooldown_left: float = 0.0

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
		# slash toward the enemy that triggered the attack
		dir = (target.global_position - global_position).normalized()
	else:
		# fallback (e.g. future button press with no enemy near): use facing
		dir = get_parent().last_direction.normalized()

	_spawn_projectile(dir)
	get_parent().play_attack_animation()

func _spawn_projectile(dir: Vector2) -> void:
	var slash = knife_slash_scene.instantiate()
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position
	slash.damage = damage
	slash.direction = dir
