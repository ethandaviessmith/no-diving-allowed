@icon("res://addons/simple-state/icons/state.png")
class_name Sleep
extends State

func _enter() -> void:
	if debug_mode:
		print("Entered Sleep state.")
	if animation_player:
		animation_player.play("sleep")

func _update(delta: float) -> void:
	# If sleep is timed, wait or monitor for wake-up
	pass

func _before_exit() -> void:
	if animation_player:
		animation_player.stop()
	if debug_mode:
		print("Exiting Sleep state.")
