@icon("res://addons/simple-state/icons/state.png")
class_name Act
extends State

@onready var swimmer := owner as Swimmer

var activity_timer: float = 0.0
var duration: float = 1.0
var wait_timer: Timer
var _current_activity_particles: GPUParticles2D = null

func _enter():
	
	duration = Util.ACTIVITY_DURATION.get(swimmer.curr_action, 1)
	swimmer.activity_duration = duration
	swimmer.activity_start_time = Time.get_ticks_msec() / 1000.0

	if not swimmer.curr_action == Util.ACT_POOL_DROWN: # timer to finish activity
		if not wait_timer:
			wait_timer = Timer.new()
			wait_timer.one_shot = true
			wait_timer.timeout.connect(_on_activity_done)
			swimmer.add_child(wait_timer)
		wait_timer.start(duration)

	swimmer.update_state_label()
	
	for child in get_children(): # Match children ACT_ states if child exists
		Log.pr("act_substate", owner.name, child.name, swimmer.curr_action)
		if child is State and child.name == str(swimmer.curr_action):
			change_state_name(child.name)
			return

	var node = swimmer.target_activity.get_activity_node(swimmer)
	if node is Node2D:
		for c in node.get_children():
			if c is GPUParticles2D:
				c.emitting = true
				_current_activity_particles = c
				break

	match swimmer.curr_action:
		Util.ACT_SHOWER:
			SFX.play_activity_sfx(swimmer, "shower", SFX.sfx_samples["shower"], duration)
		Util.ACT_POOL_DIVE:
			swimmer.try_add_misbehave(MoodComponent.Misbehave.DIVE)
	swimmer.play_activity_manager_anim(swimmer.target_activity, false)

func _on_activity_done():
	_end_activity()

func _end_activity():
	if swimmer._is_state([Carry, Sit]):
		return

	if _current_activity_particles:
		_current_activity_particles.emitting = false
		_current_activity_particles = null

	match swimmer.curr_action:
		#Util.ACT_POOL_DROWN:
			#swimmer.start_drown()
			#return
		Util.ACT_SHOWER:
			swimmer.is_wet = true
			swimmer.start_wet_timer()
			SFX.stop_activity_sfx(swimmer, "shower")
		Util.ACT_SUNBATHE:
			if swimmer._is_state(Sleep) and randf() < 0.8:
				return
		Util.ACT_POOL_DIVE:
			if swimmer.mood.has_misbehave(MoodComponent.Misbehave.DIVE):
				swimmer.mood.change_safety(-0.2)
				Log.pr("dive")

	# move swimmer to ending node (will shift to within substate soon
	if swimmer.curr_action in [Util.ACT_POOL_ENTER, Util.ACT_POOL_EXIT, Util.ACT_POOL_DIVE] and swimmer.target_activity:
		var target_pos = swimmer.target_activity.get_tween_target_for_swimmer(swimmer)
		if swimmer.global_position.distance_to(target_pos) > 100:
			Log.pr("Tween could abort: swimmer too far from assigned slot (%s → %s)" % [swimmer.global_position, target_pos])
		var tween := swimmer.create_tween()
		tween.tween_property(swimmer, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
		swimmer.navigation_agent.target_position = swimmer.navigation_agent.target_position

	swimmer.play_activity_manager_anim(swimmer.target_activity, true)
	_finish_activity()

func _finish_activity():
	
	if swimmer.curr_action == Util.ACT_EXIT:
		swimmer.leave_pool()
		return
	if swimmer.curr_action == Util.ACT_POOL_DROWN:
		return
	if not swimmer._is_state([Carry, Sit]):
		swimmer.set_state(Idle)
	else:
		Log.pr("tried to set state here")
	if swimmer.target_activity and swimmer.target_activity.has_method("notify_done"):
		swimmer.target_activity.notify_done(swimmer)
		swimmer.target_activity = null
	swimmer.curr_action = null
	swimmer.start_next_action()
