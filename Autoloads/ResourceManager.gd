extends Node

# Variáveis de recursos expandidas
var wood: int = 200
var food: int = 90
var stone: int = 10
var crystal: int = 0
var current_population: int = 3
var max_population: int = 5

# Limites de recursos
var max_wood: int = 200
var max_food: int = 100
var max_stone: int = 50
var max_crystal: int = 20

# Sinais
signal wood_changed(amount)
signal food_changed(amount)
signal stone_changed(amount)
signal crystal_changed(amount)
signal population_changed(amount)
signal resource_added(type: String, amount: int)

func _ready():
	GameSignals.resource_collected.connect(_on_resource_collected)
	print("ResourceManager iniciado")

func _on_resource_collected(resource_type: String, amount: int, position: Vector2):
	match resource_type:
		"wood":
			add_wood(amount)
		"food":
			add_food(amount)
		"stone":
			add_stone(amount)
		"crystal":
			add_crystal(amount)

func add_wood(amount: int):
	wood = min(wood + amount, max_wood)
	wood_changed.emit(wood)
	resource_added.emit("wood", amount)

func add_food(amount: int):
	food = min(food + amount, max_food)
	food_changed.emit(food)
	resource_added.emit("food", amount)

func add_stone(amount: int):
	stone = min(stone + amount, max_stone)
	stone_changed.emit(stone)
	resource_added.emit("stone", amount)

func add_crystal(amount: int):
	crystal = min(crystal + amount, max_crystal)
	crystal_changed.emit(crystal)
	resource_added.emit("crystal", amount)

func use_wood(amount: int) -> bool:
	if wood >= amount:
		wood -= amount
		wood_changed.emit(wood)
		GameSignals.wood_used.emit(amount)
		return true
	return false

func use_food(amount: int) -> bool:
	if food >= amount:
		food -= amount
		food_changed.emit(food)
		GameSignals.food_used.emit(amount)
		return true
	return false

func use_stone(amount: int) -> bool:
	if stone >= amount:
		stone -= amount
		stone_changed.emit(stone)
		return true
	return false

func use_crystal(amount: int) -> bool:
	if crystal >= amount:
		crystal -= amount
		crystal_changed.emit(crystal)
		return true
	return false

# Funções para população (agora mais complexas)
func add_population(amount: int, npc_type: String = "survivor"):
	current_population = min(current_population + amount, max_population)
	population_changed.emit(current_population)
	GameSignals.npc_spawned.emit(amount)
	print("População aumentada: +", amount, " ", npc_type)

func remove_population(amount: int, reason: String = "unknown") -> bool:
	if current_population >= amount:
		current_population -= amount
		population_changed.emit(current_population)
		GameSignals.npc_died.emit(reason)
		return true
	return false

# Getter para compatibilidade
func get_population() -> int:
	return current_population

func set_population(value: int):
	current_population = value
	population_changed.emit(current_population)

func debug_add_resources():
	add_wood(50)
	add_food(30)
	add_stone(10)
	print("Recursos de debug adicionados!")
