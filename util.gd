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

const WANDER_POOL := "WanderPool"

const POOL_ENTER := [ACT_ENTRANCE, ACT_LOCKER, ACT_SHOWER, WANDER_POOL]
const POOL_EXIT := [ACT_SHOWER, ACT_LOCKER, ACT_EXIT]
const POOL_ACTIVITIES := [ACT_LAPS, ACT_SWIM, ACT_PLAY, ACT_SUNBATHE]
const POOL_LOW_HAPPY := [ACT_LAPS, ACT_PLAY, WANDER_POOL]
const POOL_LOW_ENERGY := [ACT_SWIM, ACT_SUNBATHE, WANDER_POOL]


const ACTIVITY_DURATION := {
	ACT_ENTRANCE: 0.2,
	ACT_LOCKER: 4.0,
	ACT_SHOWER: 5.0,
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

static func get_schedule_enterpool():
	return POOL_ENTER.duplicate()

static func get_schedule_exit(swimmer):
	var out = POOL_EXIT.duplicate()
	if randf() < swimmer.energy:
		out.insert(0, WANDER_POOL)
	return out

static func get_schedule_lowenergy(swimmer):
	var opts = POOL_LOW_ENERGY.duplicate()
	return Util._pick_rand(opts, 2)

static func get_schedule_lowhappy(swimmer):
	var opts =  POOL_LOW_HAPPY.duplicate()
	return Util._pick_rand(opts, 2)

static func get_schedule_random_pool(swimmer):
	return Util._pick_rand(POOL_ACTIVITIES, 3)

# Helper for 'n' unique shuffled randoms
static func _pick_rand(source:Array, n:int) -> Array:
	var opts = source.duplicate()
	opts.shuffle()
	return opts.slice(0, n)



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

static func get_area_shape_and_offset(area: Area2D):
	for child in area.get_children():
		if child is CollisionShape2D and child.shape:
			return {"shape": child.shape, "offset": child.position}
	return {"shape": null, "offset": Vector2.ZERO}
	
static func get_area_shape(area: Area2D):
	for child in area.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			return child.shape
	return null


static func set_mood_progress(bar: TextureProgressBar, value: float, max: float):
	var ratio = value / max
	bar.value = ratio * bar.max_value
	if ratio > 0.66:
		bar.modulate = Color("62ff49") # green
	elif ratio > 0.33:
		bar.modulate = Color("ffdd57") # yellow
	else:
		bar.modulate = Color("ff495b") # red
