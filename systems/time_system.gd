extends Node

signal day_passed

var current_day: int = 1

func advance_day() -> void:
    current_day += 1
    day_passed.emit()
