# KnifeSlash.gd
extends Node2D

var damage: int = 300
var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var lifetime: float = 0.2  # short lunge — keeps it feeling melee-range, not thrown

@onready var hit_area: Area2D = $HitArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	hit_area.area_entered.connect(_on_area_entered)
	
	# FORCE VISUAL FIXES (bypasses Godot editor wiping out .tscn changes)
	sprite.scale = Vector2(0.4, 0.4)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	
	# Force radius fix
	if hit_area.has_node("CollisionShape2D"):
		var shape_node = hit_area.get_node("CollisionShape2D")
		if shape_node.shape == null:
			shape_node.shape = CircleShape2D.new()
		shape_node.shape.radius = 80.0
	
	# Offset the stationary slash in front of the player
	global_position += direction * 100.0
	
	# Flip sprite if attacking left
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
		
	sprite.play("attack")
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

var hit_enemies: Array = []

func _on_body_entered(body: Node2D) -> void:
	print("[Knife] body_entered: ", body.name, ", groups: ", body.get_groups())
	if body in hit_enemies: return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		print("[Knife] HIT ENEMY BODY!")
		body.take_damage(damage)
		hit_enemies.append(body)

func _on_area_entered(area: Area2D) -> void:
	print("[Knife] area_entered: ", area.name, ", parent: ", area.get_parent().name if area.get_parent() else "none")
	if "AttackArea" not in area.name: return
	
	var parent = area.get_parent()
	if parent in hit_enemies: return
	if parent != null and parent.is_in_group("enemy") and parent.has_method("take_damage"):
		print("[Knife] HIT ENEMY AREA!")
		parent.take_damage(damage)
		hit_enemies.append(parent)
