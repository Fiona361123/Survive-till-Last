extends CharacterBody2D

# MOVEMENT VARIABLES
@export var walk_speed: float = 80.0
@export var chase_speed: float = 120.0
@export var retreat_speed: float = 180.0
@export var wander_radius: float = 150.0

# RANGE VARIABLES
@export var ideal_range: float = 300.0
@export var attack_range: float = 400.0
@export var min_range: float = 200.0
@export var detection_radius: float = 600.0

# BOUNDARY VARIABLES
@export var max_wander_distance: float = 600.0
@export var return_threshold: float = 500.0
@export var boundary_radius: float = 800.0

# ATTACK VARIABLES
@export var damage: int = 3
@export var attack_cooldown: float = 1.2
@export var projectile_speed: float = 500.0

# RETREAT / KITING VARIABLES
@export var retreat_shoot_enabled: bool = true
@export var retreat_cooldown_multiplier: float = 0.65
@export var cornered_check_time: float = 0.5
@export var cornered_distance_threshold: float = 20.0
@export var point_blank_range: float = 90.0
@export var point_blank_cooldown_multiplier: float = 0.4

# DAMAGE FALLOFF VARIABLES
@export var max_damage_range: float = 150.0
@export var min_damage_range: float = 450.0
@export var min_damage_multiplier: float = 0.3

# HEALTH
@export var max_health: int = 50
var current_health: int

# NODE REFERENCES
@onready var animated_sprite = $AnimatedSprite2D
@onready var vision_area = $VisionArea
@onready var health_bar = $HealthBar
@onready var shoot_timer = $ShootTimer

# PLAYER REFERENCE
var player: Node2D = null

# WANDER VARIABLES
var home_position: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0

# STATE MACHINE
enum State {
	IDLE, WANDER, CHASE, SHOOT, RETREAT, STUN, ALERT, DEATH, RETURN_HOME
}
var current_state = State.WANDER

# DIRECTION
var facing_direction: int = 1

# ATTACK VARIABLES
var can_shoot: bool = true
var is_shooting: bool = false

# TIMERS
var stun_timer: float = 0.0
var stun_duration: float = 0.3
var alert_timer: float = 0.0
var search_timer: float = 0.0
var time_alive: float = 0.0
var retreat_direction: Vector2 = Vector2.ZERO

# CORNERED TRACKING
var _retreat_last_pos: Vector2 = Vector2.ZERO
var _retreat_stuck_timer: float = 0.0

# PROJECTILE SCENE
@export var projectile_scene: PackedScene

# HIT EFFECT SCENE
@export var hit_effect_scene: PackedScene

# ANIMATION VARIABLES
@export var walk_speed_scale: float = 1.0
@export var attack_speed_scale: float = 1.5


func _ready():
	add_to_group("enemy")
	home_position = global_position
	current_health = max_health
	_setup_health_bar()
	_find_player()
	_setup_vision_area()
	_setup_animations()
	pick_new_wander_target()


func _physics_process(delta):
	time_alive += delta
	_update_timers(delta)

	# Distance-based detection
	if player != null:
		var dist = global_position.distance_to(player.global_position)
		if dist < detection_radius and current_state == State.WANDER:
			current_state = State.CHASE
		elif dist > detection_radius * 1.5 and current_state != State.SHOOT and current_state != State.RETREAT and current_state != State.RETURN_HOME:
			current_state = State.WANDER
			pick_new_wander_target()

	# Boundary check - return home if too far
	var distance_from_home = global_position.distance_to(home_position)
	if distance_from_home > boundary_radius:
		current_state = State.RETURN_HOME
		velocity = Vector2.ZERO
		wander_target = home_position

	# State machine
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.WANDER:
			_wander_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.SHOOT:
			_shoot_state(delta)
		State.RETREAT:
			_retreat_state(delta)
		State.STUN:
			_stun_state(delta)
		State.ALERT:
			_alert_state(delta)
		State.DEATH:
			_death_state(delta)
		State.RETURN_HOME:
			_return_home_state(delta)

	move_and_slide()
	_update_health_bar()


