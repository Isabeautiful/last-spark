extends Control

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/Tutorial.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_voltar_ao_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")
