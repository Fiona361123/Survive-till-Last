extends CharacterBody2D


@export_category("Boss Health")
@export var max_health: float = 2000.0

var health: float
var dead: bool = false


@export_category("Player Detection")
@export var player_path: NodePath

var player: Node2D = null


@export_category("Movement")
@export var normal_speed: float = 80.0
@export var phase_2_speed: float = 100.0
@export var phase_3_speed: float = 130.0

@export var phase_1_stop_distance: float = 95.0

@export var phase_2_min_distance: float = 180.0
@export var phase_2_max_distance: float = 320.0

@export var phase_3_circle_distance: float = 190.0
@export var phase_3_min_distance: float = 130.0
@export var phase_3_max_distance: float = 300.0

var current_speed: float = 80.0


@export_category("Phase 1 Prediction")
@export var prediction_strength: float = 0.35

@export var phase_1_dash_min_distance: float = 180.0
@export var phase_1_dash_max_distance: float = 420.0
@export var phase_1_dash_chance: float = 0.025


@export_category("Damage")
@export var melee_damage_1: float = 20.0
@export var melee_damage_2: float = 30.0
@export var melee_damage_3: float = 50.0
@export var teleport_damage: float = 35.0
@export var counter_damage: float = 40.0
@export var dash_damage: float = 50.0


@export_category("Attack Range")
@export var melee_range: float = 200.0
@export var teleport_trigger_range: float = 600.0
@export var teleport_distance: float = 140.0

@export var dash_trigger_range: float = 500.0
@export var dash_hit_range: float = 55.0


@export_category("Attack Cooldowns")
@export var melee_cooldown: float = 1.5
@export var trap_cooldown: float = 5.0
@export var dash_cooldown: float = 4.0
@export var teleport_cooldown_time: float = 3.0


@export_category("Combo")
@export var combo_window: float = 2.0

var combo_step: int = 0
var combo_available: bool = false


@export_category("Counter")
@export var counter_chance_phase_1: float = 0.15
@export var counter_chance_phase_2: float = 0.20
@export var counter_chance_phase_3: float = 0.25
@export var counter_duration: float = 0.8

var counter_active: bool = false


@export_category("Phase 2 Assassin")
@export var phase_2_circle_distance: float = 250.0
@export var phase_2_circle_speed: float = 1.2
@export var phase_2_direction_change_time: float = 1.5
@export var phase_2_trap_chance: float = 0.015

var phase_2_circle_direction: float = 1.0
var phase_2_circle_timer: float = 0.0

@export_category("Trap")
@export var trap_scene: PackedScene

var can_place_trap: bool = true


@export_category("Clones")
@export var clone_scene: PackedScene
@export var clone_lifetime: float = 12.0

var clones_created: bool = false


@export_category("Dash")
@export var dash_speed: float = 600.0
@export var dash_distance: float = 300.0
@export var dash_warning_time: float = 0.5
@export var dash_duration: float = 0.45
@export var dash_recovery: float = 0.6

var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO


@export_category("Phase 3 Movement")
@export var circle_direction_change_time: float = 2.5
@export var phase_3_dash_chance: float = 0.025
@export var phase_3_trap_chance: float = 0.015

var circle_direction: float = 1.0
var circle_timer: float = 0.0


enum BossPhase {
	PHASE_1,
	PHASE_2,
	PHASE_3
}

var current_phase: BossPhase = BossPhase.PHASE_1


enum BossState {
	IDLE,
	CHASE,
	CIRCLE,
	ATTACK,
	TELEPORT,
	COUNTER,
	DASH,
	DEATH
}

var current_state: BossState = BossState.IDLE


var is_hurt: bool = false
var is_attacking: bool = false
var can_attack: bool = true


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var combo_timer: Timer = $ComboTimer
@onready var teleport_timer: Timer = $TeleportTimer
@onready var hurt_timer: Timer = $HurtTimer


func _ready() -> void:
	health = max_health
	current_speed = normal_speed

	if player_path != NodePath(""):
		player = get_node_or_null(player_path)

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player is CollisionObject2D:
		add_collision_exception_with(player)

	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	if not combo_timer.timeout.is_connected(_on_combo_timer_timeout):
		combo_timer.timeout.connect(_on_combo_timer_timeout)

	if not hurt_timer.timeout.is_connected(_on_hurt_timer_timeout):
		hurt_timer.timeout.connect(_on_hurt_timer_timeout)

	attack_timer.one_shot = true
	combo_timer.one_shot = true
	hurt_timer.one_shot = true
	teleport_timer.one_shot = true

	attack_timer.wait_time = melee_cooldown
	combo_timer.wait_time = combo_window
	teleport_timer.wait_time = teleport_cooldown_time

	if sprite:
		sprite.visible = true
		sprite.speed_scale = 1.0
		sprite.modulate = Color.WHITE
		sprite.play("idle")

	print("SHADOW OVERLORD HAS APPEARED!")


