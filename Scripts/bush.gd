extends Area2D

@export var food_amount: int = 1
@export var drop_seed_chance: float = 0.9  # 90% chance
@export var seed_drop_amount: int = 1
@export var can_drop_seeds: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_collectible: bool = true
var player_in_range: bool = false

signal harvested(amount: int)
var health = 2
func _ready():
	# Conectar sinais
	area_entered.connect(_on_self_area_entered)
	area_exited.connect(_on_self_area_exited)
	
	# Adicionar grupos
	add_to_group("bush")
	add_to_group("collectible")
	add_to_group("resource")
	
	print("Arbusto pronto. Posição: ", global_position)
	print("Configuração de drop: ", drop_seed_chance * 100, "% chance, ", seed_drop_amount, " semente(s)")

func _on_self_area_entered(area: Area2D):
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		player_in_range = true
		highlight(true)
	else:
		print("Arbusto: Área não identificada como player_area")

func _on_self_area_exited(area: Area2D):
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		print("Arbusto: Player saiu da área")
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
	print("\n=== COLHENDO ARBUSTO ===")
	print("Posição: ", global_position)
	print("É coletável: ", is_collectible)
	print("Player na área: ", player_in_range)
	print("Chance de drop: ", drop_seed_chance * 100, "%")
	print("Pode dropar: ", can_drop_seeds)
	
	if not is_collectible:
		return false
	
	if not player_in_range:
		return false
	
	is_collectible = false
	
	# Emitir sinal ANTES do efeito visual
	harvested.emit(food_amount)
	
	# SISTEMA DE DROP DIRETO NO ARBUSTO
	if can_drop_seeds and randf() < drop_seed_chance:
		ResourceManager.add_bush_seed(seed_drop_amount)
		print("✓ DROP CONFIRMADO: ", seed_drop_amount, " semente(s) de arbusto!")
		print("Total de sementes agora: ", ResourceManager.bush_seeds)
	else:
		print("✗ Nenhuma semente dropada desta vez")
	
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
		sprite.modulate = Color.WHITE
		sprite.modulate.a = 1.0
		sprite.scale = Vector2.ONE
	
	if collision:
		collision.disabled = false
	
	show()
	print("Arbusto resetado para nova plantação")
	
	
func take_damage():
	health -= 1
	# Efeito visual
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
