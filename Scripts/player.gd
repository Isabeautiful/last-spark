extends CharacterBody2D

@export var speed: float = 300.0

@onready var harvest_area: Area2D = $HarvestArea
@onready var harvest_shape: CollisionShape2D = $HarvestArea/CollisionShape2D

var current_direction: Vector2 = Vector2.DOWN
var resources_in_range: Array[Node] = []  # Mudei o nome para ser mais genérico
var can_harvest: bool = true

func _ready():
	add_to_group("player")
	setup_harvest_area()
	harvest_area.area_entered.connect(_on_harvest_area_area_entered)
	harvest_area.area_exited.connect(_on_harvest_area_area_exited)
	harvest_area.add_to_group("player_harvest")
	
	print("Player configurado")
	print("HarvestArea collision_layer: ", harvest_area.collision_layer)
	print("HarvestArea collision_mask: ", harvest_area.collision_mask)

func setup_harvest_area():
	if harvest_shape:
		var shape = harvest_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(80, 40)
	
	# CONFIGURAÇÃO CORRETA DAS LAYERS:
	# 1. A HarvestArea deve estar na layer 1 para ser detectada pelas árvores/arbustos
	# 2. A HarvestArea deve detectar objetos na layer 2 (árvores/arbustos)
	harvest_area.collision_layer = 1  # IMPORTANTE: layer 1
	harvest_area.collision_mask = 2   # Detecta layer 2
	
	# DEBUG: Verificar se a shape está correta
	if harvest_shape:
		print("HarvestArea shape size: ", (harvest_shape.shape as RectangleShape2D).size)
	
	update_harvest_area_position(Vector2.DOWN)

func _physics_process(delta):
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	
	if input_dir.length() > 0.1:
		current_direction = input_dir.normalized()
		update_harvest_area_position(current_direction)
	
	velocity = input_dir * speed
	move_and_slide()
	
	if Input.is_action_just_pressed("Collect") and can_harvest:
		print("=== TENTATIVA DE COLETA ===")
		print("Recursos na área: ", resources_in_range.size())
		try_harvest_in_area()

func update_harvest_area_position(direction: Vector2):
	if not harvest_area:
		return
	var normalized_dir = direction.normalized()
	var angle = normalized_dir.angle()
	harvest_area.rotation = angle
	harvest_area.position = normalized_dir * 20

func _on_harvest_area_area_entered(area: Area2D):
	print("Área detectada: ", area.name, " Grupos: ", area.get_groups())
	
	# Verificar se é um recurso coletável
	if area.is_in_group("tree") or area.is_in_group("bush"):
		print("✅ Recurso detectado na área de colheita!")
		
		# Destacar o recurso (se tiver método highlight)
		if area.has_method("highlight"):
			area.highlight(true)
		
		if not resources_in_range.has(area):
			resources_in_range.append(area)
			print("Recurso adicionado. Total: ", resources_in_range.size())

func _on_harvest_area_area_exited(area: Area2D):
	if (area.is_in_group("tree") or area.is_in_group("bush")) and resources_in_range.has(area):
		print("Recurso saiu da área: ", area.name)
		
		# Remover destaque
		if area.has_method("highlight"):
			area.highlight(false)
		
		resources_in_range.erase(area)
		print("Recurso removido. Total: ", resources_in_range.size())

func try_harvest_in_area():
	if resources_in_range.is_empty():
		print("❌ Nenhum recurso na área de colheita")
		return
	
	print("Verificando ", resources_in_range.size(), " recursos...")
	
	for i in range(resources_in_range.size()):
		var resource = resources_in_range[i]
		
		if resource == null or not is_instance_valid(resource):
			print("Recurso inválido, removendo da lista")
			resources_in_range.remove_at(i)
			continue
		
		print("Tentando coletar: ", resource.name)
		
		if resource.has_method("harvest"):
			print("Chamando método harvest()...")
			can_harvest = false
			
			# Chamar harvest() e aguardar
			var harvested = await resource.harvest()
			
			if harvested:
				print("✅ Coleta bem-sucedida!")
				# Remover da lista
				if resources_in_range.has(resource):
					resources_in_range.erase(resource)
				break  # Coletar apenas um por vez
			else:
				print("❌ Falha na coleta")
		
		# Pequeno delay para evitar coleta rápida demais
		await get_tree().create_timer(0.1).timeout
	
	# Cooldown antes de poder coletar novamente
	await get_tree().create_timer(0.3).timeout
	can_harvest = true
	print("Pronto para coletar novamente")
