extends Node

# Variáveis de recursos expandidas
var wood: int = 200
var food: int = 90

# Limites de recursos
var max_wood: int = 200
var max_food: int = 100

# Sementes
var tree_seeds: int = 5
var bush_seeds: int = 5

# Sinais
signal wood_changed(amount)
signal food_changed(amount)
signal stone_changed(amount)
signal crystal_changed(amount)
signal resource_added(type: String, amount: int)
# Novos sinais para sementes
signal tree_seeds_changed(amount)
signal bush_seeds_changed(amount)

func _ready():
	GameSignals.resource_collected.connect(_on_resource_collected)

func _on_resource_collected(resource_type: String, amount: int, position: Vector2):
	match resource_type:
		"wood":
			add_wood(amount)
		"food":
			add_food(amount)

# Funções para sementes
func add_tree_seed(amount: int):
	tree_seeds += amount
	tree_seeds_changed.emit(tree_seeds)

func add_bush_seed(amount: int):
	bush_seeds += amount
	bush_seeds_changed.emit(bush_seeds)

func use_tree_seed(amount: int) -> bool:
	if tree_seeds >= amount:
		tree_seeds -= amount
		tree_seeds_changed.emit(tree_seeds)
		return true
	return false

func use_bush_seed(amount: int) -> bool:
	if bush_seeds >= amount:
		bush_seeds -= amount
		bush_seeds_changed.emit(bush_seeds)
		return true
	return false

# Funções de recursos originais
func add_wood(amount: int):
	wood = min(wood + amount, max_wood)
	wood_changed.emit(wood)
	resource_added.emit("wood", amount)

func add_food(amount: int):
	food = min(food + amount, max_food)
	food_changed.emit(food)
	resource_added.emit("food", amount)

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

func debug_add_resources():
	add_wood(50)
	add_food(30)
