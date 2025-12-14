extends Node2D

@export var max_energy: float = 100.0
@export var consumption_rate: float = 1.0
var current_energy: float = 100.0

@onready var light_area = $LightArea
@onready var energy_bar = get_node("/root/Game/InGameHUD/CanvasLayer/MarginContainer/VBoxContainer/EnergyBar") if get_node("/root/Game/InGameHUD") else null

func _ready():
	current_energy = max_energy
	update_energy_bar()
	add_to_group("fire")
	
	if light_area:
		light_area.add_to_group("fire_light")
	
	# Área central para dano
	var core_area = Area2D.new()
	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 20
	core_area.add_child(collision)
	core_area.add_to_group("fire_core")
	add_child(core_area)

func _process(delta):
	current_energy -= consumption_rate * delta
	current_energy = max(current_energy, 0)
	
	if light_area:
		var energy_percent = current_energy / max_energy
		light_area.scale = Vector2.ONE * energy_percent
	
	update_energy_bar()
	
	if current_energy <= 0:
		game_over()

func take_damage(amount: float):
	current_energy = max(current_energy - amount, 0)
	update_energy_bar()
	$Sprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$Sprite2D.modulate = Color.WHITE

func add_fuel(amount: float):
	current_energy = min(current_energy + amount, max_energy)
	update_energy_bar()

func update_energy_bar():
	if energy_bar:
		energy_bar.value = (current_energy / max_energy) * 100

func game_over():
	GameSignals.game_over.emit("A chama se apagou!")
