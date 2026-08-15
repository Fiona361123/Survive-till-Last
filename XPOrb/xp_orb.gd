extends Area2D

@export var xp_value: int = 5
@export var attract_radius: float = 120.0
@export var move_speed: float = 200.0

var player: Node2D = null
var _pulse_time: float = 0.0
var _attracted: bool = false

@export var card_texture: Texture2D
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("xp_orb")
	monitoring = true
	monitorable = false
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)
	
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Keep pixel art crisp!
	
	if card_texture:
		_sprite.texture = card_texture
		_sprite.scale = Vector2(2.0, 2.0) # Double the size of the pixel art chest so it's easy to see
	else:
		_sprite.texture = load("res://XPOrb/Screenshot 2026-08-15 180045.png")
		_sprite.scale = Vector2(2.0, 2.0) # Shrink the default icon so it's not huge
		
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_pulse_time += delta

	# Add a slight hovering bounce animation to the card
	if _sprite:
		var bounce := sin(_pulse_time * 4.0) * 5.0
		_sprite.position.y = bounce

	if player == null:
		return

	var dist := global_position.distance_to(player.global_position)
	var total_radius: float = attract_radius
	if "xp_attract_bonus" in player:
		total_radius += float(player.xp_attract_bonus)
		
	if dist <= total_radius:
		_attracted = true

	if _attracted:
		var dir := (player.global_position - global_position).normalized()
		var speed: float = move_speed + (total_radius - dist) * 2.0
		global_position += dir * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("open_chest"):
		body.open_chest()
		queue_free()
