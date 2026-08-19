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

@export var knife_scene: PackedScene
@export var gun_scene: PackedScene

# --- NODE REFERENCES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = get_node_or_null("AnimatedSprite2D/HealthBarAnchor/HealthBarAnchor")

var _game_over_ui_script = load("res://UI/game_over_ui.gd")
var _game_over_ui: Node = null

var hp_label: Label

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		health_bar.show_percentage = false # Hide the default "100%"
		
		# Create a text label to show exact HP numbers
		hp_label = Label.new()
		hp_label.add_theme_font_size_override("font_size", 12)
		hp_label.add_theme_color_override("font_color", Color.WHITE)
		hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		health_bar.add_child(hp_label)
		_update_hp_label()
		
	# Create Game Over UI automatically (deferred so scene tree is ready)
	_game_over_ui = _game_over_ui_script.new()
	get_tree().root.call_deferred("add_child", _game_over_ui)
	# Connect signal after a short delay so the node is in the tree first
	_game_over_ui.set_deferred("name", "GameOverUI")
	player_died.connect(_on_player_died)

func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = str(current_hp) + " / " + str(max_hp)

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return

	# 1. Read Movement Input
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * speed
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
	elif not is_attacking:
		update_animation(input_vector)

	# 4. Move
	move_and_slide()

# --- JUMP ANIMATION CONTROLLER ---
func play_jump_animation() -> void:
	sprite.flip_h = (last_direction.x < 0)

	# If jumping while facing UP/Backwards
	if last_direction.y < -0.35 and sprite.sprite_frames.has_animation("jump_up"):
		sprite.play("jump_up")
	# If jumping while facing DOWN/Forwards
	elif last_direction.y > 0.35 and sprite.sprite_frames.has_animation("jump_down"):
		sprite.play("jump_down")
	elif sprite.sprite_frames.has_animation("jump"):
		sprite.play("jump")

# --- ANIMATION CONTROLLER (ANGLE-BASED 8-DIRECTIONAL) ---
func update_animation(input_vec: Vector2) -> void:
	if current_hp <= 0:
		return
	if is_attacking:
		return

	# Use active input when moving, or last_direction when idle
	var dir := input_vec if input_vec != Vector2.ZERO else last_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	# Convert vector to degrees (-180 to 180)
	var deg := rad_to_deg(dir.angle())
	sprite.flip_h = false

	# 1. Straight Right (-22.5 to 22.5)
	if deg >= -22.5 and deg < 22.5:
		_play_anim(["run_right", "run", "default"], false)

	# 2. Down-Right (22.5 to 67.5) -> FRONT-RIGHT
	elif deg >= 22.5 and deg < 67.5:
		_play_anim(["run_right_down", "run_down_right", "run_down", "default"], false)

	# 3. Straight Down (67.5 to 112.5) -> FRONT
	elif deg >= 67.5 and deg < 112.5:
		_play_anim(["run_down", "default"], false)

	# 4. Down-Left (112.5 to 157.5) -> FRONT-LEFT
	elif deg >= 112.5 and deg < 157.5:
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
		else:
			sprite.play("run_down")

	# 5. Straight Left (>= 157.5 or < -157.5)
	elif deg >= 157.5 or deg < -157.5:
		if sprite.sprite_frames.has_animation("run_left"):
			sprite.play("run_left")
		elif sprite.sprite_frames.has_animation("run_right"):
			sprite.play("run_right")
			sprite.flip_h = true
		else:
			sprite.play("default")
			sprite.flip_h = true

	# 6. Up-Left (-157.5 to -112.5) -> BACK-LEFT
	elif deg >= -157.5 and deg < -112.5:
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
		else:
			sprite.play("run_up")

	# 7. Straight Up (-112.5 to -67.5) -> BACK
	elif deg >= -112.5 and deg < -67.5:
		_play_anim(["run_up", "default"], false)

	# 8. Up-Right (-67.5 to -22.5) -> BACK-RIGHT
	elif deg >= -67.5 and deg < -22.5:
		_play_anim(["run_right_up", "run_up_right", "run_up", "default"], false)

	# Freeze frame on current direction if not actively moving
	if input_vec == Vector2.ZERO:
		sprite.stop()

# Helper function to play the first available matching animation
func _play_anim(names: Array, flip: bool) -> void:
	sprite.flip_h = flip
	for anim_name in names:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
			return

# Returns the correct flip_h based on last_direction angle,
# matching the same logic used in update_animation() so attacks
# don't override the diagonal facing direction.
func _facing_flip_h() -> bool:
	var deg := rad_to_deg(last_direction.angle())
	# Only flip for left-side directions that are mirroring a right-side animation.
	# Down-Left: mirrors run_down_right
	if deg >= 112.5 and deg < 157.5:
		return true
	# Straight Left: flip only when using run_right as mirror (no run_left exists)
	elif deg >= 157.5 or deg < -157.5:
		return not sprite.sprite_frames.has_animation("run_left")
	# Up-Left: mirrors run_up_right
	elif deg >= -157.5 and deg < -112.5:
		return true
	return false

# --- JUMP VISUAL HOP ---
func handle_jump(delta: float) -> void:
	if is_jumping:
		jump_time += delta * jump_speed
		var offset_y := sin(jump_time * PI) * jump_height
		sprite.position.y = -offset_y
		
		if jump_time >= 1.0:
			is_jumping = false
			sprite.position.y = 0

