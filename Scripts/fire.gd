extends Node2D

@export var max_energy: float = 100.0
@export var consumption_rate: float = 1.0
var current_energy: float = 100.0

@onready var light_area = $LightArea
@onready var energy_bar = get_node("/root/Game/InGameHUD/CanvasLayer/MarginContainer/VBoxContainer/EnergyBar") if get_node("/root/Game/InGameHUD") else null

func _ready():
	current_energy = max_energy
	update_energy_bar()
	add_to_group("fire")
	
	if light_area:
		light_area.add_to_group("fire_light")
	
	# Área central para dano
	var core_area = Area2D.new()
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 20
	core_area.add_child(collision)
	core_area.add_to_group("fire_core")
	add_child(core_area)
	
	# Área de interação para o jogador
	var interaction_area = Area2D.new()
	var interaction_collision = CollisionShape2D.new()
	interaction_collision.shape = CircleShape2D.new()
	interaction_collision.shape.radius = 40
	interaction_area.add_child(interaction_collision)
	interaction_area.add_to_group("fire_interaction")
	add_child(interaction_area)

func _process(delta):
	current_energy -= consumption_rate * delta
	current_energy = max(current_energy, 0)
	
	if light_area:
		var energy_percent = current_energy / max_energy
		light_area.scale = Vector2.ONE * energy_percent
		light_area.modulate.a = energy_percent * 0.8  # Luz fica mais fraca com menos energia
	
	update_energy_bar()
	
	if current_energy <= 0:
		game_over()

func take_damage(amount: float):
	current_energy = max(current_energy - amount, 0)
	update_energy_bar()
	$Sprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$Sprite2D.modulate = Color.WHITE
	print("Fogo tomou dano! Energia: ", current_energy)

func add_fuel(amount: float):
	current_energy = min(current_energy + amount, max_energy)
	update_energy_bar()
	print("Combustível adicionado! +", amount, " energia. Total: ", current_energy)

# NOVA FUNÇÃO: Adicionar combustível do inventário
func add_fuel_from_inventory() -> bool:
	if ResourceManager.wood > 0:
		var wood_to_use = 1  # Usa 1 madeira por vez
		var energy_per_wood = 25.0  # Cada madeira dá 25 de energia
		
		if ResourceManager.use_wood(wood_to_use):
			add_fuel(energy_per_wood)
			return true
		else:
			print("Sem madeira para alimentar o fogo!")
			return false
	else:
		print("Sem madeira no inventário!")
		return false

func update_energy_bar():
	if energy_bar:
		energy_bar.value = (current_energy / max_energy) * 100
		if energy_bar.has_node("Label"):
			energy_bar.get_node("Label").text = str(int(current_energy)) + "/" + str(int(max_energy))

func game_over():
	print("GAME OVER: A chama se apagou!")
	GameSignals.game_over.emit("A chama se apagou!")
