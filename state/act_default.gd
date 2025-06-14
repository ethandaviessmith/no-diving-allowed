@icon("res://addons/simple-state/icons/state.png")
class_name ActDefault
extends State

@onready var swimmer := owner# as Swimmer

func _enter():
	get_parent()._enter()

func _end_activity():
	get_parent()._end_activity()

func _finish_activity():
	get_parent()._finish_activity()
