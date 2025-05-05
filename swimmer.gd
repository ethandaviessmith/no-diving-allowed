class_name Swimmer extends CharacterBody2D
enum State { IDLE, APPROACH, IN_LINE, WANDERING, ACT }
enum PersonalityType { RANDOM, CHILD, ADULT, ATHLETE, LEISURE }
enum Mood { GREAT, GOOD, BAD, ISSUE }

@export var pool: Pool
@export var schedule: Array = []
var state: State = State.IDLE
var move_target: Vector2
var target_activity: Node
var curr_action = null
## Duration
var activity_start_time: float = 0
var activity_duration: float = 0
@onready var wait_timer: Timer = $WaitTimer
@onready var state_label: Label = $Label
@onready var splash: GPUParticles2D = $GPUParticles2D


var speed: float = 120
var swim_speed: float = 180
var base_speed := 120
var wander_points: Array[Vector2] = []
var wander_index: int = 0
var wander_speed_range := Vector2(40, 80)
var wander_pause_range := Vector2(0.5, 2.5)
var pause_timer := 0.0
var wandering_paused := false

var happiness: float = 0.8
var max_happy:float = 1.0
var energy: float = 10.0
var max_energy: float = 10.0
var safety: float = 1.0
var max_safety: float = 1.0
var cleanliness: float = 1.0
var max_clean: float = 1.0
@export var personality_type: PersonalityType
var mood: int = Mood.GOOD  # enum: GREAT, GOOD, BAD, ISSUE

@export var mood_color_great: Color
@export var mood_color_good: Color
@export var mood_color_bad: Color
@export var mood_color_issue: Color
@onready var mood_bar: ColorRect = $MoodBar

@onready var bar_happy: TextureProgressBar = $HappyProgressBar
@onready var bar_energy: TextureProgressBar = $EnergyProgressBar
@onready var bar_safety: TextureProgressBar = $SafetyProgressBar
@onready var bar_clean: TextureProgressBar = $CleanProgressBar


var path_follow: PathFollow2D = null
var path_direction: int = 1
var path_progress: float = 0.0
var is_on_lane: bool = false

var _queued_path_follow: PathFollow2D = null
var sprite_frame
signal left_pool


var is_swimming := false

func _on_pool_entered(body):
	if body == self:
		is_swimming = true
		splash.visible = true
		$Sprite2D.frame = 4

func _on_pool_exited(body):
	if body == self:
		is_swimming = false
		splash.visible = false
		$Sprite2D.frame = sprite_frame

func set_pool(_pool, s):
	pool = _pool
	schedule = s if s != null else Util.make_swim_schedule()
	pool.poolArea2D.body_entered.connect(_on_pool_entered)
	pool.poolArea2D.body_exited.connect(_on_pool_exited)
	left_pool.connect(pool.on_swimmer_left_pool.bind(self))

func _ready():
	if schedule.is_empty():
		schedule = Util.make_swim_schedule() # manual swimmers
	splash.visible = false
	update_state_label()
	sprite_frame = randi() % 4
	$Sprite2D.frame = sprite_frame
	if personality_type == PersonalityType.RANDOM:
		personality_type = PersonalityType.values()[randi() % PersonalityType.size()]
	if personality_type == PersonalityType.CHILD:
		$Sprite2D.scale.y = 0.7
		$Sprite2D.scale.x = 0.9
	elif personality_type == PersonalityType.ATHLETE:
		$Sprite2D.scale.x = 0.9
	elif personality_type == PersonalityType.LEISURE:
		$Sprite2D.scale.x = 1.1

func _process(delta: float) -> void:
	if state == State.IDLE and schedule.size() == 0:
		left_pool.emit(self)
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0, 0.4)
		tween.tween_property(self, "scale", scale * Vector2(1.0, 0.8), 0.35)
		tween.set_parallel(true)
		tween.connect("finished", Callable(self, "queue_free"))
		pass
	update_mood()
	
	if !is_on_lane:
		return
	
	var length = path_follow.get_parent().curve.get_baked_length()
	path_follow.progress_ratio += path_direction * swim_speed * delta / length
	
	# Clamp and swap direction to bounce at ends
	if path_follow.progress_ratio >= 1 - path_buffer:
		path_follow.progress_ratio = 1.0 - path_buffer
		path_direction = -1
	elif path_follow.progress_ratio <= path_buffer:
		path_follow.progress_ratio = path_buffer
		path_direction = 1
	$Sprite2D.flip_h = path_direction > 0

	global_position = path_follow.global_position # Follows path

