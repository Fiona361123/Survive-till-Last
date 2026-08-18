extends Area2D

## Amount of HP restored when picked up
@export var heal_amount: int = 15

@export var attract_radius: float = 80.0
@export var move_speed: float = 180.0

var player: Node2D = null
var _pulse_time: float = 0.0
var _attracted: bool = false
var _orb: Node2D       # visual container that bobs
var _label: Label

func _ready() -> void:
	add_to_group("hp_orb")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

	# Visual container for bobbing
	_orb = Node2D.new()
	add_child(_orb)

	# Small red circle as the orb body (16px radius)
	var circle = Polygon2D.new()
	var pts: PackedVector2Array = []
	var r := 10.0
	for i in 32:
		var a := (float(i) / 32.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
	circle.polygon = pts
	circle.color = Color(0.9, 0.15, 0.15)
	_orb.add_child(circle)

	# White cross on top (+)
	var h_bar = Polygon2D.new()
	h_bar.polygon = PackedVector2Array([
		Vector2(-7, -2.5), Vector2(7, -2.5),
		Vector2(7,  2.5), Vector2(-7,  2.5)
	])
	h_bar.color = Color.WHITE
	_orb.add_child(h_bar)

	var v_bar = Polygon2D.new()
	v_bar.polygon = PackedVector2Array([
		Vector2(-2.5, -7), Vector2(2.5, -7),
		Vector2(2.5,  7), Vector2(-2.5,  7)
	])
	v_bar.color = Color.WHITE
	_orb.add_child(v_bar)

	# "+15" label above
	_label = Label.new()
	_label.text = "+" + str(heal_amount)
	_label.position = Vector2(-12, -28)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	add_child(_label)

	# Collision circle
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	_pulse_time += delta

	# Bob the visual up and down
	if _orb:
		_orb.position.y = sin(_pulse_time * 4.0) * 4.0

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(player.global_position)
	var total_radius: float = attract_radius
	if "xp_attract_bonus" in player:
		total_radius += float(player.xp_attract_bonus) * 0.5

	if dist <= total_radius:
		_attracted = true

	if _attracted:
		var dir := (player.global_position - global_position).normalized()
		var speed: float = move_speed + (total_radius - dist) * 2.0
		global_position += dir * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("heal"):
		body.heal(heal_amount)
		queue_free()