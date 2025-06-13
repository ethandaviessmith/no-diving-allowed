@icon("res://addons/simple-state/icons/state.png")
class_name Carry extends State

@onready var swimmer: Swimmer = owner as Swimmer

func _enter() -> void:
	swimmer.navigation_agent.process_mode = Node.PROCESS_MODE_DISABLED
	if swimmer.sprite_frame < 2:
		swimmer.anim.play("sit_m")
	else:
		swimmer.anim.play("sit_f")
	swimmer.collision_shape.disabled = true
	swimmer.rotation_degrees = 50
	swimmer.being_carried = true

func _update(delta: float) -> void:
	if swimmer.carry_target:
		swimmer.global_position = swimmer.carry_target.global_position + swimmer.carry_offset

func _exit() -> void:
	swimmer.navigation_agent.process_mode = Node.PROCESS_MODE_INHERIT
	swimmer.collision_shape.disabled = false
	swimmer.rotation_degrees = 0
	swimmer.being_carried = false
	swimmer.anim.play("Idle")
