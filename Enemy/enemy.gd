#enemy.gd
extends CharacterBody2D

# movement
@export var speed: float = 60.0
@export var chase_speed: float = 180.0
@export var wander_radius: float = 200.0
@export var attack_range: float = 150.0
@export var attack_cooldown: float = 0.8
@export var damage: int = 2

# health
@export var max_health: int = 100
var current_health: int

# XP drop on death
@export var xp_drop: int = 15
const XP_ORB_SCENE = preload("res://XPOrb/XPOrb.tscn")

#smooth movement
@export var acceleration: float = 600.0
@export var friction: float = 400.0
@export var rotation_speed: float = 6.0

# detect
@export var detection_radius: float = 400.0

# animation
@export var walk_speed_scale: float = 1.0
@export var attack_speed_scale: float = 2.5

@onready var animated_sprite = $AnimatedSprite2D
@onready var vision_area = $VisionArea
@onready var health_bar = $HealthBar

# player reference
var player: Node2D = null

# wander
var home_position: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0

# state
enum State { WANDER, CHASE, ATTACK }
var current_state = State.WANDER

# direction
var facing_direction: int = 1
var current_direction: Vector2 = Vector2.ZERO

var can_attack: bool = true
var attack_timer: float = 0.0
var has_dealt_damage: bool = false
var attack_target_position: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var attack_duration: float = 0.0
var damage_frame: int = 2
var attack_started: bool = false

func _ready():
	add_to_group("enemy")
	home_position = global_position
	
	# FORCE CENTER THE ENEMY (Godot Editor was wiping out my scene file changes!)
	if has_node("AnimatedSprite2D"): $AnimatedSprite2D.position = Vector2.ZERO
	if has_node("CollisionShape2D"): $CollisionShape2D.position = Vector2.ZERO
	if has_node("VisionArea/CollisionShape2D"): $"VisionArea/CollisionShape2D".position = Vector2.ZERO
	if has_node("AttackArea/CollisionShape2D"): $"AttackArea/CollisionShape2D".position = Vector2.ZERO

	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false
		health_bar.position = Vector2(-32, -68) # Center health bar above head
		
	# Force set the attack area radius so it matches
	var attack_area = get_node_or_null("AttackArea")
	if attack_area != null:
		var shape_node = attack_area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is CircleShape2D:
			shape_node.shape = shape_node.shape.duplicate()
			shape_node.shape.radius = attack_range
			
	# Give the physical body a shape if it's missing
	if has_node("CollisionShape2D"):
		var shape_node = $CollisionShape2D
		if shape_node.shape == null:
			var c = CircleShape2D.new()
			c.radius = 30.0
			shape_node.shape = c

	# Find player
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if player == null:
		print("ERROR: Player not found! Add 'Player' group to player.")

	if vision_area != null:
		var shape_node = vision_area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is CircleShape2D:
			shape_node.shape = shape_node.shape.duplicate()
			shape_node.shape.radius = detection_radius

		vision_area.body_entered.connect(_on_vision_area_body_entered)
		vision_area.body_exited.connect(_on_vision_area_body_exited)

	pick_new_wander_target()
	animated_sprite.play("walk")
	animated_sprite.speed_scale = walk_speed_scale

func _physics_process(delta):
	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# Handle the current state
	match current_state:
		State.WANDER:
			_wander_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)

	move_and_slide()

# Wander
func _wander_state(delta):
	var distance_to_target = global_position.distance_to(wander_target)
	var target_velocity = Vector2.ZERO

	if distance_to_target < 10.0:
		if wander_timer > 0:
			wander_timer -= delta
			if wander_timer <= 0:
				pick_new_wander_target()
		else:
			pick_new_wander_target()
	else:
		var direction = (wander_target - global_position).normalized()
		target_velocity = direction * speed
		_update_facing(direction.x)

	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	if velocity.length() > 5.0:
		_update_facing(velocity.x)

	if velocity.length() < 5.0:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
	else:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	
	if health_bar:
		health_bar.visible = false

