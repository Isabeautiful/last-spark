extends Node

# Variáveis de recursos
var wood: int = 0
var food: int = 0
var population: int = 3

# Sinais para notificar mudanças
signal wood_changed(amount)
signal food_changed(amount)
signal population_changed(amount)
signal resource_added(type: String, amount: int)

func _ready():
	# Conectar ao sinal de recurso coletado
	GameSignals.resource_collected.connect(_on_resource_collected)
	print("ResourceManager iniciado - ouvindo sinais de coleta")

func _on_resource_collected(resource_type: String, amount: int, position: Vector2):
	match resource_type:
		"wood":
			add_wood(amount)
			print("Madeira coletada via signal: +", amount)
		"food":
			add_food(amount)
			print("Comida coletada via signal: +", amount)
		_:
			print("Recurso desconhecido coletado:", resource_type)
			
func add_wood(amount: int):
	wood += amount
	wood_changed.emit(wood)
	print("Madeira: +", amount, " (Total: ", wood, ")")

func add_food(amount: int):
	food += amount
	food_changed.emit(food)
	print("Comida: +", amount, " (Total: ", food, ")")

func use_wood(amount: int) -> bool:
	if wood >= amount:
		wood -= amount
		wood_changed.emit(wood)
		return true
	print("Madeira insuficiente! Necessário: ", amount, ", Disponível: ", wood)
	return false

func use_food(amount: int) -> bool:
	if food >= amount:
		food -= amount
		food_changed.emit(food)
		return true
	print("Comida insuficiente!")
	return false
