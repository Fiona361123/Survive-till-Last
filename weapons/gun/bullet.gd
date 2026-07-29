# bullet.gd
extends Node2D

var damage: int = 15
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var lifetime: float = 1.5   # flies far, unlike the knife lunge

@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	rotation = direction.angle()   # point the sprite along flight direction
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
