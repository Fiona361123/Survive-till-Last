extends StaticBody2D

@export var player: CharacterBody2D

@export var min_x := -10000.0
@export var max_x := 10000.0
@export var min_y := -10000.0
@export var max_y := 10000.0

func _physics_process(_delta):
	if player == null:
		return

	player.global_position.x = clamp(player.global_position.x, min_x, max_x)
	player.global_position.y = clamp(player.global_position.y, min_y, max_y)