# Chase
func _chase_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player <= attack_range and can_attack:
		velocity = Vector2.ZERO
		is_attacking = false
		has_dealt_damage = false
		attack_started = false
		current_state = State.ATTACK
		return

	var direction_to_player = (player.global_position - global_position).normalized()
	
	var target_velocity = direction_to_player * chase_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	if velocity.length() > 5.0:
		_update_facing(velocity.x)

	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")
	
	animated_sprite.speed_scale = walk_speed_scale
	
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

# Attack
func _attack_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	if not is_attacking:
		is_attacking = true
		attack_duration = 0.0
		has_dealt_damage = false
		attack_started = true

		velocity = Vector2.ZERO
		attack_target_position = player.global_position

		var direction_to_target = (attack_target_position - global_position).normalized()
		
		if direction_to_target.x > 0:
			animated_sprite.flip_h = false
			facing_direction = 1
		elif direction_to_target.x < 0:
			animated_sprite.flip_h = true
			facing_direction = -1
		else:
			if facing_direction == 1:
				animated_sprite.flip_h = false
			else:
				animated_sprite.flip_h = true

		animated_sprite.speed_scale = attack_speed_scale
		animated_sprite.play("attack")
		animated_sprite.frame = 0
		return

	attack_duration += delta
	velocity = Vector2.ZERO

	var current_frame = animated_sprite.frame

	if not has_dealt_damage and current_frame >= damage_frame:
		_deal_damage()
		has_dealt_damage = true

	var animation_done = not animated_sprite.is_playing() and animated_sprite.animation == "attack"
	
	var sprite_frames = animated_sprite.sprite_frames
	var frame_count = 1
	if sprite_frames != null and sprite_frames.has_animation("attack"):
		frame_count = sprite_frames.get_frame_count("attack")
	var reached_last_frame = current_frame >= frame_count - 1

	if animation_done or reached_last_frame:
		is_attacking = false
		can_attack = false
		attack_timer = attack_cooldown
		
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_range:
			current_state = State.ATTACK
		else:
			current_state = State.CHASE

		animated_sprite.speed_scale = walk_speed_scale
		animated_sprite.play("walk")

# --- TAKE DAMAGE FUNCTION ---
func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(0, current_health)
	
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = true
	
	# Flash red when hit
	animated_sprite.modulate = Color(1, 0.3, 0.3, 1)
	await get_tree().create_timer(0.15).timeout
	animated_sprite.modulate = Color(1, 1, 1, 1)
	
	if current_health <= 0:
		die()

# Death
func die() -> void:
	if health_bar:
		health_bar.visible = false
		
	# Only drop the XP orb if this is the last enemy alive
	if get_tree().get_nodes_in_group("enemy").size() <= 1:
		var orb = XP_ORB_SCENE.instantiate()
		orb.xp_value = xp_drop
		orb.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", orb)
		
	queue_free()

func pick_new_wander_target():
	var random_angle = randf_range(0, PI * 2)
	var random_distance = randf_range(0, wander_radius)
	var random_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	wander_target = home_position + random_offset

	if randf() < 0.2:
		wander_timer = randf_range(0.3, 0.8)
	else:
		wander_timer = 0.0

func _update_facing(direction_x: float):
	var threshold = 1.0

	if direction_x > threshold:
		if facing_direction != 1:
			facing_direction = 1
			animated_sprite.flip_h = false
	elif direction_x < -threshold:
		if facing_direction != -1:
			facing_direction = -1
			animated_sprite.flip_h = true

func _deal_damage():
	if player != null and player.has_method("take_damage"):
		var current_distance = global_position.distance_to(player.global_position)
		if current_distance <= attack_range * 2.0:
			player.take_damage(damage)

func _on_vision_area_body_entered(body):
	if body == player:
		current_state = State.CHASE

func _on_vision_area_body_exited(body):
	if body == player:
		current_state = State.WANDER
		pick_new_wander_target()
