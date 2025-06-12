class_name Swimmer extends CharacterBody2D

# == ENUMS ==
enum SwimmerState { IDLE, APPROACH, IN_LINE, WANDERING, ACT, SLEEP, CARRY, SIT }


# == EXPORTED VARS & NODES ==
@export var pool: Pool
@export var schedule: Array = []
@export var puddle_scene: PackedScene

@onready var state_machine:State = $StateMachine
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var wait_timer: Timer = $WaitTimer
@onready var whistle_timer: Timer = $WhistleTimer
@onready var state_label: Label = $Label
@onready var splash: GPUParticles2D = $SwimmingGPUParticles2D
@onready var drip_particles: GPUParticles2D = $DrippingGPUParticles2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var mood: MoodComponent = $MoodComponent
@onready var sprite: Sprite2D = $Sprite2D

signal left_pool
signal rule_broken(swimmer, amount)

# == BASIC PROPERTIES ==
var state = SwimmerState.IDLE: set = set_state, get = get_state
var move_target: Vector2
var target_activity: ActivityManager
var curr_action = null
var is_running := false
var is_swimming := false
var is_wet: bool = false
var wet_timer: Timer = null
var in_puddle: Dirt = null
var puddle_slow := 0.5
var activity_start_time: float = 0
var activity_duration: float = 0
var sprite_frame

func set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	# Transition the state machine:
	#var state_machine:State = $StateMachine  # or whatever the node path is
	if STATE_ENUM_TO_NODE.has(new_state):
		await state_machine.change_state_name(STATE_ENUM_TO_NODE[new_state])
	if STATE_ENUM_TO_NODE[new_state] == "Active":
		state_machine.get_active_substate().set_behavior_state(new_state)
	_on_state_changed(new_state)

func get_state() -> int:
	return state

func _on_state_changed(new_state: int) -> void:
	Log.pr("state changed", STATE_ENUM_TO_NODE[new_state])
	pass

# Patch to transition to state machine
const STATE_ENUM_TO_NODE = {
	SwimmerState.IDLE: "Idle",
	SwimmerState.APPROACH: "Active",
	SwimmerState.IN_LINE: "Active",
	SwimmerState.WANDERING: "Active",
	SwimmerState.ACT: "Act",
	SwimmerState.SLEEP: "Sleep",
	SwimmerState.CARRY: "Carry",
	SwimmerState.SIT: "Sit",
}


# Tracking rescue targets
var carry_target: Node = null   # Could be the life-saver or later the lifeguard
var carry_offset: Vector2 = Vector2.ZERO  # Optional offset for position (carried above lifeguard, etc)
var being_carried := false

# == SCHEDULE/WANDER ==
#var wander_points: Array[Vector2] = []
#var wander_index: int = 0
var wander_speed_range := Vector2(40, 80)
var wander_pause_range := Vector2(0.5, 2.5)
#var pause_timer := 0.0
#var wandering_paused := false

# == POOL LANE/PATH ==
var path_follow: PathFollow2D = null
var path_direction: int = 1
var path_progress: float = 0.0
var is_on_lane: bool = false

# == MOVEMENT/SWIMMING ==
var swim_speed: float = 180
var base_speed := 120

# == ACTIVITY PARTICLES ==
var _current_activity_particles

# == READY AND BASIC SETUP ==
func _ready():
	navigation_agent.velocity_computed.connect(_on_agent_velocity_computed)
	set_is_swimming(false)
	if schedule.is_empty():
		schedule = Util.get_schedule_enter(self)
	splash.visible = false
	update_state_label()
	sprite_frame = randi() % 4
	set_sprite()

func set_sprite():
	mood.set_sprite(sprite, sprite_frame)

func set_pool(_pool, s):
	pool = _pool
	schedule = s if s != null else Util.get_schedule_enter(self)
	pool.pool_area.body_entered.connect(_on_pool_entered)
	pool.pool_area.body_exited.connect(_on_pool_exited)
	left_pool.connect(pool.on_swimmer_left_pool.bind(self))

