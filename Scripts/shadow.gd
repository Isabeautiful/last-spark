extends CharacterBody2D

@export var speed: float = 50.0
var target_position: Vector2

@onready var sprite = $Sprite2D

signal destroyed()

func _ready():
	add_to_group("shadow")
	add_to_group("enemy")
	target_position = Vector2.ZERO

func reset():
	if sprite:
		sprite.modulate.a = 1.0
		sprite.modulate = Color.WHITE
	velocity = Vector2.ZERO
	target_position = Vector2.ZERO
	global_position = Vector2(-10000, -10000)

func setup_spawn_position(spawn_center: Vector2, spawn_distance: float):
	var spawn_angle = randf_range(0, 2 * PI)
	global_position = spawn_center + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_distance
	
	var fire = get_tree().get_first_node_in_group("fire")
	if fire:
		target_position = fire.global_position

func _physics_process(delta):
	if target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		if global_position.distance_to(target_position) < 20:
			_on_reached_fire()

func _on_area_entered(area: Area2D):
	if area.is_in_group("fire_light"):
		print("Sombra dissipada pela luz!")
		destroy()
	elif area.is_in_group("fire_core"):
		_on_reached_fire()

func _on_reached_fire():
	var fire = get_tree().get_first_node_in_group("fire")
	if fire and fire.has_method("take_damage"):
		fire.take_damage(10)
	destroy()

func destroy():
	velocity = Vector2.ZERO
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tween.finished
	
	destroyed.emit()
	return_to_pool()

func return_to_pool():
	PoolManager.return_object(self, "shadow")
