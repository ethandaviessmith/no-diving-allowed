class_name Swimmer extends CharacterBody2D
enum State { IDLE, APPROACH, IN_LINE, WANDERING, ACT, SLEEP }
enum PersonalityType { RANDOM, CHILD, ADULT, ATHLETE, LEISURE }
#enum Mood { GREAT, GOOD, BAD, ISSUE }

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
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var anim: AnimationPlayer = $AnimationPlayer

@export var personality_type: PersonalityType
@onready var mood: MoodComponent = $MoodComponent

var swim_speed: float = 180
var base_speed := 120
var wander_points: Array[Vector2] = []
var wander_index: int = 0
var wander_speed_range := Vector2(40, 80)
var wander_pause_range := Vector2(0.5, 2.5)
var pause_timer := 0.0
var wandering_paused := false
var is_running := false


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


func _ready():
	navigation_agent.velocity_computed.connect(_on_agent_velocity_computed)
	set_is_swimming(false)
	
	if schedule.is_empty():
		schedule = Util.get_schedule_enter(self) # manual swimmers
	splash.visible = false
	update_state_label()
	sprite_frame = randi() % 4
	set_sprite()


func set_sprite():
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
		
func set_pool(_pool, s):
	pool = _pool
	schedule = s if s != null else Util.get_schedule_enter(self)
	pool.poolArea2D.body_entered.connect(_on_pool_entered)
	pool.poolArea2D.body_exited.connect(_on_pool_exited)
	left_pool.connect(pool.on_swimmer_left_pool.bind(self))

## Movement
func _on_agent_velocity_computed(suggested_velocity: Vector2):
	velocity = suggested_velocity
	move_and_slide()
	if velocity.x != 0:
		$Sprite2D.flip_h = velocity.x < 0
	
func _step_move():
	if _is_state(State.WANDERING):
		_wander_move()
	elif _is_state([State.APPROACH, State.IN_LINE]):
		_standard_move()
		if curr_action == Util.ACT_POOL_DIVE and randf() > 0.1:
			mood.add_misbehave(MoodComponent.Misbehave.DIVE) # sometimes show divers ahead of time
	if navigation_agent.is_navigation_finished():
		if _is_state(State.APPROACH):
			var dist = global_position.distance_to(move_target)
			if dist > 50.0:
				Log.pr("Too far from activity (%s px), resetting path: %s → %s" % [dist, global_position, move_target])
				navigation_agent.set_target_position(move_target)
			else:
				state = State.ACT
				_do_perform_activity()

func _standard_move():
	if navigation_agent.get_target_position() != move_target:
		navigation_agent.set_target_position(move_target)
	if not navigation_agent.is_navigation_finished():
		var dir = (navigation_agent.get_next_path_position() - global_position).normalized()
		navigation_agent.set_velocity(dir * _get_walk_speed())
		
	if global_position != move_target and is_far_from_navigation_path(80.0):
		navigation_agent.target_position = navigation_agent.target_position
		Log.pr("nav", name, self, navigation_agent.target_position, move_target, global_position)

