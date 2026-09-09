class_name Level1Bomb
extends Node2D

@export var blast_damage: int = 25
@export var is_real_bomb: bool = true
@export var trigger_distance: float = 55.0

@onready var blast_area: TrapDamageArea = $BlastArea
@onready var attack_area: Area2D = $AttackArea

var _exploded: bool = false
var player: Node2D = null


func _ready() -> void:
	# Find the player
	player = get_tree().get_first_node_in_group("player")

	# Keep projectile/Area2D activation
	if attack_area != null:
		attack_area.body_entered.connect(_on_attack_area_body_entered)


func _physics_process(_delta: float) -> void:
	if _exploded:
		return

	if not is_real_bomb:
		return

	# Find player if it wasn't available during _ready()
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	# Check distance between player and bomb
	if global_position.distance_to(player.global_position) <= trigger_distance:
		_exploded = true
		_explode()


# Activated by projectile
func take_damage(_amount: int) -> void:
	if _exploded:
		return

	if not is_real_bomb:
		return

	_exploded = true
	_explode()


# Activated by AttackArea
func _on_attack_area_body_entered(body: Node2D) -> void:
	if _exploded:
		return

	if not is_real_bomb:
		return

	if body.is_in_group("player"):
		_exploded = true
		_explode()


func _explode() -> void:
	blast_area.begin_activation(blast_damage)

	await get_tree().physics_frame

	blast_area.damage_overlapping_bodies()

	blast_area.end_activation()

	queue_free()
