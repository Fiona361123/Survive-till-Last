extends CharacterBody2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

@export_category("Clone Settings")
@export var lifetime: float = 25.0
@export var move_speed: float = 75.0
@export var stop_distance: float = 50.0

@export_category("Clone Attack")
@export var attack_range: float = 65.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 0.25

@export_category("Appear")
@export var appear_time: float = 0.6

@export_category("Disappear")
@export var disappear_time: float = 0.4

var player: Node2D = null
var real_player: Node2D = null
var target_refresh_timer: float = 0.0
const TARGET_REFRESH_INTERVAL: float = 0.1

var dying: bool = false
var appearing: bool = true
var attacking: bool = false
var can_attack: bool = true

var lifetime_started: bool = false
var attack_id: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if real_player == null:
		real_player = get_tree().get_first_node_in_group("player")
	_refresh_combat_target()

	# Make clone unable to physically block the player
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if sprite:
		sprite.visible = true
		sprite.speed_scale = 1.0

		if sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("appear"):
				sprite.play("appear")
			elif sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")

	play_appear_animation()
	start_lifetime()


func setup(target_player: Node2D, duration: float) -> void:
	real_player = target_player
	_refresh_combat_target()
	lifetime = duration

	if lifetime_started:
		return

	start_lifetime()


func play_appear_animation() -> void:
	appearing = true
	velocity = Vector2.ZERO

	if sprite == null:
		appearing = false
		return

	if sprite.sprite_frames == null:
		appearing = false
		return

	if sprite.sprite_frames.has_animation("appear"):
		sprite.speed_scale = 1.0
		sprite.play("appear")

		await sprite.animation_finished
	else:
		await get_tree().create_timer(appear_time).timeout

	if dying:
		return

	appearing = false
	play_animation("idle")


func start_lifetime() -> void:
	if lifetime_started:
		return

	lifetime_started = true

	await get_tree().create_timer(lifetime).timeout

	if not is_instance_valid(self):
		return

	if dying:
		return

	disappear()


func _physics_process(delta: float) -> void:
	if dying:
		velocity = Vector2.ZERO
		return

	if appearing:
		velocity = Vector2.ZERO
		return

	if attacking:
		velocity = Vector2.ZERO
		return

	if real_player == null or not is_instance_valid(real_player):
		real_player = get_tree().get_first_node_in_group("player")

	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0 or player == null or not is_instance_valid(player):
		_refresh_combat_target()

	if player == null:
		velocity = Vector2.ZERO
		play_animation("idle")
		return

	face_player()

	var distance := global_position.distance_to(player.global_position)

	# Attack when close enough
	if distance <= attack_range:
		velocity = Vector2.ZERO

		if can_attack:
			clone_attack()
		else:
			play_animation("idle")

		return

	# Move toward player
	if distance > attack_range:
		var direction := global_position.direction_to(player.global_position)

		velocity = direction * move_speed
		move_and_slide()

		play_animation("walk")
		return


func _refresh_combat_target() -> void:
	target_refresh_timer = TARGET_REFRESH_INTERVAL
	player = COMBAT_TARGET_SELECTOR.choose_target(self, real_player)


func clone_attack() -> void:
	if attacking:
		return

	if not can_attack:
		return

	if dying:
		return

	if appearing:
		return

	if player == null or not is_instance_valid(player):
		return

	can_attack = false
	attacking = true

	velocity = Vector2.ZERO

	attack_id += 1
	var current_attack := attack_id

	face_player()

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack")

	await get_tree().create_timer(attack_windup).timeout

	if dying:
		return

	if current_attack != attack_id:
		return

	if player == null or not is_instance_valid(player):
		attacking = false
		can_attack = true
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= attack_range + 15.0:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

			print("CLONE ATTACKED PLAYER FOR ", attack_damage, " DAMAGE")

	await wait_for_attack_animation()

	if dying:
		return

	if current_attack != attack_id:
		return

	attacking = false
	play_animation("idle")

	# No retreat.
	# Clone stays near the player and attacks again after cooldown.
	start_attack_cooldown()


func start_attack_cooldown() -> void:
	if dying:
		return

	await get_tree().create_timer(attack_cooldown).timeout

	if dying:
		return

	can_attack = true


func wait_for_attack_animation() -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation("attack"):
		return

	if sprite.animation != "attack":
		return

	await sprite.animation_finished


func face_player() -> void:
	if player == null:
		return

	if sprite == null:
		return

	if player.global_position.x < global_position.x:
		sprite.flip_h = false
	else:
		sprite.flip_h = true


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


func disappear() -> void:
	if dying:
		return

	dying = true
	appearing = false
	attacking = false
	can_attack = false
	velocity = Vector2.ZERO

	print("CLONE DISAPPEARING")

	attack_id += 1

	if sprite:
		sprite.speed_scale = 1.0

		if sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("disappear"):
				sprite.play("disappear")

				await get_tree().create_timer(disappear_time).timeout

	if is_instance_valid(self):
		queue_free()
