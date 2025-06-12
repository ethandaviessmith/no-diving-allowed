@icon("res://addons/simple-state/icons/random_state.png")
class_name Wandering
extends State

@onready var swimmer := owner as Swimmer

var wander_state: String = "WanderMove" # default child state

func _enter():
	wandering_paused = true
	if wander_points.is_empty():
		#swimmer._setup_wander_and_go_with_area(swimmer.pool.pick_random_area(), 3)
		Log.pr(swimmer.name, "no wander points")
	change_state_name(wander_state)

func change_to_next_substate(force := false) -> void:
	if wandering_paused:
		change_state_name("WanderPause")
	else:
		change_state_name("WanderMove")

func on_swimmer_velocity_computed(suggested_velocity: Vector2) -> void:
	if get_parent().has_method("on_swimmer_velocity_computed"):
		get_parent().on_swimmer_velocity_computed(suggested_velocity)


var wander_points: Array[Vector2] = []
var wander_index: int = 0
var pause_timer: float = 0.0
var wandering_paused: bool = false

# Access these from swimmer/swimmer.config if needed:
# swimmer.wander_speed_range / swimmer.wander_pause_range

func _setup_wander_and_go_with_area(area: Area2D, count:int = 3):
	var attrs = Util.get_area_shape_and_offset(area)
	var shape = attrs.shape
	var offset = attrs.offset
	clear_wander()
	if shape == null:
		wander_points = [area.global_position]
		return
	wander_points.clear()
	for i in count:
		wander_points.append(Util.rand_point_within_shape(shape, area.global_position + offset))

func check_wander():
	if not wander_points:
		Log.err("no wander points, wandering in a bad state")
		return
	var target_point = wander_points[wander_index]
	if swimmer.move_target == target_point:
		if swimmer.global_position.distance_to(target_point) < 10.0:
			wander_index += 1
			if wander_index >= wander_points.size():
				clear_wander()
				swimmer._end_perform_activity()
				return false
	else:
		if wander_index < wander_points.size():
			swimmer.move_target = target_point
	return true

func clear_wander():
	wander_index = 0
	wander_points.clear()
