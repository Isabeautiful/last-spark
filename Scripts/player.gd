extends CharacterBody2D

@export var base_speed: float = 250.0
@export var run_speed: float = 400.0

@onready var action_area: Area2D = $ActionArea
@onready var action_shape: CollisionShape2D = $ActionArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var Player_Audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


# Status do jogador
var current_speed: float = 250.0
var hunger: float = 100.0
var cold: float = 100.0
var health: float = 100.0
var is_running: bool = false
var is_in_heat_zone: bool = true

#enum pra gerenciar os status do player mais fácil
var PlayerStatus = {hungry=false,hurt = false, cold = false}

#Váriaveis de controle de dano de inimigos
var damage_cooldown = 0.5
var is_on_damage_cooldown = false
var hit_mp3_path = "res://Assets/audio/hit/hit.mp3"

#variáveis para controle dos avisos 
@export var is_hunger_warning_set = false
@export var is_cold_warning_set = false
@export var is_health_warning_set = false

# Variável para semente atual (apenas para referência, será gerenciado pelo PlantingSystem)
var current_seed_type: String = "tree"

# Direção do jogador
var current_direction: Vector2 = Vector2.DOWN

# Objetos na área
var objects_in_range: Dictionary = {
	"resources": [],   # Árvores, arbustos
	"enemies": [],     # Sombras
	"fire": null,      # Fogueira (apenas uma)
}

# Controles
var can_process_input: bool = true
var can_action: bool = true
var current_weapon: String = "stick"
var attack_damage: int = 1

# Timers
@onready var hunger_timer: Timer = $HungerTimer
@onready var cold_timer: Timer = $ColdTimer

func _ready():
	add_to_group("player")
	setup_area()
	setup_timers()
	set_meta("CharacterType","Player")
	
	# Conectar sinais da área
	action_area.area_entered.connect(_on_action_area_entered)
	action_area.area_exited.connect(_on_action_area_exited)
	action_area.body_entered.connect(_on_action_area_body_entered)
	action_area.body_exited.connect(_on_action_area_body_exited)
	
	GameSignals.player_hit.connect(take_damage)
	# Configurar entrada
	_setup_input_actions()

func setup_area():
	# Adicionar grupos para identificação
	action_area.add_to_group("player_area")
	action_area.add_to_group("player_harvest")
	
	# Posicionar a área na frente do jogador
	update_area_position(Vector2.DOWN)

func set_warning_status(status,cond):
	match cond:
		"health":
			is_health_warning_set = status
		"hunger":
			is_hunger_warning_set = status
		"cold":
			is_cold_warning_set = status
			
func setup_timers():
	# Timer de fome
	hunger_timer.timeout.connect(_on_hunger_timer_timeout)
	hunger_timer.start()
	
	# Timer de frio
	cold_timer.timeout.connect(_on_cold_timer_timeout)
	cold_timer.start()

func _setup_input_actions():
	
	# Ação de correr (Shift)
	if not InputMap.has_action("run"):
		InputMap.add_action("run")
		var event_shift = InputEventKey.new()
		event_shift.keycode = KEY_SHIFT
		InputMap.action_add_event("run", event_shift)
	
	# Ação de atacar (Barra de Espaço ou Botão Esquerdo do Mouse)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		# Barra de espaço
		var event_space = InputEventKey.new()
		event_space.keycode = KEY_SPACE
		InputMap.action_add_event("attack", event_space)
		
		# Botão esquerdo do mouse (para clicar nas sombras)
		var event_mouse_left = InputEventMouseButton.new()
		event_mouse_left.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", event_mouse_left)
	
	# Ação de interagir (F ou Clique em recursos/fogo)
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		# Tecla F
		var event_f = InputEventKey.new()
		event_f.keycode = KEY_F
		InputMap.action_add_event("interact", event_f)
		
		# Botão direito do mouse (para coletar recursos)
		var event_mouse_right = InputEventMouseButton.new()
		event_mouse_right.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("interact", event_mouse_right)
	
	# Ação de comer (Q)
	if not InputMap.has_action("eat"):
		InputMap.add_action("eat")
		var event_q = InputEventKey.new()
		event_q.keycode = KEY_Q
		InputMap.action_add_event("eat", event_q)
	
	# Ação de construção (B) - agora será gerenciada pelo Game.gd
	if not InputMap.has_action("build_menu"):
		InputMap.add_action("build_menu")
		var event_b = InputEventKey.new()
		event_b.keycode = KEY_B
		InputMap.action_add_event("build_menu", event_b)

