class_name ObjectPool

var objeto: PackedScene
var num_objetos: int
var lista_objetos: Array[Node2D]
var nome: String
var parent: Node

func _init(objeto: PackedScene, num_objetos: int, nome: String, parent_node: Node) -> void:
	self.objeto = objeto
	self.num_objetos = num_objetos
	self.nome = nome
	self.parent = parent_node
	
	instancia_objetos()

func instancia_objetos() -> void:
	lista_objetos.resize(num_objetos)
	
	for i in range(num_objetos):
		var obj = objeto.instantiate()
		obj.name = nome + "_" + str(i)
		obj.hide()
		obj.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Configurar propriedades de pool
		obj.set_meta("pool_type", nome)
		obj.set_meta("in_pool", true)
		
		parent.add_child(obj)
		lista_objetos[i] = obj

# Verifica se objeto esta disponivel na pool
func esta_disponivel(obj: Node2D) -> bool:
	return obj.is_inside_tree() and obj.process_mode == Node.PROCESS_MODE_DISABLED

# Obtém objeto da pool
func get_from_pool() -> Node2D:
	for obj in lista_objetos:
		if esta_disponivel(obj):
			# Remover das listas antigas se necessario
			obj.get_parent().remove_child(obj)
			parent.add_child(obj)
			
			obj.show()
			obj.process_mode = Node.PROCESS_MODE_ALWAYS
			obj.set_meta("in_pool", false)
			return obj
	return create_extra_object()

# Cria objeto extra (expansão dinamica da pool)
func create_extra_object() -> Node2D:
	var obj = objeto.instantiate()
	obj.name = nome + "_extra_" + str(lista_objetos.size())
	obj.set_meta("pool_type", nome)
	obj.set_meta("is_extra", true)
	
	parent.add_child(obj)
	lista_objetos.append(obj)
	
	return obj

func return_object(obj: Node2D) -> void:
	if not obj or not is_instance_valid(obj):
		return

	obj.hide()
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.set_meta("in_pool", true)

# Conta objetos disponiveis
func get_available_count() -> int:
	var count = 0
	for obj in lista_objetos:
		if esta_disponivel(obj):
			count += 1
	return count

# Limpa todos os objetos (apenas os extras)
func clear_extra_objects() -> void:
	var to_remove = []
	
	for obj in lista_objetos:
		if obj.has_meta("is_extra") and obj.get_meta("is_extra") == true:
			to_remove.append(obj)
	
	for obj in to_remove:
		if is_instance_valid(obj):
			obj.queue_free()
		lista_objetos.erase(obj)

func clear_all_objects():
	for i in lista_objetos:
		parent.remove_child(i)
		
	lista_objetos.clear()
