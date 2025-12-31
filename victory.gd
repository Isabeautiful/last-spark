extends Control

@onready var new_game: Button = $Victory_reset
@onready var Quit_Game: Button = $Victory_Quit
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_stream_player_2: AudioStreamPlayer = $AudioStreamPlayer2

var intensidade = 1.25
var duracao = 0.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not audio_stream_player.playing:
		audio_stream_player.play()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _process(delta: float) -> void:
	btn_hover(new_game)
	btn_hover(Quit_Game)
	
	if !audio_stream_player.playing:
		audio_stream_player.play(0.0)

func hover(Obj:Object,property:String,value:Variant,duration:float):
	var tween = create_tween()
	tween.tween_property(Obj,property,value,duration)

func btn_hover(button:Button):
	button.pivot_offset = button.size/2
	
	if button.is_hovered():
		hover(button,"scale",Vector2.ONE*intensidade,duracao)
	else:
		hover(button,"scale",Vector2.ONE,duracao)


func _on_victory_quit_pressed() -> void:
	get_tree().quit()

func _on_victory_reset_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