func _on_agent_velocity_computed(suggested_velocity: Vector2):
	# By default, send to active movement state
	var cur_state = $StateMachine.get_deep_active_state()
	if cur_state.has_method("on_swimmer_velocity_computed"):
		cur_state.on_swimmer_velocity_computed(suggested_velocity)

# == PHYSICS & FRAME UPDATE ==
func _physics_process(delta):
	if _is_state(SwimmerState.CARRY) and carry_target:
		global_position = carry_target.global_position + carry_offset
		return  # Don't process normal movement in carry state
	#_step_move()

func _process(delta: float) -> void:
	check_mood_actions()
	mood.update_mood()
	update_state_label()


func set_activity(activity: String) -> void:
	match activity:
		Util.ACT_POOL_LAPS, Util.ACT_WANDER:
			state_machine.change_state_name(activity)
	state_machine.change_state_name("Act")

# == SCHEDULE / NEXT ACTIVITY / DECISION LOGIC ==
func _is_state(states) -> bool:
	return Util.is_state(get_state(), states)

# -------- SPEED HELPERS --------
func get_walk_speed() -> float:
	return (base_speed * 2 if is_running else base_speed) * (puddle_slow if in_puddle else 1)

func get_wander_speed() -> float:
	var speed = randf_range(wander_speed_range.x, wander_speed_range.y)
	return (speed * 2 if is_running else speed) * (puddle_slow if in_puddle else 1)

func check_mood_actions(): # changing action based on mood (e.g. when clean stop showering)
	if _is_state(SwimmerState.ACT):
		if curr_action == Util.ACT_SHOWER and mood.clean == mood.max_clean:
			_on_wait_timer_timeout()

func start_next_action():
	if schedule.is_empty() or not pool:
		set_state(SwimmerState.IDLE)
		return

	if being_carried:
		Log.pr("carry")

	Log.pr("start_next_action", schedule[0])
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
				set_state(SwimmerState.IN_LINE)
				activity_manager.try_queue_swimmer(self)
			else:
				set_state(SwimmerState.WANDERING)
	else:
		if curr_action == Util.ACT_POOL_DROWN:
			Log.pr("drowning and going to wander")
		var area = pool.get_action_wander_area(curr_action)
		if area:
			schedule.remove_at(0)
			#wandering_paused = true
			var count = randi_range(1, 2) if mood.energy > 0.5 else randi_range(2, 5)
			_setup_wander_and_go_with_area(area, count)
			set_state(SwimmerState.WANDERING)

func get_in_line(line_pos: Vector2):
	move_target = line_pos
	set_state(SwimmerState.IN_LINE)

func try_leave_line_and_use_activity(activity_manager):
	if schedule.size() > 0 and schedule[0] == curr_action:
		schedule.pop_front()
	target_activity = activity_manager
	#if target_activity.assign_swimmer_to_slot(self) >= 0:
	begin_approach_to_activity(activity_manager)

func begin_approach_to_activity(activity_manager: ActivityManager):
	move_target = activity_manager.get_interaction_pos(self) ## when compiling this line fails first, likely something else is wrong or needs to save / recompile
	set_state(SwimmerState.APPROACH)
	
func _setup_wander_and_go_with_area(area: Area2D, count: int = 3):
	var wandering = state_machine.get_node("Active/Wandering")
	if wandering and wandering.has_method("_setup_wander_and_go_with_area"):
		wandering._setup_wander_and_go_with_area(area, count)
	else:
		push_error("Wandering state missing in StateMachine for %s" % name)

# == ACTIVITY/STATE TIMERS AND LABELS ==
func get_state_duration_left() -> float:
	if _is_state(SwimmerState.ACT):
		return max(0.0, (activity_start_time + activity_duration) - (Time.get_ticks_msec() / 1000.0))
	return 0.0

func toggle_label(visible: bool):
	if state_label:  # Replace with correct node path
		state_label.visible = visible

