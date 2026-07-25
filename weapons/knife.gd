extends Node2D

@export var damage: int = 10
@export var fire_interval: float = 1.0
@export var swing_duration: float = 0.15

@onready var hit_area: Area2D = $HitArea
@onready var collision_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var fire_timer: Timer = $FireTimer

var enemies_hit: Array = []

func _ready() -> void:
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	hit_area.body_entered.connect(_on_body_entered)
	collision_shape.disabled = true

func _on_fire_timer_timeout() -> void:
	_swing()

func _swing() -> void:
	enemies_hit.clear()
	collision_shape.disabled = false
	# optional: play a swing animation here if KnifeSprite is an AnimatedSprite2D
	await get_tree().create_timer(swing_duration).timeout
	collision_shape.disabled = true

func _on_body_entered(body: Node2D) -> void:
	if body in enemies_hit:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		enemies_hit.append(body)
