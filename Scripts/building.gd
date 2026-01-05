extends Area2D
class_name Building

var building_resource: BuildingResource = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $Collision
@onready var construction_timer: Timer = $ConstructionTimer
@onready var highlight_area: Sprite2D = $HighlightArea
@onready var food_timer: Timer = $FoodProductionTimer

var is_constructed: bool = false
var is_highlighted: bool = false
var health: int = 100  

signal construction_completed
signal building_destroyed

func _ready():
	if building_resource == null:
		push_error("Building não tem Resource configurado!")
		queue_free()
		return
	
	# Inicializar health do Resource
	health = building_resource.health
	
	add_to_group("building")
	add_to_group(building_resource.building_type)
	
	# Usar construction_time do Resource
	construction_timer.wait_time = building_resource.construction_time
	construction_timer.timeout.connect(_on_construction_timer_timeout)
	construction_timer.start()

func _on_construction_timer_timeout():
	is_constructed = true
	sprite.modulate = Color.WHITE
	collision.disabled = false
	construction_completed.emit()
	apply_building_effects()

func apply_building_effects():
	match building_resource.building_type:
		"hut":
			# Aumenta população máxima E atual
			ResourceManager.max_population += 2
			ResourceManager.current_population += 2
			ResourceManager.population_changed.emit(ResourceManager.current_population)
			GameSignals.building_constructed.emit("Cabana")
			print("População aumentada! Máxima: ", ResourceManager.max_population, ", Atual: ", ResourceManager.current_population)
		
		"kitchen":
			start_food_production()
			GameSignals.building_constructed.emit("Cozinha")
		
		"storage":
			ResourceManager.max_wood += 100
			GameSignals.building_constructed.emit("Depósito")
			print("Capacidade de madeira aumentada para: ", ResourceManager.max_wood)
		
		"tower":
			GameSignals.victory.emit("Torre de Vigia construída!")
			GameSignals.building_constructed.emit("Torre de Vigia")

func start_food_production():
	food_timer.timeout.connect(_produce_food)
	food_timer.start()
	print("Cozinha iniciou produção de comida!")

func _produce_food():
	if ResourceManager.food < ResourceManager.max_food:
		var food_to_add = 5  # Produz 5aa comida a cada wait time do food_timer
		ResourceManager.add_food(food_to_add)
		print("Cozinha produziu ", food_to_add, " de comida!")

func take_damage(amount: int):
	if not is_constructed:
		return
	
	health -= amount
	GameSignals.building_damaged.emit(building_resource.building_type, amount)
	
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE
	
	if health <= 0:
		destroy()

func destroy():
	remove_building_effects()
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	building_destroyed.emit()
	queue_free()

func remove_building_effects():
	match building_resource.building_type:
		"hut":
			ResourceManager.max_population -= 2
			ResourceManager.current_population = min(ResourceManager.current_population, ResourceManager.max_population)
			ResourceManager.population_changed.emit(ResourceManager.current_population)
		"storage":
			ResourceManager.max_wood -= 100
			ResourceManager.wood = min(ResourceManager.wood, ResourceManager.max_wood)
			ResourceManager.wood_changed.emit(ResourceManager.wood)
