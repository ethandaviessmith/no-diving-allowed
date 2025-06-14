@icon("res://addons/simple-state/icons/state.png")
class_name Approach
extends State

@onready var swimmer := owner# as Swimmer

func _enter():
	if debug_mode:
		print("Entering Approach state.")
	if swimmer:
		swimmer.navigation_agent.set_target_position(swimmer.move_target)

func _update(delta):
	if swimmer:
		if not swimmer.navigation_agent.is_navigation_finished():
			var dir = (swimmer.navigation_agent.get_next_path_position() - swimmer.global_position).normalized()
			swimmer.navigation_agent.set_velocity(dir * swimmer.get_walk_speed())
		else:
			swimmer.velocity = Vector2.ZERO
			# Check distance threshold
			var dist = swimmer.global_position.distance_to(swimmer.move_target)
			if dist > 50.0:
				Log.pr("Too far from activity; resetting path: %s → %s" % [swimmer.global_position, swimmer.move_target])
				swimmer.navigation_agent.set_target_position(swimmer.move_target)
			else:
				if debug_mode:
					Log.pr("approach done", swimmer.name)
				swimmer.set_state(Act)

func standard_move() -> void:
	if swimmer.navigation_agent.get_target_position() != swimmer.move_target:
		swimmer.navigation_agent.set_target_position(swimmer.move_target)
	if not swimmer.navigation_agent.is_navigation_finished():
		var dir = (swimmer.navigation_agent.get_next_path_position() - swimmer.global_position).normalized()
		swimmer.navigation_agent.set_velocity(dir * swimmer.get_walk_speed())
	if swimmer.global_position != swimmer.move_target and get_parent().is_far_from_navigation_path(80.0):
		swimmer.navigation_agent.target_position = swimmer.navigation_agent.target_position
		Log.pr("nav", swimmer.name, swimmer, swimmer.navigation_agent.target_position, swimmer.move_target, swimmer.global_position)

func on_swimmer_velocity_computed(suggested_velocity: Vector2) -> void:
	if get_parent().has_method("on_swimmer_velocity_computed"):
		get_parent().on_swimmer_velocity_computed(suggested_velocity)

func _before_exit() -> void:
	if debug_mode:
		print("Exiting Approach state.")
