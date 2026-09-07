class_name Level1Bomb
extends Node2D

@export var blast_damage: int = 25

@onready var blast_area: TrapDamageArea = $BlastArea

var _exploded: bool = false


# Huang Wan Jun 2204536 - Let player weapons activate the barrel through the same damage interface used by enemies.
func take_damage(_amount: int) -> void:
	if _exploded:
		return
	_exploded = true
	_explode()


# Huang Wan Jun 2204536 - Damage every player or enemy body inside the blast once, then remove the spent barrel.
func _explode() -> void:
	blast_area.begin_activation(blast_damage)
	await get_tree().physics_frame
	blast_area.damage_overlapping_bodies()
	blast_area.end_activation()
	queue_free()
