extends CharacterBody2D

@export var base_speed: float = 250.0
@export var run_speed: float = 400.0

@onready var harvest_area: Area2D = $HarvestArea
@onready var harvest_shape: CollisionShape2D = $HarvestArea/CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

# Status do jogador
var current_speed: float = 250.0
var hunger: float = 100.0  # 0-100
var cold: float = 100.0    # 0-100
var health: float = 100.0  # 0-100
var is_running: bool = false
var is_in_heat_zone: bool = true

# Inventário
var inventory: Dictionary = {
	"wood": 0,
	"food": 0,
	"stone": 0
}

# Coleta e combate
var current_direction: Vector2 = Vector2.DOWN
var resources_in_range: Array[Node] = []
var can_harvest: bool = true
var can_attack: bool = true
var current_weapon: String = "stick"  # stick, axe, spear
var attack_damage: int = 1

# Controles
var can_process_input: bool = true
var fire_in_range: bool = false

# Timers
var hunger_timer: Timer
var cold_timer: Timer

func _ready():
	add_to_group("player")
	setup_areas()
	setup_timers()
	
	# Conectar sinais
	harvest_area.area_entered.connect(_on_harvest_area_area_entered)
	harvest_area.area_exited.connect(_on_harvest_area_area_exited)
	harvest_area.add_to_group("player_harvest")
	
	attack_area.area_entered.connect(_on_attack_area_area_entered)
	
	# Configurar entrada
	_setup_input_actions()

func setup_areas():
	# Área de coleta/interação (harvest_area)
	if harvest_shape:
		var shape = harvest_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(80, 40)
	
	# Configurar layers e masks
	harvest_area.collision_layer = 0  # Não precisa detectar outras áreas
	harvest_area.collision_mask = 2 | 4  # Detecta collectibles (2) e fire (4)
	
	# Área de ataque
	if attack_shape:
		var shape = attack_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(60, 60)
	
	attack_area.collision_layer = 0
	attack_area.collision_mask = 3  # Detecta enemies (3)
	
	# O próprio jogador (CharacterBody2D)
	self.collision_layer = 1  # player
	self.collision_mask = 1 | 5 | 7  # Colide com player (1), buildings (5), terrain (7)
	
	update_areas_position(Vector2.DOWN)


func setup_timers():
	# Timer de fome
	hunger_timer = Timer.new()
	hunger_timer.wait_time = 5.0  # Perde fome a cada 5 segundos
	hunger_timer.timeout.connect(_on_hunger_timer_timeout)
	add_child(hunger_timer)
	hunger_timer.start()
	
	# Timer de frio
	cold_timer = Timer.new()
	cold_timer.wait_time = 3.0  # Verifica frio a cada 3 segundos
	cold_timer.timeout.connect(_on_cold_timer_timeout)
	add_child(cold_timer)
	cold_timer.start()

func _setup_input_actions():
	# Ação de correr (Shift)
	if not InputMap.has_action("run"):
		InputMap.add_action("run")
		var event_shift = InputEventKey.new()
		event_shift.keycode = KEY_SHIFT
		InputMap.action_add_event("run", event_shift)
	
	# Ação de atacar (Barra de Espaço ou Botão Esquerdo do Mouse)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		# Barra de espaço
		var event_space = InputEventKey.new()
		event_space.keycode = KEY_SPACE
		InputMap.action_add_event("attack", event_space)
		
		# Botão esquerdo do mouse (para clicar nas sombras)
		var event_mouse_left = InputEventMouseButton.new()
		event_mouse_left.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", event_mouse_left)
	
	# Ação de interagir (F ou Clique em recursos/fogo)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		# Tecla F
		var event_f = InputEventKey.new()
		event_f.keycode = KEY_F
		InputMap.action_add_event("interact", event_f)
		
		# Botão direito do mouse (para coletar recursos)
		var event_mouse_right = InputEventMouseButton.new()
		event_mouse_right.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("interact", event_mouse_right)
	
	# Ação de comer (Q)
	if not InputMap.has_action("eat"):
		InputMap.add_action("eat")
		var event_q = InputEventKey.new()
		event_q.keycode = KEY_Q
		InputMap.action_add_event("eat", event_q)
	
	# Ação de construção (B)
	if not InputMap.has_action("build_menu"):
		InputMap.add_action("build_menu")
		var event_b = InputEventKey.new()
		event_b.keycode = KEY_B
		InputMap.action_add_event("build_menu", event_b)

func _physics_process(delta):
	if not can_process_input:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Calcular velocidade baseada na fome e corrida
	var speed_multiplier = 1.0
	if hunger > 70:
		speed_multiplier = 1.1  # Bônus se bem alimentado
	elif hunger < 30:
		speed_multiplier = 0.7  # Penalidade se com fome
	
	current_speed = base_speed * speed_multiplier
	
	# Correr (consome fome extra)
	if Input.is_action_pressed("run") and hunger > 10:
		current_speed = run_speed * speed_multiplier
		is_running = true
		
		# Consumir fome extra ao correr
		hunger -= delta * 5
	else:
		is_running = false
	
	# Movimentação
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	
	if input_dir.length() > 0.1:
		current_direction = input_dir.normalized()
		update_areas_position(current_direction)
		
		# Animação simples (poderia ser sprite sheets)
		sprite.rotation = current_direction.angle()
	
	velocity = input_dir * current_speed
	move_and_slide()
	
	# Atualizar HUD
	GameSignals.player_status_changed.emit(health, hunger, cold)