func update_state_label():
	var dur = ""
	if _is_state(SwimmerState.ACT):
		dur = "%.1f" % get_state_duration_left()
	var state_machine:State = $StateMachine if has_node("StateMachine") else null
	var state_name = ""
	if state_machine and state_machine.get_deep_active_state():
		state_name = "(" + state_machine.get_deep_active_state().name + ")"
	elif typeof(get_state()) == TYPE_INT and get_state() in SwimmerState.values():
		state_name = SwimmerState.keys()[get_state()]
	else:
		state_name = str(get_state())
	var txt = "%s_%s:%s" % [
		state_name,
		curr_action if curr_action != null else "",
		dur if dur != "" else "",
	]
	if carry_target:
		state_label.text = carry_target.name
	else:
		state_label.text = txt

# == START AND END ACTIVITY ==
func perform_activity():
	set_state(SwimmerState.ACT)

# Called by Act state when activity fully ends
func on_activity_finished():
	set_state(SwimmerState.IDLE) # Or whatever fallback
	start_next_action()


# == POOL ENTRY & EXIT ==
func leave_pool():
	left_pool.emit()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.4)
	tween.tween_property(self, "scale", scale * Vector2(1.0, 0.8), 0.35)
	tween.set_parallel(true)
	tween.connect("finished", Callable(self, "queue_free"))

func remove_from_pool():
	if target_activity:
		target_activity.clear_swimmer(self)
	#leave_pool()
	queue_free()

func _on_pool_entered(body):
	if body == self:
		set_is_swimming(true)
		splash.visible = true
		$Sprite2D.frame = sprite_frame + 4

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

# == MOOD/BEHAVIOR/INTERACTIONS ==
func whistled_at():
	var broken_count = mood.count_whistle_removable_misbehaves()
	if broken_count > 0:
		rule_broken.emit(self, broken_count)
		mood.start_removing_misbehave_icons()
	mood.clear_misbehaves_by_filter(MoodComponent.WHISTLE_REMOVABLES)
	if curr_action == Util.ACT_POOL_DIVE:
		curr_action = Util.ACT_POOL_ENTER
	if curr_action == Util.ACT_SUNBATHE and _is_state(SwimmerState.SLEEP):
		on_activity_finished()
	mood.change_safety(0.8)
	set_run(false)
	whistle_timer.start()

func get_mood_rank():
	return mood.get_mood_rank()

# Send state back to mood for logic
func call_update_mood():
	mood.mood_update(curr_action, get_state(), is_swimming, in_puddle)
	mood.try_misbehave(curr_action, get_state(), is_swimming, in_puddle, is_running)

func start_drown():
	if not try_add_misbehave(MoodComponent.Misbehave.DROWN): return
	mood.change_happy(-0.3)
	schedule.clear()
	schedule.append(Util.ACT_POOL_DROWN)
	curr_action = Util.ACT_POOL_DROWN
	target_activity = pool.getActivityManager(Util.ACT_POOL_DROWN, self)
	
	move_target = global_position
	navigation_agent.set_target_position(move_target)  # Stay in place
	perform_activity()
	if sprite_frame < 2:
		anim.play("drown_m")
	else:
		anim.play("drown_f")
		
func life_saver_thrown_at(lifesaver: Node2D):
	if _is_state(SwimmerState.ACT) and curr_action == Util.ACT_POOL_DROWN:
		mood.clear_misbehaves_by_filter(MoodComponent.LIFE_SAVER_REMOVABLES)
		on_activity_finished()
		set_swimmer_mode(SwimmerState.CARRY, true)
		carry_target = lifesaver
		carry_offset = Vector2(-20, -20)
		lifesaver.linked_swimmer = self

func on_lifeguard_picks_up(life_guard):
	if life_guard.has_method("release_item"):
		life_guard.release_item()
	set_swimmer_mode(SwimmerState.CARRY, true)
	carry_target = life_guard
	carry_offset = Vector2(-20, -30) # adjust as needed, above lifeguard's hands

func put_down():
	set_swimmer_mode(SwimmerState.CARRY, false)

func enter_first_aid():
	curr_action = Util.ACT_FIRSTAID
	set_swimmer_mode(SwimmerState.CARRY, false)
	perform_activity()

