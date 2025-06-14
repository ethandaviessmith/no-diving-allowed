@icon("res://addons/simple-state/icons/animation_state.png")
class_name Idle
extends AnimationState

@onready var swimmer := owner# as Swimmer

func _enter() -> void:
	if swimmer:
		swimmer.set_sprite()
	if debug_mode:
		print("Entered Idle state.")
		swimmer.target_activity = $"../../ActivityManager"

func _update(delta: float) -> void:
	if swimmer:
		if swimmer.schedule.size() > 0:
			swimmer.start_next_action()
		else:
			set_next_schedule()

func _before_exit() -> void:
	if animation_player:
		animation_player.stop()
	if debug_mode:
		print("Exiting Idle state.")


func set_next_schedule():
	if (swimmer.curr_action != Util.ACT_POOL_DROWN) and swimmer.schedule.size() == 0:
		if swimmer.mood.energy + swimmer.mood.happy < 0.4 or swimmer.mood.happy < 0.2:
			swimmer.schedule = Util.get_schedule_exit(swimmer)
		elif swimmer.mood.energy < 0.5:
			swimmer.schedule = Util.get_schedule_lowenergy(swimmer)
		elif swimmer.mood.happy < 0.5:
			swimmer.schedule = Util.get_schedule_lowhappy(swimmer)
		else:
			swimmer.schedule = Util.get_schedule_random_pool(swimmer)
		swimmer.start_next_action()
