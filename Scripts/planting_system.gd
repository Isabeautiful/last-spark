extends Node
class_name PlantingSystem

var current_seed_type: String = "tree"
var ghost_plant: Sprite2D = null
var is_planting_mode: bool = false
var can_place: bool = false

var planting_configs: Dictionary = {}

@onready var game = get_tree().root.get_child(0)
@onready var tilemap: TileMapLayer
@onready var camera: Camera2D

signal planting_mode_changed(active: bool)
signal seed_planted(seed_type: String, position: Vector2)

func _ready():
	# Obter referências de forma segura
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager:
		tilemap = map_manager.get_node("GroundLayer") if map_manager.has_node("GroundLayer") else null
	
	# Tentar obter a câmera do jogador
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
	else:
		# Fallback: pegar a câmera ativa do viewport
		camera = get_viewport().get_camera_2d()
		if not camera:
			camera = Camera2D.new()
			game.add_child(camera)
			camera.make_current()
	
	# Carregar configurações das cenas
	load_planting_configs()
	
	# Criar sprite fantasma SOMENTE quando necessário
	_create_ghost_plant()
	
	# Adicionar ao grupo para fácil acesso
	add_to_group("planting_system")
	
	# Inicialmente não processar entrada
	set_process_input(false)

func load_planting_configs():
	# Configurações base para cada tipo de planta
	var base_configs = {
		"tree": {
			"name": "Árvore",
			"cost_seed": 1,
			"scene": preload("res://Scenes/Tree.tscn"),
			"drop_seed_chance": 0.5,
			"seed_drop_amount": 1,
			"can_drop_seeds": true,
			"color": Color(0.6, 0.4, 0.2, 0.5),
			"size": Vector2(32, 32),
			"wood_amount": 1  # Adicionado: quantidade de madeira
		},
		"bush": {
			"name": "Arbusto",
			"cost_seed": 1,
			"scene": preload("res://Scenes/Bush.tscn"), 
			"drop_seed_chance": 0.9,
			"seed_drop_amount": 2,
			"can_drop_seeds": true,
			"color": Color(0.2, 0.8, 0.2, 0.5),
			"size": Vector2(24, 24),
			"food_amount": 1  # Adicionado: quantidade de comida
		}
	}
	
	# Para cada tipo, instanciar a cena temporariamente para ler suas propriedades
	for seed_type in base_configs:
		var config = base_configs[seed_type].duplicate(true)  # Cópia profunda
		var scene = config["scene"]
		
		if scene:
			# Instanciar temporariamente para ler propriedades
			var plant_instance = scene.instantiate()
			
			# Ler propriedades da instância (se existirem)
			if plant_instance.has_method("get_planting_config"):
				# Se a planta tem um método para fornecer configurações
				var plant_config = plant_instance.get_planting_config()
				for key in plant_config:
					config[key] = plant_config[key]
			else:
				# Tentar ler propriedades exportadas diretamente
				if plant_instance.has_meta("drop_seed_chance"):
					config["drop_seed_chance"] = plant_instance.get_meta("drop_seed_chance")
				if plant_instance.has_meta("seed_drop_amount"):
					config["seed_drop_amount"] = plant_instance.get_meta("seed_drop_amount")
				if plant_instance.has_meta("can_drop_seeds"):
					config["can_drop_seeds"] = plant_instance.get_meta("can_drop_seeds")
			
			# Ler propriedades específicas para recursos
			if plant_instance.has_method("get_wood_amount"):
				config["wood_amount"] = plant_instance.get_wood_amount()
			elif plant_instance.has_meta("wood_amount"):
				config["wood_amount"] = plant_instance.get_meta("wood_amount")
				
			if plant_instance.has_method("get_food_amount"):
				config["food_amount"] = plant_instance.get_food_amount()
			elif plant_instance.has_meta("food_amount"):
				config["food_amount"] = plant_instance.get_meta("food_amount")
			
			# Liberar a instância temporária
			plant_instance.queue_free()
			
			planting_configs[seed_type] = config

func _create_ghost_plant():
	# Destruir ghost existente se houver
	if ghost_plant and is_instance_valid(ghost_plant):
		ghost_plant.queue_free()
	
	# Criar novo sprite fantasma
	ghost_plant = Sprite2D.new()
	ghost_plant.modulate = Color(1, 1, 1, 0.6)
	ghost_plant.centered = true
	ghost_plant.scale = Vector2(0.8, 0.8)
	ghost_plant.z_index = 100  # Garantir que fique na frente
	
	# Adicionar à cena do jogo
	game.call_deferred("add_child", ghost_plant)
	
	# Esconder inicialmente
	ghost_plant.hide()