func _physics_process(delta):	
	if not can_process_input:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Calcular velocidade baseada na fome
	var speed_multiplier = 1.0
	if hunger > 70:
		speed_multiplier = 1.1
	elif hunger < 30:
		speed_multiplier = 0.7
	
	current_speed = base_speed * speed_multiplier
	
	# Correr (consome fome extra)
	if Input.is_action_pressed("run") and hunger > 10:
		current_speed = run_speed * speed_multiplier
		is_running = true
		hunger -= delta * 5
	else:
		is_running = false
	
	# Movimentação
	var input_dir = Input.get_vector("Left", "Right", "Up", "Down")
	
	if input_dir.length() > 0.1:
		var new_direction = input_dir.normalized()
		
		# Atualizar direção apenas se mudou significativamente
		if new_direction.distance_to(current_direction) > 0.1:
			current_direction = new_direction
			update_area_position(current_direction)
		
		# Animação simples
		#sprite.rotation = current_direction.angle()
		match input_dir:
			Vector2.LEFT:
				sprite.frame = 2
				sprite.flip_h = false
			Vector2.RIGHT:
				sprite.frame = 2
				sprite.flip_h = true
			Vector2.UP:
				sprite.frame = 1
				sprite.flip_v = false
			Vector2.DOWN:
				sprite.frame = 0
				sprite.flip_v = false
			
	velocity = input_dir * current_speed * delta
	move_and_collide(velocity)

	if health < 100:
		health += Get_heal_factor() * delta
	
	GameSignals.player_status_changed.emit(health,hunger,cold)

#Retorna o valor de cura do jogador de acordo com o status
func Get_heal_factor():
	if PlayerStatus.hungry: return 0
	var sum  = 0.0
	
	if not PlayerStatus.cold: sum += 0.30
	if not PlayerStatus.hurt: sum += 0.30 
	
	if hunger >= 80: sum += 0.40
	elif not PlayerStatus.hungry: sum += 0.2
	
	return sum
func _input(event):
	if not can_process_input or not can_action:
		return
	
	# REMOVIDO: Sistema de plantio - agora é gerenciado pelo PlantingSystem
	# Sistema de ações inteligente original
	if event.is_action_pressed("attack"):
		# Primeiro tenta atacar inimigos
		if not objects_in_range["enemies"].is_empty():
			attack_enemy()
		else:
			# Se não tem inimigos, tenta coletar recursos
			if not objects_in_range["resources"].is_empty():
				harvest_resource()
	
	elif event.is_action_pressed("interact"):
		# Interage com fogueira se disponível
		if objects_in_range["fire"] != null:
			interact_with_fire()
		# Senão, tenta coletar recursos
		elif not objects_in_range["resources"].is_empty():
			harvest_resource()
	
	# Comer comida (tecla Q)
	elif event.is_action_pressed("eat"):
		eat_food()

func update_area_position(direction: Vector2):
	var normalized_dir = direction.normalized()
	var angle = normalized_dir.angle()
	
	action_area.rotation = angle
	action_area.position = normalized_dir 

func _on_hunger_timer_timeout():
	hunger -= 2
	
	if is_running:
		hunger -= 3
	
	hunger = max(hunger, 0)
	
	if hunger <= 0:
		take_damage(5, "fome")
		PlayerStatus.hungry = true
		
		if not is_hunger_warning_set:
			GameSignals.showWarning.emit("Fome Extrema!","hunger")
			is_hunger_warning_set = true
	else:
		PlayerStatus.hungry = false
		is_hunger_warning_set = false
		GameSignals.hideWarning.emit("hunger")
	
	if GameSignals.has_user_signal("player_status_changed"):
		GameSignals.player_status_changed.emit(health, hunger, cold)
		
func _on_cold_timer_timeout():
	var fire = get_tree().get_first_node_in_group("fire")
	var distance_to_fire = global_position.distance_to(fire.global_position)
	var heat_radius = fire.get_light_radius()
	
	is_in_heat_zone = distance_to_fire <= heat_radius

	if not is_in_heat_zone:
		cold -= 10
	else:
		cold = min(cold + 15, 100)

	cold = max(cold, 0)
	
	if cold <= 20:
		PlayerStatus.cold = true
		take_damage(3, "frio")
		
		if not is_cold_warning_set:
			GameSignals.showWarning.emit("Hipotermia!","cold")
			is_cold_warning_set = true
	else:
		PlayerStatus.cold = false
		is_cold_warning_set = false
		GameSignals.hideWarning.emit("cold")
		
	if GameSignals.has_user_signal("player_status_changed"):
		GameSignals.player_status_changed.emit(health, hunger, cold)

func _on_action_area_entered(area: Area2D):
	if area.is_in_group("tree") or area.is_in_group("bush"):
		if not objects_in_range["resources"].has(area):
			objects_in_range["resources"].append(area)
			if area.has_method("highlight"):
				area.highlight(true)
	
	elif area.is_in_group("shadow"):
		if not objects_in_range["enemies"].has(area):
			objects_in_range["enemies"].append(area)
			if area.has_method("highlight"):
				area.highlight(true)
	
	elif area.is_in_group("fire_interaction"):
		objects_in_range["fire"] = area

