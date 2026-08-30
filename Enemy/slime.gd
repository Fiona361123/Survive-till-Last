extends CharacterBody2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

# MOVEMENT
@export var speed: float = 60.0
@export var chase_speed: float = 180.0
@export var wander_radius: float = 200.0
@export var attack_range: float = 55.0
@export var attack_cooldown: float = 0.8
@export var damage: int = 8

# HEALTH
@export var max_health: int = 100
var current_health: int

# XP drop on death
@export var xp_drop: int = 10
const XP_ORB_SCENE = preload("res://enemyXP.tscn")

# SMOOTH MOVEMENT
@export var acceleration: float = 600.0
@export var friction: float = 400.0
@export var rotation_speed: float = 6.0

# DETECTION
@export var detection_radius: float = 400.0

# ANIMATION
@export var walk_speed_scale: float = 1.0
@export var attack_speed_scale: float = 2.5

# SEPARATION - Prevents overlapping
@export var separation_radius: float = 60.0
@export var separation_force: float = 200.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var vision_area = $VisionArea
@onready var health_bar = $HealthBar

# PLAYER REFERENCE
var player: Node2D = null
var real_player: Node2D = null
var target_refresh_timer: float = 0.0
const TARGET_REFRESH_INTERVAL: float = 0.1

# WANDER
var home_position: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0

# STATE
enum State { WANDER, CHASE, ATTACK, DEATH }
var current_state = State.WANDER

# DIRECTION
var facing_direction: int = 1

# ATTACK VARIABLES
var can_attack: bool = true
var attack_timer: float = 0.0
var has_dealt_damage: bool = false
var attack_target_position: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var attack_duration: float = 0.0
var damage_frame: int = 2
var attack_started: bool = false

# RANDOM VARIATION
var random_offset: Vector2 = Vector2.ZERO
var zigzag_timer: float = 0.0
var zigzag_direction: float = 1.0
var time_alive: float = 0.0
var speed_variation: float = 0.0


func _ready():
	add_to_group("enemy")
	home_position = global_position

	current_health = max_health
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false

	player = get_tree().get_first_node_in_group("player")
	if player == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	if player == null:
		print("ERROR: Player not found!")
	real_player = player

	if vision_area != null:
		var shape_node = vision_area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is CircleShape2D:
			shape_node.shape = shape_node.shape.duplicate()
			shape_node.shape.radius = detection_radius

		vision_area.body_entered.connect(_on_vision_area_body_entered)
		vision_area.body_exited.connect(_on_vision_area_body_exited)

	# Randomize movement slightly so slimes don't all move identically
	random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	zigzag_timer = randf_range(0, 3.0)
	zigzag_direction = 1.0 if randf() > 0.5 else -1.0
	speed_variation = randf_range(1.0 - 0.15, 1.0 + 0.15)  # ±15% speed variation

	pick_new_wander_target()
	animated_sprite.play("walk")
	animated_sprite.speed_scale = walk_speed_scale


func _physics_process(delta):
	_refresh_combat_target(delta)
	time_alive += delta
	
	# Update zigzag
	zigzag_timer += delta
	if zigzag_timer > 3.0:
		zigzag_timer = 0
		zigzag_direction = -zigzag_direction

	# Detect player
	if player != null:
		var distance_to_player = global_position.distance_to(player.global_position)

		if current_state == State.WANDER and distance_to_player <= detection_radius:
			current_state = State.CHASE

	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	match current_state:
		State.WANDER:
			_wander_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.DEATH:
			_death_state(delta)

	move_and_slide()


func _refresh_combat_target(delta: float) -> void:
	target_refresh_timer -= delta
	if target_refresh_timer > 0.0 and is_instance_valid(player):
		return
	target_refresh_timer = TARGET_REFRESH_INTERVAL
	player = COMBAT_TARGET_SELECTOR.choose_target(self, real_player)


# SEPARATION - Prevents slimes from overlapping
func _apply_separation(delta: float) -> Vector2:
	var separation = Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for other in enemies:
		if other == self:
			continue
		
		var distance = global_position.distance_to(other.global_position)
		if distance < separation_radius and distance > 0:
			var away = (global_position - other.global_position).normalized()
			var strength = 1.0 - (distance / separation_radius)
			separation += away * strength * separation_force * delta
	
	return separation


# WANDER
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


