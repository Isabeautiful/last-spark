extends Node2D

@export var max_shadows: int = 10
@export var base_spawn_interval: float = 2.0
@export var spawn_distance: float = 500.0

var active_shadows: Array = []
var spawn_timer: Timer
var is_active: bool = false
var current_day: int = 1

# Probabilidades por tipo baseado no dia
var type_probabilities: Array = [
	1.0,  # COMMON
	0.0,  # RESILIENT (desbloqueia dia 5)
	0.0   # WINTER (desbloqueia dia 10)
]

func _ready():
	PoolManager.ensure_pool("shadow")
	spawn_timer = Timer.new()
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	print("ShadowSpawner inicializado")

func set_active(active: bool):
	is_active = active
	
	if active:
		spawn_timer.start()
		print("Spawner ativado para a noite")
	else:
		spawn_timer.stop()
		clear_all_shadows()
		print("Spawner desativado")

func set_day(day: int):
	current_day = day
	
	# Atualizar dificuldade
	update_difficulty(day)
	update_type_probabilities(day)

func update_difficulty(day: int):
	# Aumentar número máximo de sombras
	max_shadows = 8 + (day * 2)
	
	# Diminuir intervalo de spawn
	spawn_timer.wait_time = max(0.3, base_spawn_interval - (day * 0.1))
	
	print("Dificuldade ajustada - Dia ", day, ": Max=", max_shadows, ", Interval=", spawn_timer.wait_time)

func update_type_probabilities(day: int):
	# Resetar probabilidades
	type_probabilities = [1.0, 0.0, 0.0]
	
	# Dia 5+: Sombra Resiliente aparece
	if day >= 5:
		type_probabilities[1] = 0.15  # 15% de chance
		type_probabilities[0] = 0.85  # Ajustar comum para 85%
	
	# Dia 10+: Sombra de Inverno aparece
	if day >= 10:
		type_probabilities[2] = 0.05  # 5% de chance
		type_probabilities[1] = 0.15  # Mantém 15%
		type_probabilities[0] = 0.80  # Comum reduz para 80%

func get_random_shadow_type() -> int:
	var rand_val = randf()
	var cumulative = 0.0
	
	for i in range(type_probabilities.size()):
		cumulative += type_probabilities[i]
		if rand_val <= cumulative:
			return i
	
	return 0  # Fallback para COMMON

func _on_spawn_timer_timeout():
	if is_active and active_shadows.size() < max_shadows:
		spawn_shadow()

func spawn_shadow():
	var fire = get_tree().get_first_node_in_group("fire")
	if not fire:
		return
	
	var shadow = PoolManager.get_object("shadow")
	if shadow:
		# Configurar tipo baseado nas probabilidades
		var shadow_type = get_random_shadow_type()
		shadow.shadow_type = shadow_type
		shadow.configure_by_type()
		
		shadow.setup_spawn_position(fire.global_position, spawn_distance)
		
		if not shadow.destroyed.is_connected(_on_shadow_destroyed):
			shadow.destroyed.connect(_on_shadow_destroyed.bind(shadow))
		
		if not shadow.took_damage.is_connected(_on_shadow_took_damage):
			shadow.took_damage.connect(_on_shadow_took_damage)
		
		active_shadows.append(shadow)
		
		print("Sombra spawnada - Tipo: ", shadow_type)

func _on_shadow_destroyed(shadow_node):
	if active_shadows.has(shadow_node):
		active_shadows.erase(shadow_node)

func _on_shadow_took_damage(amount: int):
	# Feedback de dano causado
	GameSignals.shadow_damaged.emit(amount)

func clear_all_shadows():
	var shadows_to_clear = active_shadows.duplicate()
	for shadow in shadows_to_clear:
		if is_instance_valid(shadow):
			if shadow.destroyed.is_connected(_on_shadow_destroyed):
				shadow.destroyed.disconnect(_on_shadow_destroyed)
			PoolManager.return_object(shadow, "shadow")
	active_shadows.clear()

func get_active_count() -> int:
	return active_shadows.size()

func get_shadow_type_count() -> Dictionary:
	var count = {0: 0, 1: 0, 2: 0}
	for shadow in active_shadows:
		if is_instance_valid(shadow):
			count[shadow.shadow_type] += 1
	return count
