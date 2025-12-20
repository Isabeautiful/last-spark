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
var time_of_day: String = "day"     # "day", "evening", "night"

# Sistema de eventos
var event_manager: Node
var active_events: Array = []

func _ready():
	# Conectar sinais de recursos
	ResourceManager.wood_changed.connect(_on_wood_changed)
	ResourceManager.food_changed.connect(_on_food_changed)
	ResourceManager.population_changed.connect(_on_population_changed)
	
	# Configurar HUD inicial
	hud.update_day(current_day)
	
	# Conectar ciclo dia/noite
	day_night_cycle.day_started.connect(_on_day_started)
	day_night_cycle.night_started.connect(_on_night_started)
	
	# Conectar sinais de jogo
	GameSignals.game_over.connect(_on_game_over)
	GameSignals.victory.connect(_on_victory)
	
	# Conectar novos sinais (verificar se existem)
	if GameSignals.has_user_signal("fire_low_warning"):
		GameSignals.fire_low_warning.connect(_on_fire_low_warning)
	if GameSignals.has_user_signal("fire_critical"):
		GameSignals.fire_critical.connect(_on_fire_critical)
	if GameSignals.has_user_signal("player_status_changed"):
		GameSignals.player_status_changed.connect(_on_player_status_changed)
	if GameSignals.has_user_signal("player_died"):
		GameSignals.player_died.connect(_on_player_died)
	
	# Configurar spawner
	if shadow_spawner:
		shadow_spawner.set_active(false)
		# Verificar se o método set_day existe
		if shadow_spawner.has_method("set_day"):
			shadow_spawner.set_day(current_day)
	
	# Configurar entrada
	_setup_inputs()
	
	# Conectar sistema de construção
	if building_system:
		building_system.build_mode_changed.connect(_on_build_mode_changed)
	
	# Inicialmente esconder menu
	if build_menu:
		build_menu.hide()
	
	# Inicializar eventos (agora sem adicionar como filho)
	initialize_events()
	
	print("=== JOGO INICIADO ===")
	print("Dia ", current_day)
	print("População: ", ResourceManager.current_population)
	print("Recursos: Madeira=", ResourceManager.wood, " Comida=", ResourceManager.food)

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
	
	# Ação para comer (tecla Q)
	if not InputMap.has_action("eat"):
		InputMap.add_action("eat")
		var event_q = InputEventKey.new()
		event_q.keycode = KEY_Q
		InputMap.action_add_event("eat", event_q)

func _input(event):
	# Abrir/fechar menu de construção
	if event.is_action_pressed("build_menu"):
		if game_state == "playing":
			_enter_build_menu_mode()
		elif game_state == "menu":
			_return_to_playing_mode()
	
	# Comer comida (tecla Q)
	if event.is_action_pressed("eat"):
		if player and player.has_method("eat_food"):
			player.eat_food()
	
	# Cancelar com ESC
	if event.is_action_pressed("ui_cancel"):
		if game_state == "building":
			if building_system:
				building_system.cancel_building()
			_return_to_playing_mode()
		elif game_state == "menu":
			if build_menu:
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

func initialize_events():
	# Criar sistema básico de eventos
	event_manager = Node.new()
	event_manager.name = "EventManager"
	
	# Timer para verificar eventos a cada minuto
	var event_timer = Timer.new()
	event_timer.name = "EventTimer"
	event_timer.wait_time = 60.0
	event_timer.timeout.connect(_check_events)
	event_manager.add_child(event_timer)
	add_child(event_manager)  # AGORA podemos adicionar como filho
	
	event_timer.start()
	print("Sistema de eventos inicializado")

func _check_events():
	if current_day >= 3:
		# Chance de evento aleatório após o dia 3
		if randf() < 0.3:  # 30% de chance
			trigger_random_event()

func trigger_random_event():
	var events = [
		"storm",      # Tempestade
		"merchant",   # Mercante
		"earthquake", # Terremoto
		"regrowth"    # Renascimento
	]
	
	var random_event = events[randi() % events.size()]
	handle_event(random_event)

