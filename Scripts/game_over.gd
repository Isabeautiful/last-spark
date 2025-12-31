extends Control

@onready var new_game: Button = $Game_Over_Retry
@onready var Quit_Game: Button = $Game_Over_Quit

@onready var color_rect: TextureRect = $ColorRect

var intensidade = 1.25
var duracao = 0.5

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_stream_player_2: AudioStreamPlayer = $AudioStreamPlayer2
var num_Play = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _process(delta: float) -> void:
	btn_hover(new_game)
	btn_hover(Quit_Game)
	
	if !audio_stream_player.playing:
		audio_stream_player.play(0.0)

#TODO: backgrounds diferentes para morte por fogueira e por dano
func choose_bakcground(type:String):
	var TextureR = TextureRect.new()
	match type:
		"fire_out":
			pass
		"death":
			pass

func hover(Obj:Object,property:String,value:Variant,duration:float):
	var tween = create_tween()
	tween.tween_property(Obj,property,value,duration)

func btn_hover(button:Button):
	button.pivot_offset = button.size/2
	
	if button.is_hovered():
		hover(button,"scale",Vector2.ONE*intensidade,duracao)
	else:
		hover(button,"scale",Vector2.ONE,duracao)

func _on_game_over_quit_pressed() -> void:
	get_tree().quit()

func _on_game_over_quit_mouse_entered() -> void:
	audio_stream_player_2.play()

func _on_game_over_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _on_game_over_retry_mouse_entered() -> void:
	audio_stream_player_2.play()
