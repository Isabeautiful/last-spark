extends Node2D

@onready var player = $Player
@onready var fire = $Fire
@onready var hud = $InGameHUD
@onready var day_night_cycle = $DayNightCycle
@onready var camera: Camera2D = $Player/Camera2D
@onready var ground_layer: TileMapLayer = $MapManager/GroundLayer
@onready var shadow_spawner = $ShadowSpawner

var current_day: int = 1

func _ready():
	ResourceManager.wood_changed.connect(_on_wood_changed)
	ResourceManager.food_changed.connect(_on_food_changed)
	ResourceManager.population_changed.connect(_on_population_changed)
	
	hud.update_day(current_day)
	
	day_night_cycle.day_started.connect(_on_day_started)
	day_night_cycle.night_started.connect(_on_night_started)
	
	if shadow_spawner:
		shadow_spawner.set_active(false)

func _on_wood_changed(_amount):
	hud.update_resources()

func _on_food_changed(_amount):
	hud.update_resources()

func _on_population_changed(_amount):
	hud.update_resources()

func _on_day_started(day_number: int):
	print("=== DIA ", day_number, " INICIADO ===")
	current_day = day_number
	hud.update_day(current_day)
	hud.update_time(true, day_night_cycle.get_time_percent())
	
	if shadow_spawner:
		shadow_spawner.set_active(false)
	
	if current_day >= 10:
		GameSignals.victory.emit("Sobreviveu 10 dias!")

func _on_night_started():
	print("=== NOITE INICIADA ===")
	hud.update_time(false, day_night_cycle.get_time_percent())
	
	if shadow_spawner:
		shadow_spawner.set_active(true)