var is_invincible: bool = false

# --- LEVEL & XP SYSTEM ---
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 15
var level_up_ui_script = load("res://UI/level_up_ui.gd")

var xp_attract_bonus: float = 0.0
var _level_up_ui: Node = null

func open_chest() -> void:
	if current_hp <= 0: return
	
	current_level += 1
	if _level_up_ui == null:
		_level_up_ui = level_up_ui_script.new()
		get_tree().root.add_child(_level_up_ui)
		_level_up_ui.upgrade_chosen.connect(_on_upgrade_chosen)
		
	_level_up_ui.show_level_up(current_level)

func _on_upgrade_chosen(key: String) -> void:
	# Visual confirmation flash
	if sprite:
		sprite.modulate = Color(0.5, 2.0, 0.5) # Bright green flash
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
		
	# Floating Level Up Celebration Icon
	var lvl_up_icon = Sprite2D.new()
	lvl_up_icon.texture = load("res://XPOrb/level_up_title.png")
	lvl_up_icon.position = Vector2(0, -60) # Start above the player's head
	add_child(lvl_up_icon)
	
	# Animate it floating up and fading out over 1.5 seconds
	var icon_tween = create_tween().set_parallel(true)
	icon_tween.tween_property(lvl_up_icon, "position:y", -120, 1.5).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(lvl_up_icon, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	icon_tween.chain().tween_callback(lvl_up_icon.queue_free)
		
	if key == "max_hp":
		max_hp += 20
		current_hp += 20
		hp_changed.emit(current_hp, max_hp)
		if health_bar:
			health_bar.max_value = max_hp
			health_bar.value = current_hp
		_update_hp_label()
	elif key == "speed":
		speed += 20
	elif key == "damage":
		var knife = get_node_or_null("Knife")
		if knife and "damage" in knife: knife.damage += 5
		var gun = get_node_or_null("Gun")
		if gun and "damage" in gun: gun.damage += 5
	elif key == "atk_speed":
		var knife = get_node_or_null("Knife")
		if knife and "attack_cooldown" in knife: knife.attack_cooldown *= 0.85
	elif key == "xp_radius":
		xp_attract_bonus += 40.0

# --- HEALTH & DAMAGE SYSTEM ---
func take_damage(amount: int) -> void:
	if current_hp <= 0 or is_invincible:
		return
		
	current_hp -= amount
	current_hp = max(0, current_hp)
	hp_changed.emit(current_hp, max_hp)
	
	if health_bar:
		health_bar.value = current_hp
	_update_hp_label()
	
	# Become invincible for 1 second
	is_invincible = true
	sprite.modulate = Color(1, 0.3, 0.3, 0.8)
	
	var t = get_tree().create_timer(1.0)
	t.timeout.connect(func(): 
		sprite.modulate = Color.WHITE
		is_invincible = false
	)
	
	if current_hp <= 0:
		die()

# --- GAME OVER TRIGGER ---
func die() -> void:
	print("Player Has Died!")
	# Freeze all movement and input
	set_physics_process(false)
	velocity = Vector2.ZERO

	# Play death animation if it exists, wait for it to finish
	if sprite.sprite_frames.has_animation("die"):
		# Force the animation to NOT loop (overrides editor settings)
		sprite.sprite_frames.set_animation_loop("die", false)
		sprite.play("die")
		# Wait until the animation finishes
		await sprite.animation_finished

	# Now emit signal — Game Over UI will show and pause
	player_died.emit()

# Called when player_died emits — safely triggers the Game Over UI
func _on_player_died() -> void:
	if _game_over_ui != null and _game_over_ui.is_inside_tree():
		_game_over_ui.show_game_over()
	else:
		# Fallback: UI not ready yet, try next frame
		await get_tree().process_frame
		if _game_over_ui != null:
			_game_over_ui.show_game_over()

# --- ATTACK ANIMATIONS ---
func play_attack_animation() -> void:
	if current_hp <= 0:
		return
	if sprite.sprite_frames.has_animation("attack_by_knife"):
		is_attacking = true
		sprite.play("attack_by_knife")
		# Use _facing_flip_h() so diagonal directions are respected,
		# not just a simple left/right flip that breaks diagonal facing.
		sprite.flip_h = _facing_flip_h()
		var frames = sprite.sprite_frames.get_frame_count("attack_by_knife")
		var fps = sprite.sprite_frames.get_animation_speed("attack_by_knife")
		await get_tree().create_timer(frames / fps).timeout
		is_attacking = false
		update_animation(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"))

func play_shoot_animation() -> void:
	if current_hp <= 0:
		return
	if sprite.sprite_frames.has_animation("attack_by_gun"):
		is_attacking = true
		sprite.play("attack_by_gun")
		# Use _facing_flip_h() so diagonal directions are respected.
		sprite.flip_h = _facing_flip_h()
		var frames = sprite.sprite_frames.get_frame_count("attack_by_gun")
		var fps = sprite.sprite_frames.get_animation_speed("attack_by_gun")
		await get_tree().create_timer(frames / fps).timeout
		is_attacking = false
		update_animation(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"))