const path_buffer := 0.00

func start_lap_movement():
	is_on_lane = true
	path_direction = -1
	path_follow.progress_ratio = path_buffer
	$AnimationPlayer.play("swim")

func end_lap_movement():
	is_on_lane = false
	path_follow = null
	$AnimationPlayer.stop()
	$Sprite2D.frame = 4

func _physics_process(delta):
	if state == State.APPROACH or state == State.WANDERING or state == State.IN_LINE:
		_step_move()
	# nothing else handled each frame
	update_state_label()

func start_next_action():
	if schedule.is_empty() or not pool:
		state = State.IDLE
		return

	curr_action = schedule[0]
	
	#var activity_manager = Util.get_activity_manager(curr_action)
	var activity_manager: ActivityManager = pool.getActivityManager(curr_action)
	if activity_manager:
		if activity_manager.has_open_direct_slot():
			target_activity = activity_manager
			if (activity_manager.try_queue_swimmer(self)):
				begin_approach_to_activity(activity_manager)
				schedule.remove_at(0)
		else:
			if activity_manager.has_available_line_position():
				target_activity = activity_manager
				state = State.IN_LINE
				activity_manager.try_queue_swimmer(self)
			else:
				state = State.WANDERING
				#_setup_wander_and_go(curr_action)

func begin_approach_to_activity(activity_manager: ActivityManager):
	state = State.APPROACH
	move_target = activity_manager.get_interaction_pos(self)

func _step_move():
	if state == State.WANDERING:
		# Handle wait-at-point:
		if wandering_paused:
			pause_timer -= get_physics_process_delta_time()
			if pause_timer <= 0:
				wandering_paused = false
				if wander_index < wander_points.size():
					move_target = wander_points[wander_index]
		else:
			var dist = global_position.distance_to(move_target)
			var speed = randf_range(wander_speed_range.x, wander_speed_range.y)
			if dist > 6:
				velocity = (move_target - global_position).normalized() * speed
				move_and_slide()
				if velocity.x != 0:
					$Sprite2D.flip_h = velocity.x < 0
			else:
				velocity = Vector2.ZERO
				# Arrived at point, so pause a bit before next:
				wandering_paused = true
				pause_timer = randf_range(wander_pause_range.x, wander_pause_range.y)
				_check_wander()
	else:
		var dist = global_position.distance_to(move_target)
		velocity = (move_target - global_position).normalized() * base_speed
		if dist > 6:
			move_and_slide()
			if velocity.x != 0:
				$Sprite2D.flip_h = velocity.x < 0
		# Handle arrival as before:
		elif state == State.APPROACH:
			state = State.ACT
			_do_perform_activity()
		elif state == State.IN_LINE:
			pass # line move, if any other custom arrivals

func _do_perform_activity():
	activity_duration = Util.ACTIVITY_DURATION.get(curr_action, 1)
	activity_start_time = Time.get_ticks_msec() / 1000.0
	wait_timer.start(activity_duration)
	update_state_label()
	
	var node = target_activity.get_activity_node(self)
	if node is Path2D:
		var path_follow = node.get_child(0) if node.get_child_count() > 0 else null
		if path_follow:
			target_activity.swimmer_attach_to_path(self, path_follow)

func get_in_line(line_pos: Vector2):
	state = State.IN_LINE
	move_target = line_pos # line position slot

func try_leave_line_and_use_activity(activity_manager):
	if schedule[0] == curr_action: # only try if expected
		schedule.pop_front()
	target_activity = activity_manager
	state = State.APPROACH
	move_target = activity_manager.get_interaction_pos(self)


func _setup_wander_and_go_with_area(area: Area2D):
	var shape = Util.get_area_shape(area)
	clear_wander()
	if shape == null:
		wander_points = [area.global_position]
		return
	wander_points.clear()
	var count = randi_range(3, 6)
	for i in count:
		wander_points.append(Util.rand_point_within_shape(shape, area.global_position))

