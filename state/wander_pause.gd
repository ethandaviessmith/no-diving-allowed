@icon("res://addons/simple-state/icons/state.png")
class_name WanderPause
extends State

@onready var swimmer := owner as Swimmer

func _enter() -> void:
	if debug_mode:
		print("WanderPause: pausing before next move.")

func _update(delta):
	get_parent().pause_timer -= swimmer.get_physics_process_delta_time()
	if get_parent().pause_timer <= 0:
		get_parent().wandering_paused = false
		if get_parent().wander_index < get_parent().wander_points.size():
			swimmer.move_target = get_parent().wander_points[get_parent().wander_index]
			swimmer.navigation_agent.set_target_position(swimmer.move_target)
		get_parent().change_state_name("WanderMove") # Switch to movement state

func on_swimmer_velocity_computed(suggested_velocity: Vector2) -> void:
	if get_parent().has_method("on_swimmer_velocity_computed"):
		get_parent().on_swimmer_velocity_computed(suggested_velocity)