func _physics_process(_delta: float) -> void:
	if dead:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

		if player == null:
			velocity = Vector2.ZERO

			if sprite:
				sprite.play("idle")

			return

		if player is CollisionObject2D:
			add_collision_exception_with(player)

	face_player()
	update_phase()

	if current_state == BossState.DEATH:
		velocity = Vector2.ZERO
		return

	if is_attacking:
		velocity = Vector2.ZERO
		return

	var distance := global_position.distance_to(player.global_position)

	match current_phase:
		BossPhase.PHASE_1:
			phase_one_behavior(distance)

		BossPhase.PHASE_2:
			phase_two_behavior(distance)

		BossPhase.PHASE_3:
			phase_three_behavior(distance)

	if not is_attacking:
		move_and_slide()


func update_phase() -> void:
	if dead:
		return

	var health_percent := (health / max_health) * 100.0

	if health_percent <= 30.0:
		if current_phase != BossPhase.PHASE_3:
			enter_phase_3()

		return

	if health_percent <= 60.0:
		if current_phase != BossPhase.PHASE_2:
			enter_phase_2()

		return

	if current_phase != BossPhase.PHASE_1:
		current_phase = BossPhase.PHASE_1
		current_state = BossState.CHASE


func phase_one_behavior(distance: float) -> void:
	current_speed = normal_speed

	if distance <= melee_range:
		stop_moving()

		if can_attack:
			choose_melee_attack()

		return

	if can_dash:
		if distance >= phase_1_dash_min_distance:
			if distance <= phase_1_dash_max_distance:
				if randf() < phase_1_dash_chance:
					phase_1_short_dash()
					return

	predictive_chase()


func predictive_chase() -> void:
	if player == null:
		return

	if dead or is_attacking:
		velocity = Vector2.ZERO
		return

	var target_position := player.global_position

	if player is CharacterBody2D:
		target_position += player.velocity * prediction_strength

	var distance := global_position.distance_to(player.global_position)

	if distance <= phase_1_stop_distance:
		velocity = Vector2.ZERO
		play_animation("idle")
		return

	var direction := global_position.direction_to(target_position)

	velocity = direction * current_speed

	current_state = BossState.CHASE

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 1.0


func phase_1_short_dash() -> void:
	if not can_dash or player == null or not start_attack():
		return

	can_dash = false
	current_state = BossState.DASH

	var target_position := player.global_position

	if player is CharacterBody2D:
		target_position += player.velocity * prediction_strength

	dash_direction = global_position.direction_to(target_position)

	if dash_direction.length() == 0:
		dash_direction = Vector2.RIGHT

	velocity = Vector2.ZERO

	# Short preparation
	if sprite:
		sprite.play("idle")
		sprite.speed_scale = 1.0

	await get_tree().create_timer(0.15).timeout

	if dead:
		return

	# Dash toward player
	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 2.0

	var dash_time := dash_distance / dash_speed
	var elapsed := 0.0

	while elapsed < dash_time:
		if dead:
			return

		var delta := get_physics_process_delta_time()
		elapsed += delta

		velocity = dash_direction * dash_speed
		move_and_slide()

		await get_tree().process_frame

	velocity = Vector2.ZERO

	if dead:
		return

	# Immediately attack after dash
	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack1")

		await get_tree().create_timer(0.15).timeout

	if dead:
		return

	# Damage immediately after dash
	if player != null and is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)

		if distance <= melee_range + 30.0:
			if player.has_method("take_damage"):
				player.take_damage(melee_damage_1)

				print("PHASE 1 DASH ATTACK HIT PLAYER FOR ", melee_damage_1, " DAMAGE")

	if sprite:
		await sprite.animation_finished

	if dead:
		return

	can_dash = true
	end_attack()
	

