extends Node2D

@export var max_shadows: int = 10
@export var spawn_interval: float = 2.0
@export var spawn_distance: float = 500.0

var active_shadows: Array = []
var spawn_timer: Timer
var is_active: bool = false

func _ready():
	PoolManager.ensure_pool("shadow")
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func set_active(active: bool):
	is_active = active
	
	if active:
		spawn_timer.start()
	else:
		spawn_timer.stop()
		clear_all_shadows()

func _on_spawn_timer_timeout():
	if is_active and active_shadows.size() < max_shadows:
		spawn_shadow()

func spawn_shadow():
	var fire = get_tree().get_first_node_in_group("fire")
	if not fire:
		return
	
	var shadow = PoolManager.get_object("shadow")
	if shadow:
		shadow.setup_spawn_position(fire.global_position, spawn_distance)
		
		if not shadow.destroyed.is_connected(_on_shadow_destroyed):
			shadow.destroyed.connect(_on_shadow_destroyed.bind(shadow))
		
		active_shadows.append(shadow)

func _on_shadow_destroyed(shadow_node):
	if active_shadows.has(shadow_node):
		active_shadows.erase(shadow_node)

func clear_all_shadows():
	var shadows_to_clear = active_shadows.duplicate()
	for shadow in shadows_to_clear:
		if is_instance_valid(shadow):
			if shadow.destroyed.is_connected(_on_shadow_destroyed):
				shadow.destroyed.disconnect(_on_shadow_destroyed)
			PoolManager.return_object(shadow, "shadow")
	active_shadows.clear()
