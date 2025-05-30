extends Panel

@export var tower = preload("res://scenes/towers/espanta_pajaros.tscn") # Carga la escena de la torreta
var tempTower # Variable para almacenar la torreta temporal
var canPlace = false # Variable para verificar si se puede colocar la torreta

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_mask == 1: # Al hacer clic con el botón izquierdo del ratón
		tempTower = tower.instantiate() # Instancia la torreta
		add_child(tempTower) # Añade la torreta como hijo del panel
		
		tempTower.set_physics_process(true) # Activa el procesamiento de física
		tempTower.get_node("Area").show()
		tempTower.get_node("Area2D").hide() # Muestra el área de la torreta
		tempTower.get_node("Area2D").process_mode = Node.PROCESS_MODE_DISABLED
		
	elif event is InputEventMouseMotion and event.button_mask == 1: # Al mover el ratón con el botón izquierdo presionado
		if tempTower:
			tempTower.global_position = event.global_position # Actualiza la posición de la torreta
			
			if tempTower.get_node("colision").get_overlapping_bodies().size() <1 and isTower(tempTower):
				canPlace = true
			else:
				canPlace = false
			
			if event.global_position.x >= 1792:
				tempTower.get_node("Area").modulate = Color(1, 0, 0) # Cambia el color del área a rojo si x >= 1792
			else:
				tempTower.get_node("Area").modulate = Color(1, 1, 1) if canPlace else Color(1, 0, 0) # Cambia el color del área según si hay colisión

	elif event is InputEventMouseButton and event.button_mask == 0: # Al soltar el botón izquierdo del ratón
		if tempTower:
			if event.global_position.x >= 1792:
				if get_child_count() > 1:
					get_child(1).queue_free()
			tempTower.get_node("Area").hide() # Oculta el área de la torreta
			if canPlace:
				var path = get_tree().get_root().get_node("Mapa/towers") # Obtiene el nodo donde se colocará la torreta
				remove_child(tempTower) # Elimina la torreta del panel
				path.add_child(tempTower) # Añade la torreta al nodo `towers`
				tempTower.global_position = event.global_position # Actualiza la posición de la torreta
				tempTower.set_physics_process(true) # Reactiva el procesamiento de física
				tempTower.get_node("Area2D").process_mode = Node.PROCESS_MODE_INHERIT
			else:
				tempTower.queue_free() # Elimina la torreta si no se puede colocar
			tempTower = null # Resetea la variable de la torreta temporal

func isTower(towers: Node):
	var overlapping_areas = towers.get_node("colision").get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("towers"):
			return false
	return true