# RETURN HOME - moves back to spawn point
func _return_home_state(delta):
	var direction_to_home = (home_position - global_position).normalized()
	var target_velocity = direction_to_home * chase_speed
	velocity = velocity.move_toward(target_velocity, chase_speed * 2 * delta)
	_update_facing(velocity.x)
	_play_animation("walk", walk_speed_scale)

	var distance_from_home = global_position.distance_to(home_position)
	if distance_from_home < return_threshold:
		current_state = State.WANDER
		pick_new_wander_target()


# SETUP FUNCTIONS
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
	if shoot_timer != null and not can_shoot:
		if shoot_timer.is_stopped():
			can_shoot = true

func _update_health_bar():
	if health_bar != null and current_state != State.WANDER and current_state != State.IDLE:
		health_bar.visible = true
		health_bar.value = current_health


# IDLE - waits then wanders
func _idle_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")
	search_timer += delta
	if search_timer > 0.5:
		search_timer = 0
		current_state = State.WANDER


# WANDER - walks randomly
func _wander_state(delta):
	var distance_to_target = global_position.distance_to(wander_target)
	var target_velocity = Vector2.ZERO

	if wander_target.distance_to(home_position) > max_wander_distance:
		pick_new_wander_target()
		return

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

	velocity = velocity.move_toward(target_velocity, walk_speed * 2 * delta)

	if velocity.length() > 5.0:
		_update_facing(velocity.x)

	_update_animation_state()
	if health_bar != null:
		health_bar.visible = false


# CHASE - moves toward player
func _chase_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# Player too close - retreat
	if distance_to_player < min_range:
		_enter_retreat()
		return

	# Perfect range - shoot
	if distance_to_player <= ideal_range + 30:
		current_state = State.SHOOT
		return

	# Too far - chase
	if distance_to_player > ideal_range + 30:
		var direction_to_player = (player.global_position - global_position).normalized()
		var target_velocity = direction_to_player * chase_speed
		velocity = velocity.move_toward(target_velocity, chase_speed * 2 * delta)
		_update_facing(velocity.x)
		_play_animation("walk", walk_speed_scale)

		# Don't chase too far from home
		var dist_from_home = global_position.distance_to(home_position)
		if dist_from_home > max_wander_distance:
			current_state = State.RETURN_HOME
			return


# SHOOT - stops and fires projectiles
func _shoot_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# Player got too close - retreat
	if distance_to_player < min_range:
		_enter_retreat()
		return

	# Player too far - chase
	if distance_to_player > attack_range:
		current_state = State.CHASE
		return

	# Stop and shoot
	velocity = Vector2.ZERO
	_face_player()

	if can_shoot:
		_fire_at_player(1.0)

	if animated_sprite.animation == "attack" and not animated_sprite.is_playing():
		animated_sprite.speed_scale = walk_speed_scale
		animated_sprite.play("idle")


# RETREAT - backs away while shooting (kiting)
func _enter_retreat():
	current_state = State.RETREAT
	_retreat_last_pos = global_position
	_retreat_stuck_timer = 0.0

func _retreat_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# Safe distance reached - go back to shooting
	if distance_to_player > ideal_range:
		current_state = State.SHOOT
		return

	# Move away from player
	var direction_away = (global_position - player.global_position).normalized()
	if direction_away == Vector2.ZERO:
		direction_away = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	# Check if retreating is working (not stuck on wall)
	var moved_since_check = global_position.distance_to(_retreat_last_pos)
	if moved_since_check < cornered_distance_threshold:
		_retreat_stuck_timer += delta
	else:
		_retreat_stuck_timer = 0.0
		_retreat_last_pos = global_position

	var is_cornered = _retreat_stuck_timer >= cornered_check_time

	# Move away or stand ground if cornered
	if not is_cornered:
		var target_velocity = direction_away * retreat_speed
		velocity = velocity.move_toward(target_velocity, retreat_speed * 3 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, retreat_speed * 3 * delta)

	# Face player while retreating
	_face_player()
	_play_animation("walk", walk_speed_scale)

	# Shoot while retreating if enabled
	if retreat_shoot_enabled and can_shoot:
		var cooldown_mult = retreat_cooldown_multiplier
		if is_cornered or distance_to_player <= point_blank_range:
			cooldown_mult = point_blank_cooldown_multiplier
		_fire_at_player(cooldown_mult)

	# Don't retreat too far from home
	var dist_from_home = global_position.distance_to(home_position)
	if dist_from_home > max_wander_distance:
		current_state = State.RETURN_HOME


