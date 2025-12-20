extends Area2D

@export var wood_amount: int = 1

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
	
	print("✅ Árvore pronta. Layers: ", collision_layer, " Mask: ", collision_mask)
	print("🌳 Posição: ", global_position)

func _on_self_area_entered(area: Area2D):
	print("\n🌳 Árvore: Área entrou - ", area.name)
	print("🏷️ Grupos da área: ", area.get_groups())
	
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		print("🎯 Árvore: Player entrou na área!")
		player_in_range = true
		highlight(true)
	else:
		print("❌ Árvore: Área não identificada como player_area")

func _on_self_area_exited(area: Area2D):
	# Verificar se é a área do jogador
	if area.is_in_group("player_area") or area.is_in_group("player_harvest"):
		print("🚪 Árvore: Player saiu da área")
		player_in_range = false
		highlight(false)

func highlight(active: bool):
	if not sprite:
		return
	
	if active:
		sprite.modulate = Color(1.1, 1.1, 0.9, 1.0)
		print("✨ Árvore destacada")
	else:
		sprite.modulate = Color.WHITE

func harvest() -> bool:
	print("\n=== 🪓 COLHENDO ÁRVORE ===")
	print("📊 is_collectible: ", is_collectible)
	print("📍 player_in_range: ", player_in_range)
	
	if not is_collectible:
		print("❌ Árvore já foi coletada!")
		return false
	
	if not player_in_range:
		print("❌ Jogador não está na área da árvore!")
		return false
	
	is_collectible = false
	print("✅ Emitindo sinal harvested com ", wood_amount, " madeira")
	
	# Emitir sinal ANTES do efeito visual
	harvested.emit(wood_amount)
	
	# Efeito visual
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.5)
		await tween.finished
	
	return_to_pool()
	return true

func return_to_pool():
	print("🔄 Árvore retornando à pool...")
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
	print("♻️ Árvore resetada")
