extends CharacterBody2D

# --- SIGNALS ---
signal player_died
signal hp_changed(current_hp: int, max_hp: int)

# --- MOVEMENT SETTINGS ---
@export var speed: float = 200.0

# --- JUMP VISUAL SETTINGS ---
@export var jump_height: float = 120.0
@export var jump_speed: float = 3.0
var is_jumping: bool = false
var jump_time: float = 0.0
var is_attacking: bool = false

# Track last faced direction (defaults to Down / Front)
var last_direction: Vector2 = Vector2.DOWN

# --- HEALTH STATS ---
@export var max_hp: int = 100
var current_hp: int

# --- NODE REFERENCES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = get_node_or_null("%HealthBar")

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return

	# 1. Keyboard movement
	# 1. Read Movement Input
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * speed
		# Store precise normalized direction
		last_direction = input_vector.normalized()
	else:
		velocity = Vector2.ZERO

	# 2. Handle Spacebar Jump
	if Input.is_action_just_pressed("ui_accept") and not is_jumping:
		is_jumping = true
		jump_time = 0.0

	handle_jump(delta)

	# 3. Update Animations
	if is_jumping:
		play_jump_animation()
	else:
		update_animation(input_vector)

	# 4. Move
	move_and_slide()

# --- JUMP ANIMATION CONTROLLER ---
func play_jump_animation() -> void:
	sprite.flip_h = (last_direction.x < 0)

	# If facing UP (or UP-LEFT / UP-RIGHT), play back jump animation if available
	if last_direction.y < -0.35 and sprite.sprite_frames.has_animation("jump_up"):
		sprite.play("jump_up")
	# If facing DOWN, play front jump animation if available
	elif last_direction.y > 0.35 and sprite.sprite_frames.has_animation("jump_down"):
		sprite.play("jump_down")
	# Fallback to default jump animation
	elif sprite.sprite_frames.has_animation("jump"):
		sprite.play("jump")

# --- ANIMATION CONTROLLER ---
func update_animation(input_vec: Vector2) -> void:
	if is_attacking:
		return
	# Use active input if moving; use last_direction when stopped!
	var active := input_vec if input_vec != Vector2.ZERO else last_direction
	
	# PRECISE DIRECTION SNAP: Converts floats strictly into -1, 0, or 1
	var dir_x: int = 0
	var dir_y: int = 0
	
	if active.x > 0.35: dir_x = 1
	elif active.x < -0.35: dir_x = -1
	
	if active.y > 0.35: dir_y = 1
	elif active.y < -0.35: dir_y = -1

	sprite.flip_h = false

	# 1. Moving / Facing UP-RIGHT (Back-Right)
	if dir_y < 0 and dir_x > 0:
		if sprite.sprite_frames.has_animation("run_right_up"):
			sprite.play("run_right_up")
		elif sprite.sprite_frames.has_animation("run_up_right"):
			sprite.play("run_up_right")
		elif sprite.sprite_frames.has_animation("run_up"):
			sprite.play("run_up")
		else:
			sprite.play("default")

	# 2. Moving / Facing UP-LEFT (Back-Left)
	elif dir_y < 0 and dir_x < 0:
		if sprite.sprite_frames.has_animation("run_left_up"):
			sprite.play("run_left_up")
		elif sprite.sprite_frames.has_animation("run_up_left"):
			sprite.play("run_up_left")
		elif sprite.sprite_frames.has_animation("run_right_up"):
			sprite.play("run_right_up")
			sprite.flip_h = true
		elif sprite.sprite_frames.has_animation("run_up_right"):
			sprite.play("run_up_right")
			sprite.flip_h = true
		elif sprite.sprite_frames.has_animation("run_up"):
			sprite.play("run_up")
		else:
			sprite.play("default")

	# 3. Moving / Facing DOWN-RIGHT (Front-Right)
	elif dir_y > 0 and dir_x > 0:
		if sprite.sprite_frames.has_animation("run_right_down"):
			sprite.play("run_right_down")
		elif sprite.sprite_frames.has_animation("run_down_right"):
			sprite.play("run_down_right")
		elif sprite.sprite_frames.has_animation("run_down"):
			sprite.play("run_down")
		else:
			sprite.play("default")

	# 4. Moving / Facing DOWN-LEFT (Front-Left)
	elif dir_y > 0 and dir_x < 0:
		if sprite.sprite_frames.has_animation("run_left_down"):
			sprite.play("run_left_down")
		elif sprite.sprite_frames.has_animation("run_down_left"):
			sprite.play("run_down_left")
		elif sprite.sprite_frames.has_animation("run_right_down"):
			sprite.play("run_right_down")
			sprite.flip_h = true
		elif sprite.sprite_frames.has_animation("run_down_right"):
			sprite.play("run_down_right")
			sprite.flip_h = true
		elif sprite.sprite_frames.has_animation("run_down"):
			sprite.play("run_down")
		else:
			sprite.play("default")

	# 5. Moving / Facing STRAIGHT UP
	elif dir_y < 0 and dir_x == 0:
		if sprite.sprite_frames.has_animation("run_up"):
			sprite.play("run_up")
		else:
			sprite.play("default")

	# 6. Moving / Facing STRAIGHT DOWN
	elif dir_y > 0 and dir_x == 0:
		if sprite.sprite_frames.has_animation("run_down"):
			sprite.play("run_down")
		else:
			sprite.play("default")

	# 7. Moving / Facing STRAIGHT LEFT / RIGHT
	else:
		if dir_x < 0 and sprite.sprite_frames.has_animation("run_left"):
			sprite.play("run_left")
		elif sprite.sprite_frames.has_animation("run_right"):
			sprite.play("run_right")
			sprite.flip_h = (dir_x < 0)
		else:
			sprite.play("default")
			sprite.flip_h = (dir_x < 0)

	# WHEN STOPPED: Pause frame animation AFTER applying the correct direction!
	if input_vec == Vector2.ZERO:
		sprite.stop()
		return  # Don't play animations if idle

# --- JUMP VISUAL HOP ---
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

# --- ATTACK ANIMATION (called by Knife) ---
func play_attack_animation() -> void:
	if sprite.sprite_frames.has_animation("attack"):
		is_attacking = true
		sprite.play("attack")
		sprite.flip_h = (last_direction.x < 0)
		# wait for animation length, not the signal — can't get stuck
		var frames = sprite.sprite_frames.get_frame_count("attack")
		var fps = sprite.sprite_frames.get_animation_speed("attack")
		await get_tree().create_timer(frames / fps).timeout
		is_attacking = false

func switch_weapon(weapon_name: String) -> void:
	# remove current weapon(s)
	for child in get_children():
		if child.is_in_group("weapon"):
			child.queue_free()
	# add the new one
	var scene: PackedScene
	match weapon_name:
		"gun":
			scene = preload("res://weapons/gun/Gun.tscn")
		"knife":
			scene = preload("res://weapons/Knife.tscn")
	if scene:
		var weapon = scene.instantiate()
		add_child(weapon)
