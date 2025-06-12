@icon("res://addons/simple-state/icons/state.png")
class_name PoolLaps extends State

@onready var swimmer := owner as Swimmer
var path_buffer = 0.0

func _enter():
	if not swimmer.target_activity:
		Log.err("no activity set on laps")
		return
	var node = swimmer.target_activity.get_activity_node(swimmer)
	if not node:
		Log.err("Swimmer not assigned to any activity position")
		return
	var debug_names = []
	for s in swimmer.target_activity.current_swimmers:
		debug_names.append(s.name if s is Node else str(s))
	Log.pr("Laps Enter: swimmer.name=%s, activity.current_swimmers=%s" % [swimmer.name, debug_names])
	if node is Path2D:
		var path_follow = node.get_child(0) if node.get_child_count() > 0 else null
		if path_follow:
			swimmer.target_activity.swimmer_attach_to_path(swimmer, path_follow)
			Log.pr("path found", path_follow.name)

	swimmer.is_on_lane = true
	swimmer.path_direction = -1
	swimmer.path_follow.progress_ratio = path_buffer
	swimmer.anim.play("swim")

func _exit():
	swimmer.is_on_lane = false
	swimmer.path_follow = null
	swimmer.anim.stop()
	swimmer.sprite.frame = swimmer.sprite_frame + 4

func _update(delta):
	process_lane_follow(delta)

func process_lane_follow(delta: float) -> void:
	if not swimmer.is_on_lane:
		return
	var length = swimmer.path_follow.get_parent().curve.get_baked_length()
	swimmer.path_follow.progress_ratio += swimmer.path_direction * swimmer.swim_speed * delta / length
	if swimmer.path_follow.progress_ratio >= 1 - path_buffer:
		swimmer.path_follow.progress_ratio = 1.0 - path_buffer
		swimmer.path_direction = -1
	elif swimmer.path_follow.progress_ratio <= path_buffer:
		swimmer.path_follow.progress_ratio = path_buffer
		swimmer.path_direction = 1
	swimmer.sprite.flip_h = swimmer.path_direction > 0
	swimmer.global_position = swimmer.path_follow.global_position

func start_lap_movement() -> void:
	pass

func end_lap_movement() -> void:
	pass
