class_name Swimmer extends CharacterBody2D
enum State { IDLE, APPROACH, IN_LINE, WANDERING, ACT, SLEEP }
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
@onready var splash: GPUParticles2D = $SwimmingGPUParticles2D
@onready var mood_icon: Sprite2D = $MoodIcon

var swim_speed: float = 180
var base_speed := 120
var wander_points: Array[Vector2] = []
var wander_index: int = 0
var wander_speed_range := Vector2(40, 80)
var wander_pause_range := Vector2(0.5, 2.5)
var pause_timer := 0.0
var wandering_paused := false

@export var happy: float = 0.8
@export var energy: float = 10.0
@export var safety: float = 0.8
@export var clean: float = 0.6
@export var personality_type: PersonalityType
var max_happy:float = 1.0
var max_energy: float = 10.0
var max_safety: float = 1.0
var max_clean: float = 1.0
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
const path_buffer := 0.00

var _queued_path_follow: PathFollow2D = null
var sprite_frame
signal left_pool
var is_swimming := false
@export var puddle_scene: PackedScene # Drag your Dirt scene in the editor
@onready var drip_particles: GPUParticles2D = $DrippingGPUParticles2D
var is_wet: bool = false
var wet_timer: Timer = null
var in_puddle: Dirt = null
var puddle_slow := 0.5

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
		is_wet = true
		start_wet_timer()

func set_pool(_pool, s):
	pool = _pool
	schedule = s if s != null else Util.get_schedule_enterpool()
	pool.poolArea2D.body_entered.connect(_on_pool_entered)
	pool.poolArea2D.body_exited.connect(_on_pool_exited)
	left_pool.connect(pool.on_swimmer_left_pool.bind(self))

func _ready():
	if schedule.is_empty():
		schedule = Util.get_schedule_enterpool() # manual swimmers
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

func _physics_process(delta):
	if state == State.APPROACH or state == State.WANDERING or state == State.IN_LINE:
		_step_move()

func _process(delta: float) -> void:
	if state == State.IDLE and schedule.size() == 0:
		if energy + happy < 0.4 or happy < 0.2:
			schedule = Util.get_schedule_exit(self)
		elif energy < 0.5:
			schedule = Util.get_schedule_lowenergy(self)
		elif happy < 0.5:
			schedule = Util.get_schedule_lowhappy(self)
		else:
			schedule = Util.get_schedule_random_pool(self)
		start_next_action()
	check_mood_actions()
	update_mood()
	process_lane_follow(delta)
	update_state_label()

func leave_pool():
		left_pool.emit()
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0, 0.4)
		tween.tween_property(self, "scale", scale * Vector2(1.0, 0.8), 0.35)
		tween.set_parallel(true)
		tween.connect("finished", Callable(self, "queue_free"))

func process_lane_follow(delta: float):
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

func _get_walk_speed() -> float:
	return (base_speed * 2 if is_running else base_speed) * (puddle_slow if in_puddle else 1)

func _get_wander_speed() -> float:
	var speed = randf_range(wander_speed_range.x, wander_speed_range.y)
	return (speed * 2 if is_running else speed) * (puddle_slow if in_puddle else 1)

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

func check_mood_actions():
	if state == State.ACT:
		if curr_action == Util.ACT_SHOWER and clean == max_clean:
			_on_wait_timer_timeout()
	pass

func start_next_action():
	if schedule.is_empty() or not pool:
		state = State.IDLE
		return

	curr_action = schedule[0]
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
				state = State.WANDERING # waiting for line
	else:
		var area = pool.get_action_wander_area(curr_action)
		if area:
			schedule.remove_at(0)
			state = State.WANDERING
			wandering_paused = true
			var count = randi_range(1, 2) if energy > 0.5 else randi_range(2, 5)
			_setup_wander_and_go_with_area(area, count)

func begin_approach_to_activity(activity_manager: ActivityManager):
	state = State.APPROACH
	move_target = activity_manager.get_interaction_pos(self)

