extends Area2D

@export var food_amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_collectible: bool = true
var player_in_range: bool = false

signal harvested(amount: int)

func _ready():
	# Conectar sinais
	area_entered.connect(_on_self_area_entered)
	area_exited.connect(_on_self_area_exited)
	
	# Adicionar grupos
	add_to_group("bush")
	add_to_group("collectible")
	add_to_group("resource")

func _on_self_area_entered(area: Area2D):
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		player_in_range = true
		highlight(true)
	else:
		print("❌ Arbusto: Área não identificada como player_area")

func _on_self_area_exited(area: Area2D):
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		print("🚪 Arbusto: Player saiu da área")
		player_in_range = false
		highlight(false)

func highlight(active: bool):
	if not sprite:
		return
	
	if active:
		sprite.modulate = Color(1.0, 1.0, 0.8, 1.0)
	else:
		sprite.modulate = Color.GREEN

func harvest() -> bool:
	if not is_collectible:
		return false
	
	if not player_in_range:
		return false
	
	is_collectible = false
	
	# Emitir sinal ANTES do efeito visual
	harvested.emit(food_amount)
	
	# Efeito visual
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.5)
		await tween.finished
	
	return_to_pool()
	return true

func return_to_pool():
	PoolManager.return_object(self, "bush")

func reset():
	is_collectible = true
	player_in_range = false
	
	if sprite:
		sprite.modulate = Color.GREEN
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
	
	if collision:
		collision.disabled = false
	
	show()
