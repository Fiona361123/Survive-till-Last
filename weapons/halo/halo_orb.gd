# halo_orb.gd
extends Area2D
class_name HaloOrb

var damage: int = 5
var hit_cooldown: float = 0.5
var damage_enabled: bool = true

var _recent_hits: Dictionary = {}

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func set_damage_enabled(value: bool) -> void:
	damage_enabled = value
	visible = value
	set_process(value)

	# Physics-query properties are deferred so this remains safe even when the
	# Halo breaks during a collision callback.
	set_deferred("monitoring", value)
	set_deferred("monitorable", value)
	if collision_shape:
		collision_shape.set_deferred("disabled", not value)

	if not value:
		_recent_hits.clear()

func _process(delta: float) -> void:
	if not damage_enabled:
		return

	# tick down each enemy's cooldown
	for enemy in _recent_hits.keys():
		_recent_hits[enemy] -= delta
		if _recent_hits[enemy] <= 0.0:
			_recent_hits.erase(enemy)

	# check everything currently overlapping this orb
	for body in get_overlapping_bodies():
		_try_damage(body)

func _try_damage(body: Node2D) -> void:
	if not damage_enabled:
		return
	if not body.is_in_group("enemy"):
		return
	if not body.has_method("take_damage"):
		return
	if _recent_hits.has(body):
		return
	body.take_damage(damage)
	_recent_hits[body] = hit_cooldown
