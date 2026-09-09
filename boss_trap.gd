extends Area2D

const COMBAT_TARGET_SELECTOR = preload("res://systems/combat_target_selector.gd")

@export_category("Trap Settings")
@export var attack_range: float = 60.0
@export var damage: int = 25

@export_category("Timing")
@export var seed_delay: float = 1.2
@export var grow_delay: float = 0.2
@export var idle_time: float = 0.8
@export var attack_windup: float = 0.15

@export_category("Hit Detection")
@export var damage_range_bonus: float = 20.0

@export_category("Animation")
@export var disappear_time: float = 0.4

var player: Node2D = null
var real_player: Node2D = null
var target_refresh_timer: float = 0.0
const TARGET_REFRESH_INTERVAL: float = 0.1

var has_attacked: bool = false
var is_attacking: bool = false
var ready_to_attack: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if real_player == null:
		real_player = get_tree().get_first_node_in_group("player")
	_refresh_combat_target()

	if sprite == null:
		return

	sprite.speed_scale = 1.0
	sprite.play("seed")

	await get_tree().create_timer(seed_delay).timeout

	if not is_instance_valid(self):
		return

	grow_trap()


func grow_trap() -> void:
	if sprite == null:
		return

	sprite.speed_scale = 1.0
	sprite.play("grow")

	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("grow"):
			await sprite.animation_finished

	if not is_instance_valid(self):
		return

	await get_tree().create_timer(grow_delay).timeout

	if not is_instance_valid(self):
		return

	sprite.play("idle")

	ready_to_attack = true

	await get_tree().create_timer(idle_time).timeout

	if not is_instance_valid(self):
		return


func _process(delta: float) -> void:
	if not ready_to_attack:
		return

	if has_attacked:
		return

	if is_attacking:
		return

	if real_player == null or not is_instance_valid(real_player):
		real_player = get_tree().get_first_node_in_group("player")

	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0 or player == null or not is_instance_valid(player):
		_refresh_combat_target()

	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= attack_range:
		attack_player()


func setup(target_player: Node2D) -> void:
	real_player = target_player
	_refresh_combat_target()


func _refresh_combat_target() -> void:
	target_refresh_timer = TARGET_REFRESH_INTERVAL
	player = COMBAT_TARGET_SELECTOR.choose_target(self, real_player)


func attack_player() -> void:
	if is_attacking:
		return

	if has_attacked:
		return

	if dying():
		return

	if player == null or not is_instance_valid(player):
		return

	is_attacking = true
	has_attacked = true
	ready_to_attack = false

	face_player()

	if sprite:
		sprite.speed_scale = 1.0
		sprite.play("attack")

	await get_tree().create_timer(attack_windup).timeout

	if not is_instance_valid(self):
		return

	if player == null or not is_instance_valid(player):
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= attack_range + damage_range_bonus:
		deal_damage()

	if sprite and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("attack"):
			if sprite.animation == "attack":
				await sprite.animation_finished

	if not is_instance_valid(self):
		return

	disappear()


func deal_damage() -> void:
	if player == null:
		return

	if not is_instance_valid(player):
		return

	if player.has_method("take_damage"):
		player.take_damage(damage)

		print("TRAP HIT PLAYER FOR ", damage, " DAMAGE")


func face_player() -> void:
	if player == null:
		return

	if sprite == null:
		return

	if player.global_position.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false


func disappear() -> void:
	if not is_instance_valid(self):
		return

	ready_to_attack = false
	is_attacking = true

	if sprite:
		sprite.speed_scale = 1.0

		if sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("disappear"):
				sprite.play("disappear")

				await sprite.animation_finished
			else:
				await get_tree().create_timer(disappear_time).timeout

	if is_instance_valid(self):
		queue_free()


func dying() -> bool:
	return not is_instance_valid(self)
