extends CharacterBody2D

# --- SIGNALS ---
signal player_died
signal hp_changed(current_hp: int, max_hp: int)

# --- MOVEMENT SETTINGS ---
@export var speed: float = 200.0
@export var chase_speed: float = 300.0  # Faster when chasing
@export var detection_range: float = 400.0  # How far the enemy can see
@export var chase_range: float = 500.0  # How far it will chase before giving up

# --- JUMP VISUAL SETTINGS ---
@export var jump_height: float = 100.0
@export var jump_speed: float = 3.0
var is_jumping: bool = false
var jump_time: float = 0.0

# Store last movement direction so sprite faces the right direction when stopped
var last_input_vector: Vector2 = Vector2.DOWN

# --- HEALTH STATS ---
@export var max_hp: int = 100
var current_hp: int

# --- NODE REFERENCES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = get_node_or_null("%HealthBar")

# --- NEW: Chase State ---
var player: Node2D = null  # Reference to the player
var is_chasing: bool = false
var state: String = "idle"  # "idle", "patrol", "chase", "attack"

func _ready() -> void:
	add_to_group("Player")
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	
	# Find the player (assuming it's in the scene tree)
	# Option 1: Find by group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	# Option 2: Find by name (if you named your player "Player")
	if player == null:
		player = get_node_or_null("../Player")  # Adjust path as needed

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return

	# 1. Check if player is in range
	detect_player()
	
	# 2. Determine movement based on state
	var input_vector := Vector2.ZERO
	
	if is_chasing and player != null:
		# Chase the player
		input_vector = (player.global_position - global_position).normalized()
		velocity = input_vector * chase_speed
		last_input_vector = input_vector
	else:
		# Normal movement (idle/patrol)
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_vector != Vector2.ZERO:
			velocity = input_vector.normalized() * speed
			last_input_vector = input_vector
		else:
			velocity = Vector2.ZERO

	# 3. Trigger Jump
	if Input.is_action_just_pressed("ui_accept") and not is_jumping:
		is_jumping = true
		jump_time = 0.0

	# 4. Handle Jump Arc
	handle_jump(delta)

	# 5. Update Animations
	update_8way_animation(input_vector if not is_chasing else last_input_vector)

	# 6. Move
	move_and_slide()

# --- NEW: Player Detection ---
func detect_player() -> void:
	if player == null:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Check if player is in detection range
	if distance <= detection_range:
		# Check line of sight (optional - prevents seeing through walls)
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
		query.exclude = [self]  # Don't collide with self
		var result = space_state.intersect_ray(query)
		
		# If nothing in the way or the first thing hit is the player
		if result.is_empty() or result.collider == player:
			is_chasing = true
			state = "chase"
			print("Player detected! Chasing...")
			return
	
	# Check if player left chase range
	if distance > chase_range:
		is_chasing = false
		state = "idle"
		print("Lost the player...")

# --- ANIMATION CONTROLLER ---
func update_8way_animation(input_vec: Vector2) -> void:
	var active_vec := input_vec if input_vec != Vector2.ZERO else last_input_vector

	# =========================================================================
	# 1. JUMP STATE (DIRECTION-AWARE)
	# =========================================================================
	if is_jumping:
		sprite.flip_h = false

		# A. JUMPING UP (Back View)
		if active_vec.y < 0 and abs(active_vec.y) >= abs(active_vec.x):
			if sprite.sprite_frames.has_animation("jump_up"):
				sprite.play("jump_up")
			elif sprite.sprite_frames.has_animation("run_up"):
				sprite.play("run_up")
			else:
				sprite.play("default")

		# B. JUMPING DOWN (Front View Facing You)
		elif active_vec.y > 0 and abs(active_vec.y) >= abs(active_vec.x):
			if sprite.sprite_frames.has_animation("jump_down"):
				sprite.play("jump_down")
			elif sprite.sprite_frames.has_animation("jump"):
				sprite.play("jump")
			elif sprite.sprite_frames.has_animation("run_down"):
				sprite.play("run_down")
			else:
				sprite.play("default")

		# C. JUMPING LEFT / RIGHT (Side View with horizontal flip)
		else:
			if sprite.sprite_frames.has_animation("jump"):
				sprite.play("jump")
				sprite.flip_h = (active_vec.x < 0)
			elif sprite.sprite_frames.has_animation("jump_down"):
				sprite.play("jump_down")
				sprite.flip_h = (active_vec.x < 0)
			else:
				sprite.play("default")
				sprite.flip_h = (active_vec.x < 0)

		return # Stops execution so running animations don't override the jump pose!

	# =========================================================================
	# 2. GROUNDED / RUNNING STATE
	# =========================================================================
	if input_vec == Vector2.ZERO and not is_chasing:
		sprite.stop()
		return  # Don't play animations if idle and not chasing

	sprite.flip_h = false
	var angle := rad_to_deg(active_vec.angle())

	# 8-Directional Clips
	if sprite.sprite_frames.has_animation("run_down_right"):
		if angle >= -22.5 and angle < 22.5:
			sprite.play("run_right")
		elif angle >= 22.5 and angle < 67.5:
			sprite.play("run_down_right")
		elif angle >= 67.5 and angle < 112.5:
			sprite.play("run_down")
		elif angle >= 112.5 and angle < 157.5:
			sprite.play("run_down_left")
		elif angle >= 157.5 or angle < -157.5:
			sprite.play("run_left")
		elif angle >= -157.5 and angle < -112.5:
			sprite.play("run_up_left")
		elif angle >= -112.5 and angle < -67.5:
			sprite.play("run_up")
		elif angle >= -67.5 and angle < -22.5:
			sprite.play("run_up_right")

	# Fallback: 4-Directional Setup
	else:
		if active_vec.y < 0 and abs(active_vec.y) >= abs(active_vec.x):
			if sprite.sprite_frames.has_animation("run_up"):
				sprite.play("run_up")
			else:
				sprite.play("default")
		elif active_vec.y > 0 and abs(active_vec.y) >= abs(active_vec.x):
			if sprite.sprite_frames.has_animation("run_down"):
				sprite.play("run_down")
			else:
				sprite.play("default")
		else:
			if sprite.sprite_frames.has_animation("run_right"):
				sprite.play("run_right")
				sprite.flip_h = (active_vec.x < 0)
			else:
				sprite.play("default")
				sprite.flip_h = (active_vec.x < 0)

# --- VISUAL JUMP HOP ARC ---
func handle_jump(delta: float) -> void:
	if is_jumping:
		jump_time += delta * jump_speed
		var offset_y := sin(jump_time * PI) * jump_height
		sprite.position.y = -offset_y
		
		if jump_time >= 1.0:
			is_jumping = false
			sprite.position.y = 0

# --- HEALTH & DAMAGE SYSTEM ---
func take_damage(amount: int) -> void:
	if current_hp <= 0:
		return
		
	current_hp -= amount
	current_hp = max(0, current_hp)
	hp_changed.emit(current_hp, max_hp)
	
	if health_bar:
		health_bar.value = current_hp
	
	sprite.modulate = Color(1, 0.3, 0.3, 0.8)
	get_tree().create_timer(0.15).timeout.connect(func(): sprite.modulate = Color.WHITE)
	
	if current_hp <= 0:
		die()

# --- GAME OVER TRIGGER ---
func die() -> void:
	print("Player Has Died!")
	player_died.emit()
	get_tree().paused = true
