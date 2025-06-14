@icon("res://addons/simple-state/icons/state.png")
class_name Drown extends State

@onready var swimmer := owner# as Swimmer

func _enter() -> void:
	Log.pr("drowning started")
	swimmer.navigation_agent.set_target_position(swimmer.global_position) # Stay in place
	swimmer.collision_shape.disabled = false
	swimmer.being_carried = false
	#swimmer.curr_action = Util.ACT_POOL_DROWN
	if swimmer.sprite_frame < 2:
		swimmer.anim.play("drown_m")
	else:
		swimmer.anim.play("drown_f")
	swimmer.mood.change_happy(-0.3)
	#swimmer.schedule.clear()
	#swimmer.schedule.append(Util.ACT_POOL_DROWN)

func _update(delta: float) -> void:
	# Could add time-in-state or auto-fail if not rescued in time
	Log.pr("drowning")
	pass

func _exit() -> void:
	Log.err("drown exit", swimmer.curr_action)
	#swimmer.curr_action = null
