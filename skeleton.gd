extends CharacterBody2D

# MOVEMENT VARIABLES
@export var walk_speed: float = 60.0
@export var chase_speed: float = 140.0
@export var wander_radius: float = 200.0
@export var acceleration: float = 600.0
@export var rotation_speed: float = 6.0

# COMBAT RANGES
@export var attack_range: float = 50.0
@export var min_distance: float = 35.0
@export var detection_radius: float = 600.0

# HEALTH
@export var max_health: int = 100
var current_health: int

# XP DROP ON DEATH
@export var xp_drop: int = 15
const XP_ORB_SCENE = preload("res://enemyXP.tscn")

# ATTACK VARIABLES
@export var damage: int = 2
@export var attack_cooldown: float = 0.8
@export var damage_frame: int = 2

# ATTACK COMBO - this makes attack2 work!
enum ComboStage { NONE, ATTACK_1, ATTACK_2 }
var combo_stage: ComboStage = ComboStage.NONE
var combo_timer: float = 0.0
var combo_window: float = 2.0  # Time window to do second attack
var attack_count: int = 0

# KNOCKBACK
@export var knockback_force: float = 300.0
@export var stun_duration: float = 0.4

# NODE REFERENCES
@onready var animated_sprite = $AnimatedSprite2D
@onready var vision_area = $VisionArea
@onready var vision_shape = $VisionArea/CollisionShape2D
@onready var health_bar = $HealthBar
@onready var attack_timer = $AttackTimer
@onready var stun_timer = $StunTimer

# PLAYER REFERENCE
var player: Node2D = null

# WANDER VARIABLES
var home_position: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0

# STATE MACHINE
enum State {
	IDLE, WANDER, CHASE, ATTACK, STUN, RETREAT, ALERT, DEATH
}
var current_state = State.WANDER

# DIRECTION
var facing_direction: int = 1

# ATTACK STATE VARIABLES
var is_attacking: bool = false
var has_dealt_damage: bool = false
var attack_started: bool = false
var attack_duration: float = 0.0

# TIMERS
var can_attack: bool = true
var attack_timer_value: float = 0.0
var alert_timer: float = 0.0
var search_timer: float = 0.0
var stun_timer_value: float = 0.0
var retreat_timer: float = 0.0
var group_attack_cooldown: float = 0.0
var time_alive: float = 0.0

# ANIMATION VARIABLES
@export var walk_speed_scale: float = 1.0
@export var attack_speed_scale: float = 1.5


func _ready():
	_initialize()
	_setup_health_bar()
	_find_player()
	_setup_vision_area()
	_setup_animations()
	pick_new_wander_target()
	add_to_group("enemy")


func _physics_process(delta):
	time_alive += delta
	_update_timers(delta)
	
	# Combo timer - resets if player runs away
	if combo_timer > 0:
		combo_timer -= delta
	else:
		if combo_stage != ComboStage.NONE:
			combo_stage = ComboStage.NONE
			attack_count = 0
	
	# Auto detect player
	if player != null:
		var distance_to_player = global_position.distance_to(player.global_position)
		if current_state == State.WANDER and distance_to_player <= detection_radius:
			current_state = State.CHASE
	
	# State machine
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.WANDER:
			_wander_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.STUN:
			_stun_state(delta)
		State.RETREAT:
			_retreat_state(delta)
		State.ALERT:
			_alert_state(delta)
		State.DEATH:
			_death_state(delta)
	
	move_and_slide()
	_update_health_bar()


# INITIALIZATION
func _initialize():
	home_position = global_position
	current_health = max_health
	current_state = State.WANDER


func _setup_health_bar():
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false


func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _setup_vision_area():
	if vision_shape != null and vision_shape.shape is CircleShape2D:
		vision_shape.shape = vision_shape.shape.duplicate()
		vision_shape.shape.radius = detection_radius
	
	if vision_area != null:
		vision_area.body_entered.connect(_on_vision_area_body_entered)
		vision_area.body_exited.connect(_on_vision_area_body_exited)


func _setup_animations():
	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
	else:
		animated_sprite.play("walk")
	animated_sprite.speed_scale = walk_speed_scale


func _update_timers(delta):
	if not can_attack:
		attack_timer_value -= delta
		if attack_timer_value <= 0:
			can_attack = true
	
	if group_attack_cooldown > 0:
		group_attack_cooldown -= delta


func _update_health_bar():
	if health_bar != null and current_state != State.WANDER and current_state != State.IDLE and current_state != State.DEATH:
		health_bar.visible = true
		health_bar.value = current_health


