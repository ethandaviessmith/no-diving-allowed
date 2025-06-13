@icon("res://addons/simple-state/icons/random_state.png")
class_name WanderMove
extends State

@onready var swimmer := owner as Swimmer

func _enter():
	# Optionally log or reset
	pass

func _update(delta):
	if not swimmer.navigation_agent.is_navigation_finished():
		var wander_speed = swimmer.get_walk_speed() if get_parent().wander_index == 0 else swimmer.get_wander_speed()
		var dir = (swimmer.navigation_agent.get_next_path_position() - swimmer.global_position).normalized()
		swimmer.navigation_agent.set_velocity(dir * wander_speed)
	else:
		swimmer.velocity = Vector2.ZERO
		get_parent().wandering_paused = true
		get_parent().pause_timer = randf_range(Util.wander_pause_range.x, Util.wander_pause_range.y)
		if get_parent().check_wander():
			get_parent().change_state_name("WanderPause") # Switch to pause state

func on_swimmer_velocity_computed(suggested_velocity: Vector2) -> void:
	if get_parent().has_method("on_swimmer_velocity_computed"):
		get_parent().on_swimmer_velocity_computed(suggested_velocity)
