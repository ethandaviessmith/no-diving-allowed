class_name Swimmer extends CharacterBody2D

@export var mood := 1.0
@export var color_normal := Color(0, 0.8, 1, 1)
@export var color_happy := Color("ffe600")
@export var color_sad := Color("053086")
var activity_idx := 0
var leave_time := 0
signal ready_to_leave
signal left_pool

func _ready():
	update_color()
	perform_activity()

func process_activity():
	# Step through schedule with mood decay
	if activity_idx < schedule.size():
		var current = schedule[activity_idx]
		# placeholder: each lasts say 4s
		leave_time = Time.get_ticks_msec() + 4000
		activity_idx += 1
		mood -= randf_range(-0.1, 0.0) # chance mood goes up or down
		update_color()
	else:
		emit_signal("ready_to_leave")


func update_color():
	var color = color_happy.lerp(color_sad, 1-mood)
	$ColorRect.modulate = color

func _process(delta):
	if leave_time > 0 and Time.get_ticks_msec() > leave_time:
		process_activity()
	
	if performing and activity_time_left > 0.0:
		activity_time_left = max(0, activity_time_left - delta)
		label_time_left.text = str(ceil(activity_time_left))
	#if target_area and global_position.distance_to(target_area.global_position) < 8:
		#perform_activity()

var target_area: Node = null

func _physics_process(delta):
	if moving and not performing:
		var direction = (move_target - global_position).normalized()
		var distance = global_position.distance_to(move_target)
		if distance > 6:
			velocity = direction * speed
			move_and_slide()
		else:
			moving = false
			velocity = Vector2.ZERO
			move_and_slide()
	elif not moving and not performing and  target_area and global_position.distance_to(target_area.global_position) < 8:
		perform_activity()


var schedule = []
var schedule_index = 0
func make_schedule():
	var activities = Util.POOL_ACTIVITIES
	activities.shuffle()
	var activity_count = randi_range(1, 3)
	var chosen_activities = activities.slice(0, activity_count)

	schedule = Util.POOL_ENTER + chosen_activities + Util.POOL_EXIT
	schedule_index = 0


func move_to(destination: Vector2):
	move_target = destination
	moving = true
	
var move_target: Vector2 = Vector2.ZERO
var moving: bool = false
@export var speed: float = 120.0

var performing = false
var current_manager: Node = null

func perform_activity():
	if schedule.size() == 0:
		make_schedule() # scene start swimmers
	var area_name = schedule[schedule_index]
	var area_manager = get_node_or_null("/root/Pool/" + area_name + "/ActivityManager")
	if area_manager:
		Log.pr("try go to", area_name)
		try_start_activity(area_manager)
	else:
		Log.pr("go to", area_name)
		start_activity()

func try_start_activity(manager: ActivityManager): # Possible queue
	current_manager = manager
	if manager.request_slot(self):
		in_line = false
		start_activity()
	else:
		in_line = true
		var queue_pos = manager.global_position_for_queue_position(manager.queue.size() - 1)
		move_to(queue_pos)

var in_line

func on_assigned_queue_position(pos: Vector2):
	in_line = true
	move_to(pos)

func on_granted_slot(slot_position):
	if in_line:
		move_to(slot_position)
	else:
		start_activity()
	# Optionally: call start_activity after a short delay

func start_activity():
	# Actual timer/activity
	performing = true
	var duration = Util.ACTIVITY_DURATION.get(schedule[schedule_index], 1.0)
	activity_time_left = duration
	label_time_left.visible = true
	label_time_left.text = str(round(activity_time_left))

	# Show time left, wait until timer then finish activity
	await get_tree().create_timer(duration).timeout
	performing = false
	label_time_left.visible = false
	if current_manager:
		current_manager.release_slot(self)
		current_manager = null
	schedule_index += 1
	go_to_next_area()

func go_to_next_area():
	if schedule_index >= schedule.size():
		left_pool.emit()
		queue_free()
		return
	var area_name = schedule[schedule_index]
	var scene_root = get_tree().get_root().get_node("/root/Pool")
	target_area = scene_root.get_node_or_null(area_name)
	if target_area:
		move_to(target_area.global_position)

@onready var label_time_left: Label = $Label
var activity_time_left := 0.0
