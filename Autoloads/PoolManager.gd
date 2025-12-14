extends Node

# Dicionário de pools: { "tipo": ObjectPool }
var pools = {}

# Configurações de pool por tipo
var pool_configs = {
	"tree": { "size": 120, "scene_path": "res://Scenes/Tree.tscn" },
	"bush": { "size": 50, "scene_path": "res://Scenes/Bush.tscn" },
	"shadow": { "size": 20, "scene_path": "res://Scenes/Shadow.tscn" },
}

func _ready():
	print("PoolManager inicializado")
	# As pools serão criadas sob demanda

# Cria uma pool se não existir
func ensure_pool(pool_type: String) -> ObjectPool:
	if not pools.has(pool_type):
		if pool_configs.has(pool_type):
			var config = pool_configs[pool_type]
			var scene = load(config.scene_path) as PackedScene
			if scene:
				pools[pool_type] = ObjectPool.new(scene, config.size, pool_type, self)
				print("Pool criada: ", pool_type, " (tamanho: ", config.size, ")")
			else:
				printerr("Cena não encontrada: ", config.scene_path)
		else:
			printerr("Tipo de pool não configurado: ", pool_type)
	
	return pools.get(pool_type)

# Obtém um objeto da pool
func get_object(pool_type: String, position: Vector2 = Vector2.ZERO, rotation: float = 0.0) -> Node2D:
	var pool = ensure_pool(pool_type)
	if pool:
		var obj = pool.get_from_pool()
		if obj:
			obj.global_position = position
			obj.rotation = rotation
			obj.reset()  # Método que cada objeto deve ter
		return obj
	return null

# Retorna um objeto à pool
func return_object(obj: Node2D, pool_type: String):
	var pool = pools.get(pool_type)
	if pool:
		pool.return_object(obj)
	else:
		printerr("Pool não encontrada para tipo: ", pool_type)

# Status das pools (para debug)
func get_pool_status() -> Dictionary:
	var status = {}
	for pool_type in pools:
		var pool = pools[pool_type]
		status[pool_type] = {
			"total": pool.num_objetos,
			"available": pool.get_available_count()
		}
	return status
