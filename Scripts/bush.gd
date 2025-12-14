# Bush.gd - VERSÃO CORRIGIDA (sem verificação de conexão)
extends Area2D

@export var food_amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_collectible: bool = true
var player_in_range: bool = false

signal harvested(amount: int)

func _ready():
	collision_layer = 2
	collision_mask = 1
	
	area_entered.connect(_on_self_area_entered)
	area_exited.connect(_on_self_area_exited)
	
	add_to_group("bush")
	add_to_group("collectible")
	

func reset():
	is_collectible = true
	player_in_range = false
	
	if sprite:
		sprite.modulate = Color.GREEN  # Cor para debug
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
		sprite.show()
	
	if collision:
		collision.disabled = false
	
	show()

func _on_self_area_entered(area: Area2D):
	if area.is_in_group("player_harvest"):
		player_in_range = true
		highlight(true)

func _on_self_area_exited(area: Area2D):
	if area.is_in_group("player_harvest"):
		player_in_range = false
		highlight(false)

func highlight(active: bool):
	if not sprite:
		return
	
	if active:
		sprite.modulate = Color(1.0, 1.0, 0.8, 1.0)
	else:
		sprite.modulate = Color.GREEN  # Volta para cor debug

func harvest() -> bool:
	if not is_collectible or not player_in_range:
		return false
	
	is_collectible = false
	harvested.emit(food_amount)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.3)
		await tween.finished
	
	return_to_pool()
	return true

func return_to_pool():
	PoolManager.return_object(self, "bush")
