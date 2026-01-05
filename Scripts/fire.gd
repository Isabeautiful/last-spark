extends Node2D
class_name Fire

@export var max_energy: float = 100.0
@export var base_consumption_rate: float = 0.5
@export var min_energy_percentage: float = 0.25

var current_energy: float
var current_consumption_rate: float = 0.5
var fire_level: int = 1
var is_fire_lit: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var point_light: PointLight2D = $PointLight2D
@onready var light_area: Area2D = $LightArea
@onready var light_area_collision: CollisionShape2D = $LightArea/CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea

var is_low_warning_set = false
var is_critical_warning_set = false

var energy_bar = null

var base_light_energy: float = 1.5
var base_light_area_radius: float = 200.0

func _ready():
	current_energy = max_energy
	
	# Obter referência da HUD
	if get_node_or_null("/root/Game/InGameHUD/CanvasLayer/MarginContainer3/VBoxContainer/HBoxContainer4/EnergyBar"):
		energy_bar = get_node("/root/Game/InGameHUD/CanvasLayer/MarginContainer3/VBoxContainer/HBoxContainer4/EnergyBar")
	
	add_to_group("fire")
	
	# Configurar luz
	if point_light:
		point_light.energy = base_light_energy
		point_light.texture_scale = 1.0
	
	if light_area_collision:
		var shape = light_area_collision.shape as CircleShape2D
		if shape:
			shape.radius = base_light_area_radius
	
	# Criar área de interação
	interaction_area.add_to_group("fire_interaction")
	
	# Conectar sinais
	if light_area:
		light_area.area_entered.connect(_on_light_area_area_entered)
		light_area.add_to_group("fire_light")
	
	# Timer de consumo
	var consumption_timer = Timer.new()
	consumption_timer.wait_time = 1.0
	consumption_timer.timeout.connect(_on_consumption_timer_timeout)
	add_child(consumption_timer)
	consumption_timer.start()
	
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
	update_light_and_area()
	update_energy_bar()
	
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

func update_light_and_area():
	var energy_percent = current_energy / max_energy
	
	if point_light:
		point_light.energy = base_light_energy * energy_percent
		point_light.texture_scale = energy_percent
		
		if energy_percent > 0.75:
			point_light.color = Color(1.0, 0.9, 0.7)
		elif energy_percent > 0.25:
			point_light.color = Color(1.0, 0.7, 0.4)
		else:
			point_light.color = Color(0.8, 0.4, 0.2)
	
	if light_area_collision:
		var shape = light_area_collision.shape as CircleShape2D
		if shape:
			shape.radius = base_light_area_radius * energy_percent

func take_damage(amount: float):
	current_energy = max(current_energy - amount, 0)
	update_energy_bar()
	
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