func handle_event(event_type: String):
	match event_type:
		"storm":
			print("=== TEMPESTADE DE NEVE ===")
			print("Visibilidade reduzida! Recursos congelam temporariamente.")
			# Chamar sinal para HUD mostrar aviso
			if hud.has_method("show_warning"):
				hud.show_warning("Tempestade de neve!")
		"merchant":
			print("=== MERCADO VISITANTE ===")
			print("Um mercante chegou! Troque recursos por itens raros.")
			if hud.has_method("show_notification"):
				hud.show_notification("Mercante chegou!")
		"earthquake":
			print("=== ATIVIDADE SÍSMICA ===")
			print("Alguns recursos foram destruídos pelo tremor!")
			# Aqui poderíamos remover alguns recursos do mapa
			if hud.has_method("show_warning"):
				hud.show_warning("Terremoto!")
		"regrowth":
			print("=== RENASCIMENTO ===")
			print("Novas árvores e arbustos surgiram na floresta!")
			if hud.has_method("show_notification"):
				hud.show_notification("Floresta renasceu!")

func _on_day_started(day_number: int):
	print("=== DIA ", day_number, " INICIADO ===")
	current_day = day_number
	time_of_day = "day"
	
	hud.update_day(current_day)
	if hud.has_method("update_time_of_day"):
		hud.update_time_of_day("day")
	
	if shadow_spawner:
		shadow_spawner.set_active(false)
		# Atualizar dificuldade baseada no dia
		if shadow_spawner.has_method("set_day"):
			shadow_spawner.set_day(current_day)
	
	# Verificar condições de vitória
	if current_day >= 15:
		GameSignals.victory.emit("Sobreviveu 15 dias!")
	
	# Atualizar dificuldade
	update_difficulty(day_number)

func _on_night_started():
	print("=== NOITE INICIADA ===")
	time_of_day = "night"
	
	if hud.has_method("update_time_of_day"):
		hud.update_time_of_day("night")
	
	if shadow_spawner:
		shadow_spawner.set_active(true)
	
	# NPCs devem recolher (se existirem)
	print("NPCs se recolhendo para a noite...")

func update_difficulty(day: int):
	# Aumentar consumo da fogueira com o tempo
	if fire and fire.has_method("set_base_consumption_rate"):
		var new_rate = 0.5 + (day * 0.05)
		fire.base_consumption_rate = new_rate
	
	print("Dificuldade aumentada para o dia ", day)

func _on_wood_changed(_amount):
	if hud:
		hud.update_resources()

func _on_food_changed(_amount):
	if hud:
		hud.update_resources()

func _on_population_changed(_amount):
	if hud:
		hud.update_resources()

func _on_fire_low_warning(energy_percent: float):
	print("ALERTA: Fogueira fraca! (", int(energy_percent * 100), "%)")
	if hud and hud.has_method("show_warning"):
		hud.show_warning("Fogueira fraca!")

func _on_fire_critical():
	print("ALERTA CRÍTICO: Fogueira prestes a apagar!")
	if hud and hud.has_method("show_warning"):
		hud.show_warning("FOGUEIRA CRÍTICA!")

func _on_player_status_changed(health: float, hunger: float, cold: float):
	if hud and hud.has_method("update_player_status"):
		hud.update_player_status(health, hunger, cold)
	
	# Verificar status críticos
	if health < 30:
		if hud and hud.has_method("show_warning"):
			hud.show_warning("Saúde baixa!")
	if hunger < 20:
		if hud and hud.has_method("show_warning"):
			hud.show_warning("Fome extrema!")
	if cold < 20:
		if hud and hud.has_method("show_warning"):
			hud.show_warning("Hipotermia!")

func _on_player_died():
	print("O jogador morreu!")
	# Verificar se há NPCs para continuar
	if ResourceManager.current_population > 0:
		print("NPCs ainda vivem. O jogo continua...")
		# Aqui poderia trocar para controle de NPC
	else:
		GameSignals.game_over.emit("Todos morreram!")

func _on_game_over(reason: String):
	print("GAME OVER: ", reason)
	
	# Pausar o jogo
	get_tree().paused = true
	
	# Mostrar tela de game over (implementar depois)
	# get_tree().change_scene_to_file("res://Scenes/UI/GameOverScreen.tscn")
	
	print("FIM DE JOGO: ", reason)

func _on_victory(reason: String):
	print("VITÓRIA: ", reason)
	
	# Pausar o jogo
	get_tree().paused = true
	
	# Mostrar tela de vitória (implementar depois)
	# get_tree().change_scene_to_file("res://Scenes/UI/VictoryScreen.tscn")
	
	print("VENCEU!")
