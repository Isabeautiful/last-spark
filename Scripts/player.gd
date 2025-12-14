extends CharacterBody2D

@export var speed: float = 300.0

@onready var harvest_area: Area2D = $HarvestArea
@onready var harvest_shape: CollisionShape2D = $HarvestArea/CollisionShape2D

var current_direction: Vector2 = Vector2.DOWN
var resources_in_range: Array[Node] = []
var can_harvest: bool = true

# Controle de entrada
var can_process_input: bool = true

# Interação com fogo
var fire_in_range: bool = false

func _ready():
	add_to_group("player")
	setup_harvest_area()
	harvest_area.area_entered.connect(_on_harvest_area_area_entered)
	harvest_area.area_exited.connect(_on_harvest_area_area_exited)
	harvest_area.add_to_group("player_harvest")

func setup_harvest_area():
	if harvest_shape:
		var shape = harvest_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(80, 40)
	
	harvest_area.collision_layer = 1
	harvest_area.collision_mask = 2
	
	update_harvest_area_position(Vector2.DOWN)

func _physics_process(delta):
	if not can_process_input:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	
	if input_dir.length() > 0.1:
		current_direction = input_dir.normalized()
		update_harvest_area_position(current_direction)
	
	velocity = input_dir * speed
	move_and_slide()

func _input(event):
	if not can_process_input:
		return
	
	# Coleta com botão esquerdo ou tecla E
	if (event.is_action_pressed("Collect") or 
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		
		if can_harvest and not resources_in_range.is_empty():
			try_harvest_in_area()
	
	# Interagir com fogo (tecla F)
	if event.is_action_pressed("interact"):
		if fire_in_range:
			var fire = get_tree().get_first_node_in_group("fire")
			if fire and fire.has_method("add_fuel_from_inventory"):
				fire.add_fuel_from_inventory()

func update_harvest_area_position(direction: Vector2):
	if not harvest_area:
		return
	var normalized_dir = direction.normalized()
	var angle = normalized_dir.angle()
	harvest_area.rotation = angle
	harvest_area.position = normalized_dir * 20

func _on_harvest_area_area_entered(area: Area2D):
	if area.is_in_group("tree") or area.is_in_group("bush"):
		if area.has_method("highlight"):
			area.highlight(true)
		
		if not resources_in_range.has(area):
			resources_in_range.append(area)
	elif area.is_in_group("fire_interaction"):
		fire_in_range = true
		print("Perto do fogo - pressione F para adicionar lenha")

func _on_harvest_area_area_exited(area: Area2D):
	if (area.is_in_group("tree") or area.is_in_group("bush")) and resources_in_range.has(area):
		if area.has_method("highlight"):
			area.highlight(false)
		
		resources_in_range.erase(area)
	elif area.is_in_group("fire_interaction"):
		fire_in_range = false
		print("Saiu da área do fogo")

func try_harvest_in_area():
	if resources_in_range.is_empty():
		return
	
	for i in range(resources_in_range.size()):
		var resource = resources_in_range[i]
		
		if resource == null or not is_instance_valid(resource):
			resources_in_range.remove_at(i)
			continue
		
		if resource.has_method("harvest"):
			can_harvest = false
			
			var harvested = await resource.harvest()
			
			if harvested:
				if resources_in_range.has(resource):
					resources_in_range.erase(resource)
				break
		
		await get_tree().create_timer(0.1).timeout
	
	await get_tree().create_timer(0.3).timeout
	can_harvest = true

func set_can_process_input(can_process: bool):
	can_process_input = can_process
	
	if not can_process:
		velocity = Vector2.ZERO
		move_and_slide()