# STUN - plays hurt animation when hit
func _stun_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "hurt":
		animated_sprite.play("hurt")
	stun_timer += delta
	if stun_timer >= stun_duration:
		stun_timer = 0
		current_state = State.CHASE


# ALERT - reacts to nearby allies
func _alert_state(delta):
	animated_sprite.play("alert")
	alert_timer += delta
	if alert_timer > 0.5:
		alert_timer = 0
		current_state = State.CHASE


# DEATH - plays death animation
func _death_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "death":
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0


# FIRE HELPER - shared by SHOOT and RETREAT
func _fire_at_player(cooldown_multiplier: float) -> void:
	if player == null:
		return
	var direction_to_target = (player.global_position - global_position).normalized()
	_shoot_projectile(direction_to_target)
	can_shoot = false
	if shoot_timer != null:
		shoot_timer.start(attack_cooldown * cooldown_multiplier)

	if animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.speed_scale = attack_speed_scale
		animated_sprite.play("attack")


# Face the player
func _face_player() -> void:
	if player == null:
		return
	var direction_to_target = (player.global_position - global_position).normalized()
	if direction_to_target.x > 0:
		animated_sprite.flip_h = false
		facing_direction = 1
	else:
		animated_sprite.flip_h = true
		facing_direction = -1


# SHOOT PROJECTILE
func _shoot_projectile(direction: Vector2):
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	if projectile == null:
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var normalized_direction = direction.normalized()

	# Damage falloff - less damage at longer range
	var damage_multiplier = 1.0
	if distance_to_player > max_damage_range:
		var falloff_range = min_damage_range - max_damage_range
		var falloff_percent = (distance_to_player - max_damage_range) / falloff_range
		falloff_percent = clamp(falloff_percent, 0.0, 1.0)
		damage_multiplier = 1.0 - (falloff_percent * (1.0 - min_damage_multiplier))
		damage_multiplier = clamp(damage_multiplier, min_damage_multiplier, 1.0)

	var final_damage = max(1, floor(damage * damage_multiplier))
	var hit_frame = clamp(floor(distance_to_player / 50.0), 1, 5)

	var root = get_tree().current_scene
	if root == null:
		return

	projectile.global_position = global_position + normalized_direction * 20
	projectile.direction = normalized_direction
	projectile.speed = projectile_speed
	projectile.damage = final_damage
	projectile.hit_frame = hit_frame

	if projectile.has_method("set_hit_effect"):
		projectile.set_hit_effect(hit_effect_scene)

	root.add_child(projectile)


# TAKE DAMAGE
func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(0, current_health)

	if health_bar != null:
		health_bar.value = current_health
		health_bar.visible = true

	animated_sprite.modulate = Color(1, 0.2, 0.2, 1)
	current_state = State.STUN
	stun_timer = 0

	if player != null:
		var knockback_dir = (global_position - player.global_position).normalized()
		velocity = knockback_dir * 200

	await get_tree().create_timer(0.15).timeout
	animated_sprite.modulate = Color(1, 1, 1, 1)

	if current_health <= 0:
		die()


# DEATH
func die() -> void:
	current_state = State.DEATH
	if health_bar != null:
		health_bar.visible = false
	await get_tree().create_timer(0.8).timeout
	queue_free()


# HELPER FUNCTIONS
func pick_new_wander_target():
	var random_angle = randf_range(0, PI * 2)
	var random_distance = randf_range(0, min(wander_radius, max_wander_distance * 0.7))
	var random_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	wander_target = home_position + random_offset

	if wander_target.distance_to(home_position) > max_wander_distance:
		wander_target = home_position + (wander_target - home_position).normalized() * max_wander_distance * 0.7

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


# VISION AREA SIGNALS
func _on_vision_area_body_entered(body):
	if body == player:
		if current_state != State.RETURN_HOME:
			current_state = State.CHASE

func _on_vision_area_body_exited(body):
	if body == player:
		if current_state != State.SHOOT and current_state != State.RETREAT and current_state != State.RETURN_HOME:
			current_state = State.WANDER
			pick_new_wander_target()


# GROUP BEHAVIOR - alerts nearby enemies
func on_ally_alert():
	if current_state == State.WANDER or current_state == State.IDLE:
		current_state = State.ALERT
		alert_timer = 0
