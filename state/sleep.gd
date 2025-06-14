@icon("res://addons/simple-state/icons/state.png")
class_name Sleep extends State

@onready var swimmer := owner# as Swimmer

func _enter() -> void:
	#swimmer.set_anim("sleep") # change as needed
	swimmer.velocity = Vector2.ZERO

func _update(delta: float) -> void:
	if swimmer.mood.energy >= 1.0:
		swimmer.set_state(Idle)

# Optionally, add an _exit for cleanup
func _exit() -> void:
	swimmer.set_anim("idle")