# CHASE - Now with separation and zigzag
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

	# Direction to player
	var direction_to_player = (player.global_position - global_position).normalized()
	
	# Zigzag variation - makes slimes take different paths
	var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
	var zigzag_strength = 0.3  # Adjust this for more/less zigzag
	var zigzag_offset = perpendicular * sin(zigzag_timer * 2.0) * zigzag_direction * zigzag_strength
	
	# Base target velocity with speed variation
	var base_speed = chase_speed * speed_variation
	var target_velocity = (direction_to_player + zigzag_offset).normalized() * base_speed
	
	# Add random offset (small)
	target_velocity += random_offset * 0.05
	
	# Add separation from other slimes
	var separation = _apply_separation(delta)
	target_velocity += separation
	
	# Apply velocity with smoothing
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	if velocity.length() > 5.0:
		_update_facing(velocity.x)

	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")
	
	animated_sprite.speed_scale = walk_speed_scale
	
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health


# ATTACK
func _attack_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# If player ran away, go back to chase
	if distance_to_player > attack_range * 1.5:
		current_state = State.CHASE
		return

	velocity = Vector2.ZERO  
	
	# Face the player
	var direction_to_target = (player.global_position - global_position).normalized()
	if direction_to_target.x > 0:
		animated_sprite.flip_h = false
		facing_direction = 1
	else:
		animated_sprite.flip_h = true
		facing_direction = -1

	# Start attack if not already attacking
	if not is_attacking:
		is_attacking = true
		attack_duration = 0.0
		has_dealt_damage = false
		attack_started = true

		animated_sprite.speed_scale = attack_speed_scale
		animated_sprite.play("attack")
		animated_sprite.frame = 0
		return

	# Attack is in progress
	attack_duration += delta

	var current_frame = animated_sprite.frame

	# DEAL DAMAGE at the right frame
	if not has_dealt_damage and current_frame >= damage_frame:
		_deal_damage()
		has_dealt_damage = true

	# Check if animation finished
	var animation_done = not animated_sprite.is_playing()
	var frame_count = 1
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("attack"):
		frame_count = animated_sprite.sprite_frames.get_frame_count("attack")
	var reached_last_frame = current_frame >= frame_count - 1

	if animation_done or reached_last_frame:
		is_attacking = false
		can_attack = false
		attack_timer = attack_cooldown
		
		# Check if player is still in range
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range and can_attack:
			current_state = State.ATTACK
		else:
			current_state = State.CHASE

		animated_sprite.speed_scale = walk_speed_scale
		animated_sprite.play("walk")


# DEATH STATE
func _death_state(_delta: float) -> void:
	velocity = Vector2.ZERO
	
	if animated_sprite.sprite_frames.has_animation("death"):
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
			animated_sprite.speed_scale = 1.0
		
		if not animated_sprite.is_playing():
			queue_free()
	else:
		queue_free()


# TAKE DAMAGE
func take_damage(amount: int) -> void:
	if current_state == State.DEATH or current_health <= 0:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	if health_bar:
		health_bar.value = current_health
		health_bar.visible = true
	
	animated_sprite.modulate = Color(1, 0.3, 0.3, 1)
	await get_tree().create_timer(0.15).timeout
	animated_sprite.modulate = Color(1, 1, 1, 1)
	
	if current_health <= 0:
		die()


# DEATH
func die() -> void:
	if current_state == State.DEATH:
		return
	
	current_state = State.DEATH
	
	if health_bar:
		health_bar.visible = false
	
	var spawn_pos = global_position + Vector2(randf_range(-20, 20), -30)
	
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_center = camera.global_position
		var half_width = viewport_size.x / 2
		var half_height = viewport_size.y / 2
		spawn_pos.x = clamp(spawn_pos.x, camera_center.x - half_width + 50, camera_center.x + half_width - 50)
		spawn_pos.y = clamp(spawn_pos.y, camera_center.y - half_height + 50, camera_center.y + half_height - 50)
	else:
		spawn_pos.x = clamp(spawn_pos.x, -1000, 1000)
		spawn_pos.y = clamp(spawn_pos.y, -1000, 1000)
	
	var orb = XP_ORB_SCENE.instantiate()
	orb.is_level_up_coin = true
	orb.global_position = spawn_pos
	get_tree().current_scene.call_deferred("add_child", orb)


func pick_new_wander_target():
	var random_angle = randf_range(0, PI * 2)
	var random_distance = randf_range(0, wander_radius)
	var random_offset_pos = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	wander_target = home_position + random_offset_pos

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
		if current_state != State.ATTACK:
			current_state = State.WANDER
			pick_new_wander_target()