func phase_two_behavior(distance: float) -> void:
	current_speed = phase_2_speed

	# Teleport ambush when player is very far
	if distance > teleport_trigger_range:
		if teleport_timer.time_left <= 0.0:
			teleport_ambush()
			return

	# Close range: attack aggressively
	if distance <= melee_range:
		if can_attack:
			var choice := randf()

			if choice < 0.50:
				choose_melee_attack()
			elif choice < 0.75 and can_dash:
				phase_2_dash_attack()
			else:
				phase_2_circle_player()

			return

	# Medium range: move toward player instead of stepping back
	if distance > melee_range:
		if distance > phase_2_max_distance:
			chase_player()
			return

		# Occasionally attack even while approaching
		if can_attack and randf() < 0.20:
			choose_melee_attack()
			return

		phase_2_circle_player()

	# Trap has a chance to appear while moving
	if can_place_trap and randf() < phase_2_trap_chance:
		create_trap()

func phase_2_dash_attack() -> void:
	if player == null:
		return

	if not can_dash:
		return

	if not start_attack():
		return

	can_dash = false
	current_state = BossState.DASH

	var target_position := player.global_position

	if player is CharacterBody2D:
		target_position += player.velocity * 0.2

	dash_direction = global_position.direction_to(target_position)

	if dash_direction.length() == 0:
		dash_direction = Vector2.RIGHT

	velocity = Vector2.ZERO

	if sprite:
		sprite.play("idle")
		sprite.speed_scale = 1.0

	await get_tree().create_timer(0.2).timeout

	if dead:
		return

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 3.0

	var elapsed := 0.0
	var already_hit := false

	while elapsed < 0.3:
		if dead:
			return

		var delta := get_physics_process_delta_time()
		elapsed += delta

		velocity = dash_direction * 500.0
		move_and_slide()

		if not already_hit and player != null:
			var distance := global_position.distance_to(player.global_position)

			if distance <= dash_hit_range:
				already_hit = true

				if player.has_method("take_damage"):
					player.take_damage(dash_damage)

		await get_tree().process_frame

	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("idle")

	await get_tree().create_timer(0.5).timeout

	if dead:
		return

	can_dash = true
	end_attack()
	
func phase_2_circle_player() -> void:
	if player == null:
		return

	var to_player := global_position.direction_to(player.global_position)

	if to_player.length() == 0:
		to_player = Vector2.RIGHT

	var tangent := Vector2(-to_player.y, to_player.x)

	if phase_2_circle_direction < 0:
		tangent = -tangent

	var distance := global_position.distance_to(player.global_position)
	var movement := tangent

	# Move toward player if too far
	if distance > phase_2_circle_distance + 25.0:
		movement += to_player * 1.2

	# Do NOT move away when too close
	# Stay aggressive and circle around the player
	elif distance < 100.0:
		movement += tangent * 0.5

	if movement.length() > 0:
		movement = movement.normalized()

	velocity = movement * current_speed * phase_2_circle_speed
	current_state = BossState.CIRCLE

	phase_2_circle_timer += get_physics_process_delta_time()

	if phase_2_circle_timer >= phase_2_direction_change_time:
		phase_2_circle_direction *= -1.0
		phase_2_circle_timer = 0.0

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 1.2


func phase_three_behavior(distance: float) -> void:
	current_speed = phase_3_speed

	if distance > teleport_trigger_range:
		if teleport_timer.time_left <= 0.0:
			teleport_ambush()
			return

	if distance > phase_3_max_distance:
		chase_player()
		return

	if can_dash and distance <= dash_trigger_range:
		if randf() < phase_3_dash_chance:
			dash_attack()
			return

	if can_place_trap:
		if randf() < phase_3_trap_chance:
			create_trap()
			return

	if distance <= melee_range:
		if can_attack:
			strong_melee_combo()
			return

	circle_player()


func chase_player() -> void:
	if player == null:
		return

	if dead or is_attacking:
		velocity = Vector2.ZERO
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= melee_range:
		velocity = Vector2.ZERO
		play_animation("idle")
		return

	var direction := global_position.direction_to(player.global_position)

	velocity = direction * current_speed
	current_state = BossState.CHASE

	if sprite:
		sprite.play("walk")

		if current_phase == BossPhase.PHASE_3:
			sprite.speed_scale = 2.0
		elif current_phase == BossPhase.PHASE_2:
			sprite.speed_scale = 1.5
		else:
			sprite.speed_scale = 1.0


func retreat_from_player() -> void:
	if player == null:
		return

	if dead or is_attacking:
		velocity = Vector2.ZERO
		return

	var direction := player.global_position.direction_to(global_position)

	if direction.length() == 0:
		direction = Vector2.RIGHT

	velocity = direction * current_speed
	current_state = BossState.CHASE

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 1.5