func is_far_from_navigation_path(max_distance: float) -> bool:
	var path: PackedVector2Array = navigation_agent.get_current_navigation_path()
	if path.size() <= 1 or not navigation_agent.is_navigation_finished():
		return false
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg: Vector2 = b - a
		var to_agent: Vector2 = global_position - a
		var t: float = clamp(to_agent.dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest: Vector2 = a + seg * t
		if global_position.distance_to(closest) <= max_distance:
			return false
	return true 

func _wander_move():
	if wandering_paused:
		pause_timer -= get_physics_process_delta_time()
		if pause_timer <= 0:
			wandering_paused = false
			if wander_index < wander_points.size():
				move_target = wander_points[wander_index]
				navigation_agent.set_target_position(move_target)
	else:
		var wander_speed = _get_walk_speed() if wander_index == 0 else _get_wander_speed()
		if not navigation_agent.is_navigation_finished():
			var dir = (navigation_agent.get_next_path_position() - global_position).normalized()
			navigation_agent.set_velocity(dir * wander_speed)
		else:
			velocity = Vector2.ZERO
			wandering_paused = true
			pause_timer = randf_range(wander_pause_range.x, wander_pause_range.y)
			_check_wander()

func _physics_process(delta):
	_step_move()

func _process(delta: float) -> void:
	decide_next_action()
	check_mood_actions()
	mood.update_mood()
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

func _is_state(states) -> bool:
	return state in (states if states is Array else [states])

func decide_next_action():
	if state == State.IDLE and schedule.size() == 0:
		if mood.energy + mood.happy < 0.4 or mood.happy < 0.2:
			schedule = Util.get_schedule_exit(self)
		elif mood.energy < 0.5:
			schedule = Util.get_schedule_lowenergy(self)
		elif mood.happy < 0.5:
			schedule = Util.get_schedule_lowhappy(self)
		else:
			schedule = Util.get_schedule_random_pool(self)
		start_next_action()

func check_mood_actions():
	if _is_state(State.ACT):
		if curr_action == Util.ACT_SHOWER and mood.clean == mood.max_clean:
			_on_wait_timer_timeout()

func start_next_action():
	if schedule.is_empty() or not pool:
		state = State.IDLE
		return
	
	curr_action = schedule[0]
	var activity_manager: ActivityManager = pool.getActivityManager(curr_action, self)
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
			var count = randi_range(1, 2) if mood.energy > 0.5 else randi_range(2, 5)
			_setup_wander_and_go_with_area(area, count)

func begin_approach_to_activity(activity_manager: ActivityManager):
	state = State.APPROACH
	move_target = activity_manager.get_interaction_pos(self)

## Starts the activity timer (beginnig of performing an activity)
func _do_perform_activity():
	activity_duration = Util.ACTIVITY_DURATION.get(curr_action, 1)
	activity_start_time = Time.get_ticks_msec() / 1000.0
	wait_timer.start(activity_duration)
	update_state_label()
	
	var node = target_activity.get_activity_node(self) # PoolLaps
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
	if curr_action == Util.ACT_SHOWER:
		SFX.play_activity_sfx(self, "shower", SFX.sfx_samples["shower"], activity_duration, -10)
	if curr_action == Util.ACT_POOL_DIVE:
		mood.add_misbehave(MoodComponent.Misbehave.DIVE)
	play_activity_manager_anim(target_activity, false)

var _current_activity_particles
func _end_perform_activity():
	if self._current_activity_particles:
		self._current_activity_particles.emitting = false
		self._current_activity_particles = null

func get_in_line(line_pos: Vector2):
	state = State.IN_LINE
	move_target = line_pos # line position slot

func try_leave_line_and_use_activity(activity_manager):
	if schedule.size() > 0 and schedule[0] == curr_action: # only try if expected
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
	if _is_state(State.ACT):
		return max(0.0, (activity_start_time + activity_duration) - (Time.get_ticks_msec() / 1000.0))
	return 0.0

func update_state_label():
	var dur = ""
	if _is_state(State.ACT):
		dur = "%.1f" % get_state_duration_left()
	var txt = "%s_%s:%s" % [str(State.keys()[state]), curr_action if curr_action != null else "", dur if dur != "" else "", ]
	state_label.text = txt

#region Timers
func _on_wait_timer_timeout() -> void:
	wait_timer.stop()
	_end_perform_activity()
	if is_on_lane: end_lap_movement()
	if curr_action == Util.ACT_SHOWER:
			is_wet = true
			start_wet_timer()
			SFX.stop_activity_sfx(self, "shower")
	if curr_action == Util.ACT_SUNBATHE and _is_state(State.SLEEP):
		if randf() < 0.8: # 80% chance, to keep on sleeping
			return
	if curr_action == Util.ACT_POOL_DIVE:
		if mood.has_misbehave(MoodComponent.Misbehave.DIVE):
			mood.change_safety(-0.2)
			Log.pr("dive")
	
	# Explicit on ActivityManagers with activities that change position (except laps)
	if curr_action in [Util.ACT_POOL_ENTER, Util.ACT_POOL_EXIT, Util.ACT_POOL_DIVE] and target_activity:
		var target_pos = target_activity.get_tween_target_for_swimmer(self)
		if global_position.distance_to(target_pos) > 100:
			Log.pr("Tween abort: swimmer too far from assigned slot (%s → %s)" % [global_position, target_pos])
		var tween := create_tween()
		tween.tween_property(self, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
		navigation_agent.target_position = navigation_agent.target_position
	play_activity_manager_anim(target_activity, true)
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

func leave_pool():
		left_pool.emit()
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0, 0.4)
		tween.tween_property(self, "scale", scale * Vector2(1.0, 0.8), 0.35)
		tween.set_parallel(true)
		tween.connect("finished", Callable(self, "queue_free"))

func _on_pool_entered(body):
	if body == self:
		set_is_swimming(true)
		splash.visible = true
		$Sprite2D.frame = 4

func _on_pool_exited(body):
	if body == self:
		set_is_swimming(false)
		splash.visible = false
		$Sprite2D.frame = sprite_frame
		is_wet = true
		start_wet_timer()

func set_is_swimming(flag: bool):
	is_swimming = flag
	if is_swimming:
		var splash = preload("res://splash_effect.tscn").instantiate()
		get_parent().add_child(splash)
		splash.global_position = global_position + Vector2(0.0, -35.0)

## Animations

func play_activity_manager_anim(am: ActivityManager, use_finish: bool) -> void:
	if not am:
		return
	var anim_index: int = am.finish_activity if use_finish else am.activity
	if anim_index != Util.Anim.NA:
		var anim_name: String = Util.ANIM_NAME_MAP.get(anim_index, "idle")
		anim.play(anim_name)
	elif use_finish and am.activity:
		anim.play(Util.ANIM_NAME_MAP.get(Util.Anim.NA))

func play_dive_splash_sfx():
	SFX.play("dive_splash")
	
func play_splash_sfx():
	SFX.play("splash")


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

#############################
## MOOD

signal rule_broken(swimmer, amount)

func whistled_at():
	var broken_count = mood.misbehaves.size()
	if broken_count > 0:
		rule_broken.emit(self, broken_count)
		mood.start_removing_misbehave_icons()
	
	for type in mood.misbehaves.keys():
		mood.remove_misbehave(type)
	
	if curr_action == Util.ACT_SUNBATHE and _is_state(State.SLEEP):
		finish_activity()
	mood.change_safety(0.8)
	set_run(false)

func get_mood_rank():
	return mood.get_mood_rank()
	
func _on_mood_timer_timeout() -> void:
	var pf_child_athlete = _personality_factor([PersonalityType.CHILD, PersonalityType.ATHLETE], 0.2)
	var pf_child_leisure = _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.3)

	match state:
		State.ACT:
			var amt = 0.2
			match curr_action:
				Util.ACT_SHOWER:
					mood.change_clean(_personality_val(amt, [PersonalityType.CHILD]))
				Util.ACT_POOL_LAPS, Util.ACT_POOL_SWIM, Util.ACT_POOL_PLAY:
					mood.change_energy(_personality_val(-amt, [], [PersonalityType.LEISURE]))
				Util.ACT_SUNBATHE:
					mood.change_energy(0.1)
					mood.change_happy(-0.04)
			# Activity random negative clean
			if randf() < 0.05 + pf_child_athlete:
				mood.change_clean(_personality_val(-0.04, [], [PersonalityType.CHILD, PersonalityType.ATHLETE]))
		State.IN_LINE, State.WANDERING:
			# Random down in happy, small chance
			if randf() < 0.2 - pf_child_leisure:
				mood.change_happy(-0.04)
		State.ACT, State.APPROACH:
			# Random up in happy, small chance
			if randf() < 0.2 - pf_child_leisure:
				mood.change_happy(0.04)
			if randf() < 0.2:
				pass
				# SFX.play_interval_sfx("walk", 1.5, 2.0, self)
	if randf() < 0.5:
		if in_puddle and not _is_state(State.IN_LINE):
			mood.change_safety(-0.2)
			SFX.play("puddle")
	else: 
		mood.change_safety(0.05)
		if mood.safety == mood.max_safety:
			if randf() < 0.5:
				# lost possible bad mood icon?
				pass

	mood.update_mood()
	try_misbehave()

