#skeleton.gd
extends CharacterBody2D

# MOVEMENT
@export var walk_speed: float = 60.0
@export var chase_speed: float = 140.0
@export var wander_radius: float = 200.0
@export var acceleration: float = 600.0
@export var rotation_speed: float = 6.0

# COMBAT RANGES - Attack 2 has larger range for combo follow-up
@export var attack_range: float = 90.0
@export var attack2_range: float = 150.0
@export var detection_radius: float = 600.0

# HEALTH
@export var max_health: int = 100
var current_health: int

# XP DROP
@export var xp_drop: int = 15
@export var hp_bonus_drop: int = 30  
const XP_ORB_SCENE = preload("res://enemyXP.tscn")

# ATTACK 
@export var damage: int = 10
@export var attack2_damage: int = 15
@export var attack_cooldown: float = 0.8
@export var damage_frame: int = 4

# COMBO SYSTEM
enum ComboStage { NONE, ATTACK_1, ATTACK_2 }
var combo_stage: ComboStage = ComboStage.NONE
var combo_timer: float = 0.0
var combo_window: float = 4.0
var attack_count: int = 0

# KNOCKBACK
@export var knockback_force: float = 300.0

# NODE REFERENCES
@onready var animated_sprite = $AnimatedSprite2D
@onready var vision_area = $VisionArea
@onready var vision_shape = $VisionArea/CollisionShape2D
@onready var health_bar = $HealthBar
@onready var attack_timer = $AttackTimer

# PLAYER REFERENCE
var player: Node2D = null

# WANDER
var home_position: Vector2
var wander_target: Vector2
var wander_timer: float = 0.0

# STATE MACHINE
enum State {
	IDLE, WANDER, CHASE, ATTACK, RETREAT, ALERT, DEATH
}
var current_state = State.WANDER

# DIRECTION
var facing_direction: int = 1

# ATTACK STATE
var is_attacking: bool = false
var has_dealt_damage: bool = false
var attack_started: bool = false
var attack_duration: float = 0.0

# TIMERS
var can_attack: bool = true
var attack_timer_value: float = 0.0
var alert_timer: float = 0.0
var search_timer: float = 0.0
var retreat_timer: float = 0.0
var group_attack_cooldown: float = 0.0
var time_alive: float = 0.0
var is_hurt: bool = false
@export var hurt_duration: float = 0.25

# ANIMATION SPEED
@export var walk_speed_scale: float = 1.0
@export var attack_speed_scale: float = 0.7

# WAVE SPAWNER
@export var wave_spawner: Node2D = null
@export var wave_interval: float = 5.0
@export var max_wave_enemies: int = 10
var wave_timer: float = 0.0
var enemies_spawned: int = 0


func _ready():
	_initialize()
	_setup_health_bar()
	_find_player()
	_setup_vision_area()
	_setup_animations()
	pick_new_wander_target()
	add_to_group("enemy")
	
	# Reset wave spawner timer
	wave_timer = wave_interval


func _physics_process(delta):
	time_alive += delta
	_update_timers(delta)

	# Hurt state - freeze briefly when hit
	if is_hurt:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Combo timer counts down, allowing Attack 2
	if combo_timer > 0:
		combo_timer -= delta

	# Auto detect player
	if player != null:
		var distance_to_player = global_position.distance_to(player.global_position)
		if current_state == State.WANDER and distance_to_player <= detection_radius:
			current_state = State.CHASE

	# Wave spawning - spawns enemies in waves
	_wave_spawning(delta)

	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.WANDER:
			_wander_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.RETREAT:
			_retreat_state(delta)
		State.ALERT:
			_alert_state(delta)
		State.DEATH:
			_death_state(delta)

	move_and_slide()
	_update_health_bar()


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


# STATE: WANDER - walks to random points near spawn
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


# STATE: CHASE - follows player, uses larger range for Attack 2 combo
func _chase_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# Attack 2 has larger range, making combo easier to land
	var current_attack_range = attack_range
	if combo_stage == ComboStage.ATTACK_1 and combo_timer > 0:
		current_attack_range = attack2_range

	if distance_to_player <= current_attack_range and can_attack:

		velocity = Vector2.ZERO
		is_attacking = false
		has_dealt_damage = false
		attack_started = false

		# Combo decision: Attack 2 if Attack 1 was done recently
		if combo_stage == ComboStage.ATTACK_1 and combo_timer > 0:
			combo_stage = ComboStage.ATTACK_2
			attack_count = 2
		else:
			combo_stage = ComboStage.ATTACK_1
			attack_count = 1

		current_state = State.ATTACK
		return

	# Chase player with slight zigzag
	var direction_to_player = (player.global_position - global_position).normalized()
	var zigzag = sin(time_alive * 4) * 1.0
	var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
	var final_direction = (direction_to_player + (perpendicular * zigzag)).normalized()

	var target_velocity = final_direction * chase_speed

	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	if velocity.length() > 5:
		_update_facing(velocity.x)

	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")

	animated_sprite.speed_scale = walk_speed_scale