func circle_player() -> void:
	if player == null:
		return

	current_state = BossState.CIRCLE

	var to_player := global_position.direction_to(player.global_position)

	if to_player.length() == 0:
		to_player = Vector2.RIGHT

	var tangent := Vector2(-to_player.y, to_player.x)

	if circle_direction < 0:
		tangent = -tangent

	var distance := global_position.distance_to(player.global_position)

	var distance_adjustment := 0.0

	if distance > phase_3_circle_distance:
		distance_adjustment = 0.8
	elif distance < phase_3_circle_distance:
		distance_adjustment = -0.8

	var movement := tangent + to_player * distance_adjustment

	if movement.length() > 0:
		movement = movement.normalized()

	velocity = movement * current_speed

	circle_timer += get_physics_process_delta_time()

	if circle_timer >= circle_direction_change_time:
		circle_direction *= -1.0
		circle_timer = 0.0

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 2.0


func stop_moving() -> void:
	velocity = Vector2.ZERO
	current_state = BossState.IDLE

	if sprite and not is_attacking:
		sprite.speed_scale = 1.0
		sprite.play("idle")

func play_animation(animation_name: String) -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if sprite.animation != animation_name:
		sprite.play(animation_name)
	elif not sprite.is_playing():
		sprite.play(animation_name)

func face_player() -> void:
	if player == null or sprite == null:
		return

	if player.global_position.x < global_position.x:
		sprite.flip_h = false
	else:
		sprite.flip_h = true


func choose_melee_attack() -> void:
	if not can_attack:
		return

	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)

	if distance > melee_range + 40.0:
		return

	if combo_available:
		melee_attack_2()
	else:
		melee_attack_1()


func melee_attack_1() -> void:
	if not start_attack():
		return

	combo_available = false
	combo_step = 1
	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack1")

	await get_tree().create_timer(0.25).timeout

	if dead:
		return

	deal_melee_damage(melee_damage_1)

	if sprite:
		await sprite.animation_finished

	combo_available = true
	combo_timer.start(combo_window)

	end_attack()


func melee_attack_2() -> void:
	if dead:
		return

	if not combo_available:
		return

	if not can_attack:
		return

	if not start_attack():
		return

	combo_available = false
	combo_timer.stop()
	combo_step = 2
	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack2")
		await sprite.animation_finished

	if dead:
		return

	deal_melee_damage(melee_damage_2)

	end_attack()


func strong_melee_combo() -> void:
	if not start_attack():
		return

	combo_available = false
	combo_timer.stop()
	combo_step = 0
	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack1")
		await sprite.animation_finished

	if dead:
		return

	combo_step = 1
	deal_melee_damage(melee_damage_1)

	await get_tree().create_timer(0.12).timeout

	if dead:
		return

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack2")
		await sprite.animation_finished

	if dead:
		return

	combo_step = 2
	deal_melee_damage(melee_damage_2)

	end_attack()

	if not dead:
		if can_dash and randf() < 0.60:
			await dash_away_from_player()


func deal_melee_damage(damage: float) -> void:
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)

	var attack_range := melee_range

	if combo_step == 2:
		attack_range += 30.0
	elif combo_step == 3:
		attack_range += 60.0

	if distance <= attack_range:
		if player.has_method("take_damage"):
			var final_damage := damage

			if current_phase == BossPhase.PHASE_3:
				final_damage *= 1.1

			player.take_damage(final_damage)

			print("Boss dealt ", final_damage, " melee damage.")


func teleport_ambush() -> void:
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= teleport_trigger_range:
		return

	if teleport_timer.time_left > 0.0:
		return

	if is_attacking:
		return

	is_attacking = true
	current_state = BossState.TELEPORT
	velocity = Vector2.ZERO

	print("BOSS TELEPORT AMBUSH! Distance: ", distance)

	# Disappear
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("disappear"):
		sprite.speed_scale = 1.0
		sprite.play("disappear")
		await sprite.animation_finished
	else:
		if sprite:
			sprite.visible = false
		await get_tree().create_timer(0.2).timeout

	if dead:
		return

	# Hide during teleport
	if sprite:
		sprite.visible = false

	# Teleport close to player
	var direction := player.global_position.direction_to(global_position)

	if direction.length() == 0:
		direction = Vector2.RIGHT

	var close_distance := 100.0
	global_position = player.global_position + direction.normalized() * close_distance

	# Appear
	if sprite:
		sprite.visible = true

		if sprite.sprite_frames and sprite.sprite_frames.has_animation("appear"):
			sprite.speed_scale = 1.0
			sprite.play("appear")
			await sprite.animation_finished
		else:
			await get_tree().create_timer(0.1).timeout

	if dead:
		return

	# Fast attack after appearing
	await teleport_attack()

	if dead:
		return

	create_trap()

	teleport_timer.start(teleport_cooldown_time)

	is_attacking = false
	current_state = BossState.IDLE
	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0


