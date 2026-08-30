extends Node2D

var damage_received: int = 0


func take_damage(amount: int) -> void:
	damage_received += amount