func _input(event):
	if not is_planting_mode:
		return
	
	if event is InputEventMouseMotion:
		var mouse_pos = _get_global_mouse_position()
		ghost_plant.global_position = snap_to_grid(mouse_pos)
		
		can_place = can_place_seed(ghost_plant.global_position)
		ghost_plant.modulate = Color(0, 1, 0, 0.6) if can_place else Color(1, 0, 0, 0.6)
	
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if can_place:
				plant_seed_at_position(ghost_plant.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_planting()
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_planting()
		elif event.keycode == KEY_T:
			toggle_seed_type()

func start_planting(seed_type: String = "tree"):
	# Se já estiver no modo de plantio, cancelar
	if is_planting_mode:
		cancel_planting()
		return
	
	if not planting_configs.has(seed_type):
		push_error("Tipo de semente desconhecido: ", seed_type)
		return
	
	# Verificar recursos
	if not has_enough_seeds(seed_type):
		return
	
	# Garantir que o ghost existe
	if not ghost_plant or not is_instance_valid(ghost_plant):
		_create_ghost_plant()
		await get_tree().process_frame  # Esperar o ghost ser criado
	
	current_seed_type = seed_type
	is_planting_mode = true
	
	set_process_input(true)
	
	# Configurar ghost
	var config = planting_configs[current_seed_type]
	
	# Usar textura de debug
	ghost_plant.texture = _create_debug_texture(config["size"], config["color"])
	ghost_plant.scale = Vector2(0.8, 0.8)
	
	var mouse_pos = _get_global_mouse_position()
	ghost_plant.global_position = snap_to_grid(mouse_pos)
	
	ghost_plant.show()
	can_place = can_place_seed(ghost_plant.global_position)
	
	planting_mode_changed.emit(true)

func cancel_planting():
	if not is_planting_mode:
		return
	
	is_planting_mode = false
	set_process_input(false)
	
	if ghost_plant and is_instance_valid(ghost_plant):
		ghost_plant.hide()
	
	planting_mode_changed.emit(false)

func toggle_seed_type():
	# Alternar entre tipos de semente
	var seed_types = planting_configs.keys()
	var current_index = seed_types.find(current_seed_type)
	var next_index = (current_index + 1) % seed_types.size()
	
	var next_seed_type = seed_types[next_index]
	
	# Verificar se tem sementes do próximo tipo
	var attempts = 0
	while not has_enough_seeds(next_seed_type) and attempts < seed_types.size():
		next_index = (next_index + 1) % seed_types.size()
		next_seed_type = seed_types[next_index]
		attempts += 1
	
	if has_enough_seeds(next_seed_type):
		current_seed_type = next_seed_type
		
		# Atualizar ghost
		var config = planting_configs[current_seed_type]
		ghost_plant.texture = _create_debug_texture(config["size"], config["color"])
		
		# Verificar posição atual
		can_place = can_place_seed(ghost_plant.global_position)
	else:
		print("Nenhum tipo de semente disponível!")

func has_enough_seeds(seed_type: String) -> bool:
	if not planting_configs.has(seed_type):
		return false
	
	var cost = planting_configs[seed_type]["cost_seed"]
	
	if seed_type == "tree":
		return ResourceManager.tree_seeds >= cost
	elif seed_type == "bush":
		return ResourceManager.bush_seeds >= cost
	return false

func can_place_seed(position: Vector2) -> bool:
	if not planting_configs.has(current_seed_type):
		return false
	
	var config = planting_configs[current_seed_type]
	
	# Verificar recursos
	if not has_enough_seeds(current_seed_type):
		return false
	
	# Verificar se está muito perto do jogador
	var player = get_tree().get_first_node_in_group("player")
	if player and position.distance_to(player.global_position) < 50:
		return false
	
	# Verificar colisões com outros recursos
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = RectangleShape2D.new()
	shape.size = config["size"]
	
	query.shape = shape
	query.transform = Transform2D(0, position)
	query.collision_mask = 2  # Layer para recursos
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results = space_state.intersect_shape(query, 1)  # Limitar a 1 resultado
	
	if not results.is_empty():
		return false
	
	# Verificar com MapManager
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("can_plant_seed"):
		return map_manager.can_plant_seed(current_seed_type, position)
	
	# Por padrão, permitir plantio em qualquer lugar do chão
	return true

func plant_seed_at_position(position: Vector2):
	if not planting_configs.has(current_seed_type):
		return
	
	var config = planting_configs[current_seed_type]
	
	# Consumir semente
	var seed_consumed = false
	if current_seed_type == "tree":
		seed_consumed = ResourceManager.use_tree_seed(config["cost_seed"])
	elif current_seed_type == "bush":
		seed_consumed = ResourceManager.use_bush_seed(config["cost_seed"])
	
	if not seed_consumed:
		return
	
	# Instanciar recurso
	if config["scene"]:
		var plant = config["scene"].instantiate()
		plant.global_position = position
		
		# CONECTAR SINAIS DE COLHEITA
		if current_seed_type == "tree":
			# arvore
			if plant.harvested.is_connected(_on_tree_harvested):
				plant.harvested.disconnect(_on_tree_harvested)
			plant.harvested.connect(_on_tree_harvested.bind(plant, position, config.get("wood_amount", 1)))
		elif current_seed_type == "bush":
			# arbusto
			if plant.harvested.is_connected(_on_bush_harvested):
				plant.harvested.disconnect(_on_bush_harvested)
			plant.harvested.connect(_on_bush_harvested.bind(plant, position, config.get("food_amount", 1)))
		
		# Adicionar à cena atual
		var current_scene = get_tree().current_scene
		if current_scene:
			current_scene.add_child(plant)
		
		# Notificar o MapManager sobre o novo plantio
		_notify_map_manager_about_planting(current_seed_type, plant, position)
		
		seed_planted.emit(current_seed_type, position)
		
		# Efeito visual simples
		_create_planting_effect(position)
	else:
		push_error("Cena não configurada para: ", config["name"])
	
	# Não cancelar automaticamente - deixar o jogador plantar mais

func _create_planting_effect(position: Vector2):
	# Efeito visual simples
	var effect = Sprite2D.new()
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 1, 0, 0.8))
	var texture = ImageTexture.create_from_image(image)
	effect.texture = texture
	effect.global_position = position
	effect.scale = Vector2(0.5, 0.5)
	effect.z_index = 99
	
	game.add_child(effect)
	
	# Animação de fade out
	var tween = effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.5)
	tween.tween_callback(effect.queue_free)

