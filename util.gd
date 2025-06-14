class_name Util extends Node


## Activities that have a State should match names
const ACT_IDLE := "Idle"
const ACT_WANDER := "Wandering"
const ACT_POOL_LAPS := "PoolLaps"
const ACT_POOL_DROWN := "Drown"

const ACT_ENTRANCE := "Entrance"
const ACT_LOCKER := "Locker"
const ACT_SHOWER := "Shower"
const ACT_SUNBATHE := "Lounger"
const ACT_EXIT := "Exit"

const ACT_POOL_SWIM := "PoolSwim"
const ACT_POOL_PLAY := "PoolPlay"

const ACT_POOL_ENTER := "PoolEnter"
const ACT_POOL_EXIT := "PoolExit"
const ACT_POOL_DIVE := "PoolDive"

const ACT_SLIP := "Slip"
const ACT_FIRSTAID := "FirstAid"
const WANDER_POOL := "WanderPool"

# Lists
const POOL_ENTER := [ACT_ENTRANCE, ACT_LOCKER, ACT_SHOWER, WANDER_POOL]
const POOL_EXIT := [ACT_SHOWER, ACT_LOCKER, ACT_EXIT]
const POOL_ACTIVITIES := [ACT_POOL_LAPS, ACT_POOL_SWIM, ACT_POOL_PLAY, ACT_SUNBATHE, ACT_POOL_DIVE, WANDER_POOL]
const POOL_IN_POOL := [ACT_POOL_LAPS, ACT_POOL_SWIM, ACT_POOL_PLAY, ACT_POOL_DIVE, ACT_POOL_ENTER]
const POOL_LOW_HAPPY := [ACT_POOL_LAPS, ACT_POOL_PLAY, WANDER_POOL, ACT_POOL_DIVE]
const POOL_LOW_ENERGY := [ACT_POOL_SWIM, ACT_SUNBATHE, WANDER_POOL, ACT_POOL_ENTER]

# Checks
const POOL_ENERGY = [ACT_LOCKER, ACT_SHOWER, WANDER_POOL, ACT_POOL_LAPS, ACT_POOL_SWIM, ACT_SUNBATHE, ACT_POOL_DIVE]

const ACTIVITY_DURATION := {
	ACT_POOL_DROWN: 25.0,
	ACT_ENTRANCE: 0.2,
	ACT_LOCKER: 4.0,
	ACT_SHOWER: 5.0,
	ACT_POOL_LAPS: 12.0,
	ACT_POOL_SWIM: 12.0,
	ACT_POOL_PLAY: 12.0,
	ACT_SUNBATHE: 12.0,
	ACT_WANDER: 8.0,
	ACT_POOL_DIVE: 5.0,
}

enum Anim {NA, JUMP, LAPS, SHOWER, ENTER_POOL, DROWN}
const ANIM_NAME_MAP = {
	Anim.NA: "Idle",
	Anim.JUMP: "jump",
	Anim.LAPS: "swim",
	Anim.SHOWER: "shower",
	Anim.ENTER_POOL: "enter_pool",
	Anim.DROWN: "drown",
	# sync with your actual animation names
}

# == SCHEDULE/WANDER ==
const wander_speed_range := Vector2(40, 80)
const wander_pause_range := Vector2(0.5, 2.5)


## Maps state file names to class_names for cleaner looking calls to set_state(Idle)
const STATE_ENUM : Dictionary = {
	"idle": "Idle",
	"active": "Active",
	"approach": "Approach",
	"in_line": "InLine",
	"wandering": "Wandering",
	"act": "Act",
	"act_default": "ActDefault",
	"pool_laps": "PoolLaps",
	"drown": "Drown",
	"sit": "Sit",
	"carry": "Carry",
	"sleep": "Sleep"
}

static func get_state_key(state) -> String:
	if typeof(state) == TYPE_STRING:
		return state
	if typeof(state) == TYPE_OBJECT:
		if state is Node:
			return state.get_class() # always correct if class_name set
		if state is GDScript:
			var fname = state.resource_path.get_file().get_basename().to_lower()
			if STATE_ENUM.has(fname):
				return STATE_ENUM[fname]
			return fname # fallback, but strongly prefer enum match!
	return str(state)

static func get_caller_func_name() -> String:
	var stack = get_stack()
	# stack[0] is set_state, stack[1] is the caller
	var i = 3
	if stack.size() > i and stack[i].has("function"):
		return stack[i]["function"]
	return "unknown"
	
#region SCHEDULE
static func get_schedule_enter(swimmer):
	return Util.add_schedule(swimmer, POOL_ENTER.duplicate())

static func get_schedule_exit(swimmer):
	var out = POOL_EXIT.duplicate()
	if randf() < swimmer.mood.energy:
		out.insert(0, WANDER_POOL)
	return Util.add_schedule(swimmer, out)

static func get_schedule_lowenergy(swimmer):
	return Util.add_schedule(swimmer, Util._pick_rand(POOL_LOW_ENERGY, 2))

static func get_schedule_lowhappy(swimmer):
	return Util.add_schedule(swimmer, Util._pick_rand(POOL_LOW_HAPPY, 2))

static func get_schedule_random_pool(swimmer):
	return Util.add_schedule(swimmer, Util._pick_rand(POOL_ACTIVITIES, 3))

static func _pick_rand(source:Array, n:int) -> Array:
	var opts = source.duplicate()
	opts.shuffle()
	return opts.slice(0, n)

static func add_schedule(swimmer, activities):
	var schedule = []
	var was_in_pool = swimmer.is_swimming
	for i in activities.size():
		var next_act = activities[i]

		# Check for required pool transitions
		var next_is_in_pool = next_act in POOL_IN_POOL
		if not was_in_pool and next_is_in_pool:
			schedule.append(ACT_POOL_ENTER)
		if was_in_pool and not next_is_in_pool:
			schedule.append(ACT_POOL_EXIT)
		
		schedule.append(next_act)
		was_in_pool = next_is_in_pool
	return schedule

#endregion

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

static func is_state(state, states) -> bool:
	return state in (states if states is Array else [states])
