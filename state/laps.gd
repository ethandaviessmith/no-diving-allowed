@icon("res://addons/simple-state/icons/state.png")
class_name Laps
extends State

@onready var swimmer := owner as Swimmer

func _enter():
	swimmer.is_on_lane = true
	swimmer.path_direction = -1
	swimmer.path_follow.progress_ratio = swimmer.path_buffer
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
	if swimmer.path_follow.progress_ratio >= 1 - swimmer.path_buffer:
		swimmer.path_follow.progress_ratio = 1.0 - swimmer.path_buffer
		swimmer.path_direction = -1
	elif swimmer.path_follow.progress_ratio <= swimmer.path_buffer:
		swimmer.path_follow.progress_ratio = swimmer.path_buffer
		swimmer.path_direction = 1
	swimmer.sprite.flip_h = swimmer.path_direction > 0
	swimmer.global_position = swimmer.path_follow.global_position

func start_lap_movement() -> void:
	pass

func end_lap_movement() -> void:
	pass
