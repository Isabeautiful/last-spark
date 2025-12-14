extends Area2D
class_name Fire

@export var max_energy: float = 100.0
@export var base_consumption_rate: float = 0.5
@export var min_energy_percentage: float = 0.25  # 25% mínimo para não apagar

var current_energy: float = 100.0
var current_consumption_rate: float = 0.5
var fire_level: int = 1  # Nível da chama (1: fraca, 2: moderada, 3: vigorosa)
var is_fire_lit: bool = true

# Referências aos nós da cena (certifique-se que existem!)
@onready var sprite: Sprite2D = $Sprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var light_area: Area2D = $LightArea
@onready var light_area_collision: CollisionShape2D = $LightArea/CollisionShape2D

# Área de interação para o jogador
var interaction_area: Area2D

# Referência à HUD (se existir)
var energy_bar = null

# Configurações de luz
var base_light_energy: float = 1.5
var base_light_radius: float = 300.0
var base_light_area_radius: float = 200.0

func _ready():
	current_energy = max_energy
	
	# Tentar obter a referência da HUD de forma segura
	if get_node_or_null("/root/Game/InGameHUD/CanvasLayer/MarginContainer/VBoxContainer/EnergyBar"):
		energy_bar = get_node("/root/Game/InGameHUD/CanvasLayer/MarginContainer/VBoxContainer/EnergyBar")
	
	add_to_group("fire")
	
	# Configurar luz inicial
	if point_light:
		point_light.energy = base_light_energy
		point_light.texture_scale = 1.0
	
	# Configurar área de luz
	if light_area_collision:
		var shape = light_area_collision.shape as CircleShape2D
		if shape:
			shape.radius = base_light_area_radius
	
	# Criar área de interação para o jogador
	create_interaction_area()
	
	# Conectar sinais da área de luz (APENAS area_entered)
	if light_area:
		light_area.area_entered.connect(_on_light_area_area_entered)
		# REMOVIDO: area_exited não é necessário para o nosso uso
		# light_area.area_exited.connect(_on_light_area_area_exited)
		light_area.add_to_group("fire_light")
	
	# Iniciar timer de consumo
	var consumption_timer = Timer.new()
	consumption_timer.wait_time = 1.0
	consumption_timer.timeout.connect(_on_consumption_timer_timeout)
	add_child(consumption_timer)
	consumption_timer.start()
	
	print("Fogueira inicializada - Energia: ", current_energy, "/", max_energy)

func create_interaction_area():
	# Área para o jogador interagir (adicionar lenha)
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 80  # Aumentei para 80 para ficar mais fácil
	
	interaction_area.add_child(collision)
	interaction_area.add_to_group("fire_interaction")
	
	# Configurar layers
	interaction_area.collision_layer = 4  # fire
	interaction_area.collision_mask = 9   # player_harvest (área do jogador)
	
	add_child(interaction_area)

func _on_consumption_timer_timeout():
	# Consumo baseado no nível da chama
	current_consumption_rate = base_consumption_rate * fire_level
	
	# NPCs na vila aumentam o consumo (se existirem)
	if ResourceManager:
		var npc_count = ResourceManager.current_population
		current_consumption_rate += npc_count * 0.1
	
	# Aplicar consumo
	current_energy -= current_consumption_rate
	current_energy = max(current_energy, 0)
	
	# Atualizar nível da chama
	update_fire_level()
	
	# Atualizar luz e área
	update_light_and_area()
	update_energy_bar()
	
	# Verificar game over
	if current_energy <= 0:
		game_over()
	
	# Verificar chama fraca
	if current_energy / max_energy < min_energy_percentage:
		emit_chama_fraca_warning()

func update_fire_level():
	var energy_percent = current_energy / max_energy
	
	if energy_percent < 0.25:
		fire_level = 1  # Brasas
		if sprite:
			sprite.modulate = Color(0.8, 0.3, 0.1)  # Vermelho fraco
	elif energy_percent < 0.75:
		fire_level = 2  # Moderada
		if sprite:
			sprite.modulate = Color.WHITE
	else:
		fire_level = 3  # Vigorosa
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 0.8)  # Branco amarelado

