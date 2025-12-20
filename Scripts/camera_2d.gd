extends Camera2D

@export var target: Node2D
@export var zoom_min: Vector2 = Vector2(0.8, 0.8)
@export var zoom_max: Vector2 = Vector2(1.2, 1.2)

func _ready():
	if target:
		global_position = target.global_position

func _process(delta):
	if target:
		global_position = global_position.lerp(target.global_position, 10 * delta)
		
