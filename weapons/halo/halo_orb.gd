# halo_orb.gd
extends Area2D
class_name HaloOrb

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")
const WEAPON_DAMAGE = preload("res://systems/weapon_damage.gd")

@export var damage: int = 15
@export var hit_cooldown: float = 0.5
@export var heat_flash_duration: float = 0.28
@export var heat_flash_color: Color = Color(1.0, 0.12, 0.03, 1.0)
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
	if not COMBAT_TARGET_SELECTOR.is_living_enemy(body):
		return
	if _recent_hits.has(body):
		return
	_play_heat_damage_effect(body)
	body.take_damage(WEAPON_DAMAGE.calculate(damage, self))
	_recent_hits[body] = hit_cooldown


# Repeated hits restart the same flash instead of stacking conflicting tweens.
# Metadata is stored on the enemy because any of the six rods may touch it.
func _play_heat_damage_effect(enemy: Node2D) -> void:
	var original_color: Color
	if enemy.has_meta(&"blaze_original_modulate"):
		original_color = enemy.get_meta(&"blaze_original_modulate") as Color
	else:
		original_color = enemy.modulate
		enemy.set_meta(&"blaze_original_modulate", original_color)

	var previous_tween: Variant = null
	if enemy.has_meta(&"blaze_heat_tween"):
		previous_tween = enemy.get_meta(&"blaze_heat_tween")
	if previous_tween is Tween and previous_tween.is_valid():
		previous_tween.kill()

	enemy.modulate = Color(
		heat_flash_color.r,
		heat_flash_color.g,
		heat_flash_color.b,
		original_color.a
	)
	var flash_tween := enemy.create_tween()
	enemy.set_meta(&"blaze_heat_tween", flash_tween)
	flash_tween.tween_property(
		enemy,
		"modulate",
		original_color,
		maxf(heat_flash_duration, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_spawn_heat_ring(enemy.global_position)


func _spawn_heat_ring(world_position: Vector2) -> void:
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_tree().root

	var heat_ring := Line2D.new()
	heat_ring.name = "BlazeHeatRing"
	heat_ring.width = 3.0
	heat_ring.default_color = Color(1.0, 0.16, 0.02, 0.9)
	heat_ring.closed = true
	heat_ring.antialiased = true
	heat_ring.z_index = 120
	for segment in range(20):
		var ring_angle := TAU * float(segment) / 20.0
		heat_ring.add_point(Vector2.from_angle(ring_angle) * 12.0)

	effect_parent.add_child(heat_ring)
	heat_ring.global_position = world_position
	var ring_tween := heat_ring.create_tween().set_parallel(true)
	ring_tween.tween_property(heat_ring, "scale", Vector2.ONE * 2.3, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(heat_ring, "modulate:a", 0.0, 0.24)
	ring_tween.chain().tween_callback(heat_ring.queue_free)