func _step_move():
	if state == State.WANDERING:
		if wandering_paused:
			pause_timer -= get_physics_process_delta_time()
			if pause_timer <= 0:
				wandering_paused = false
				if wander_index < wander_points.size():
					move_target = wander_points[wander_index]
		else:
			var dist = global_position.distance_to(move_target)
			var wander_speed =  _get_walk_speed() if wander_index == 0 else _get_wander_speed() # First point walk then wander
			if dist > 2:
				velocity = (move_target - global_position).normalized() * wander_speed
				move_and_slide()
				if velocity.x != 0:
					$Sprite2D.flip_h = velocity.x < 0
			else:
				velocity = Vector2.ZERO
				wandering_paused = true
				pause_timer = randf_range(wander_pause_range.x, wander_pause_range.y)
				_check_wander()
	else:
		var dist = global_position.distance_to(move_target)
		velocity = (move_target - global_position).normalized() * _get_walk_speed()
		if dist > 2:
			move_and_slide()
			if velocity.x != 0:
				$Sprite2D.flip_h = velocity.x < 0
		elif state == State.APPROACH:
			state = State.ACT
			_do_perform_activity()
		elif state == State.IN_LINE:
			pass

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
	if node is Node2D:
		for c in node.get_children():
			if c is GPUParticles2D:
				c.emitting = true
				self._current_activity_particles = c
				break

var _current_activity_particles
func _end_perform_activity():
	if self._current_activity_particles:
		self._current_activity_particles.emitting = false
		self._current_activity_particles = null

func get_in_line(line_pos: Vector2):
	state = State.IN_LINE
	move_target = line_pos # line position slot

func try_leave_line_and_use_activity(activity_manager):
	if schedule[0] == curr_action: # only try if expected
		schedule.pop_front()
	target_activity = activity_manager
	state = State.APPROACH
	move_target = activity_manager.get_interaction_pos(self)


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

func whistled_at():
	for type in misbehaves.keys():
		remove_misbehave(type)
	
	if curr_action == Util.ACT_SUNBATHE and state == State.SLEEP:
		finish_activity()
	change_safety(0.8)
	set_run(false)

func update_mood():
	# Just as an example, tweak to fit your liking
	if happy > 0.75 and energy > 6.0 and safety > 0.7 and clean > 0.8:
		mood = Mood.GREAT
	elif happy > 0.5 and energy > 3.0 and safety > 0.5:
		mood = Mood.GOOD
	elif happy < 0.25 or energy < 2.0 or safety < 0.3:
		mood = Mood.BAD
	else:
		mood = Mood.ISSUE
	update_mood_bar_color()
	Util.set_mood_progress(bar_happy, happy, max_happy)
	Util.set_mood_progress(bar_energy, energy, max_energy)
	Util.set_mood_progress(bar_safety, safety, max_safety)
	Util.set_mood_progress(bar_clean, clean, max_clean)

func get_mood_rank() -> float:
	var energy_rank = 1.0 - clamp(energy / max_energy, 0.0, 1.0) # flipped
	return (clamp(happy,0.0,max_happy) + clamp(safety,0.0,max_safety) + clamp(clean,0.0,max_clean) + energy_rank) / 4.0

func update_mood_bar_color():
	match mood:
		Mood.GREAT: mood_bar.color = mood_color_great
		Mood.GOOD: mood_bar.color = mood_color_good
		Mood.BAD: mood_bar.color = mood_color_bad
		Mood.ISSUE: mood_bar.color = mood_color_issue

func change_happy(amount: float): 
	happy = clamp(happy + amount, 0.0, 1.0)

func drain_energy(amount: float = 1.0): 
	energy = max(energy - amount, 0.0)

func restore_energy(amount: float = 1.0): 
	energy = min(energy + amount, 10.0)

func change_safety(amount: float):
	safety = clamp(safety + amount, 0.0, 1.0)

