extends Node

# Sinais do sistema de coleta
signal player_try_harvest(harvest_position: Vector2, player_direction: Vector2)
signal resource_collected(resource_type: String, amount: int, position: Vector2)
signal player_direction_changed(new_direction: Vector2)

# Sinais do jogo em geral
signal day_started(day_number: int)
signal night_started()
signal fire_energy_changed(current: float, max: float)
signal game_over(reason: String)
signal victory(reason: String)
signal building_constructed(building_type: String)
signal building_damaged(building_type: String, damage: int)

# Sinais para construção
signal build_menu_toggled()
signal building_mode_started()
signal building_mode_ended()
signal building_selected(building_type: String)