func try_misbehave():
	if randf() > mood.safety: # More likely to misbehave with lower safety
		var pf_child_athlete = _personality_factor([PersonalityType.CHILD, PersonalityType.ATHLETE], 0.2)
		var pf_child_leisure = _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.3)
		
		# Waiting (in line)
		if not is_swimming and _is_state(State.IN_LINE):
			if randf() > mood.clean + pf_child_athlete and randf() > 0.1 + pf_child_athlete:
				throw_trash()
		# Walking Around
		elif not is_swimming and _is_state([State.IDLE, State.APPROACH, State.WANDERING]):
			if randf() > mood.clean + pf_child_athlete and randf() > 0.3 + pf_child_athlete:
				throw_trash()
			elif randf() > 0.5 + pf_child_leisure:
				toggle_run()
		# In Pool (but not laps)
		elif is_swimming and curr_action != Util.ACT_POOL_LAPS:
			if randf() > 0.5 + pf_child_athlete:
				splashplay()
			else:
				horseplay()
			SFX.play("splash")
		# On Lounger
		elif curr_action == Util.ACT_SUNBATHE and _is_state(State.ACT):
			if randf() > mood.happy + pf_child_leisure and randf() > 0.7 + pf_child_leisure:
				fall_asleep()

func _personality_factor(types:Array = [], base:float = 0.0) -> float:
	return base if personality_type in types else 0.0