# STATE: WANDER
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
		target_velocity = direction * walk_speed
		_update_facing(direction.x)
	
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	
	if velocity.length() > 5.0:
		_update_facing(velocity.x)
	
	_update_animation_state()
	if health_bar != null:
		health_bar.visible = false


# STATE: CHASE
func _chase_state(delta):
	if player == null:
		current_state = State.WANDER
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Too close - back away
	if distance_to_player < min_distance:
		var direction_away = (global_position - player.global_position).normalized()
		if direction_away == Vector2.ZERO:
			direction_away = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var target_velocity = direction_away * chase_speed * 1.2
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
		_update_facing(velocity.x)
		_play_animation("walk", walk_speed_scale)
		_separate_from_player(delta)
		return
	
	# In attack range - attack!
	if distance_to_player <= attack_range and can_attack:
		velocity = Vector2.ZERO
		is_attacking = false
		has_dealt_damage = false
		attack_started = false
		
		# COMBO LOGIC - this makes attack2 happen!
		if combo_stage == ComboStage.NONE:
			combo_stage = ComboStage.ATTACK_1
			attack_count = 1
		elif combo_stage == ComboStage.ATTACK_1 and combo_timer > 0:
			combo_stage = ComboStage.ATTACK_2
			attack_count = 2  # ← attack2 plays when attack_count = 2
		else:
			combo_stage = ComboStage.ATTACK_1
			attack_count = 1
		
		current_state = State.ATTACK
		return
	
	# Normal chase with zigzag
	var direction_to_player = (player.global_position - global_position).normalized()
	var zigzag = sin(time_alive * 4) * 0.2
	var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
	var final_direction = (direction_to_player + (perpendicular * zigzag)).normalized()
	
	var target_velocity = final_direction * chase_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	
	if velocity.length() > 5.0:
		_update_facing(velocity.x)
	
	_play_animation("walk", walk_speed_scale)
	_avoid_other_enemies(delta)
	_separate_from_player(delta)
	
	if distance_to_player < detection_radius * 0.7:
		_alert_nearby_enemies()


func _separate_from_player(delta):
	if player == null:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player < 30:
		var push_direction = (global_position - player.global_position).normalized()
		if push_direction == Vector2.ZERO:
			push_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var push_force = (30 - distance_to_player) * 2.0
		velocity += push_direction * push_force


# STATE: ATTACK - attack2 plays here!
func _attack_state(delta):
	if player == null:
		current_state = State.WANDER
		return
	
	velocity = Vector2.ZERO
	_face_player()
	
	# Choose animation: attack or attack2
	var anim_name = "attack"
	if attack_count == 2 and animated_sprite.sprite_frames.has_animation("attack2"):
		anim_name = "attack2"
	
	if animated_sprite.animation != anim_name:
		animated_sprite.speed_scale = attack_speed_scale
		animated_sprite.play(anim_name)
		has_dealt_damage = false
	
	var current_frame = animated_sprite.frame
	
	# Deal damage at the right frame
	if not has_dealt_damage and current_frame >= damage_frame:
		var current_damage = damage
		if attack_count == 2:
			current_damage = damage + 1  
		_deal_damage(current_damage)
		has_dealt_damage = true
	
	# Attack finished - go back to chase
	if not animated_sprite.is_playing():
		is_attacking = false
		can_attack = false
		attack_timer_value = attack_cooldown
		combo_timer = combo_window  # Reset combo window for next attack
		current_state = State.CHASE
		animated_sprite.speed_scale = walk_speed_scale
		animated_sprite.play("walk")


# STATE: STUN - plays hurt animation
func _stun_state(delta):
	velocity = Vector2.ZERO
	
	if animated_sprite.sprite_frames.has_animation("hurt"):
		if animated_sprite.animation != "hurt":
			animated_sprite.play("hurt")
			animated_sprite.speed_scale = 1.0
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
	
	stun_timer_value += delta
	if stun_timer_value >= stun_duration:
		stun_timer_value = 0
		current_state = State.CHASE
		animated_sprite.speed_scale = walk_speed_scale
		animated_sprite.play("walk")


# STATE: RETREAT
func _retreat_state(delta):
	if player == null:
		current_state = State.WANDER
		return
	var direction_away = (global_position - player.global_position).normalized()
	velocity = direction_away * chase_speed * 0.7
	_update_facing(-direction_away.x)
	retreat_timer += delta
	if retreat_timer > 0.8:
		retreat_timer = 0
		current_state = State.CHASE


