extends Control

@onready var start: Button = $VBoxContainer/Start
@onready var quit: Button = $VBoxContainer/Quit
@onready var credits: Button = $VBoxContainer/Credits

var intensidade = 1.25
var duracao = 0.5

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_stream_player_2: AudioStreamPlayer = $AudioStreamPlayer2
var num_Play = 0

func _process(_delta: float) -> void:
	btn_hover(start)
	btn_hover(credits)
	btn_hover(quit)
	
	if !audio_stream_player.playing:
		audio_stream_player.play(0.0)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/Tutorial.tscn")
	
func _on_quit_pressed() -> void:
	get_tree().quit()

func hover(Obj:Object,property:String,value:Variant,duration:float):
	var tween = create_tween()
	tween.tween_property(Obj,property,value,duration)

func btn_hover(button:Button):
	button.pivot_offset = button.size/2
	
	if button.is_hovered():
		hover(button,"scale",Vector2.ONE*intensidade,duracao)
	else:
		hover(button,"scale",Vector2.ONE,duracao)


func _on_start_mouse_entered() -> void:
	audio_stream_player_2.play()
	
func _on_credits_mouse_entered() -> void:
	audio_stream_player_2.play()
	
func _on_quit_mouse_entered() -> void:
	audio_stream_player_2.play()


func _on_credits_pressed() -> void:
	# load cena creditos
	pass # Replace with function body.