# STATE: ATTACK - plays animation once, deals damage at specific frame
func _attack_state(delta):
	if player == null:
		current_state = State.WANDER
		return

	velocity = Vector2.ZERO

	# Start attack animation only once
	if not is_attacking:
		is_attacking = true
		has_dealt_damage = false

		var anim_name = "attack"
		if attack_count == 2 and animated_sprite.sprite_frames.has_animation("attack2"):
			anim_name = "attack2"

		animated_sprite.speed_scale = attack_speed_scale
		animated_sprite.play(anim_name)

	# Deal damage at the right frame
	if not has_dealt_damage and animated_sprite.frame >= damage_frame:
		var current_damage = damage
		if attack_count == 2:
			current_damage = attack2_damage
		_deal_damage(current_damage)
		has_dealt_damage = true

	# Wait until animation finishes
	if not animated_sprite.is_playing():
		is_attacking = false
		can_attack = false
		attack_timer_value = attack_cooldown

		if attack_count == 1:
			combo_timer = combo_window
		else:
			combo_timer = 0
			combo_stage = ComboStage.NONE
			attack_count = 0

		current_state = State.CHASE
		animated_sprite.speed_scale = walk_speed_scale
		animated_sprite.play("walk")


# STATE: RETREAT - backs away when too close
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


# STATE: ALERT - reacts to nearby allies
func _alert_state(delta):
	animated_sprite.play("alert")
	alert_timer += delta
	if alert_timer > 0.5:
		alert_timer = 0
		current_state = State.CHASE


# STATE: DEATH - plays death animation
func _death_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "death":
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0


# STATE: IDLE - brief pause before wandering
func _idle_state(delta):
	velocity = Vector2.ZERO
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")
	search_timer += delta
	if search_timer > 0.5:
		search_timer = 0
		current_state = State.WANDER


# FACE PLAYER - flips sprite to face target
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


# DEAL DAMAGE - uses larger hit range for Attack 2
func _deal_damage(attack_damage: int):
	if player != null and player.has_method("take_damage"):
		var current_distance = global_position.distance_to(player.global_position)
		
		# Attack 2 has larger hit range to match its larger attack range
		var max_hit_range = attack_range * 2.0
		if attack_count == 2:
			max_hit_range = attack2_range * 2.0
			
		if current_distance <= max_hit_range:
			player.take_damage(attack_damage)
			_apply_knockback_to_player()


# APPLY KNOCKBACK - pushes player back on hit
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


# GROUP BEHAVIOR - avoids overlapping with other enemies
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


# GROUP BEHAVIOR - alerts nearby enemies when player is detected
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


func _play_knife_sound():
	pass


# WAVE SPAWNING - spawns enemies at intervals
func _wave_spawning(delta):
	if wave_spawner == null:
		return
	
	# Count current enemies
	var current_enemies = get_tree().get_nodes_in_group("enemy").size()
	
	# Only spawn if below max limit
	if current_enemies >= max_wave_enemies:
		wave_timer = 0.5
		return
	
	wave_timer -= delta
	
	if wave_timer <= 0 and current_enemies < max_wave_enemies:
		_spawn_enemy()
		wave_timer = wave_interval

func _spawn_enemy():
	if wave_spawner == null:
		return
	
	var spawn_points = wave_spawner.get_children()
	if spawn_points.size() == 0:
		return
	
	# Pick a random spawn point
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	
	# Instantiate a new enemy (this same scene)
	var new_enemy = load(scene_file_path).instantiate()
	
	# Set its position to the spawn point
	new_enemy.global_position = spawn_point.global_position
	
	# Reset its health and state
	new_enemy.current_health = new_enemy.max_health
	
	# Safely reset health bar
	if new_enemy.health_bar != null:
		new_enemy.health_bar.value = new_enemy.max_health
		new_enemy.health_bar.visible = false
	
	new_enemy.current_state = State.WANDER
	new_enemy.is_attacking = false
	new_enemy.has_dealt_damage = false
	new_enemy.combo_stage = ComboStage.NONE
	new_enemy.attack_count = 0
	new_enemy.combo_timer = 0
	
	# Safely reset sprite modulate
	if new_enemy.animated_sprite != null:
		new_enemy.animated_sprite.modulate = Color(1, 1, 1, 1)
	
	# Make sure it has the player reference
	new_enemy.player = player
	
	# Add to the scene
	get_tree().current_scene.add_child(new_enemy)
	
	enemies_spawned += 1
	print("🔄 Wave spawned enemy #", enemies_spawned)

# VISION AREA SIGNALS
func _on_vision_area_body_entered(body):
	if body == player:
		current_state = State.CHASE


func _on_vision_area_body_exited(body):
	if body == player:
		# Keep combo alive if Attack 1 was done recently
		if combo_timer > 0 and attack_count == 1:
			current_state = State.CHASE
		else:
			current_state = State.WANDER
			pick_new_wander_target()


# WANDER HELPER - picks random target near spawn
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


# TAKING DAMAGE - white flash effect, doesn't interrupt attack
func take_damage(amount: int) -> void:
	if current_state == State.DEATH or current_health <= 0:
		return

	current_health -= amount
	current_health = max(0, current_health)

	if health_bar != null:
		health_bar.value = current_health
		health_bar.visible = true

	# White flash when hit (doesn't interrupt attack)
	if current_health > 0:
		_hurt_flash()

	if current_health <= 0:
		die()


func _hurt_flash() -> void:
	animated_sprite.modulate = Color(3,3,3,1)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color(1, 1, 1, 1)


# DEATH - spawns XP , plays death animation
func die() -> void:
	current_state = State.DEATH
	
	if health_bar != null:
		health_bar.visible = false
	
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
	orb.heal_bonus = hp_bonus_drop   # Skeleton coin also restores HP
	orb.global_position = spawn_pos
	get_tree().current_scene.call_deferred("add_child", orb)
	
	if animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		animated_sprite.speed_scale = 1.0
		await animated_sprite.animation_finished
	
	queue_free()


# RESET - returns enemy to full health
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
