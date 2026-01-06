extends Node

@export var day_duration: float = 10.0
@export var night_duration: float = 15

@onready var timer: Timer = $Timer

var is_day: bool = true
var current_day: int = 1

signal day_started(day_number: int)
signal night_started

func _ready():
	timer.wait_time = day_duration
	timer.timeout.connect(_on_timer_timeout)
	timer.start()
	emit_signal("day_started", current_day)

func _on_timer_timeout():
	if is_day:
		is_day = false
		timer.wait_time = night_duration
		emit_signal("night_started")
	else:
		is_day = true
		current_day += 1
		timer.wait_time = day_duration
		emit_signal("day_started", current_day)
	
	timer.start()

func get_time_percent() -> float:
	return timer.time_left / timer.wait_time