# STATE: ALERT
func _alert_state(delta):
	animated_sprite.play("alert")
	alert_timer += delta
	if alert_timer > 0.5:
		alert_timer = 0
		current_state = State.CHASE


# STATE: DEATH
func _death_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "death":
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0


# STATE: IDLE
func _idle_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")
	search_timer += delta
	if search_timer > 0.5:
		search_timer = 0
		current_state = State.WANDER


# UTILITY FUNCTIONS
func _face_player():
	if player == null:
		return
	var direction_to_target = (player.global_position - global_position).normalized()
	if direction_to_target.x > 0:
		animated_sprite.flip_h = false
		facing_direction = 1
	elif direction_to_target.x < 0:
		animated_sprite.flip_h = true
		facing_direction = -1


func _deal_damage(attack_damage: int):
	if player != null and player.has_method("take_damage"):
		var current_distance = global_position.distance_to(player.global_position)
		if current_distance <= attack_range * 2.0:
			player.take_damage(attack_damage)
			_apply_knockback_to_player()


func _apply_knockback_to_player():
	if player != null and player.has_method("apply_knockback"):
		var knockback_direction = (player.global_position - global_position).normalized()
		player.apply_knockback(knockback_direction * knockback_force)


# ANIMATION HELPERS
func _play_animation(anim_name: String, speed: float):
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
		animated_sprite.speed_scale = speed


func _update_animation_state():
	if velocity.length() < 5.0:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
	else:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")


# GROUP BEHAVIOR
func _avoid_other_enemies(delta):
	var enemies = get_tree().get_nodes_in_group("enemy")
	var avoidance = Vector2.ZERO
	for other in enemies:
		if other != self:
			var distance = global_position.distance_to(other.global_position)
			if distance < 40:
				var away = (global_position - other.global_position).normalized()
				avoidance += away * (40 - distance) / 40
	velocity += avoidance * 100 * delta


func _alert_nearby_enemies():
	if group_attack_cooldown > 0:
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	for other in enemies:
		if other != self and other.has_method("on_ally_alert"):
			var distance = global_position.distance_to(other.global_position)
			if distance < 300:
				other.on_ally_alert()
	group_attack_cooldown = 2.0


func on_ally_alert():
	if current_state == State.WANDER or current_state == State.IDLE:
		current_state = State.ALERT
		alert_timer = 0


# SOUND EFFECTS
func _play_knife_sound():
	pass


# VISION AREA SIGNALS
func _on_vision_area_body_entered(body):
	if body == player:
		current_state = State.CHASE


func _on_vision_area_body_exited(body):
	if body == player:
		if current_state != State.ATTACK:
			current_state = State.WANDER
			pick_new_wander_target()


# WANDER HELPER
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


# TAKING DAMAGE
func take_damage(amount: int) -> void:
	if current_state == State.DEATH or current_health <= 0:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	if health_bar != null:
		health_bar.value = current_health
		health_bar.visible = true
	
	# Flash red on hit
	animated_sprite.modulate = Color(1, 0.3, 0.3, 1)
	
	# Knockback
	if player != null:
		var knockback_dir = (global_position - player.global_position).normalized()
		if knockback_dir == Vector2.ZERO:
			knockback_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		velocity = knockback_dir * 200
	
	# Enter stun (plays hurt animation)
	current_state = State.STUN
	stun_timer_value = 0
	
	await get_tree().create_timer(0.15).timeout
	animated_sprite.modulate = Color(1, 1, 1, 1)
	
	if current_health <= 0:
		die()


# DEATH - spawns XP orb
func die() -> void:
	current_state = State.DEATH
	
	if health_bar != null:
		health_bar.visible = false
	
	# Spawn XP orb
	var spawn_pos = global_position + Vector2(randf_range(-20, 20), -30)
	
	# Keep orb inside camera view
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
	orb.xp_value = xp_drop
	orb.global_position = spawn_pos
	get_tree().current_scene.call_deferred("add_child", orb)
	
	# Play death animation
	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0
		await animated_sprite.animation_finished
	
	queue_free()


# RESET
func reset_enemy():
	current_health = max_health
	if health_bar != null:
		health_bar.value = current_health
		health_bar.visible = false
	current_state = State.WANDER
	is_attacking = false
	has_dealt_damage = false
	combo_stage = ComboStage.NONE
	attack_count = 0
	combo_timer = 0
	animated_sprite.modulate = Color(1, 1, 1, 1)
	pick_new_wander_target()
