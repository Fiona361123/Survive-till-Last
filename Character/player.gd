extends CharacterBody2D

# --- SIGNALS ---
signal player_died
signal hp_changed(current_hp: int, max_hp: int)

# --- MOVEMENT SETTINGS ---
@export var speed: float = 200.0

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

func _ready() -> void:
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return

	# 1. Read 8-Directional Input
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * speed
		last_input_vector = input_vector
	else:
		velocity = Vector2.ZERO

	# 2. Trigger Jump
	if Input.is_action_just_pressed("ui_accept") and not is_jumping:
		is_jumping = true
		jump_time = 0.0

	# 3. Handle Jump Arc
	handle_jump(delta)

	# 4. Update Animations
	update_8way_animation(input_vector)

	# 5. Move
	move_and_slide()

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
	if input_vec == Vector2.ZERO:
		sprite.stop()

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