func teleport_attack() -> void:
	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack1")

		# Small delay so the attack starts quickly
		await get_tree().create_timer(0.12).timeout

	if dead:
		return

	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= melee_range + 30.0:
		if player.has_method("take_damage"):
			var damage := teleport_damage

			if current_phase == BossPhase.PHASE_3:
				damage *= 1.2

			player.take_damage(damage)

			print("Teleport attack hit player for ", damage, " damage.")

	if sprite:
		sprite.speed_scale = 1.0


func create_trap() -> void:
	if not can_place_trap:
		return

	if trap_scene == null:
		print("WARNING: trap_scene is not assigned.")
		return

	if player == null:
		return

	can_place_trap = false

	var trap = trap_scene.instantiate()

	get_parent().add_child(trap)

	var direction := 1.0

	if player.global_position.x < global_position.x:
		direction = -1.0

	trap.global_position = global_position + Vector2(direction * 70.0, 20.0)

	print("BOSS CREATED TRAP!")

	_reset_trap_cooldown()


func _reset_trap_cooldown() -> void:
	await get_tree().create_timer(trap_cooldown).timeout

	if not dead:
		can_place_trap = true


func create_clones() -> void:
	if clone_scene == null:
		print("WARNING: clone_scene is not assigned.")
		return

	if player == null:
		return

	if clones_created:
		return

	clones_created = true

	print("BOSS CREATED TWO CLONES!")

	var positions := [
		Vector2(-180.0, -80.0),
		Vector2(180.0, -80.0)
	]

	for i in range(positions.size()):
		var clone = clone_scene.instantiate()

		get_tree().current_scene.add_child(clone)

		clone.global_position = global_position + positions[i]

		if clone.has_method("setup_with_side"):
			var side := -1.0 if i == 0 else 1.0

			clone.setup_with_side(
				player,
				clone_lifetime,
				side
			)
		elif clone.has_method("setup"):
			clone.setup(
				player,
				clone_lifetime
			)


func dash_attack() -> void:
	if not can_dash:
		return

	if player == null:
		return

	if not start_attack():
		return

	can_dash = false
	current_state = BossState.DASH
	velocity = Vector2.ZERO

	dash_direction = global_position.direction_to(player.global_position)

	if dash_direction.length() == 0:
		dash_direction = Vector2.RIGHT

	print("BOSS DASH ATTACK!")

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("idle")

	await get_tree().create_timer(dash_warning_time).timeout

	if dead:
		return

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 3.0

	var elapsed := 0.0
	var already_hit := false

	while elapsed < dash_duration:
		if dead:
			return

		var delta := get_physics_process_delta_time()
		elapsed += delta

		velocity = dash_direction * dash_speed

		move_and_slide()

		if not already_hit and player != null:
			var distance := global_position.distance_to(player.global_position)

			if distance <= dash_hit_range:
				already_hit = true

				if player.has_method("take_damage"):
					var damage := dash_damage

					if current_phase == BossPhase.PHASE_3:
						damage *= 1.2

					player.take_damage(damage)

					print("Dash hit player for ", damage, " damage.")

		await get_tree().process_frame

	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("idle")

	await get_tree().create_timer(dash_recovery).timeout

	if dead:
		return

	can_dash = true

	end_attack()


func dash_away_from_player() -> void:
	if player == null:
		return

	if dead:
		return

	can_dash = false
	is_attacking = true
	current_state = BossState.DASH

	var direction := player.global_position.direction_to(global_position)

	if direction.length() == 0:
		direction = Vector2.RIGHT

	dash_direction = direction.normalized()

	velocity = Vector2.ZERO

	if sprite:
		sprite.play("walk")
		sprite.speed_scale = 3.0

	var elapsed := 0.0

	while elapsed < 0.35:
		if dead:
			return

		var delta := get_physics_process_delta_time()
		elapsed += delta

		velocity = dash_direction * dash_speed
		move_and_slide()

		await get_tree().process_frame

	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.5
		sprite.play("idle")

	is_attacking = false
	current_state = BossState.CIRCLE

	await get_tree().create_timer(0.5).timeout

	if dead:
		return

	can_dash = true


