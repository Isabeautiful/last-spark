extends Control

@onready var hut_button = $Panel/VBoxContainer/HutButton
@onready var kitchen_button = $Panel/VBoxContainer/KitchenButton
@onready var storage_button = $Panel/VBoxContainer/StorageButton
@onready var tower_button = $Panel/VBoxContainer/TowerButton

@onready var building_system = get_node("/root/Game/BuildingSystem")

func _ready():
	# Conectar botões
	hut_button.pressed.connect(_on_hut_pressed)
	kitchen_button.pressed.connect(_on_kitchen_pressed)
	storage_button.pressed.connect(_on_storage_pressed)
	tower_button.pressed.connect(_on_tower_pressed)
	
	# Atualizar textos
	update_button_texts()
	
	# Esconder inicialmente
	hide()

func update_button_texts():
	# Usar os custos do BuildingSystem
	if building_system:
		var hut_config = building_system.building_configs[building_system.BuildingType.HUT]
		var kitchen_config = building_system.building_configs[building_system.BuildingType.KITCHEN]
		var storage_config = building_system.building_configs[building_system.BuildingType.STORAGE]
		var tower_config = building_system.building_configs[building_system.BuildingType.TOWER]
		
		hut_button.text = "Cabana\nMadeira: %d\nComida: %d" % [hut_config.cost_wood, hut_config.cost_food]
		kitchen_button.text = "Cozinha\nMadeira: %d\nComida: %d" % [kitchen_config.cost_wood, kitchen_config.cost_food]
		storage_button.text = "Depósito\nMadeira: %d\nComida: %d" % [storage_config.cost_wood, storage_config.cost_food]
		tower_button.text = "Torre\nMadeira: %d\nComida: %d" % [tower_config.cost_wood, tower_config.cost_food]

func _on_hut_pressed():
	building_system.start_building(building_system.BuildingType.HUT)
	hide()

func _on_kitchen_pressed():
	building_system.start_building(building_system.BuildingType.KITCHEN)
	hide()

func _on_storage_pressed():
	building_system.start_building(building_system.BuildingType.STORAGE)
	hide()

func _on_tower_pressed():
	building_system.start_building(building_system.BuildingType.TOWER)
	hide()
