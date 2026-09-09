# bullet.gd
extends Node2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")
const WEAPON_DAMAGE = preload("res://systems/weapon_damage.gd")

var damage: int = 100
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var lifetime: float = 1.5   # flies far, unlike the knife lunge
var target: Node2D = null
var homing_turn_speed: float = 2.8
var homing_duration: float = 0.32
var homing_stop_distance: float = 52.0
var homing_time_left: float = 0.0

@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	hit_area.area_entered.connect(_on_area_entered)
	homing_time_left = homing_duration
	
	# Keep a safe fallback for bullets instantiated without the scene shape.
	if hit_area.has_node("CollisionShape2D"):
		var shape_node := hit_area.get_node("CollisionShape2D") as CollisionShape2D
		if shape_node.shape == null:
			shape_node.shape = CircleShape2D.new()
			shape_node.shape.radius = 8.0
		
	rotation = direction.angle()   # point the sprite along flight direction
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# Prediction supplies the main trajectory. Homing only makes a small early
	# correction; it switches off near the target or after an overshoot so a
	# bullet can never loop around and fly backwards.
	homing_time_left = maxf(0.0, homing_time_left - delta)
	if homing_time_left > 0.0 and is_instance_valid(target) \
			and COMBAT_TARGET_SELECTOR.is_living_enemy(target):
		var aim_position := _get_target_aim_position(target)
		var to_target := aim_position - global_position
		var desired_direction := to_target.normalized()
		var target_is_ahead := direction.dot(desired_direction) > 0.2
		if to_target.length() <= homing_stop_distance or not target_is_ahead:
			target = null
			homing_time_left = 0.0
		elif desired_direction != Vector2.ZERO:
			var turn_amount := clampf(
				direction.angle_to(desired_direction),
				-homing_turn_speed * delta,
				homing_turn_speed * delta
			)
			direction = direction.rotated(turn_amount).normalized()
			rotation = direction.angle()
	global_position += direction * speed * delta


func _get_target_aim_position(enemy: Node2D) -> Vector2:
	var body_shape := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null and not body_shape.disabled:
		return body_shape.global_position
	return enemy.global_position

var hit_enemies: Array = []

func _on_body_entered(body: Node2D) -> void:
	if body in hit_enemies: return
	if COMBAT_TARGET_SELECTOR.is_living_enemy(body):
		body.take_damage(WEAPON_DAMAGE.calculate(damage, self))
		hit_enemies.append(body)

func _on_area_entered(area: Area2D) -> void:
	if "AttackArea" not in area.name: return
	
	var parent = area.get_parent()
	if parent in hit_enemies: return
	if parent != null and COMBAT_TARGET_SELECTOR.is_living_enemy(parent):
		parent.take_damage(WEAPON_DAMAGE.calculate(damage, self))
		hit_enemies.append(parent)