func update_light_and_area():
	var energy_percent = current_energy / max_energy
	
	# Atualizar PointLight2D
	if point_light:
		# Energia da luz (brilho)
		point_light.energy = base_light_energy * energy_percent
		
		# Raio da luz (texture_scale controla o tamanho)
		point_light.texture_scale = energy_percent
		
		# Cor da luz - mais quente quando mais energia
		if energy_percent > 0.75:
			point_light.color = Color(1.0, 0.9, 0.7)  # Laranja claro
		elif energy_percent > 0.25:
			point_light.color = Color(1.0, 0.7, 0.4)  # Laranja
		else:
			point_light.color = Color(0.8, 0.4, 0.2)  # Vermelho escuro
	
	# Atualizar área de colisão da luz
	if light_area_collision:
		var shape = light_area_collision.shape as CircleShape2D
		if shape:
			# O raio da área cresce com a energia
			shape.radius = base_light_area_radius * energy_percent

func take_damage(amount: float):
	current_energy = max(current_energy - amount, 0)
	update_energy_bar()
	
	# Efeito visual de dano
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	print("Fogueira tomou dano! -", amount, " energia. Total: ", current_energy)
	
	# Verificar se está crítica
	if current_energy / max_energy < 0.1:
		if GameSignals.has_user_signal("fire_critical"):
			GameSignals.fire_critical.emit()

func add_fuel(amount: float):
	current_energy = min(current_energy + amount, max_energy)
	update_energy_bar()
	
	# Efeito visual de adicionar combustível
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	
	print("Combustível adicionado! +", amount, " energia. Total: ", current_energy)

func add_fuel_from_inventory() -> bool:
	if ResourceManager.wood > 0:
		var wood_to_use = 1
		var energy_per_wood = 25.0  # Cada madeira dá 25 de energia
		
		if ResourceManager.use_wood(wood_to_use):
			add_fuel(energy_per_wood)
			
			# Emitir sinal de madeira usada
			if GameSignals.has_user_signal("wood_used"):
				GameSignals.wood_used.emit(wood_to_use)
			
			return true
		else:
			print("Erro ao usar madeira!")
			return false
	else:
		print("Sem madeira no inventário!")
		return false

func update_energy_bar():
	if energy_bar:
		var energy_percent = (current_energy / max_energy) * 100
		energy_bar.value = energy_percent
		
		# Mudar cor baseada no nível
		if energy_percent < 25:
			energy_bar.modulate = Color.RED
		elif energy_percent < 50:
			energy_bar.modulate = Color.YELLOW
		else:
			energy_bar.modulate = Color.GREEN
		
		if energy_bar.has_node("Label"):
			energy_bar.get_node("Label").text = str(int(current_energy)) + "/" + str(int(max_energy))

func _on_light_area_area_entered(area: Area2D):
	# Quando uma sombra entra na área de luz
	if area.is_in_group("shadow"):
		var shadow = area.get_parent()
		if shadow and shadow.has_method("get_damage_amount"):
			var damage = shadow.get_damage_amount()
			take_damage(damage)
			
			# Destruir sombra
			if shadow.has_method("destroy"):
				shadow.destroy()

func emit_chama_fraca_warning():
	if GameSignals.has_user_signal("fire_low_warning"):
		GameSignals.fire_low_warning.emit(current_energy / max_energy)

func game_over():
	if not is_fire_lit:
		return
	
	is_fire_lit = false
	print("GAME OVER: A chama se apagou!")
	
	# Efeito de apagar
	if point_light:
		var tween = create_tween()
		tween.tween_property(point_light, "energy", 0.0, 2.0)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
		await tween.finished
	
	if GameSignals.has_user_signal("game_over"):
		GameSignals.game_over.emit("A chama se apagou!")

func get_fire_level() -> int:
	return fire_level

func get_energy_percentage() -> float:
	return current_energy / max_energy

func get_light_radius() -> float:
	if light_area_collision:
		var shape = light_area_collision.shape as CircleShape2D
		if shape:
			return shape.radius
	return 0.0

# Funções auxiliares para debug
func debug_set_energy(energy: float):
	current_energy = clamp(energy, 0, max_energy)
	update_light_and_area()
	update_energy_bar()
	print("Energia ajustada para: ", current_energy)

func debug_add_wood(amount: int):
	for i in range(amount):
		add_fuel(25.0)