func change_clean(amount: float):
	var ratio := 1.0
	if target_activity and "get_clean_ratio" in target_activity:
		var clean_ratio = target_activity.get_clean_ratio()
		if amount > 0: ratio = lerp(0.5, 1.5, clean_ratio)
		else: ratio = lerp(1.5, 0.5, clean_ratio)
	clean = clamp(clean + amount * ratio, 0.0, 1.0)
	if clean == max_clean:
		remove_misbehave(Misbehave.TRASH)

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
				Util.ACT_SHOWER:
					change_clean(_personality_val(amt, [PersonalityType.CHILD]))
				Util.ACT_LAPS, Util.ACT_SWIM, Util.ACT_PLAY:
					drain_energy(_personality_val(amt, [], [PersonalityType.LEISURE]))
				Util.ACT_SUNBATHE:
					restore_energy(0.1)
					change_happy(-0.04)
			# Activity random negative clean
			if randf() < 0.05 + _personality_factor([PersonalityType.CHILD, PersonalityType.ATHLETE], 0.2):
				change_clean(_personality_val(-0.04, [], [PersonalityType.CHILD, PersonalityType.ATHLETE]))
		State.IN_LINE, State.WANDERING:
			# Random down in happy, small chance
			if randf() < 0.2 - _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.3):
				change_happy(-0.04)
		State.ACT, State.APPROACH:
			# Random up in happy, small chance
			if randf() < 0.2 - _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.3):
				change_happy(0.04)
	if randf() < 0.5:
		if in_puddle and not state == State.IN_LINE:
			change_safety(-0.2)
	else: 
		change_safety(0.05)
		if safety == max_safety:
			if randf() < 0.5:
				# lost possible bad mood icon?
				pass
			pass
			
	update_mood()
	try_misbehave()

func _on_wait_timer_timeout() -> void:
	wait_timer.stop()
	_end_perform_activity()
	if is_on_lane: end_lap_movement()
	if curr_action == Util.ACT_SHOWER:
			is_wet = true
			start_wet_timer()
	if curr_action == Util.ACT_SUNBATHE and state == State.SLEEP:
		if randf() < 0.8: # 80% chance, to keep on sleeping
			return
	finish_activity()

func finish_activity():
	if curr_action == Util.ACT_EXIT:
		leave_pool()
		return
	state = State.IDLE
	if target_activity and target_activity.has_method("notify_done"):
		target_activity.notify_done(self) # tells manager to pop next in line, etc
	curr_action = null
	start_next_action()
	
func start_wet_timer():
	if wet_timer: wet_timer.queue_free()
	wet_timer = Timer.new()
	wet_timer.wait_time = 0.7 # Set duration as fits your design
	wet_timer.one_shot = false
	wet_timer.autostart = true
	add_child(wet_timer)
	wet_timer.timeout.connect(_on_wet_tick)
	drip_particles.emitting = true

func _on_wet_tick():
	if not is_wet:
		return
	# Small random chance to spawn a puddle at swimmer's feet
	var base_chance = 0.2
	var bonus = 0.4 if in_puddle else 0
	if randf() < base_chance: 
		_spawn_puddle()

	# End wet effect randomly (or by timer duration)
	if randf() < 0.27:
		is_wet = false
		drip_particles.emitting = false
		wet_timer.queue_free()

func _spawn_puddle():
	_spawn_dirt_or_puddle(Dirt.DirtType.PUDDLE)

func _spawn_dirt():
	_spawn_dirt_or_puddle(Dirt.DirtType.DIRT)

func _spawn_dirt_or_puddle(dirt_type: Dirt.DirtType):
	if in_puddle and is_instance_valid(in_puddle) and in_puddle.type == dirt_type:
		in_puddle.make_bigger()
	else:
		var node = puddle_scene.instantiate()
		if node.has_method("setup"):
			node.setup(dirt_type)
		node.position = position + Vector2(randf_range(-10,10), randf_range(0,10))
		pool.poolDirt.add_child(node)

var is_running := false

func try_misbehave():
	# More likely to misbehave with lower safety
	if randf() > safety:
		match get_current_context():
			"waiting":
				if  randf() > clean and randf() > 0.1:
					throw_trash()
			"walking_around":
				if  randf() > clean and randf() > 0.3:
					throw_trash()
				elif randf() > 0.5:
					toggle_run()
			"in_pool":
				if randf() > 0.5:
					splashplay()
				else:
					horseplay()
			"on_lounger":
				if  randf() > happy and randf() > 0.7:
					fall_asleep()