func _on_action_area_exited(area: Area2D):
	if area.is_in_group("tree") or area.is_in_group("bush"):
		if objects_in_range["resources"].has(area):
			objects_in_range["resources"].erase(area)
			if area.has_method("highlight"):
				area.highlight(false)
	
	elif area.is_in_group("shadow"):
		if objects_in_range["enemies"].has(area):
			objects_in_range["enemies"].erase(area)
			if area.has_method("highlight"):
				area.highlight(false)
	
	elif area.is_in_group("fire_interaction"):
		if objects_in_range["fire"] == area:
			objects_in_range["fire"] = null

func _on_action_area_body_entered(body: Node2D):
	if body.is_in_group("shadow"):
		if not objects_in_range["enemies"].has(body):
			objects_in_range["enemies"].append(body)
			if body.has_method("highlight"):
				body.highlight(true)

func _on_action_area_body_exited(body: Node2D):
	if body.is_in_group("shadow"):
		if objects_in_range["enemies"].has(body):
			objects_in_range["enemies"].erase(body)
			if body.has_method("highlight"):
				body.highlight(false)

func attack_enemy():
	if not can_action or objects_in_range["enemies"].is_empty():
		return
	
	can_action = false
	
	# Pega o inimigo mais próximo
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in objects_in_range["enemies"]:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	if closest_enemy and closest_enemy.has_method("take_damage"):
		# Animação de ataque
		var original_scale = sprite.scale
		var tween = create_tween()
		tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
		tween.tween_property(sprite, "scale", original_scale, 0.1)
		
		closest_enemy.take_damage(attack_damage)
		
		if GameSignals.has_user_signal("player_attacked"):
			GameSignals.player_attacked.emit(attack_damage)
	
	# Cooldown
	await get_tree().create_timer(0.5).timeout
	can_action = true

func harvest_resource():
	if not can_action or objects_in_range["resources"].is_empty():
		return
	
	can_action = false
	
	# Pega o recurso mais próximo
	var closest_resource = null
	var closest_distance = INF
	
	for resource in objects_in_range["resources"]:
		if is_instance_valid(resource):
			var distance = global_position.distance_to(resource.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_resource = resource
	
	if closest_resource:
		if closest_resource.has_method("harvest"):
			var harvested = await closest_resource.take_damage() #await closest_resource.harvest()
			
			if harvested:
				if objects_in_range["resources"].has(closest_resource):
					objects_in_range["resources"].erase(closest_resource)
	
	# Cooldown
	await get_tree().create_timer(0.3).timeout
	can_action = true

func interact_with_fire():
	if not can_action or objects_in_range["fire"] == null:
		return
	
	can_action = false
	
	var fire = get_tree().get_first_node_in_group("fire")
	if fire and fire.has_method("add_fuel_from_inventory"):
		if ResourceManager.wood > 0:
			fire.add_fuel_from_inventory()
	
	# Cooldown curto
	await get_tree().create_timer(0.2).timeout
	can_action = true

func take_damage(amount: float, source: String = ""):
	health -= amount
	health = max(health, 0)
	
	var hit_=load("res://Assets/audio/hit/hit.mp3")
	Player_Audio.stream = hit_
	Player_Audio.play()
	
	# Efeito visual
	sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	if health <= 0:
		die()
	
	if health <= 20:
		PlayerStatus.hurt = true
		if not is_health_warning_set:
			GameSignals.showWarning.emit("Saúde Baixa!","health")
			is_health_warning_set = true
	else:
		PlayerStatus.hurt = false
		is_health_warning_set = false
		GameSignals.hideWarning.emit("health")
	
	if GameSignals.has_user_signal("player_status_changed"):
		GameSignals.player_status_changed.emit(health, hunger, cold)

func eat_food():
	if ResourceManager.food >= 1:
		if ResourceManager.use_food(1):
			hunger = min(hunger + 15, 100)
			
			# Efeito visual
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.GREEN, 0.2)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
			
			if GameSignals.has_user_signal("player_status_changed"):
				GameSignals.player_status_changed.emit(health, hunger, cold)
			
			return true
	return false

func die():
	can_process_input = false
	
	# Animação de morte
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(sprite, "rotation", sprite.rotation + PI, 1.0)
	await tween.finished
	
	if GameSignals.has_user_signal("player_died"):
		GameSignals.player_died.emit()
	
	if GameSignals.has_user_signal("game_over"):
		GameSignals.game_over.emit("O jogador morreu!")

func set_can_process_input(can_process: bool):
	can_process_input = can_process
	
	if not can_process:
		velocity = Vector2.ZERO
		move_and_slide()

func get_status() -> Dictionary:
	return {
		"health": health,
		"hunger": hunger,
		"cold": cold,
		"position": global_position,
		"seed_type": current_seed_type
	}
