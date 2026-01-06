extends Area2D

@export var wood_amount: int = 3
@export var drop_seed_chance: float = 0.5  # 50% chance
@export var seed_drop_amount: int = 5
@export var can_drop_seeds: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_collectible: bool = true
var player_in_range: bool = false

signal harvested(amount: int)
var health = 3

func _ready():
	area_entered.connect(_on_self_area_entered)
	area_exited.connect(_on_self_area_exited)
	
	add_to_group("tree")
	add_to_group("collectible")
	add_to_group("resource")

func _on_self_area_entered(area: Area2D):
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		player_in_range = true
		highlight(true)
	else:
		print("Árvore: Área não identificada como player_area")

func _on_self_area_exited(area: Area2D):
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		player_in_range = false
		highlight(false)

func highlight(active: bool):
	if not sprite:
		return
	
	if active:
		sprite.modulate = Color(1.1, 1.1, 0.9, 1.0)
	else:
		sprite.modulate = Color.WHITE

func harvest() -> bool:
	if not is_collectible:
		return false
	
	if not player_in_range:
		return false
	
	is_collectible = false
	harvested.emit(wood_amount)

	if can_drop_seeds and randf() < drop_seed_chance:
		ResourceManager.add_tree_seed(seed_drop_amount)

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.5)
		await tween.finished
	
	return_to_pool()
	return true

func return_to_pool():
	PoolManager.return_object(self, "tree")

func reset():
	is_collectible = true
	player_in_range = false
	
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
	
	if collision:
		collision.disabled = false
	
	show()

func take_damage():
	health -= 1
	audio_stream_player_2d.play()
	sprite.modulate = Color.RED
	shake()
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if health == 0:
		return await harvest()

func shake():
	var intensidade = 5
	var duracao = 0.15
	var original_pos = position
	var tween = create_tween()
	for i in range(10):
		var offset = Vector2(
			randf_range(-intensidade, intensidade),
			randf_range(-intensidade, intensidade)
		)
		tween.tween_property(self, "position", original_pos + offset, duracao / 10)
	tween.tween_property(self, "position", original_pos, duracao / 10)

func get_planting_config() -> Dictionary:
	return {
		"drop_seed_chance": drop_seed_chance,
		"seed_drop_amount": seed_drop_amount,
		"can_drop_seeds": can_drop_seeds,
		"size": Vector2(32, 32), 
		"color": Color(0.6, 0.4, 0.2, 0.5) 
	}
