class_name Swimmer extends CharacterBody2D
enum State { IDLE, APPROACH_TASK, IN_LINE, WANDERING, PERFORM_ACTIVITY }

var state: State = State.IDLE
var schedule: Array = []      # Given at setup: e.g. [Util.ACT_SHOWER, Util.ACT_POOL]
var pool: Pool
var target_activity: Node     # Set when planning
var curr_action = null        # e.g. Util.ACT_SHOWER
var wait_timer: Timer
var line_position: Vector2
var wander_points: Array[Vector2] = []
var wander_index: int = 0
var move_target: Vector2
var speed: float = 120
@onready var state_label: Label = $Label

signal left_pool

func _ready():
	wait_timer = Timer.new()
	wait_timer.one_shot = true
	add_child(wait_timer)
	wait_timer.connect("timeout", Callable(self, "_on_PerformDone"))
	wait_timer.start()
	if schedule.is_empty():
		schedule = Util.make_swim_schedule() # manual swimmers
	update_state_label()
	$Sprite2D.frame = randi() % $Sprite2D.hframes

func _process(delta: float) -> void:
	if state == State.IDLE and schedule.size() == 0:
		left_pool.emit(self)
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0, 0.4)
		tween.tween_property(self, "scale", scale * Vector2(1.0, 0.8), 0.35)
		tween.set_parallel(true)
		tween.connect("finished", Callable(self, "queue_free"))
		pass

func _physics_process(delta):
	if state == State.APPROACH_TASK or state == State.WANDERING or state == State.IN_LINE:
		_step_move()
	# nothing else handled each frame
	update_state_label()

func start_next_action():
	if schedule.is_empty() or not pool:
		state = State.IDLE
		return

	curr_action = schedule[0]
	schedule.remove_at(0)
	#var activity_manager = Util.get_activity_manager(curr_action)
	var activity_manager: ActivityManager = pool.getActivityManager(curr_action)
	if activity_manager:
		if activity_manager.has_open_direct_slot():
			target_activity = activity_manager
			if (activity_manager.try_queue_swimmer(self)):
				begin_approach_to_activity(activity_manager)
		else:
			if activity_manager.has_available_line_position():
				target_activity = activity_manager
				state = State.IN_LINE
				activity_manager.try_queue_swimmer(self)
			else:
				state = State.WANDERING
				_setup_wander_and_go(curr_action)

func begin_approach_to_activity(activity_manager: ActivityManager):
	state = State.APPROACH_TASK
	move_target = activity_manager.get_interaction_pos(self)

func _step_move():
	var dist = global_position.distance_to(move_target)
	if dist > 6:
		velocity = (move_target - global_position).normalized() * speed
		move_and_slide()
	else:
		if state == State.APPROACH_TASK:
			state = State.PERFORM_ACTIVITY
			_do_perform_activity()
		elif state == State.WANDERING:
			_process_wander()

func get_in_line(line_pos: Vector2):
	state = State.IN_LINE
	move_target = line_pos # line position slot

func try_leave_line_and_use_activity(activity_manager):
	if schedule[0] == curr_action: # only try if expected
		schedule.pop_front()
	target_activity = activity_manager
	state = State.APPROACH_TASK
	move_target = activity_manager.get_interaction_pos(self)

func _on_PerformDone():
	state = State.IDLE
	
	if target_activity and target_activity.has_method("notify_done"):
		target_activity.notify_done(self) # tells manager to pop next in line, etc
		Log.pr("target", "notify done", target_activity.get_parent().name, curr_action)
	curr_action = null
	start_next_action()

func _setup_wander_and_go(action):
	var area = get_node('/root/Pool/LockerRoom') #Util.pick_random_wander_area_for(action)
	if not area: 
		state = State.IDLE
		return
	wander_points.clear()
	var shape = area.get_node("CollisionShape2D").shape
	var count = randi_range(3, 6)
	for i in count:
		wander_points.append(Util.rand_point_within_shape(shape, area.global_position))
	wander_index = 0
	move_target = wander_points[wander_index]

func _process_wander():
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	wander_index += 1
	if wander_index < wander_points.size():
		move_target = wander_points[wander_index]
	else:
		start_next_action()


## Duration
var activity_start_time: float = 0
var activity_duration: float = 0

func _do_perform_activity():
	activity_duration = Util.ACTIVITY_DURATION.get(curr_action, 1)
	activity_start_time = Time.get_ticks_msec() / 1000.0
	wait_timer.start(activity_duration)
	update_state_label()

func get_state_duration_left() -> float:
	if state == State.PERFORM_ACTIVITY:
		return max(0.0, (activity_start_time + activity_duration) - (Time.get_ticks_msec() / 1000.0))
	return 0.0

func update_state_label():
	var dur = ""
	if state == State.PERFORM_ACTIVITY:
		dur = "%.1f" % get_state_duration_left()
	var txt = "%s_%s:%s" % [str(State.keys()[state]), curr_action if curr_action != null else "", dur if dur != "" else "", ]
	state_label.text = txt
