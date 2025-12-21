extends Area2D

@export var wood_amount: int = 1
@export var drop_seed_chance: float = 0.5  # 50% chance
@export var seed_drop_amount: int = 1
@export var can_drop_seeds: bool = true

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
	add_to_group("tree")
	add_to_group("collectible")
	add_to_group("resource")
	
	print("Árvore pronta. Layers: ", collision_layer, " Mask: ", collision_mask)
	print("Posição: ", global_position)
	print("Configuração de drop: ", drop_seed_chance * 100, "% chance, ", seed_drop_amount, " semente(s)")

func _on_self_area_entered(area: Area2D):
	print("\nrvore: Área entrou - ", area.name)
	print("Grupos da área: ", area.get_groups())
	
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		print("Árvore: Player entrou na área!")
		player_in_range = true
		highlight(true)
	else:
		print("Arvore: Área não identificada como player_area")

func _on_self_area_exited(area: Area2D):
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		print("Árvore: Player saiu da área")
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
	print("\n=== COLHENDO ÁRVORE ===")
	print("Posição: ", global_position)
	print("É coletável: ", is_collectible)
	print("Player na área: ", player_in_range)
	print("Chance de drop: ", drop_seed_chance * 100, "%")
	print("Pode dropar: ", can_drop_seeds)
	print("Quantidade de sementes por drop: ", seed_drop_amount)
	
	if not is_collectible:
		print("Árvore já foi coletada!")
		return false
	
	if not player_in_range:
		print("Jogador não está na área da árvore!")
		return false
	
	is_collectible = false
	print("Emitindo sinal harvested com ", wood_amount, " madeira")
	
	# Emitir sinal ANTES do efeito visual
	harvested.emit(wood_amount)
	
	# SISTEMA DE DROP DIRETO NA ÁRVORE
	if can_drop_seeds and randf() < drop_seed_chance:
		ResourceManager.add_tree_seed(seed_drop_amount)
		print("✓ DROP CONFIRMADO: ", seed_drop_amount, " semente(s) de árvore!")
		print("Total de sementes agora: ", ResourceManager.tree_seeds)
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
	print("Arvore retornando à pool...")
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
	print("Árvore resetada para nova plantação")
