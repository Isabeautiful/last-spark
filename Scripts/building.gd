extends Area2D
class_name Building

@export var building_name: String = "Cabana"
@export var building_type: String = "hut"
@export var cost_wood: int = 20
@export var cost_food: int = 5
@export var construction_time: float = 5.0
@export var health: int = 100

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $Collision
@onready var construction_timer: Timer = $ConstructionTimer
@onready var highlight_area: Sprite2D = $HighlightArea

var is_constructed: bool = false
var is_highlighted: bool = false

signal construction_completed
signal building_destroyed

func _ready():
	add_to_group("building")
	add_to_group(building_type)
	
	# Criar highlight dinamicamente se não tiver textura
	if highlight_area:
		if not highlight_area.texture:
			highlight_area.texture = _create_highlight_texture()
		highlight_area.modulate = Color(0, 1, 0, 0.3)
		highlight_area.hide()
	
	# Inicialmente em construção
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.7)
	collision.disabled = true
	
	construction_timer.wait_time = construction_time
	construction_timer.timeout.connect(_on_construction_timer_timeout)
	construction_timer.start()

func _create_highlight_texture() -> Texture2D:
	# Criar uma textura quadrada verde para highlight
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 1, 0, 0.3))
	
	# Adicionar borda mais visível
	for x in range(32):
		for y in range(32):
			if x < 2 or x >= 30 or y < 2 or y >= 30:
				image.set_pixel(x, y, Color(0, 1, 0, 0.8))
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func _on_construction_timer_timeout():
	is_constructed = true
	sprite.modulate = Color.WHITE
	collision.disabled = false
	construction_completed.emit()
	apply_building_effects()
	print(building_name, " construída!")

func apply_building_effects():
	match building_type:
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
	var timer = Timer.new()
	timer.wait_time = 30.0  # Produz a cada 30 segundos (para teste)
	timer.timeout.connect(_produce_food)
	add_child(timer)
	timer.start()
	print("Cozinha iniciou produção de comida!")

func _produce_food():
	if ResourceManager.food < ResourceManager.max_food:
		var food_to_add = 2  # Produz 2 comida a cada 30 segundos
		ResourceManager.add_food(food_to_add)
		print("Cozinha produziu ", food_to_add, " de comida!")

func take_damage(amount: int):
	if not is_constructed:
		return
	
	health -= amount
	GameSignals.building_damaged.emit(building_type, amount)
	
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
	match building_type:
		"hut":
			ResourceManager.max_population -= 2
			ResourceManager.current_population = min(ResourceManager.current_population, ResourceManager.max_population)
			ResourceManager.population_changed.emit(ResourceManager.current_population)
		"storage":
			ResourceManager.max_wood -= 100
			ResourceManager.wood = min(ResourceManager.wood, ResourceManager.max_wood)
			ResourceManager.wood_changed.emit(ResourceManager.wood)

func highlight(active: bool):
	is_highlighted = active
	if highlight_area:
		highlight_area.visible = active
