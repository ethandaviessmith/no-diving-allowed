class_name Util extends Node

const ACT_ENTRANCE := "Entrance"
const ACT_LOCKER := "Locker"
const ACT_SHOWER := "Shower"
const ACT_LAPS := "PoolLaps"
const ACT_SWIM := "PoolSwim"
const ACT_PLAY := "PoolPlay"
const ACT_SUNBATHE := "Lounger"
const ACT_EXIT := "Exit"
const ACT_WANDER := "Wander"

const POOL_ACTIVITIES := [ACT_LAPS, ACT_SWIM, ACT_PLAY, ACT_SUNBATHE]
const POOL_ENTER := [ACT_ENTRANCE, ACT_LOCKER, ACT_SHOWER]
const POOL_EXIT := [ACT_SHOWER, ACT_LOCKER, ACT_EXIT]


const ACTIVITY_DURATION := {
	ACT_ENTRANCE: 0.2,
	ACT_LOCKER: 13.5,
	ACT_SHOWER: 8.0,
	ACT_LAPS: 12.0,
	ACT_SWIM: 12.0,
	ACT_PLAY: 12.0,
	ACT_SUNBATHE: 12.0,
	ACT_WANDER: 8.0,
} 

static func make_swim_schedule() -> Array:
	var schedule = Util.POOL_ENTER.duplicate()
	var activities = Util.POOL_ACTIVITIES.duplicate()
	activities.shuffle()
	
	for i in range(randi() % 2 + 1):
		schedule.append(activities[i])

	schedule.append_array(Util.POOL_EXIT)
	return schedule


static func rand_point_within_shape(shape: Shape2D, origin: Vector2) -> Vector2:
	if shape is RectangleShape2D:
		var rx = randf_range(-shape.extents.x, shape.extents.x)
		var ry = randf_range(-shape.extents.y, shape.extents.y)
		return origin + Vector2(rx, ry)
	elif shape is CircleShape2D:
		var angle = randf_range(0, TAU)
		var radius = sqrt(randf()) * shape.radius
		return origin + Vector2(cos(angle), sin(angle)) * radius
	return origin # fallback

static func get_area_shape(area: Area2D):
	for child in area.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			return child.shape
	return null
