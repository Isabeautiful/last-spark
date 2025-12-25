extends CharacterBody2D

enum ShadowType {
	COMMON = 0,
	RESILIENT = 1,
	WINTER = 2
}

@export var shadow_type: ShadowType = ShadowType.COMMON
@export var base_speed: float = 50.0

@onready var sprite = $Sprite2D

var target_position: Vector2
var current_speed: float = 50.0
var health: int = 1
var damage_amount: int
var is_in_light: bool = false
var light_timer: float = 0.0
@onready var area_2d: Area2D = $Area2D

# Cor baseada no tipo
var type_colors = {
	ShadowType.COMMON: Color(0.2, 0.2, 0.8, 0.8),
	ShadowType.RESILIENT: Color(0.5, 0.2, 0.5, 0.9),
	ShadowType.WINTER: Color(0.8, 0.9, 1.0, 0.9)
}

signal destroyed()
signal took_damage(amount: int)

func _ready():
	add_to_group("shadow")
	add_to_group("enemy")
	
	# Configurar baseado no tipo
	configure_by_type()
	
func reset():
	if sprite:
		sprite.modulate.a = 1.0
		sprite.modulate = type_colors[shadow_type]
	
	health = get_max_health()
	velocity = Vector2.ZERO
	target_position = Vector2.ZERO
	is_in_light = false
	light_timer = 0.0
	
	configure_by_type()

func configure_by_type():
	match shadow_type:
		ShadowType.COMMON:
			current_speed = base_speed
			damage_amount = 1.5
			health = 1
		ShadowType.RESILIENT:
			current_speed = base_speed * 0.7
			damage_amount = 2.5
			health = 3
		ShadowType.WINTER:
			current_speed = base_speed * 1.3
			damage_amount = 3.5
			health = 2
	
	if sprite:
		sprite.modulate = type_colors[shadow_type]

func setup_spawn_position(spawn_center: Vector2, spawn_distance: float):
	var spawn_angle = randf_range(0, 2 * PI)
	global_position = spawn_center + Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_distance
	
	var fire = get_tree().get_first_node_in_group("fire")
	if fire:
		target_position = fire.global_position
	
func _physics_process(delta):
	#if target_position != Vector2.ZERO: o fogo tá posicionado no (0.0,0.0) então ele é o Vector2.ZERO
		var dv = (target_position-position).normalized()
		velocity = dv * current_speed * delta
		
		var collision = move_and_collide(dv * current_speed * delta)
		
		if(collision) and collision.get_collider().get_meta("CharacterType")=="Player":
			GameSignals.player_hit.emit(20.0,"Enemy")
			destroyed.emit()
			return_to_pool()
		
		if global_position.distance_to(target_position) < 30:
			_on_reached_fire()
		
		# Verificar se está na luz
		check_light_exposure(delta)

func check_light_exposure(delta):
	if is_in_light:
		light_timer += delta
		
		# Diferentes tempos para dissipação baseado no tipo
		var dissolve_time = get_dissolve_time()
		
		if light_timer >= dissolve_time:
			print("Sombra ", shadow_type, " dissipada pela luz!")
			destroy()
		else:
			# Efeito visual de estar na luz
			var alpha = 1.0 - (light_timer / dissolve_time)
			sprite.modulate.a = alpha
	else:
		# Recuperar opacidade se saiu da luz
		if sprite.modulate.a < 1.0:
			sprite.modulate.a = min(sprite.modulate.a + delta * 2, 1.0)

func get_dissolve_time() -> float:
	match shadow_type:
		ShadowType.COMMON: return 1.0
		ShadowType.RESILIENT: return 3.0
		ShadowType.WINTER: return 2.0
		
	return 1.0

func get_max_health() -> int:
	match shadow_type:
		ShadowType.COMMON: return 1
		ShadowType.RESILIENT: return 3
		ShadowType.WINTER: return 2
	return 1

func _on_area_entered(area: Area2D):
	if area.is_in_group("fire_light"):
		is_in_light = true
		print("Sombra entrou na luz!")
		
	elif area.is_in_group("fire_core"):
		_on_reached_fire()

func _on_area_exited(area: Area2D):
	if area.is_in_group("fire_light"):
		is_in_light = false
		light_timer = 0.0
		print("Sombra saiu da luz!")

func _on_reached_fire():
	var fire = get_tree().get_first_node_in_group("fire")
	if fire and fire.has_method("take_damage"):
		fire.take_damage(damage_amount)
		print("Sombra ", shadow_type, " atingiu o fogo! Dano: ", damage_amount)
	
	destroy()

func take_damage(amount: int):
	took_damage.emit(amount)
	health -= amount
	
	# Efeito visual
	sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", type_colors[shadow_type], 0.2)
	
	if health <= 0:
		destroy()

func destroy():
	velocity = Vector2.ZERO
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
		await tween.finished
	
	destroyed.emit()
	return_to_pool()

func return_to_pool():
	PoolManager.return_object(self, "shadow")

func get_damage_amount() -> int:
	return damage_amount

func highlight(active: bool):
	if active:
		sprite.modulate = Color(1.0, 0.5, 0.5, sprite.modulate.a)
	else:
		sprite.modulate = type_colors[shadow_type]
		sprite.modulate.a = sprite.modulate.a