func _personality_val(amt:float, less:Array[PersonalityType] = [], more:Array[PersonalityType] = []) -> float:
	if personality_type in less:
		return amt * 0.5
	if personality_type in more:
		return amt * 1.5
	return amt

func throw_trash():
	mood.add_misbehave(MoodComponent.Misbehave.TRASH)
	mood.change_clean(-0.05)
	_spawn_dirt()
	# Optionally spawn litter signal/event

func toggle_run():
	set_run(not is_running)

func set_run(is_run:bool):
	mood.add_misbehave(MoodComponent.Misbehave.RUN) if is_run else mood.remove_misbehave(MoodComponent.Misbehave.RUN)
	is_running = is_run

func splashplay():
	mood.add_misbehave(MoodComponent.Misbehave.SPLASH)
	mood.change_happy(0.02)
	# Option: SFX, particles, fountain

func horseplay():
	mood.add_misbehave(MoodComponent.Misbehave.BAD)
	var affected_others = find_swimmers_nearby()
	if affected_others.size() > 0:
		var victim = affected_others.pick_random()
		if victim:
			victim.mood.change_happy(-0.2)
			print("%s made %s unhappy!" % [name, victim.name])

func find_swimmers_nearby() -> Array:
	var others := []
	for o in get_tree().get_nodes_in_group("swimmer"):
		if o != self and global_position.distance_to(o.global_position) < 80.0:
			others.append(o)
	return others

func fall_asleep():
	mood.add_misbehave(MoodComponent.Misbehave.SLEEP)
	mood.energy = min(mood.max_energy, mood.energy + 1)
	state = State.SLEEP

#endregion
