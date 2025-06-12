@icon("res://addons/simple-state/icons/state.png")
class_name Act
extends State

func _enter() -> void:
	if debug_mode:
		print("Entered Act state.")
	# Decide activity using activity manager or schedule
	if target and target.has_method("start_activity"):
		target.start_activity()

func _update(delta: float) -> void:
	# If current activity is timed, decrement timer or check for completion
	# If done, choose next state or emit signal
	pass

func _before_exit() -> void:
	if target and target.has_method("end_activity"):
		target.end_activity()
	if debug_mode:
		print("Exiting Act state.")