func get_counter_chance() -> float:
	match current_phase:
		BossPhase.PHASE_1:
			return counter_chance_phase_1

		BossPhase.PHASE_2:
			return counter_chance_phase_2

		BossPhase.PHASE_3:
			return counter_chance_phase_3

	return counter_chance_phase_1


func start_counter() -> void:
	if counter_active:
		return

	if dead:
		return

	counter_active = true
	is_attacking = true
	current_state = BossState.COUNTER
	velocity = Vector2.ZERO

	print("BOSS COUNTER!")

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("idle")
		sprite.modulate = Color(1.0, 0.8, 0.8, 1.0)

	await get_tree().create_timer(counter_duration).timeout

	if dead:
		return

	counter_active = false
	is_attacking = false

	if sprite:
		sprite.modulate = Color.WHITE

	if player != null:
		var distance := global_position.distance_to(player.global_position)

		if distance <= melee_range + 50.0:
			if player.has_method("take_damage"):
				var damage := counter_damage

				if current_phase == BossPhase.PHASE_3:
					damage *= 1.2

				player.take_damage(damage)

				print("Counter hit player for ", damage, " damage.")

	current_state = BossState.IDLE

	attack_timer.start(melee_cooldown)


func start_attack() -> bool:
	if dead:
		return false

	if counter_active:
		return false

	if is_attacking:
		return false

	if not can_attack:
		return false

	can_attack = false
	is_attacking = true
	current_state = BossState.ATTACK
	velocity = Vector2.ZERO

	return true


func end_attack() -> void:
	if dead:
		return

	is_attacking = false
	current_state = BossState.IDLE
	velocity = Vector2.ZERO

	if sprite:
		sprite.speed_scale = 1.0
		sprite.modulate = Color.WHITE

	attack_timer.start(melee_cooldown)


func _on_attack_timer_timeout() -> void:
	if dead:
		return

	can_attack = true


func _on_combo_timer_timeout() -> void:
	combo_available = false
	combo_step = 0


func take_damage(amount: float) -> void:
	if dead:
		return

	if not counter_active:
		var counter_chance := get_counter_chance()

		if randf() < counter_chance:
			start_counter()
			return

	health -= amount

	print("Boss HP: ", health)

	hit_reaction()

	if health <= 0.0:
		die()


func hit_reaction() -> void:
	if dead:
		return

	if is_hurt:
		return

	is_hurt = true

	if sprite:
		sprite.modulate = Color.WHITE

	hurt_timer.start(0.1)


func _on_hurt_timer_timeout() -> void:
	is_hurt = false

	if sprite:
		sprite.modulate = Color.WHITE


func enter_phase_2() -> void:
	current_phase = BossPhase.PHASE_2
	current_state = BossState.CHASE

	current_speed = phase_2_speed

	combo_available = false
	combo_step = 0

	print("BOSS PHASE 2")
	print("DISTANCE + TELEPORT + TRAP ACTIVATED")


func enter_phase_3() -> void:
	current_phase = BossPhase.PHASE_3
	current_state = BossState.ATTACK

	current_speed = phase_3_speed

	combo_available = false
	combo_step = 0

	can_attack = true
	is_attacking = true

	velocity = Vector2.ZERO

	print("BOSS ENTERS FINAL PHASE")
	print("CIRCLE + DASH + TELEPORT + TRAP + CLONES")

	if sprite:
		if sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("enrage"):
				sprite.play("enrage")

		sprite.speed_scale = 1.0

	await get_tree().create_timer(1.5).timeout

	if dead:
		return

	is_attacking = false
	current_state = BossState.CIRCLE

	if sprite:
		sprite.speed_scale = 1.5

	create_clones()


func die() -> void:
	if dead:
		return

	dead = true

	current_state = BossState.DEATH
	velocity = Vector2.ZERO

	attack_timer.stop()
	combo_timer.stop()
	teleport_timer.stop()
	hurt_timer.stop()

	is_attacking = false
	counter_active = false

	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.speed_scale = 1.0
		sprite.play("death")

	print("SHADOW OVERLORD DEFEATED!")

	await get_tree().create_timer(2.0).timeout

	boss_defeated()


func boss_defeated() -> void:
	print("VICTORY!")

	queue_free()
