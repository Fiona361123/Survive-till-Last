extends Area2D

@export var float_amplitude: float = 5.0
@export var float_speed: float = 3.0
@export var attract_radius: float = 120.0
@export var move_speed: float = 200.0

var player: Node2D = null
var is_collected: bool = false
var start_position: Vector2
var float_time: float = 0.0
var _attracted: bool = false

func _ready() -> void:
	start_position = global_position
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)
	
	# Small delay before it can be collected
	var t = Timer.new()
	t.wait_time = 0.5
	t.one_shot = true
	t.timeout.connect(func(): if has_node("CollisionShape2D"): get_node("CollisionShape2D").disabled = false)
	add_child(t)
	t.start()
	
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").disabled = true

func _physics_process(delta: float) -> void:
	if is_collected: return
	
	if player != null:
		var dist := global_position.distance_to(player.global_position)
		var total_radius: float = attract_radius
		if "xp_attract_bonus" in player:
			total_radius += float(player.xp_attract_bonus)
			
		if dist <= total_radius:
			_attracted = true
			
		if _attracted:
			var dir = (player.global_position - global_position).normalized()
			global_position += dir * move_speed * delta
			move_speed += 150.0 * delta
			return
			
	# Floating effect
	float_time += delta
	var float_offset = sin(float_time * float_speed) * float_amplitude
	global_position.y = start_position.y + float_offset

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_collected:
		is_collected = true
		if body.has_method("open_chest"):
			body.open_chest(3)
		_create_effect()
		queue_free()

func _create_effect() -> void:
	var flash = ColorRect.new()
	flash.size = Vector2(30, 30)
	flash.color = Color(1, 0.8, 0.2, 0.8)
	flash.position = global_position - Vector2(15, 15)
	get_tree().current_scene.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(3, 3), 0.2)
	tween.parallel().tween_property(flash, "color", Color(1, 1, 1, 0), 0.2)
	tween.chain().tween_callback(flash.queue_free)