## CARRY/SIT state changes
func set_swimmer_mode(mode: int, enabled: bool):
	if curr_action == Util.ACT_POOL_DROWN:
		curr_action = null
	if enabled:
		set_state(mode)
		navigation_agent.process_mode = Node.PROCESS_MODE_DISABLED
		if sprite_frame < 2:
			anim.play("sit_m")
		else:
			anim.play("sit_f")

		if mode == SwimmerState.CARRY:
			collision_shape.disabled = true
			rotation_degrees = 50
			being_carried = true
			if curr_action == Util.ACT_POOL_DROWN:
				curr_action = null
		else:
			rotation_degrees = 0
			collision_shape.disabled = false
			being_carried = false
	else:
		set_state(SwimmerState.IDLE) # Reset to normal/idle
		navigation_agent.process_mode = Node.PROCESS_MODE_INHERIT
		collision_shape.disabled = false
		anim.play("Idle")

		rotation_degrees = 0
		being_carried = false

func try_add_misbehave(misbehave_type) -> bool:
	if whistle_timer.time_left > 0:
		return false
	mood.add_misbehave(misbehave_type)
	return true

func throw_trash():
	if try_add_misbehave(MoodComponent.Misbehave.TRASH):
		mood.change_clean(-0.05)
		mood.change_happy(-0.05)
		_spawn_dirt()

func toggle_run():
	set_run(not is_running)

func set_run(is_run:bool):
	if is_run:
		try_add_misbehave(MoodComponent.Misbehave.RUN)
	else:
		mood.remove_misbehave(MoodComponent.Misbehave.RUN)
	is_running = is_run

func splashplay():
	if try_add_misbehave(MoodComponent.Misbehave.SPLASH):
		mood.change_happy(0.02)

func horseplay():
	if not try_add_misbehave(MoodComponent.Misbehave.BAD): return
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
	if not try_add_misbehave(MoodComponent.Misbehave.SLEEP): return
	mood.energy = min(mood.max_energy, mood.energy + 1)
	set_state(SwimmerState.SLEEP)
	
func start_slip():
	mood.add_misbehave(MoodComponent.Misbehave.SLIP)
	set_swimmer_mode(SwimmerState.SIT, true)
	Log.pr("have animation to show slip")

# == WET/DRIP/ENVIRONMENT TIMER/PUZZLE LOGIC ==
func start_wet_timer():
	if wet_timer: wet_timer.queue_free()
	wet_timer = Timer.new()
	wet_timer.wait_time = 0.7
	wet_timer.one_shot = false
	wet_timer.autostart = true
	add_child(wet_timer)
	wet_timer.timeout.connect(_on_wet_tick)
	drip_particles.emitting = true

func _on_wet_tick():
	if not is_wet:
		return
	var base_chance = 0.2
	var bonus = 0.4 if in_puddle else 0
	if randf() < base_chance: 
		_spawn_dirt(Dirt.DirtType.PUDDLE)
	if randf() < 0.27:
		is_wet = false
		drip_particles.emitting = false
		wet_timer.queue_free()

func _spawn_dirt(dirt_type: Dirt.DirtType = Dirt.DirtType.DIRT):
	if in_puddle and is_instance_valid(in_puddle) and in_puddle.type == dirt_type:
		in_puddle.make_bigger()
	else:
		var node = puddle_scene.instantiate()
		if node.has_method("setup"):
			node.setup(dirt_type)
		node.position = position + Vector2(randf_range(-10,10), randf_range(0,10))
		pool.pool_dirt.add_child(node)

# == ACTIVITY ANIMATION/SFX ==
func play_activity_manager_anim(am: ActivityManager, use_finish: bool) -> void:
	if not am:
		return
	var anim_index: int = am.finish_activity if use_finish else am.activity
	if anim_index != Util.Anim.NA:
		var anim_name: String = Util.ANIM_NAME_MAP.get(anim_index, "Idle")
		anim.play(anim_name)
	elif use_finish and am.activity:
		anim.play(Util.ANIM_NAME_MAP.get(Util.Anim.NA))

func play_dive_splash_sfx():
	SFX.play("dive_splash")

func play_splash_sfx():
	SFX.play("splash")

# == REGION: Timers (end)==
func _on_wait_timer_timeout() -> void:
	wait_timer.stop()
	on_activity_finished()
