@icon("res://addons/simple-state/icons/state.png")
class_name Active
extends State

@onready var swimmer := owner as Swimmer

var current_behavior: Variant = null

# Accept class reference or name string as argument
func set_behavior_state(behavior_state) -> void:
	var target_state_name: String
	if typeof(behavior_state) == TYPE_STRING:
		target_state_name = behavior_state
	elif typeof(behavior_state) == TYPE_OBJECT and behavior_state is Script:
		target_state_name = behavior_state.get_class()
	elif behavior_state != null:
		target_state_name = str(behavior_state)
	else:
		target_state_name = ""
	
	match target_state_name:
		"Approach":
			change_state_name("Approach")
		"InLine":
			change_state_name("InLine")
		"Wandering":
			change_state_name("Wandering")
		_:
			change_to_next_substate()

	current_behavior = behavior_state


func _enter() -> void:
	if current_behavior:
		set_behavior_state(current_behavior)
	else:
		change_to_next_substate()
	if debug_mode:
		print("Entered Active state.")


# -------- MOVEMENT HELPERS --------

func on_swimmer_velocity_computed(suggested_velocity: Vector2) -> void:
	swimmer.velocity = suggested_velocity
	swimmer.move_and_slide()
	if swimmer.velocity.x != 0:
		swimmer.sprite.flip_h = swimmer.velocity.x < 0

func is_far_from_navigation_path(max_distance: float) -> bool:
	var path: PackedVector2Array = swimmer.navigation_agent.get_current_navigation_path()
	if path.size() <= 1 or not swimmer.navigation_agent.is_navigation_finished():
		return false
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg: Vector2 = b - a
		var to_agent: Vector2 = swimmer.global_position - a
		var t: float = clamp(to_agent.dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest: Vector2 = a + seg * t
		if swimmer.global_position.distance_to(closest) <= max_distance:
			return false
	return true