func get_current_context() -> String:
	if is_swimming and curr_action != Util.ACT_LAPS:
		return "in_pool"
	elif curr_action == Util.ACT_SUNBATHE and state == State.ACT:
		return "on_lounger"
	elif not is_swimming and (state == State.IDLE or state == State.APPROACH or state == State.WANDERING):
		return "walking_around"
	elif not is_swimming and state == State.IN_LINE:
		return "waiting"
		pass
	return "unknown"

func throw_trash():
	add_misbehave(Misbehave.TRASH)
	print("%s throws trash!" % name)
	change_clean(-0.05)
	_spawn_dirt()
	# Optionally spawn litter signal/event

func toggle_run():
	set_run(not is_running)

func set_run(is_run:bool):
	add_misbehave(Misbehave.RUN) if is_run else remove_misbehave(Misbehave.RUN)
	is_running = is_run
	print("%s is now %s" % [name, "RUNNING" if is_running else "walking"])

func splashplay():
	add_misbehave(Misbehave.SPLASH)
	print("%s splashes loudly!" % name)
	change_happy(0.02)
	# Option: SFX, particles, fountain

func horseplay():
	add_misbehave(Misbehave.BAD)
	print("%s starts horseplay!" % name)
	var affected_others = find_swimmers_nearby()
	if affected_others.size() > 0:
		var victim = affected_others.pick_random()
		if victim:
			victim.change_happy(-0.2)
			print("%s made %s unhappy!" % [name, victim.name])

func fall_asleep():
	add_misbehave(Misbehave.SLEEP)
	print("%s falls asleep on lounger." % name)
	energy = min(max_energy, energy + 1)
	state = State.SLEEP

func find_swimmers_nearby() -> Array:
	var others := []
	for o in get_tree().get_nodes_in_group("swimmer"):
		if o != self and global_position.distance_to(o.global_position) < 80.0:
			others.append(o)
	return others
	
@onready var mood_icon_stack := $MoodIconStack
enum Misbehave { BAD, RUN, TRASH, SPLASH, SLEEP }
const MISBEHAVE_ICONS = {
	Misbehave.BAD:    preload("res://assets/icons5.png"),
	Misbehave.RUN:    preload("res://assets/icons6.png"),
	Misbehave.TRASH:  preload("res://assets/icons7.png"),
	Misbehave.SPLASH: preload("res://assets/icons8.png"),
	Misbehave.SLEEP:  preload("res://assets/icons9.png"),
}
var misbehaves = {} # Misbehave enum : start_time
const MISBEHAVE_ICON_OFFSET = 32
const MISBEHAVE_DURATION = 60

func add_misbehave(type: Misbehave):
	if misbehaves.has(type): return
	misbehaves[type] = Time.get_ticks_msec() / 1000.0
	var icon = Sprite2D.new()
	icon.texture = MISBEHAVE_ICONS[type]
	icon.name = str(type)
	icon.position.x = mood_icon_stack.get_child_count() * MISBEHAVE_ICON_OFFSET
	mood_icon_stack.add_child(icon)

func has_misbehave(type: Misbehave) -> bool:
	return misbehaves.has(type)

func remove_misbehave(type: Misbehave):
	if misbehaves.has(type):
		misbehaves.erase(type)
		var icon = mood_icon_stack.get_node_or_null(str(type))
		if icon:
			icon.queue_free()
		_update_misbehave_icon_positions()

func _update_misbehave_icon_positions():
	var i = 0
	for icon in mood_icon_stack.get_children():
		icon.position.x = i * MISBEHAVE_ICON_OFFSET
		i += 1

func process_misbehaves():
	var now = Time.get_ticks_msec() / 1000.0
	for type in misbehaves.keys():
		if now - misbehaves[type] > MISBEHAVE_DURATION:
			remove_misbehave(type)
