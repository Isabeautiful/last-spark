extends Area2D
class_name Fire

@export var max_energy: float = 100.0
@export var base_consumption_rate: float = 0.5
@export var min_energy_percentage: float = 0.25

@onready var consumption_timer: Timer = $ConsumptionTimer

var current_energy: float
var current_consumption_rate: float = 0.5
var fire_level: int = 1
var is_fire_lit: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var light_area: Area2D = $LightArea
@onready var light_area_collision: CollisionShape2D = $LightArea/CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var point_light: PointLight2D = $PointLight2D

var is_low_warning_set = false
var is_critical_warning_set = false

var energy_bar = null

var base_light_energy: float = 1.5
var base_light_area_radius: float = 172.16562
var base_light_texture_scale: float = 1.72

func _ready():
	current_energy = max_energy
	
	if get_node_or_null("/root/Game/InGameHUD/CanvasLayer/MarginContainer3/VBoxContainer/HBoxContainer4/EnergyBar"):
		energy_bar = get_node("/root/Game/InGameHUD/CanvasLayer/MarginContainer3/VBoxContainer/HBoxContainer4/EnergyBar")
	
	add_to_group("fire")
	
	# Obter valores iniciais da luz
	if point_light:
		base_light_energy = point_light.energy
		base_light_texture_scale = point_light.texture_scale
	
	# Criar área de interação
	interaction_area.add_to_group("fire_interaction")
	
	# Conectar sinais
	if light_area:
		light_area.area_entered.connect(_on_light_area_area_entered)
		light_area.add_to_group("fire_light")
	
	if not consumption_timer.timeout.is_connected(_on_consumption_timer_timeout):
		consumption_timer.timeout.connect(_on_consumption_timer_timeout)
	
	# Configurar luz inicial
	update_light()

func set_warning_status(status,cond):
	match cond:
		"low":
			is_low_warning_set = status
		"critical":
			is_critical_warning_set = status

func _on_consumption_timer_timeout():
	current_consumption_rate = base_consumption_rate * fire_level
	
	current_energy -= current_consumption_rate
	current_energy = max(current_energy, 0)
	
	update_fire_level()
	update_energy_bar()
	update_light()  # Adicionar chamada para atualizar a luz
	
	if current_energy <= 0:
		game_over()
	
	if current_energy / max_energy < min_energy_percentage:
		emit_chama_fraca_warning()
	elif is_low_warning_set:
		is_low_warning_set = false
		print("foi foi")
		GameSignals.hideWarning.emit("low")

func update_fire_level():
	var energy_percent = current_energy / max_energy
	
	if energy_percent < 0.25:
		fire_level = 1
		if sprite:
			sprite.modulate = Color(0.8, 0.3, 0.1)
	elif energy_percent < 0.75:
		fire_level = 2
		if sprite:
			sprite.modulate = Color.WHITE
	else:
		fire_level = 3
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 0.8)
	
	if light_area_collision:
		var shape = light_area_collision.shape as CircleShape2D
		if shape:
			# Usando uma função de interpolação suave para o raio
			shape.radius = base_light_area_radius * clamp(energy_percent, 0.3, 1.0)
	
	update_light()

func update_light():
	var energy_percent = current_energy / max_energy
	if point_light:
		# Ajustar intensidade da luz com um mínimo para não apagar completamente
		point_light.energy = base_light_energy * clamp(energy_percent, 0.2, 1.0)
		
		# Ajustar o texture_scale para controlar o tamanho da luz
		# Usando uma interpolação suave com um mínimo
		var scale_factor = clamp(energy_percent, 0.3, 1.0)
		point_light.texture_scale = base_light_texture_scale * scale_factor
		
		# Ajustar a cor da luz conforme a energia
		if energy_percent < 0.25:
			point_light.color = Color(1.0, 0.6, 0.4)  # Laranja avermelhado mais suave
		elif energy_percent < 0.75:
			point_light.color = Color(1.0, 0.85, 0.7)  # Laranja claro mais suave
		else:
			point_light.color = Color(1.0, 0.95, 0.9)  # Quase branco, levemente amarelado
		
		# Ajustar sombra baseado na energia
		point_light.shadow_enabled = energy_percent > 0.15
		
		# Ajustar opacidade da luz (não diretamente suportado, mas podemos usar modulate)
		point_light.visible = energy_percent > 0.05

func take_damage(amount: float):
	current_energy = max(current_energy - amount, 0)
	update_energy_bar()
	update_light()  # Adicionar para atualizar luz quando tomar dano
	
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	if current_energy / max_energy < 0.1:
		if GameSignals.has_user_signal("fire_critical"):
			GameSignals.fire_critical.emit()
			
	elif is_critical_warning_set:
		is_critical_warning_set = false
		print("foi")
		GameSignals.hideWarning.emit("critical")
	

func add_fuel(amount: float):
	current_energy = min(current_energy + amount, max_energy)
	update_energy_bar()
	update_light()  # Adicionar para atualizar luz quando adicionar combustível
	
	# Efeito visual ao adicionar combustível
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(0.5, 1.0, 0.5)  # Verde claro
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_modulate, 0.5)
	
	# Efeito de piscar na luz ao adicionar combustível
	if point_light:
		var original_energy = point_light.energy
		point_light.energy = original_energy * 1.2  # Aumenta temporariamente
		var tween = create_tween()
		tween.tween_property(point_light, "energy", original_energy, 0.5)

func add_fuel_from_inventory() -> bool:
	if ResourceManager.wood > 0:
		var wood_to_use = 1
		var energy_per_wood = 25.0
		
		if ResourceManager.use_wood(wood_to_use):
			add_fuel(energy_per_wood)
			
			if GameSignals.has_user_signal("wood_used"):
				GameSignals.wood_used.emit(wood_to_use)
			
			return true
	return false

func update_energy_bar():
	if energy_bar:
		var energy_percent = (current_energy / max_energy) * 100
		energy_bar.value = energy_percent
		
		if energy_percent < 25:
			energy_bar.modulate = Color.RED
		elif energy_percent < 50:
			energy_bar.modulate = Color.YELLOW
		else:
			energy_bar.modulate = Color.GREEN
		
		if energy_bar.has_node("Label"):
			energy_bar.get_node("Label").text = str(int(current_energy)) + "/" + str(int(max_energy))

func _on_light_area_area_entered(area: Area2D):
	if area.is_in_group("shadow"):
		var shadow = area.get_parent()
		if shadow and shadow.has_method("get_damage_amount"):
			var damage = shadow.get_damage_amount()
			take_damage(damage)
			
			if shadow.has_method("destroy"):
				shadow.destroy()

func emit_chama_fraca_warning():
	if GameSignals.has_user_signal("fire_low_warning"):
		GameSignals.fire_low_warning.emit(current_energy / max_energy)

func game_over():
	if not is_fire_lit:
		return
	
	is_fire_lit = false
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 2.0)
		if point_light:
			tween.parallel().tween_property(point_light, "energy", 0.0, 2.0)
			tween.parallel().tween_property(point_light, "texture_scale", 0.0, 2.0)
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
