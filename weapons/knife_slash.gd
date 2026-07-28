# KnifeSlash.gd
extends Node2D

var damage: int = 10
var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var lifetime: float = 0.2  # short lunge — keeps it feeling melee-range, not thrown

@onready var hit_area: Area2D = $HitArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	sprite.play("attack")
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()  # disappears on first hit
