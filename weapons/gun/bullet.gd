# bullet.gd
extends Node2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

var damage: int = 100
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var lifetime: float = 1.5   # flies far, unlike the knife lunge

@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	hit_area.area_entered.connect(_on_area_entered)
	
	# Force radius fix
	if hit_area.has_node("CollisionShape2D"):
		var shape_node = hit_area.get_node("CollisionShape2D")
		if shape_node.shape == null:
			shape_node.shape = CircleShape2D.new()
		shape_node.shape.radius = 15.0
		
	rotation = direction.angle()   # point the sprite along flight direction
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

var hit_enemies: Array = []

func _on_body_entered(body: Node2D) -> void:
	if body in hit_enemies: return
	if COMBAT_TARGET_SELECTOR.is_living_enemy(body):
		body.take_damage(damage)
		hit_enemies.append(body)

func _on_area_entered(area: Area2D) -> void:
	if "AttackArea" not in area.name: return
	
	var parent = area.get_parent()
	if parent in hit_enemies: return
	if parent != null and COMBAT_TARGET_SELECTOR.is_living_enemy(parent):
		parent.take_damage(damage)
		hit_enemies.append(parent)
