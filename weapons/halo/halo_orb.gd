# halo_orb.gd
extends Area2D

var damage: int = 5
var hit_cooldown: float = 0.5

var _recent_hits: Dictionary = {}

func _process(delta: float) -> void:
	# tick down each enemy's cooldown
	for enemy in _recent_hits.keys():
		_recent_hits[enemy] -= delta
		if _recent_hits[enemy] <= 0.0:
			_recent_hits.erase(enemy)

	# check everything currently overlapping this orb
	for body in get_overlapping_bodies():
		_try_damage(body)

func _try_damage(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return
	if not body.has_method("take_damage"):
		return
	if _recent_hits.has(body):
		return
	body.take_damage(damage)
	_recent_hits[body] = hit_cooldown
