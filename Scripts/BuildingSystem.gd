extends Node
class_name BuildingSystem

@export var building_resources: Array[BuildingResource] = [] 

var current_building_index: int = -1 
var ghost_building: Sprite2D = null
var is_building_mode: bool = false
var can_place: bool = false

@onready var game = get_tree().current_scene
@onready var tilemap: TileMapLayer
@onready var camera: Camera2D

signal build_mode_changed(active: bool)
signal building_placed(building_resource: BuildingResource, position: Vector2) 

func _ready():
	# Obter ref
	var map_manager = game.get_node("MapManager") if game.has_node("MapManager") else null
	if map_manager:
		tilemap = map_manager.get_node("GroundLayer") if map_manager.has_node("GroundLayer") else null
	
	# obter a camera
	var player = game.get_node("Player") if game.has_node("Player") else null
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
	else:
		camera = get_viewport().get_camera_2d()
	
	# Criar sprite fantasma COM CALL_DEFERRED
	ghost_building = Sprite2D.new()
	ghost_building.modulate = Color(1, 1, 1, 0.6)
	ghost_building.centered = true
	game.add_child.call_deferred(ghost_building)
	
	# Inicialmente nao processar entrada
	set_process_input(false)
	
	# Esconder apos ser adicionado
	await get_tree().process_frame
	ghost_building.hide()

func _input(event):
	if not is_building_mode:
		return
	
	if event is InputEventMouseMotion:
		var mouse_pos = _get_global_mouse_position()
		ghost_building.global_position = snap_to_grid(mouse_pos)
		
		can_place = can_place_building(ghost_building.global_position)
		ghost_building.modulate = Color(0, 1, 0, 0.6) if can_place else Color(1, 0, 0, 0.6)
	
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if can_place:
				place_building(ghost_building.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_building()
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_building()

func start_building(index: int):
	if is_building_mode:
		cancel_building()
	
	if index < 0 or index >= building_resources.size():
		push_error("Índice de construção inválido: ", index)
		return
	
	current_building_index = index
	is_building_mode = true
	
	set_process_input(true)
	
	var config = building_resources[current_building_index]
	var use_texture = null
	
	# Carregar textura pelo caminho
	if not use_texture:
		var texture_path = "res://Assets/Buildings/" + config.building_type + ".png"
		var loaded_texture = load(texture_path)
		
		if loaded_texture:
			ghost_building.texture = loaded_texture
		else: ##textura de debug
			ghost_building.texture = _create_debug_texture(config.size, config.color)
	else:
		ghost_building.texture = use_texture
	
	ghost_building.scale = Vector2.ONE
	
	var mouse_pos = _get_global_mouse_position()
	ghost_building.global_position = snap_to_grid(mouse_pos)
	
	ghost_building.show()
	can_place = can_place_building(ghost_building.global_position)
	
	build_mode_changed.emit(true)

func cancel_building():
	is_building_mode = false
	current_building_index = -1
	
	set_process_input(false)
	
	ghost_building.hide()
	build_mode_changed.emit(false)

func can_place_building(position: Vector2) -> bool:
	if current_building_index == -1:
		return false
	
	var config = building_resources[current_building_index]
	
	# Verificar recursos
	if ResourceManager.wood < config.cost_wood or ResourceManager.food < config.cost_food:
		return false
	
	# Verificar distancia da fogueira (não muito longe)
	var fire = get_tree().get_first_node_in_group("fire")
	if fire and position.distance_to(fire.global_position) > 300:
		return false
	
	# Verificar se ta no chão
	if tilemap:
		var tile_pos = tilemap.local_to_map(position)
		var atlas_coords = tilemap.get_cell_atlas_coords(tile_pos)
		
		if atlas_coords == Vector2i(-1, -1):
			return false
	
	# Verificar colision com outros edificios
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = RectangleShape2D.new()
	shape.size = config.size
	
	query.shape = shape
	query.transform = Transform2D(0, position)
	query.collision_mask = 5  # Layer para edifícios
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results = space_state.intersect_shape(query)
	
	if not results.is_empty():
		return false
	
	return true

func place_building(position: Vector2):
	if current_building_index == -1:
		return
	
	var config = building_resources[current_building_index]
	
	
	if not ResourceManager.use_wood(config.cost_wood) or not ResourceManager.use_food(config.cost_food):
		return
	
	
	if config.scene:
		var building = config.scene.instantiate()
		building.global_position = position
		
		
		building.building_resource = config  
		
		if game:
			game.add_child(building)
		else:
			get_tree().current_scene.add_child(building)
		
		building_placed.emit(config, position)  
	else:
		push_error("Cena não configurada para: ", config.building_name)
	
	cancel_building()

func snap_to_grid(position: Vector2) -> Vector2:
	var grid_size = 16
	return Vector2(
		floor(position.x / grid_size) * grid_size + grid_size/2,
		floor(position.y / grid_size) * grid_size + grid_size/2
	)

func _get_global_mouse_position() -> Vector2:
	var viewport = get_viewport()
	
	if not viewport:
		return Vector2.ZERO
	
	var mouse_pos = viewport.get_mouse_position()
	
	if camera:
		return camera.get_global_mouse_position()
	else:
		var viewport_camera = viewport.get_camera_2d()
		if viewport_camera:
			return viewport_camera.get_global_mouse_position()
	
	var canvas_transform = viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * mouse_pos

func _create_debug_texture(size: Vector2, color: Color) -> Texture2D:
	var image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	
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
	var viewport = get_viewport()
	if viewport:
		return viewport.world_2d
	return null

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if ghost_building and is_instance_valid(ghost_building):
			ghost_building.queue_free()
