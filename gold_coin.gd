extends Area2D

@export var value: int = 1

var is_collected: bool = false
var attract_speed: float = 150.0
var min_attract_speed: float = 150.0
var max_attract_speed: float = 800.0
var acceleration: float = 800.0
var player_target = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if animated_sprite.sprite_frames.has_animation("idle_loop"):
		animated_sprite.play("idle_loop")
	else:
		animated_sprite.play("idle")
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]

func _process(delta: float) -> void:
	if is_collected:
		return
		
	if player_target != null and is_instance_valid(player_target):
		var distance = global_position.distance_to(player_target.global_position)
		var attract_radius = 80.0
		if player_target.get("xp_attract_bonus") != null:
			attract_radius += player_target.xp_attract_bonus
			
		if distance < attract_radius:
			attract_speed = min(attract_speed + acceleration * delta, max_attract_speed)
			var direction = (player_target.global_position - global_position).normalized()
			global_position += direction * attract_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		is_collected = true
		if SaveSystem.has_method("add_gold_coins"):
			SaveSystem.add_gold_coins(value)
		
		if get_node_or_null("/root/AudioManager"): get_node("/root/AudioManager").play_coin()
		
		# Show floating text
		if body.has_method("_spawn_floating_text"):
			body._spawn_floating_text("+" + str(value) + " Gold Coin", Color(1.0, 0.8, 0.0), 16, Vector2(-30, -50))
			
		queue_free()
