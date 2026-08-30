extends Node2D

@export var damage: int = 50
@export var attack_cooldown: float = 3.4
@export var attack_range: float = 400.0
@export var bomb_scene: PackedScene

var cooldown_left: float = 0.0
var active: bool = true
@onready var player = get_tree().get_first_node_in_group("player")


func _ready() -> void:
	add_to_group("weapon")


func _physics_process(delta: float) -> void:
	cooldown_left -= delta


# Gravity Bomb is manual: WeaponManager calls this only when key 5 is pressed.
func trigger_attack() -> void:
	if not active or cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy_in_range()
	if target != null:
		do_attack(target)


func _find_nearest_enemy_in_range() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := attack_range
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func do_attack(target: Node2D = null) -> void:
	if cooldown_left > 0.0 or bomb_scene == null:
		return

	cooldown_left = attack_cooldown
	var target_position := global_position + Vector2.RIGHT * attack_range
	if target != null:
		target_position = target.global_position
	elif player != null and "last_direction" in player:
		target_position = global_position + player.last_direction.normalized() * attack_range

	var bomb := bomb_scene.instantiate() as Node2D
	if bomb == null:
		return
	var scene_tree := get_tree()
	var spawn_parent: Node = scene_tree.current_scene
	if spawn_parent == null:
		spawn_parent = scene_tree.root
	spawn_parent.add_child(bomb)
	bomb.call("launch", global_position, target_position, damage, target)


func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
