class_name TrapDamageArea
extends Area2D

## Shared damage query used by Level 3 action traps.
## Collision layers 2 and 4 are the player and enemy layers respectively.
var activation_damage: int = 0
var damaged_bodies: Dictionary = {}


func _init() -> void:
	collision_layer = 0
	collision_mask = 6
	monitoring = false


func begin_activation(damage: int) -> void:
	activation_damage = maxi(damage, 0)
	damaged_bodies.clear()
	monitoring = true


func end_activation() -> void:
	monitoring = false
	damaged_bodies.clear()


func damage_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		if damaged_bodies.has(body):
			continue
		if not body.has_method("take_damage"):
			continue
		damaged_bodies[body] = true
		body.take_damage(activation_damage)
