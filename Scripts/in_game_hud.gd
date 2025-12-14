extends Control

@onready var canvas_layer = $CanvasLayer
@onready var energy_bar = $CanvasLayer/MarginContainer/VBoxContainer/EnergyBar
@onready var day_label = $CanvasLayer/MarginContainer/VBoxContainer/DayLabel
@onready var wood_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/WoodLabel
@onready var food_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/FoodLabel
@onready var pop_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer2/PopulationLabel
@onready var time_indicator = $CanvasLayer/MarginContainer/VBoxContainer/TimeIndicator
@onready var build_button = $CanvasLayer/MarginContainer/VBoxContainer/BuildButton
@onready var player_status = $CanvasLayer/MarginContainer/VBoxContainer/PlayerStatus
@onready var warning_label = $CanvasLayer/MarginContainer/VBoxContainer/WarningLabel

# Barras de status do jogador
@onready var health_bar = $CanvasLayer/MarginContainer/VBoxContainer/PlayerStatus/HealthBar
@onready var hunger_bar = $CanvasLayer/MarginContainer/VBoxContainer/PlayerStatus/HungerBar
@onready var cold_bar = $CanvasLayer/MarginContainer/VBoxContainer/PlayerStatus/ColdBar

func _ready():
	update_all_displays()
	
	if build_button:
		build_button.pressed.connect(_on_build_button_pressed)
		build_button.text = "Construir (B/RClick)"
	
	# Inicialmente esconder warning
	warning_label.hide()
	
	# Configurar barras de status
	health_bar.max_value = 100
	hunger_bar.max_value = 100
	cold_bar.max_value = 100

func _on_build_button_pressed():
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

func update_time_of_day(time: String):
	match time:
		"day":
			time_indicator.text = "☀️ DIA"
			time_indicator.modulate = Color(1, 1, 0.8)
		"evening":
			time_indicator.text = "🌆 TARDE"
			time_indicator.modulate = Color(1, 0.6, 0.3)
		"night":
			time_indicator.text = "🌙 NOITE"
			time_indicator.modulate = Color(0.5, 0.5, 1)

func update_player_status(health: float, hunger: float, cold: float):
	health_bar.value = health
	hunger_bar.value = hunger
	cold_bar.value = cold
	
	# Atualizar cores baseadas nos valores
	update_bar_color(health_bar, health)
	update_bar_color(hunger_bar, hunger)
	update_bar_color(cold_bar, cold)

func update_bar_color(bar: ProgressBar, value: float):
	if value < 25:
		bar.modulate = Color.RED
	elif value < 50:
		bar.modulate = Color.YELLOW
	else:
		bar.modulate = Color.GREEN

func show_warning(message: String):
	warning_label.text = "⚠️ " + message
	warning_label.show()
	
	# Efeito de piscar
	var tween = create_tween()
	tween.tween_property(warning_label, "modulate:a", 0.5, 0.5)
	tween.tween_property(warning_label, "modulate:a", 1.0, 0.5)
	tween.set_loops(3)
	
	# Esconder após 3 segundos
	await get_tree().create_timer(3.0).timeout
	warning_label.hide()

func update_all_displays():
	update_resources()
