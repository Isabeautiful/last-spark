extends Node2D

@onready var player = $Player
@onready var fire = $Fire
@onready var hud = $InGameHUD
@onready var day_night_cycle = $DayNightCycle
@onready var shadow_spawner = $ShadowSpawner
@onready var building_system = $BuildingSystem
@onready var build_menu = $BuildMenu
@onready var planting_system = $PlantingSystem

var current_day: int = 1
var game_state: String = "playing"  # "playing", "building", "planting", "menu"
var time_of_day: String = "day"     # "day", "evening", "night"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	# Conectar sinais de recursos
	ResourceManager.wood_changed.connect(_on_wood_changed)
	ResourceManager.food_changed.connect(_on_food_changed)
	
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
#	if GameSignals.has_user_signal("player_status_changed"):
#		GameSignals.player_status_changed.connect(_on_player_status_changed)
	if GameSignals.has_user_signal("player_died"):
		GameSignals.player_died.connect(_on_player_died)
	
	# Configurar spawner
	if shadow_spawner:
		shadow_spawner.set_active(false)
		if shadow_spawner.has_method("set_day"):
			shadow_spawner.set_day(current_day)
	
	# Configurar entrada
	_setup_inputs()
	
	# Conectar sistema de construção
	if building_system:
		building_system.build_mode_changed.connect(_on_build_mode_changed)
	
	# Conectar sistema de plantio
	if planting_system:
		planting_system.planting_mode_changed.connect(_on_planting_mode_changed)
	
	# Inicialmente esconder menu
	if build_menu:
		build_menu.hide()

func _setup_inputs():
	# Ação para construção (B)
	if not InputMap.has_action("build_menu"):
		InputMap.add_action("build_menu")
		var event_b = InputEventKey.new()
		event_b.keycode = KEY_B
		InputMap.action_add_event("build_menu", event_b)
		
		var event_mouse = InputEventMouseButton.new()
		event_mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("build_menu", event_mouse)
	
	# Ação para comer (Q)
	if not InputMap.has_action("eat"):
		InputMap.add_action("eat")
		var event_q = InputEventKey.new()
		event_q.keycode = KEY_Q
		InputMap.action_add_event("eat", event_q)
	
	# Ação para ativar sistema de plantio (V)
	if not InputMap.has_action("planting_system"):
		InputMap.add_action("planting_system")
		var event_v = InputEventKey.new()
		event_v.keycode = KEY_V
		InputMap.action_add_event("planting_system", event_v)

func _input(event):
	# Abrir/fechar menu de construção (B)
	if event.is_action_pressed("build_menu"):
		_handle_build_menu_toggle()
		get_viewport().set_input_as_handled()
		return
	
	# Ativar sistema de plantio (V)
	if event.is_action_pressed("planting_system"):
		_handle_planting_toggle()
		get_viewport().set_input_as_handled()
		return
	
	# Comer comida (Q)
	if event.is_action_pressed("eat"):
		if player and player.has_method("eat_food"):
			player.eat_food()
		get_viewport().set_input_as_handled()
		return
	
	# Cancelar com ESC
	if event.is_action_pressed("ui_cancel"):
		_handle_cancel()
		get_viewport().set_input_as_handled()
		return

func _handle_build_menu_toggle():
	match game_state:
		"playing":
			_enter_build_menu_mode()
		"menu":
			_return_to_playing_mode()
		"building":
			if building_system:
				building_system.cancel_building()
			_return_to_playing_mode()
		"planting":
			# Primeiro sair do modo plantio
			if planting_system:
				planting_system.cancel_planting()
			# Depois abrir menu construção
			_enter_build_menu_mode()

func _handle_planting_toggle():
	match game_state:
		"playing":
			_enter_planting_mode()
		"planting":
			_return_from_planting_mode() 
		"building":
			# Primeiro sair do modo construção
			if building_system:
				building_system.cancel_building()
			# Depois entrar no modo plantio
			_enter_planting_mode()
		"menu":
			# Fechar menu primeiro
			_return_to_playing_mode()
			# Depois entrar no modo plantio
			_enter_planting_mode()

func _return_from_planting_mode():
	if planting_system:
		planting_system.cancel_planting()
	game_state = "playing"
	
	if player:
		player.set_can_process_input(true)
	

