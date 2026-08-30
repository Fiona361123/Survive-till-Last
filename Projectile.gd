extends Area2D

# PROJECTILE VARIABLES
@export var speed: float = 400.0
@export var damage: int = 1
@export var hit_frame: int = 2
@export var animation_name: String = "fly"

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 3.0
var hit_effect_scene: PackedScene
var has_hit: bool = false

# NODE REFERENCES
@onready var animated_sprite = $AnimatedSprite2D


func _ready():
	# Check if sprite exists
	if animated_sprite == null:
		print("AnimatedSprite2D not found!")
		return
	
	# Rotate to face direction of travel
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Play flying animation
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		animated_sprite.play()
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	await get_tree().create_timer(lifetime).timeout
	if not has_hit:
		queue_free()


func _physics_process(delta):
	# Move forward
	position += direction * speed * delta
	
	# Keep facing direction
	if direction != Vector2.ZERO:
		rotation = direction.angle()


# COLLISION
func _on_body_entered(body):
	if has_hit:
		return
	
	has_hit = true
	
	# Hit either the real player or a Temporal Echo decoy. Both expose the same
	# take_damage interface, but the decoy absorbs the attack without forwarding
	# it to the player's HP.
	if (body.is_in_group("player") or body.is_in_group("temporal_decoy")) \
			and body.has_method("take_damage"):
		body.take_damage(damage)
		_create_hit_effect(global_position)
		queue_free()
		return
	
	# Hit wall
	if body is TileMapLayer or body is StaticBody2D:
		_create_hit_effect(global_position)
		queue_free()


# HIT EFFECT - spawns explosion/impact effect
func _create_hit_effect(pos: Vector2):
	if hit_effect_scene == null:
		return
	
	var effect = hit_effect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = pos


# Set hit effect from enemy
func set_hit_effect(effect: PackedScene):
	hit_effect_scene = effect
