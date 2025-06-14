@icon("res://addons/simple-state/icons/state.png")
class_name Sit extends State

@onready var swimmer := owner# as Swimmer

func _enter() -> void:
	swimmer.navigation_agent.process_mode = Node.PROCESS_MODE_DISABLED
	swimmer.collision_shape.disabled = true
	swimmer.rotation_degrees = 0
	swimmer.being_carried = false
	if swimmer.sprite_frame < 2:
		swimmer.anim.play("sit_m")
	else:
		swimmer.anim.play("sit_f")

func _update(delta: float) -> void:
	# add logic to stand up or transition if needed
	pass

func _exit() -> void:
	swimmer.navigation_agent.process_mode = Node.PROCESS_MODE_INHERIT
	swimmer.collision_shape.disabled = false
	swimmer.anim.play("Idle")
	swimmer.rotation_degrees = 0
	swimmer.being_carried = false
