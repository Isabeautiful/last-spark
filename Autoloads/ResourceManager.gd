extends Node

# Variáveis de recursos
var wood: int = 50  # Começa com mais madeira para testes
var food: int = 30   # Começa com mais comida para testes
var current_population: int = 3  # População atual
var max_population: int = 5      # População máxima

# Limites de recursos
var max_wood: int = 200
var max_food: int = 100

# Sinais para notificar mudanças
signal wood_changed(amount)
signal food_changed(amount)
signal population_changed(amount)
signal resource_added(type: String, amount: int)

func _ready():
	GameSignals.resource_collected.connect(_on_resource_collected)
	print("ResourceManager iniciado - Madeira: ", wood, " Comida: ", food, " População: ", current_population)

func _on_resource_collected(resource_type: String, amount: int, position: Vector2):
	match resource_type:
		"wood":
			add_wood(amount)
		"food":
			add_food(amount)

func add_wood(amount: int):
	wood = min(wood + amount, max_wood)
	wood_changed.emit(wood)
	print("Madeira: +", amount, " (Total: ", wood, "/", max_wood, ")")

func add_food(amount: int):
	food = min(food + amount, max_food)
	food_changed.emit(food)
	print("Comida: +", amount, " (Total: ", food, "/", max_food, ")")

func use_wood(amount: int) -> bool:
	if wood >= amount:
		wood -= amount
		wood_changed.emit(wood)
		print("Madeira usada: -", amount, " (Restante: ", wood, ")")
		return true
	print("Madeira insuficiente! Necessário: ", amount, ", Disponível: ", wood)
	return false

func use_food(amount: int) -> bool:
	if food >= amount:
		food -= amount
		food_changed.emit(food)
		print("Comida usada: -", amount, " (Restante: ", food, ")")
		return true
	print("Comida insuficiente!")
	return false

# Funções para população
func add_population(amount: int):
	current_population = min(current_population + amount, max_population)
	population_changed.emit(current_population)
	print("População aumentada: +", amount, " (Total: ", current_population, "/", max_population, ")")

func remove_population(amount: int) -> bool:
	if current_population >= amount:
		current_population -= amount
		population_changed.emit(current_population)
		print("População reduzida: -", amount, " (Total: ", current_population, "/", max_population, ")")
		return true
	print("População insuficiente!")
	return false

# Getter para compatibilidade com código existente
func get_population() -> int:
	return current_population

# Setter para compatibilidade
func set_population(value: int):
	current_population = value
	population_changed.emit(current_population)

# Property getter para acesso direto (se usado como ResourceManager.population)
# Em GDScript, não podemos ter um método chamado "population()", então usamos uma propriedade
# Mas já temos current_population, então outros scripts devem usar ResourceManager.current_population

# Para debug: adicionar recursos facilmente
func debug_add_resources():
	add_wood(50)
	add_food(30)
	print("Recursos de debug adicionados!")