func _check_wander():
	var target_point = wander_points[wander_index]
	if move_target == target_point:
		if global_position.distance_to(target_point) < 10.0:
			wander_index += 1
			if wander_index >= wander_points.size():
				clear_wander()
				state = State.IDLE
				start_next_action()
	else:
		if wander_index < wander_points.size():
			move_target = target_point

func clear_wander():
	wander_index = 0
	wander_points.clear()



func get_state_duration_left() -> float:
	if state == State.ACT:
		return max(0.0, (activity_start_time + activity_duration) - (Time.get_ticks_msec() / 1000.0))
	return 0.0

func update_state_label():
	var dur = ""
	if state == State.ACT:
		dur = "%.1f" % get_state_duration_left()
	var txt = "%s_%s:%s" % [str(State.keys()[state]), curr_action if curr_action != null else "", dur if dur != "" else "", ]
	state_label.text = txt

func update_mood():
	# Just as an example, tweak to fit your liking
	if happiness > 0.75 and energy > 6.0 and safety > 0.7 and cleanliness > 0.8:
		mood = Mood.GREAT
	elif happiness > 0.5 and energy > 3.0 and safety > 0.5:
		mood = Mood.GOOD
	elif happiness < 0.25 or energy < 2.0 or safety < 0.3:
		mood = Mood.BAD
	else:
		mood = Mood.ISSUE
	update_mood_bar_color()
	set_mood_progress(bar_happy, happiness, max_happy)
	set_mood_progress(bar_energy, energy, max_energy)
	set_mood_progress(bar_safety, safety, max_safety)
	set_mood_progress(bar_clean, cleanliness, max_clean)


func update_mood_bar_color():
	match mood:
		Mood.GREAT: mood_bar.color = mood_color_great
		Mood.GOOD: mood_bar.color = mood_color_good
		Mood.BAD: mood_bar.color = mood_color_bad
		Mood.ISSUE: mood_bar.color = mood_color_issue

func set_mood_progress(bar: TextureProgressBar, value: float, max: float):
	var ratio = value / max
	bar.value = ratio * bar.max_value
	if ratio > 0.66:
		bar.modulate = Color("62ff49") # green
	elif ratio > 0.33:
		bar.modulate = Color("ffdd57") # yellow
	else:
		bar.modulate = Color("ff495b") # red

func change_happiness(amount: float): 
	happiness = clamp(happiness + amount, 0.0, 1.0)

func drain_energy(amount: float = 1.0): 
	energy = max(energy - amount, 0.0)

func restore_energy(amount: float = 1.0): 
	energy = min(energy + amount, 10.0)

func change_safety(amount: float):
	safety = clamp(safety + amount, 0.0, 1.0)

func change_cleanliness(amount: float):
	cleanliness = clamp(cleanliness + amount, 0.0, 1.0)

func _personality_val(amt:float, less:Array[PersonalityType] = [], more:Array[PersonalityType] = []) -> float:
	if personality_type in less:
		return amt * 0.5
	if personality_type in more:
		return amt * 1.5
	return amt

func _personality_factor(types:Array = [], base:float = 0.0) -> float:
	return base if personality_type in types else 0.0

func _on_mood_timer_timeout() -> void:
	match state:
		State.ACT:
			var amt = 0.2
			match curr_action:
				Util.ACT_LOCKER, Util.ACT_SHOWER:
					change_cleanliness(_personality_val(amt, [PersonalityType.CHILD]))
				Util.ACT_LAPS, Util.ACT_SWIM, Util.ACT_PLAY:
					drain_energy(_personality_val(amt, [], [PersonalityType.LEISURE]))
				Util.ACT_SUNBATHE:
					restore_energy(0.1)
			# Activity random negative cleanliness
			if randf() < 0.25 + _personality_factor([PersonalityType.CHILD, PersonalityType.ATHLETE], 0.3):
				change_cleanliness(_personality_val(-0.04, [], [PersonalityType.CHILD, PersonalityType.ATHLETE]))
		State.IN_LINE, State.WANDERING:
			# Random down in happiness, small chance
			if randf() < 0.2 - _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.1):
				change_happiness(-0.04)
	update_mood()

func _on_wait_timer_timeout() -> void:
	if is_on_lane: end_lap_movement()
	state = State.IDLE
	if target_activity and target_activity.has_method("notify_done"):
		target_activity.notify_done(self) # tells manager to pop next in line, etc
	curr_action = null
	start_next_action()
