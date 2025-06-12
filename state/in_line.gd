@icon("res://addons/simple-state/icons/state.png")
class_name InLine
extends State

@onready var swimmer := owner as Swimmer

func _enter():
	owner.navigation_agent.set_target_position(swimmer.move_target)

func _update(delta):
	if not swimmer.navigation_agent.is_navigation_finished():
		var dir = (swimmer.navigation_agent.get_next_path_position() - swimmer.global_position).normalized()
		swimmer.navigation_agent.set_velocity(dir * swimmer.get_walk_speed())
	else:
		swimmer.velocity = Vector2.ZERO
		# Additional InLine logic (e.g. ready to advance in line) can go here


func on_swimmer_velocity_computed(suggested_velocity: Vector2) -> void:
	if get_parent().has_method("on_swimmer_velocity_computed"):
		get_parent().on_swimmer_velocity_computed(suggested_velocity)
