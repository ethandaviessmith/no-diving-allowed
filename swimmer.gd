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

func _physics_process(delta):
	if state == State.APPROACH or state == State.WANDERING or state == State.IN_LINE:
		_step_move()

func _process(delta: float) -> void:
	if state == State.IDLE and schedule.size() == 0:
		left_pool.emit()
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0, 0.4)
		tween.tween_property(self, "scale", scale * Vector2(1.0, 0.8), 0.35)
		tween.set_parallel(true)
		tween.connect("finished", Callable(self, "queue_free"))
	
	check_mood_actions()
	update_mood()
	process_lane_follow(delta)
	update_state_label()

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
			var wander_speed = randf_range(wander_speed_range.x, wander_speed_range.y)
			if dist > 2:
				velocity = (move_target - global_position).normalized() * wander_speed
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
		velocity = (move_target - global_position).normalized() * _get_walk_speed()
		if dist > 2:
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


func _setup_wander_and_go_with_area(area: Area2D):
	var attrs = Util.get_area_shape_and_offset(area)
	var shape = attrs.shape
	var offset = attrs.offset
	clear_wander()
	if shape == null:
		wander_points = [area.global_position]
		return
	wander_points.clear()
	var count = randi_range(3, 6)
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
	clear_moodicons()
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
		remove_moodicon_named("trash")

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
		if randf() < 0.8: # 80% chance, tune as needed
			return
	finish_activity()

func finish_activity():
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
	show_moodicon_named("trash")
	print("%s throws trash!" % name)
	change_clean(-0.05)
	_spawn_dirt()
	# Optionally spawn litter signal/event

func toggle_run():
	set_run(not is_running)

func set_run(is_run:bool):
	show_moodicon_named("run") if is_run else remove_moodicon_named("run")
	is_running = is_run
	print("%s is now %s" % [name, "RUNNING" if is_running else "walking"])

func splashplay():
	show_moodicon_named("splash")
	print("%s splashes loudly!" % name)
	change_happy(0.02)
	# Option: SFX, particles, fountain

func horseplay():
	show_moodicon_named("bad")
	print("%s starts horseplay!" % name)
	var affected_others = find_swimmers_nearby()
	if affected_others.size() > 0:
		var victim = affected_others.pick_random()
		if victim:
			victim.change_happy(-0.2)
			print("%s made %s unhappy!" % [name, victim.name])

func fall_asleep():
	show_moodicon_named("sleep")
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

const MOOD_ICONS = {
	"bad": preload("res://assets/icons5.png"),
	"run": preload("res://assets/icons6.png"),
	"trash": preload("res://assets/icons7.png"),
	"splash": preload("res://assets/icons8.png"),
	"sleep": preload("res://assets/icons9.png"),
}

func show_moodicon_named(icon_key: String):
	var tex: Texture2D = MOOD_ICONS.get(icon_key)
	if not tex:
		return # fail silently if key missing
	for c in mood_icon_stack.get_children(): # prevent duplicates
		if c is Sprite2D and c.texture == tex:
			return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.modulate.a = 1.0
	sprite.position = Vector2(24 * mood_icon_stack.get_child_count(), 0)
	mood_icon_stack.add_child(sprite)

	#var tween = create_tween()
	#tween.tween_property(sprite, "position", sprite.position + Vector2(0, -32), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	#tween.connect("finished", func(): sprite.queue_free())

func clear_moodicons():
	for item in mood_icon_stack.get_children():
		item.queue_free()

func remove_moodicon_named(icon_key: String):
	var tex: Texture2D = MOOD_ICONS.get(icon_key)
	if not tex:
		return
	for c in mood_icon_stack.get_children():
		if c is Sprite2D and c.texture == tex:
			c.queue_free()
			return
func remove_random_moodicon():
	var icons = mood_icon_stack.get_children()
	if icons.size() > 0:
		icons[randi() % icons.size()].queue_free()
