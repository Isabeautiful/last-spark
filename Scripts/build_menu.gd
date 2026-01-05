extends CanvasLayer 

@onready var buttons = [
	$Panel/VBoxContainer/HutButton,
	$Panel/VBoxContainer/KitchenButton,
	$Panel/VBoxContainer/StorageButton,
	$Panel/VBoxContainer/TowerButton
]

var building_system: BuildingSystem

func _ready():
	# Obter referência ao BuildingSystem
	building_system = get_tree().root.get_node("Game/BuildingSystem")
	
	if building_system == null:
		print("ERRO: BuildingSystem não encontrado!")
		return
	
	# Configurar botões
	_update_button_texts()
	
	# Posicionar no centro da tela
	_center_menu()
	
	# Esconder inicialmente
	hide()

func _update_button_texts():
	for i in range(buttons.size()):
		if i < building_system.building_resources.size():
			var config = building_system.building_resources[i]
			buttons[i].text = "%s\nMadeira: %d\nComida: %d" % [config.building_name, config.cost_wood, config.cost_food]
			# Conectar sinal com índice
			if not buttons[i].pressed.is_connected(_on_building_button_pressed):
				buttons[i].pressed.connect(_on_building_button_pressed.bind(i))
			buttons[i].show()
		else:
			buttons[i].hide()

func _center_menu():
	# Obter tamanho da viewport
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Definir tamanho do Panel
	$Panel.custom_minimum_size = Vector2(400, 500)
	
	# Centralizar o Panel
	$Panel.position = (viewport_size - $Panel.size) / 2

func _on_building_button_pressed(index: int):
	if building_system:
		building_system.start_building(index)
		hide()
