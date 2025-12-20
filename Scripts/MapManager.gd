extends Node2D

@export var map_radius: int = 70
@export var base_tree_count: int = 100
@export var base_food_count: int = 40
@export var tree_density: float = 0.8
@export var food_density: float = 0.7
@export var safe_zone_radius: int = 8
@export var min_tree_distance: int = 10
@export var path_width: int = 3
@export var path_length_percentage: float = 1.0
@export var diagonal_path_percentage: float = 1.0

@onready var tilemap_layer: TileMapLayer = $GroundLayer
@onready var tree_container: Node2D = $GroundLayer/TreeContainer

var placed_trees: Array = []
var placed_food: Array = []
var map_center = Vector2i(0, 0)
var map_size: int
var max_coord: int
var path_length: int
var diagonal_length: int

func _ready():
	if not tilemap_layer:
		return
	
	if not tree_container:
		return
	
	PoolManager.ensure_pool("tree")
	PoolManager.ensure_pool("bush")
	
	calculate_derived_variables()
	generate_ground_layer()
	place_resources()
	place_central_path()
	
	print("=== MAPA GERADO ===")
	print("Árvores: ", placed_trees.size())
	print("Arbustos: ", placed_food.size())

func calculate_derived_variables():
	map_size = 2 * map_radius + 1
	max_coord = map_radius - 2
	path_length = int(map_radius * path_length_percentage)
	diagonal_length = int(map_radius * diagonal_path_percentage)

func generate_ground_layer():
	tilemap_layer.clear()
	
	for x in range(-map_radius, map_radius + 1):
		for y in range(-map_radius, map_radius + 1):
			var tile_pos = Vector2i(x, y)
			if tile_pos.distance_to(map_center) < safe_zone_radius:
				continue
			tilemap_layer.set_cell(tile_pos, 0, Vector2i(0, 0), 0)

func place_central_path():
	if not tilemap_layer:
		return
	
	var half_path = path_length / 2
	for x in range(-half_path, half_path + 1):
		place_path_segment(Vector2i(x, 0), path_width)
	
	for y in range(-half_path, half_path + 1):
		place_path_segment(Vector2i(0, y), path_width)
	
	var half_diagonal = diagonal_length / 2
	create_diagonal_path(Vector2i(-half_diagonal, -half_diagonal), Vector2i(half_diagonal, half_diagonal))
	create_diagonal_path(Vector2i(half_diagonal, -half_diagonal), Vector2i(-half_diagonal, half_diagonal))

func place_path_segment(center: Vector2i, width: int):
	var half_width = (width - 1) / 2
	
	for wx in range(-half_width, half_width + 1):
		for wy in range(-half_width, half_width + 1):
			var pos = center + Vector2i(wx, wy)
			if (abs(pos.x) <= map_radius and abs(pos.y) <= map_radius and
				pos.distance_to(map_center) >= safe_zone_radius):
				tilemap_layer.set_cell(pos, 0, Vector2i(0, 8), 0)

func create_diagonal_path(start: Vector2i, end: Vector2i):
	var direction = Vector2i(
		1 if end.x > start.x else -1,
		1 if end.y > start.y else -1
	)
	var current = start
	while current != end + direction:
		place_path_segment(current, path_width)
		current += direction

func place_resources():
	place_trees()
	place_food_resources()

func place_trees():
	clear_placed_resources(placed_trees, "tree")
	placed_trees.clear()
	
	var target_count = int(base_tree_count * tree_density)
	
	for i in range(target_count):
		var pos = find_valid_position(15, 25, false)
		if pos != Vector2.ZERO:
			var tree = PoolManager.get_object("tree", pos)
			if tree:
				# VERIFICAÇÃO CRÍTICA: Não conectar se já estiver conectado
				if not tree.harvested.is_connected(_on_tree_harvested):
					tree.harvested.connect(_on_tree_harvested.bind(tree, pos))
				
				placed_trees.append(tree)