func _input(event):
	if not can_process_input:
		return
	
	# Coleta com botão esquerdo ou tecla E
	if (event.is_action_pressed("Collect") or 
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		
		if can_harvest and not resources_in_range.is_empty():
			try_harvest_in_area()
	
	# Interagir com fogo (tecla F) - CORREÇÃO: usar "interact" minúsculo
	if event.is_action_pressed("Interact"):
		if fire_in_range:
			var fire = get_tree().get_first_node_in_group("fire")
			if fire and fire.has_method("add_fuel_from_inventory"):
				fire.add_fuel_from_inventory()
	
	# Ataque (barra de espaço ou botão direito)
	if event.is_action_pressed("attack"):
		if can_attack:
			perform_attack()

func update_areas_position(direction: Vector2):
	var normalized_dir = direction.normalized()
	var angle = normalized_dir.angle()
	
	# Área de coleta na frente
	harvest_area.rotation = angle
	harvest_area.position = normalized_dir * 25
	
	# Área de ataque ao redor (ou na frente para arma de longo alcance)
	if current_weapon == "spear":
		attack_area.rotation = angle
		attack_area.position = normalized_dir * 35
	else:
		# Armas curtas atacam ao redor
		attack_area.rotation = 0
		attack_area.position = Vector2.ZERO

func _on_hunger_timer_timeout():
	# Perder fome com o tempo
	hunger -= 2
	
	# Se correu recentemente, perde mais fome
	if is_running:
		hunger -= 3
	
	hunger = max(hunger, 0)
	
	# Se fome muito baixa, perde vida
	if hunger <= 0:
		take_damage(5, "fome")
	
	# Atualizar HUD
	GameSignals.player_status_changed.emit(health, hunger, cold)

func _on_cold_timer_timeout():
	# Verificar se está na zona de calor
	var fire = get_tree().get_first_node_in_group("fire")
	if fire:
		var distance_to_fire = global_position.distance_to(fire.global_position)
		
		# CORREÇÃO: usar get_light_radius() em vez de get_heat_radius()
		if fire.has_method("get_light_radius"):
			var heat_radius = fire.get_light_radius()
			
			is_in_heat_zone = distance_to_fire <= heat_radius
			
			# Se estiver fora da zona de calor, esfria mais rápido
			if not is_in_heat_zone:
				cold -= 10
				
				# Se muito frio, toma dano
				if cold <= 20:
					take_damage(3, "frio")
			else:
				# Dentro da zona de calor, recupera lentamente
				cold = min(cold + 5, 100)
		else:
			# Se o fogo não tem o método, assume que não há calor
			cold -= 10
	else:
		# Sem fogo, esfria rápido
		cold -= 15
	
	cold = max(cold, 0)
	
	# Atualizar HUD
	GameSignals.player_status_changed.emit(health, hunger, cold)

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

func _on_attack_area_area_entered(area: Area2D):
	if area.is_in_group("shadow"):
		# Feedback visual de inimigo próximo
		area.get_parent().highlight(true)

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

func perform_attack():
	if not can_attack:
		return
	
	can_attack = false
	
	# Animação de ataque
	var original_scale = sprite.scale
	var tween = create_tween()
	tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.1)
	
	# Verificar sombras na área de ataque
	var overlapping_areas = attack_area.get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("shadow"):
			var shadow = area.get_parent()
			if shadow and shadow.has_method("take_damage"):
				shadow.take_damage(attack_damage)
				
				# Feedback
				GameSignals.player_attacked.emit(attack_damage)
	
	# Tempo de recarga baseado na arma
	var cooldown = 0.5
	if current_weapon == "spear":
		cooldown = 0.7
	elif current_weapon == "axe":
		cooldown = 0.9
	
	await get_tree().create_timer(cooldown).timeout
	can_attack = true

func take_damage(amount: float, source: String = ""):
	health -= amount
	health = max(health, 0)
	
	# Efeito visual
	sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	print("Jogador tomou dano! -", amount, " de ", source, ". Vida: ", health)
	
	# Verificar morte
	if health <= 0:
		die()
	
	# Atualizar HUD
	GameSignals.player_status_changed.emit(health, hunger, cold)

func eat_food(amount: int = 10):
	if ResourceManager.food >= 1:
		if ResourceManager.use_food(1):
			hunger = min(hunger + amount, 100)
			print("Jogador comeu! Fome: ", hunger)
			
			# Efeito visual
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.GREEN, 0.2)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
			
			return true
	return false

func die():
	print("JOGADOR MORREU!")
	can_process_input = false
	
	# Animação de morte
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(sprite, "rotation", sprite.rotation + PI, 1.0)
	await tween.finished
	
	GameSignals.player_died.emit()
	# O jogo pode continuar se houver outros NPCs, mas por enquanto game over
	GameSignals.game_over.emit("O jogador morreu!")

func set_can_process_input(can_process: bool):
	can_process_input = can_process
	
	if not can_process:
		velocity = Vector2.ZERO
		move_and_slide()

func get_status() -> Dictionary:
	return {
		"health": health,
		"hunger": hunger,
		"cold": cold,
		"position": global_position
	}
