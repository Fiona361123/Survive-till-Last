extends Area2D

@export var xp_value: int = 15
@export var heal_bonus: int = 0      # Extra HP healed on pickup
@export var is_level_up_coin: bool = false # If true, gives level up directly
@export var picks_to_grant: int = 1  # Number of picks to grant (1 for slime, 3 for ranged enemy)
@export var collect_range: float = 50.0
@export var animation_name: String = "idle"
@export var collection_delay: float = 2.5

@export var float_duration: float = 1.0
@export var float_amplitude: float = 10.0
@export var float_speed: float = 30.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var timer = $Timer
@onready var collision_shape = $CollisionShape2D

# PLAYER REFERENCE
var player: Node2D = null
var can_collect: bool = false
var is_collected: bool = false

# MOVEMENT VARIABLES
var start_position: Vector2 = Vector2.ZERO
var float_time: float = 0.0
var is_floating: bool = true


func _ready():
	start_position = global_position
	player = get_tree().get_first_node_in_group("player")

	# PLAY ANIMATION
	if animated_sprite != null:
		if animated_sprite.sprite_frames.has_animation(animation_name):
			animated_sprite.play(animation_name)
		else:
			var animations = animated_sprite.sprite_frames.get_animation_names()
			if animations.size() > 0:
				animated_sprite.play(animations[0])

	# DISABLE COLLISION UNTIL READY
	if collision_shape != null:
		collision_shape.disabled = true

	# CONNECT SIGNALS
	timer.timeout.connect(_on_timer_timeout)
	body_entered.connect(_on_body_entered)

	timer.wait_time = collection_delay
	timer.start()


func _physics_process(delta):
	if is_collected:
		return
	
	# FLOATING EFFECT (only for the first float_duration seconds)
	if is_floating:
		float_time += delta
		var float_offset = sin(float_time * float_speed) * float_amplitude
		global_position.y = start_position.y + float_offset

		if float_time >= float_duration:
			is_floating = false
			global_position.y = start_position.y


func _collect():
	if is_collected:
		return
	
	is_collected = true
	
	if is_level_up_coin:
		if player != null and player.has_method("open_chest"):
			player.open_chest(picks_to_grant)
	else:
		if player != null and player.has_method("add_xp"):
			player.add_xp(xp_value, heal_bonus)
	
	_create_collect_effect()
	queue_free()


func _create_collect_effect():
	var particles = GPUParticles2D.new()
	
	var particle_material = ParticleProcessMaterial.new()
	
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 360.0
	particle_material.gravity = Vector3(0, 0, 0)
	particle_material.initial_velocity_min = 50.0
	particle_material.initial_velocity_max = 150.0
	
	particles.process_material = particle_material
	particles.amount = 25
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = global_position
	
	get_tree().current_scene.add_child(particles)
	
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(particles):
		particles.queue_free()


func _create_simple_effect():
	var flash = ColorRect.new()
	flash.size = Vector2(30, 30)
	flash.color = Color(1, 0.8, 0.2, 0.8)
	flash.position = global_position - Vector2(15, 15)
	get_tree().current_scene.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(3, 3), 0.2)
	tween.parallel().tween_property(flash, "color", Color(1, 1, 1, 0), 0.2)
	await tween.finished
	flash.queue_free()


func _on_timer_timeout():
	can_collect = true
	if collision_shape != null:
		collision_shape.disabled = false


func _on_body_entered(body):
	if body.is_in_group("player") and can_collect and not is_collected:
		_collect()


func set_xp(value: int):
	xp_value = value
