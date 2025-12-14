extends Node2D

@onready var player = $Player
@onready var fire = $Fire
@onready var hud = $InGameHUD
@onready var day_night_cycle = $DayNightCycle
@onready var shadow_spawner = $ShadowSpawner
@onready var building_system = $BuildingSystem
@onready var build_menu = $BuildMenu

var current_day: int = 1
var game_state: String = "playing"  # "playing", "building", "menu"

func _ready():
	ResourceManager.wood_changed.connect(_on_wood_changed)
	ResourceManager.food_changed.connect(_on_food_changed)
	ResourceManager.population_changed.connect(_on_population_changed)
	
	hud.update_day(current_day)
	
	day_night_cycle.day_started.connect(_on_day_started)
	day_night_cycle.night_started.connect(_on_night_started)
	
	# Conectar sinais de fim de jogo
	GameSignals.game_over.connect(_on_game_over)
	GameSignals.victory.connect(_on_victory)
	
	if shadow_spawner:
		shadow_spawner.set_active(false)
	
	# Configurar entrada
	_setup_inputs()
	
	# Conectar sinais
	if building_system:
		building_system.build_mode_changed.connect(_on_build_mode_changed)
	
	# Inicialmente esconder menu
	if build_menu:
		build_menu.hide()
	
	# Debug: adicionar recursos para teste
	ResourceManager.debug_add_resources()

func _setup_inputs():
	# Ação para construção
	if not InputMap.has_action("build_menu"):
		InputMap.add_action("build_menu")
		var event_b = InputEventKey.new()
		event_b.keycode = KEY_B
		InputMap.action_add_event("build_menu", event_b)
		
		var event_mouse = InputEventMouseButton.new()
		event_mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("build_menu", event_mouse)
	
	# Ação para interagir (com fogo)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event_f = InputEventKey.new()
		event_f.keycode = KEY_F
		InputMap.action_add_event("interact", event_f)

func _input(event):
	# Abrir/fechar menu de construção
	if event.is_action_pressed("build_menu"):
		if game_state == "playing":
			_enter_build_menu_mode()
		elif game_state == "building" or game_state == "menu":
			_return_to_playing_mode()
	
	# Cancelar com ESC
	if event.is_action_pressed("ui_cancel"):
		if game_state == "building":
			building_system.cancel_building()
			_return_to_playing_mode()
		elif game_state == "menu":
			build_menu.hide()
			_return_to_playing_mode()

func _enter_build_menu_mode():
	game_state = "menu"
	
	if build_menu:
		build_menu.show()
	
	if player:
		player.set_can_process_input(false)
	
	print("Entrou no modo menu de construção")

func _enter_building_mode():
	game_state = "building"
	
	if build_menu and build_menu.visible:
		build_menu.hide()
	
	print("Entrou no modo construção")

func _return_to_playing_mode():
	game_state = "playing"
	
	if build_menu:
		build_menu.hide()
	
	if building_system and building_system.is_building_mode:
		building_system.cancel_building()
	
	if player:
		player.set_can_process_input(true)
	
	print("Retornou ao modo jogo")

func _on_build_mode_changed(active: bool):
	if active:
		_enter_building_mode()
	else:
		_return_to_playing_mode()

func _on_wood_changed(_amount):
	hud.update_resources()

func _on_food_changed(_amount):
	hud.update_resources()

func _on_population_changed(_amount):
	hud.update_resources()

func _on_day_started(day_number: int):
	print("=== DIA ", day_number, " INICIADO ===")
	current_day = day_number
	hud.update_day(current_day)
	hud.update_time(true, day_night_cycle.get_time_percent())
	
	if shadow_spawner:
		shadow_spawner.set_active(false)
	
	# Aumentar dificuldade progressivamente
	if shadow_spawner and day_number > 1:
		shadow_spawner.max_shadows = 10 + (day_number * 2)
		shadow_spawner.spawn_interval = max(0.5, 2.0 - (day_number * 0.1))
		print("Dificuldade aumentada: Dia ", day_number)
	
	if current_day >= 10:
		GameSignals.victory.emit("Sobreviveu 10 dias!")

func _on_night_started():
	print("=== NOITE INICIADA ===")
	hud.update_time(false, day_night_cycle.get_time_percent())
	
	if shadow_spawner:
		shadow_spawner.set_active(true)

func _on_game_over(reason: String):
	print("GAME OVER: ", reason)
	# Aqui você carregaria a tela de derrota
	# get_tree().change_scene_to_file("res://Scenes/UI/GameOverScreen.tscn")
	
	# Por enquanto, apenas recarrega a cena
	get_tree().reload_current_scene()

func _on_victory(reason: String):
	print("VITÓRIA: ", reason)
	# Aqui você carregaria a tela de vitória
	# get_tree().change_scene_to_file("res://Scenes/UI/VictoryScreen.tscn")
	
	# Por enquanto, apenas mostra mensagem
	print("🎉 PARABÉNS! VOCÊ VENCEU! 🎉")
	# Pausa o jogo
	get_tree().paused = true
