# Knife.gd
extends Node2D

@export var damage: int = 10
@export var attack_cooldown: float = 0.4
@export var knife_slash_scene: PackedScene

var cooldown_left: float = 0.0

func _ready() -> void:
	add_to_group("weapon")

func _physics_process(delta: float) -> void:
	cooldown_left -= delta
	if Input.is_action_just_pressed("Attack"):
		do_attack()

func do_attack() -> void:
	if cooldown_left > 0.0:
		return
	cooldown_left = attack_cooldown
	_spawn_projectile()
	get_parent().play_attack_animation()

func _spawn_projectile() -> void:
	var slash = knife_slash_scene.instantiate()
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position
	slash.damage = damage
	slash.direction = get_parent().last_input_vector.normalized()