func snap_to_grid(position: Vector2) -> Vector2:
	var grid_size = 16
	return Vector2(
		floor(position.x / grid_size) * grid_size + grid_size/2.0,
		floor(position.y / grid_size) * grid_size + grid_size/2.0
	)

func _get_global_mouse_position() -> Vector2:
	# Obter o viewport
	var viewport = get_viewport()
	
	# Se temos uma câmera, usar seu método
	if camera:
		return camera.get_global_mouse_position()
	
	# Se não temos câmera, tentar obter do viewport
	var viewport_camera = viewport.get_camera_2d()
	if viewport_camera:
		camera = viewport_camera
		return camera.get_global_mouse_position()
	
	# Último recurso: retornar posição do mouse no viewport
	return viewport.get_mouse_position()

func _create_debug_texture(size: Vector2, color: Color) -> Texture2D:
	var image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	# Adicionar borda para melhor visualização
	for x in range(int(size.x)):
		if x == 0 or x == int(size.x) - 1:
			for y in range(int(size.y)):
				image.set_pixel(x, y, Color.WHITE)
		else:
			image.set_pixel(x, 0, Color.WHITE)
			image.set_pixel(x, int(size.y) - 1, Color.WHITE)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func get_world_2d():
	return get_tree().root.world_2d

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if ghost_plant and is_instance_valid(ghost_plant):
			ghost_plant.queue_free()

func get_current_seed_type() -> String:
	return current_seed_type

func update_plant_config(seed_type: String, key: String, value):
	if planting_configs.has(seed_type):
		planting_configs[seed_type][key] = value

func _on_tree_harvested(amount: int, tree_node: Node, tree_pos: Vector2, wood_amount: int = 1):
	GameSignals.resource_collected.emit("wood", wood_amount, tree_pos)
	
	var config = planting_configs.get("tree", {})
	if config.get("can_drop_seeds", true) and randf() < config.get("drop_seed_chance", 0.5):
		var seed_drop = config.get("seed_drop_amount", 1)
		ResourceManager.add_tree_seed(seed_drop)
		print("Sementes de árvore dropadas: ", seed_drop)
	
	# Quarto: Desconectar o sinal para evitar chamadas múltiplas
	if tree_node.harvested.is_connected(_on_tree_harvested):
		tree_node.harvested.disconnect(_on_tree_harvested)

func _on_bush_harvested(amount: int, bush_node: Node, bush_pos: Vector2, food_amount: int = 1):
	GameSignals.resource_collected.emit("food", food_amount, bush_pos)
	
	var config = planting_configs.get("bush", {})
	if config.get("can_drop_seeds", true) and randf() < config.get("drop_seed_chance", 0.9):
		var seed_drop = config.get("seed_drop_amount", 2)
		ResourceManager.add_bush_seed(seed_drop)

	if bush_node.harvested.is_connected(_on_bush_harvested):
		bush_node.harvested.disconnect(_on_bush_harvested)

func _notify_map_manager_about_planting(seed_type: String, plant: Node, position: Vector2):
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("add_plant_to_list"):
		map_manager.add_plant_to_list(seed_type, plant, position)
