# SeedItem.gd
extends Area2D

@export var resource_type: String = "tree"  # "tree" ou "bush"
@export var growth_time: float = 30.0

@onready var sprite: Sprite2D = $Sprite2D

var is_collectible: bool = true

func _ready():
	add_to_group("seed")
	
	# Conectar sinais
	area_entered.connect(_on_area_entered)
	
	# Timer para crescimento automático (se não for coletada)
	var growth_timer = Timer.new()
	growth_timer.wait_time = growth_time
	growth_timer.timeout.connect(_on_growth_timer_timeout)
	add_child(growth_timer)
	growth_timer.start()

func _on_area_entered(area: Area2D):
	if area.is_in_group("player_area") and is_collectible:
		collect()

func collect():
	is_collectible = false
	
	# Adicionar semente ao inventário
	if ResourceManager.has_method("add_seed"):
		ResourceManager.add_seed(resource_type, 1)
	
	# Efeito visual
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _on_growth_timer_timeout():
	if is_collectible:
		# Crescer no local atual
		grow_at_position(global_position)

func grow_at_position(position: Vector2):
	# Spawnar a árvore/arbusto no local
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("spawn_resource_from_seed"):
		map_manager.spawn_resource_from_seed(resource_type, position)
	
	queue_free()
