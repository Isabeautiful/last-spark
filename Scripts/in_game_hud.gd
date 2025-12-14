extends Control

@onready var canvas_layer = $CanvasLayer
@onready var energy_bar = $CanvasLayer/MarginContainer/VBoxContainer/EnergyBar
@onready var day_label = $CanvasLayer/MarginContainer/VBoxContainer/DayLabel
@onready var wood_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/WoodLabel
@onready var food_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/FoodLabel
@onready var pop_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer2/PopulationLabel
@onready var time_indicator = $CanvasLayer/MarginContainer/VBoxContainer/TimeIndicator
@onready var build_button = $CanvasLayer/MarginContainer/VBoxContainer/BuildButton

func _ready():
	update_all_displays()
	
	if build_button:
		build_button.pressed.connect(_on_build_button_pressed)
		build_button.text = "Construir (B/RClick)"

func _on_build_button_pressed():
	# Emitir sinal para abrir menu de construção
	GameSignals.build_menu_toggled.emit()

func update_energy(energy: float, max_energy: float):
	energy_bar.value = (energy / max_energy) * 100
	if energy_bar.get_node("Label"):
		energy_bar.get_node("Label").text = str(int(energy)) + "/" + str(int(max_energy))

func update_day(day: int):
	day_label.text = "DIA " + str(day)

func update_resources():
	wood_label.text = "Lenha: " + str(ResourceManager.wood) + "/" + str(ResourceManager.max_wood)
	food_label.text = "Comida: " + str(ResourceManager.food) + "/" + str(ResourceManager.max_food)
	pop_label.text = "Pop: " + str(ResourceManager.current_population) + "/" + str(ResourceManager.max_population)

func update_time(is_day: bool, _time_percent: float):
	if is_day:
		time_indicator.text = "☀️ DIA"
		time_indicator.modulate = Color(1, 1, 0.8)
	else:
		time_indicator.text = "🌙 NOITE"
		time_indicator.modulate = Color(0.5, 0.5, 1)

func update_all_displays():
	update_resources()