func _handle_cancel():
	match game_state:
		"building":
			if building_system:
				building_system.cancel_building()
			_return_to_playing_mode()
		"planting":
			if planting_system:
				planting_system.cancel_planting()
			_return_to_playing_mode()
		"menu":
			if build_menu:
				build_menu.hide()
			_return_to_playing_mode()

func _enter_build_menu_mode():
	# Verificar se já está no menu
	if game_state == "menu":
		return
	
	game_state = "menu"
	
	if build_menu:
		build_menu.show()
	
	if player:
		player.set_can_process_input(false)

func _enter_building_mode():
	game_state = "building"
	
	if build_menu and build_menu.visible:
		build_menu.hide()

func _enter_planting_mode():
	# Verificar se já está no modo plantio
	if game_state == "planting":
		return
	
	if not planting_system:
		return
	
	# Verificar se tem sementes
	var has_seeds = ResourceManager.tree_seeds > 0 or ResourceManager.bush_seeds > 0
	if not has_seeds:
		return
	
	game_state = "planting"
	
	if player:
		player.set_can_process_input(false)
	
	# Iniciar sistema de plantio com a semente atual do jogador
	var seed_type = "tree"
	if player and player.has_method("get_status"):
		var status = player.get_status()
		seed_type = status.get("seed_type", "tree")
	
	planting_system.start_planting(seed_type)

func _return_to_playing_mode():
	if game_state == "playing":
		return
	
	game_state = "playing"
	
	if build_menu:
		build_menu.hide()
	
	# NÃO chamar cancel_building ou cancel_planting aqui!
	# Isso causaria recursão infinita
	# Os sistemas já emitem sinais quando são cancelados
	
	if player:
		player.set_can_process_input(true)

func _on_build_mode_changed(active: bool):
	if active:
		_enter_building_mode()
	else:
		# Quando o BuildingSystem é cancelado, ele emite sinal com active=false
		# Neste ponto, já estamos saindo do modo construção
		game_state = "playing"
		if player:
			player.set_can_process_input(true)

func _on_planting_mode_changed(active: bool):
	if active:
		# Modo plantio ativado
		game_state = "planting"
		if player:
			player.set_can_process_input(false)
	else:
		# Modo plantio desativado
		game_state = "playing"
		if player:
			player.set_can_process_input(true)

func _on_day_started(day_number: int):
	current_day = day_number
	time_of_day = "day"
	
	hud.update_day(current_day)
	if hud.has_method("update_time_of_day"):
		hud.update_time_of_day("day")
	
	if shadow_spawner:
		shadow_spawner.set_active(false)
		if shadow_spawner.has_method("set_day"):
			shadow_spawner.set_day(current_day)
	
	if current_day >= 15:
		GameSignals.victory.emit("Sobreviveu 15 dias!")
	
	update_difficulty(day_number)

func _on_night_started():
	time_of_day = "night"
	
	if hud.has_method("update_time_of_day"):
		hud.update_time_of_day("night")
	
	if shadow_spawner:
		shadow_spawner.set_active(true)

func update_difficulty(day: int):
	if fire and fire.has_method("set_base_consumption_rate"):
		var new_rate = 0.5 + (day * 0.05)
		fire.base_consumption_rate = new_rate

func _on_wood_changed(_amount):
	if hud:
		hud.update_resources()

func _on_food_changed(_amount):
	if hud:
		hud.update_resources()

func _on_fire_low_warning(energy_percent: float):
	if hud and hud.has_method("show_warning") and not fire.is_critical_warning_set and not fire.is_low_warning_set:
		hud.show_warning("Fogueira fraca!","low")
		fire.set_warning_status(true,"low")

func _on_fire_critical():
	if fire.is_low_warning_set:
		hud.hide_warning("low")
		
	if hud and hud.has_method("show_warning") and not fire.is_critical_warning_set:
		hud.show_warning("FOGUEIRA CRÍTICA!","critical")
		fire.set_warning_status(true,"critical")
		
func _on_player_died():
	GameSignals.game_over.emit("Todos morreram!")

func _on_game_over(reason: String):
	get_tree().paused = true
	GameSignals.clear_all_pools.emit()
	GameSignals.show_game_over_screen.emit(reason)
	get_tree().change_scene_to_file("res://Scenes/UI/Game_Over.tscn")
	
func _on_victory(reason: String):
	get_tree().paused = true
	GameSignals.clear_all_pools.emit()
	GameSignals.show_game_over_screen.emit(reason)
	get_tree().change_scene_to_file("res://Scenes/UI/victory.tscn")
