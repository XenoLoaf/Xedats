extends Node3D

signal open_state_changed(is_door_open: bool)

@export var is_open: bool = false


func set_open_state(value: bool) -> void:
	is_open = value
	open_state_changed.emit(is_open)