func place_food_resources():
	clear_placed_resources(placed_food, "bush")
	placed_food.clear()
	
	var target_count = int(base_food_count * food_density)
	
	for i in range(target_count):
		var pos = find_valid_position(20, 30, true)
		if pos != Vector2.ZERO:
			var bush = PoolManager.get_object("bush", pos)
			if bush:
				# VERIFICAÇÃO CRÍTICA: Não conectar se já estiver conectado
				if not bush.harvested.is_connected(_on_bush_harvested):
					bush.harvested.connect(_on_bush_harvested.bind(bush, pos))
				
				placed_food.append(bush)
				print("Arbusto ", i, " colocado em ", pos, " (Visível: ", bush.visible, ")")

func find_valid_position(min_distance_from_center: int, min_spacing: int, is_food: bool) -> Vector2:
	var attempts = 0
	while attempts < 20:
		var tile_x = randi_range(-max_coord, max_coord)
		var tile_y = randi_range(-max_coord, max_coord)
		var world_pos = Vector2(tile_x * 15, tile_y * 15)
		
		if world_pos.distance_to(Vector2.ZERO) < min_distance_from_center * 15:
			attempts += 1
			continue
		
		var tile_pos = Vector2i(tile_x, tile_y)
		if tile_pos.distance_to(map_center) < safe_zone_radius:
			attempts += 1
			continue
		
		if is_position_on_path(tile_pos):
			attempts += 1
			continue
		
		var too_close = false
		
		if not is_food:
			for tree in placed_trees:
				if tree.global_position.distance_to(world_pos) < min_spacing:
					too_close = true
					break
		else:
			for tree in placed_trees:
				if tree.global_position.distance_to(world_pos) < min_spacing + 5:
					too_close = true
					break
			
			if not too_close:
				for bush in placed_food:
					if bush.global_position.distance_to(world_pos) < min_spacing:
						too_close = true
						break
		
		if not too_close:
			return world_pos
		
		attempts += 1
	
	return Vector2.ZERO

func is_position_on_path(position: Vector2i) -> bool:
	var atlas_coords = tilemap_layer.get_cell_atlas_coords(Vector2i(position.x,position.y))
	return atlas_coords == Vector2i(0, 8)

# CORREÇÃO: Desconectar sinais antes de conectar novamente
func _on_tree_harvested(amount: int, tree_node: Node, tree_pos: Vector2):
	# Desconectar ANTES de qualquer coisa
	if tree_node.harvested.is_connected(_on_tree_harvested):
		tree_node.harvested.disconnect(_on_tree_harvested)
	
	GameSignals.resource_collected.emit("wood", amount, tree_pos)
	placed_trees.erase(tree_node)
	
	await get_tree().create_timer(30.0).timeout
	respawn_resource("tree", tree_pos)

func _on_bush_harvested(amount: int, bush_node: Node, bush_pos: Vector2):
	# Desconectar ANTES de qualquer coisa
	if bush_node.harvested.is_connected(_on_bush_harvested):
		bush_node.harvested.disconnect(_on_bush_harvested)
	
	GameSignals.resource_collected.emit("food", amount, bush_pos)
	placed_food.erase(bush_node)
	
	await get_tree().create_timer(20.0).timeout
	respawn_resource("bush", bush_pos)

func respawn_resource(resource_type: String, position: Vector2):
	var tile_x = int(round(position.x / 15))
	var tile_y = int(round(position.y / 15))
	var tile_pos = Vector2i(tile_x, tile_y)
	
	if is_position_on_path(tile_pos):
		return
	
	var resource = PoolManager.get_object(resource_type, position)
	if resource:
		# VERIFICAÇÃO DUPLA: Desconectar qualquer conexão existente
		if resource.harvested.is_connected(_on_tree_harvested):
			resource.harvested.disconnect(_on_tree_harvested)
		if resource.harvested.is_connected(_on_bush_harvested):
			resource.harvested.disconnect(_on_bush_harvested)
		
		if resource_type == "tree":
			placed_trees.append(resource)
			resource.harvested.connect(_on_tree_harvested.bind(resource, position))
		else:
			placed_food.append(resource)
			resource.harvested.connect(_on_bush_harvested.bind(resource, position))

func clear_placed_resources(resource_list: Array, pool_type: String):
	for resource in resource_list:
		if is_instance_valid(resource):
			PoolManager.return_object(resource, pool_type)

func get_tree_count() -> int:
	return placed_trees.size()

func get_food_count() -> int:
	return placed_food.size()
