extends Control

@onready var canvas_layer = $CanvasLayer
@onready var energy_bar = $CanvasLayer/MarginContainer3/VBoxContainer/HBoxContainer4/EnergyBar
@onready var day_label = $CanvasLayer/MarginContainer2/HBoxContainer/VBoxContainer/VBoxContainer_day/DayLabel
@onready var wood_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/WoodLabel
@onready var food_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer/FoodLabel
@onready var pop_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer2/PopulationLabel
@onready var time_indicator: Label = $CanvasLayer/MarginContainer2/HBoxContainer/VBoxContainer/VBoxContainer_day/TimeIndicator
@onready var build_button = $CanvasLayer/MarginContainer/VBoxContainer/BuildButton
@onready var player_status = $CanvasLayer/MarginContainer3/VBoxContainer/PlayerStatus

@onready var warning_label_Cont = $CanvasLayer/MarginContainer2/HBoxContainer/VBoxContainer/WarningLabel
# NOVOS labels para sementes
@onready var tree_seeds_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer3/TreeSeedsLabel
@onready var bush_seeds_label = $CanvasLayer/MarginContainer/VBoxContainer/HBoxContainer3/BushSeedsLabel
@onready var planting_mode_label = $CanvasLayer/MarginContainer/VBoxContainer/PlantingModeLabel
# Barras de status do jogador
@onready var health_bar = $CanvasLayer/MarginContainer3/VBoxContainer/PlayerStatus/HBoxContainer/HealthBar
@onready var hunger_bar = $CanvasLayer/MarginContainer3/VBoxContainer/PlayerStatus/HBoxContainer2/HungerBar
@onready var cold_bar = $CanvasLayer/MarginContainer3/VBoxContainer/PlayerStatus/HBoxContainer3/ColdBar



func _ready():
	update_all_displays()
	
	if build_button:
		build_button.pressed.connect(_on_build_button_pressed)
		build_button.text = "Construir (B/RClick)"
	
	# Configurar barras de status
	health_bar.max_value = 100
	hunger_bar.max_value = 100
	cold_bar.max_value = 100
	
	# Conectar sinais de sementes
	ResourceManager.tree_seeds_changed.connect(_on_tree_seeds_changed)
	ResourceManager.bush_seeds_changed.connect(_on_bush_seeds_changed)
	
	GameSignals.planting_mode_changed.connect(_on_planting_mode_changed)
	
	GameSignals.player_status_changed.connect(update_player_status)
	GameSignals.hideWarning.connect(hide_warning)
	GameSignals.showWarning.connect(show_warning)
	
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
	# Atualizar sementes
	tree_seeds_label.text = "Semente Árvore: " + str(ResourceManager.tree_seeds)
	bush_seeds_label.text = "Semente Comida: " + str(ResourceManager.bush_seeds)

func _on_tree_seeds_changed(amount: int):
	tree_seeds_label.text = "Semente Árvore: " + str(amount)

func _on_bush_seeds_changed(amount: int):
	bush_seeds_label.text = "Semente Comida: " + str(amount)

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

func update_bar_color(bar, value: float):
	if value < 25:
		bar.modulate = Color.RED
	elif value < 50:
		bar.modulate = Color.YELLOW
	else:
		bar.modulate = Color.GREEN

func show_warning(message: String,child_meta:String):
	var warning_label = Label.new()
	warning_label.text = "⚠️ " + message
	warning_label.set_meta("tipo",child_meta)
	# Efeito de piscar
	var tween = create_tween()
	tween.tween_property(warning_label, "modulate:a", 0.5, 0.5)
	tween.tween_property(warning_label, "modulate:a", 1.0, 0.5)
	tween.set_loops(5)
	
	warning_label_Cont.add_child(warning_label)
	
func hide_warning(child_meta:String):
	print("RODOU, removendo: ",child_meta)
	for child in warning_label_Cont.get_children():
		print("lista: ",child.get_meta("tipo"),"busca: ", child_meta)
		if child.get_meta("tipo") == child_meta:
			warning_label_Cont.remove_child(child)
			child.queue_free()
	
func update_all_displays():
	update_resources()

func _on_planting_mode_changed(is_active: bool):
	if is_active:
		planting_mode_label.text = "MODO PLANTIO ATIVO (V para sair, T para trocar)"
		planting_mode_label.modulate = Color.GREEN
		planting_mode_label.show()
		
		# Mostrar qual semente está selecionada
		var planting_system = get_tree().get_first_node_in_group("planting_system")
		if planting_system and planting_system.has_method("get_current_seed_type"):
			var seed_type = planting_system.get_current_seed_type()
			if seed_type == "tree":
				planting_mode_label.text += "\n[Semente de Árvore Selecionada]"
			elif seed_type == "bush":
				planting_mode_label.text += "\n[Semente de Arbusto Selecionada]"
	else:
		planting_mode_label.hide()
