class_name Pool extends Node2D

@export var max_guests := 8
var guests := 0
@onready var poolArea2D:Area2D = $Pool
@onready var poolSwimmers: Node2D = $PoolSwimmers
@onready var poolDirt: Node2D = $PoolDirt

func _on_spawn_timer_timeout():
	if guests < max_guests: # Capacity Check
		spawn_guest()

func spawn_guest():
	var s = preload("res://swimmer.tscn").instantiate()
	s.global_position = $EntranceArea.global_position
	add_child(s)

var base_payment = 10
#var tip = int(base_payment * swimmer.mood)
#add_money(tip)

@export var swimmer_scene: PackedScene
@export var entrance_point: Node2D
#@export var exit_point: Node2D
@export var max_swimmers := 18


var swimmers_in_scene: Array = []
var spawn_timer: float = 0.0
@export var spawn_rate: float = 1.8
var spawn_variation_strength := 1.0
var spawn_period := 10.0

## clock
@export var day_start_hour := 9
@export var day_end_hour := 15
@export var day_duration_secs := 60.0

var current_hour := day_start_hour
var current_minute := 0.0
var clock_time := 0.0 # seconds since start of day

@onready var hour_hand = $PoolUI/ClockContainer/HourHand
@onready var minute_hand = $PoolUI/ClockContainer/MinuteHand
@onready var time_icon = $PoolUI/ClockContainer/TimeIcon
@onready var animation_player = $PoolUI/ClockContainer/TimeIcon/AnimationPlayer

var TOD_HOURS = {9:"morning", 11:"noon", 13:"afternoon", 15:"closing"}
var tod_phase:int = 0                       # index/order in TOD_HOURS
var tod_states = ["morning", "noon", "afternoon", "closing"]
var next_state_hour := 9


func _ready():
	
	
	for swimmer in get_tree().get_nodes_in_group("swimmer"):
		if swimmer is Swimmer:
			swimmer.set_pool(self, swimmer.schedule)
			swimmers_in_scene.append(swimmer)
	_show_time_icon("morning")
	_update_hands(0.0)
	current_hour = day_start_hour
	tod_phase = 0
	next_state_hour = int(tod_states[1])
	update_money_label()

func _process(delta):
	# Periodically try to add a new swimmer
	spawn_timer += delta
	if spawn_timer > spawn_rate and swimmers_in_scene.size() < max_swimmers:
		add_swimmer()
		spawn_timer = 0
	if spawn_timer > get_elastic_spawn_rate() and swimmers_in_scene.size() < max_swimmers:
		spawn_timer = 0.0
		add_swimmer()
		
	clock_time += delta * ((day_end_hour - day_start_hour) * 60) / day_duration_secs
	var hour_offset = clamp(clock_time / ((day_end_hour-day_start_hour)*60),0,1)
	current_hour = day_start_hour + int(hour_offset * (day_end_hour-day_start_hour))
	current_minute = fmod((hour_offset * (day_end_hour-day_start_hour)*60), 60)
	_update_hands(hour_offset)
	_check_time_of_day_triggers(current_hour)

func get_elastic_spawn_rate() -> float:
	var t := Time.get_unix_time_from_system()
	var t_mod := float(int(t) % int(spawn_period)) # Ensure both int
	var phase := t_mod / spawn_period              # Get [0,1) for phase
	var variance := sin(phase * TAU) * spawn_variation_strength
	return max(0.5, spawn_rate + variance)
	
	## Use a smooth, slightly randomized period start so not always identical cycles
	#var t = (Time.get_unix_time_from_system() % 100000) + randi() % 10000.0
	#var phase = ((t % int(spawn_period * 1000.0))) / (spawn_period * 1000.0)
	#var variance := sin(phase * TAU + randf_range(0, TAU)) * spawn_variation_strength
	#return max(0.5, spawn_rate + variance)

func add_swimmer():
	var swimmer:Swimmer = swimmer_scene.instantiate()
	poolSwimmers.add_child(swimmer)
	swimmer.global_position = entrance_point.global_position
	swimmers_in_scene.append(swimmer)
	swimmer.set_pool(self, Util.get_schedule_enter(swimmer))
	update_swimmer_count()


var min_admission = 4.0
func on_swimmer_left_pool(swimmer):
	var mood_rank = swimmer.get_mood_rank()
	var max_tip = 10.0
	var donation = round(lerp(min_admission, max_tip * randf(), mood_rank))
	change_money(donation)
	swimmers_in_scene.erase(swimmer)
	update_swimmer_count()

@export var activity_managers := {
	Util.ACT_ENTRANCE: NodePath("Entrance/ActivityManager"),
	Util.ACT_LOCKER: NodePath("Locker/ActivityManager"),
	Util.ACT_SHOWER: NodePath("Shower/ActivityManager"),
	Util.ACT_SUNBATHE: NodePath("Lounger/ActivityManager"),
	#Util.ACT_WANDER: NodePath("Wander/ActivityManager"),
	Util.ACT_EXIT: NodePath("Exit/ActivityManager"),

	Util.ACT_POOL_LAPS: NodePath("PoolLaps/ActivityManager"),
	Util.ACT_POOL_SWIM: NodePath("PoolSwim/ActivityManager"),
	Util.ACT_POOL_PLAY: NodePath("PoolPlay/ActivityManager"),
	Util.ACT_POOL_ENTER: [
		{name = "PoolStairs", node = NodePath("PoolStairsIn/ActivityManager")},
		{name = "PoolJump1", node = NodePath("PoolJump1/ActivityManager")},
		{name = "PoolJump2", node = NodePath("PoolJump2/ActivityManager")}
	],
	Util.ACT_POOL_EXIT:  [
		{name = "PoolStairs", node = NodePath("PoolStairsOut/ActivityManager")},
		{name = "PoolLadder1", node = NodePath("PoolLadder1/ActivityManager")},
		{name = "PoolLadder2", node = NodePath("PoolLadder2/ActivityManager")}
	],
	Util.ACT_POOL_DIVE: [
		{name = "PoolJump1", node = NodePath("PoolJump1/ActivityManager")},
		{name = "PoolJump2", node = NodePath("PoolJump2/ActivityManager")}
	],
}
func getActivityManager(curr_action: String, swimmer: Node = null) -> ActivityManager:
	if curr_action in [Util.ACT_POOL_ENTER, Util.ACT_POOL_EXIT, Util.ACT_POOL_DIVE] and swimmer:
		var a = get_randomized_activity_manager(curr_action)
		if a and "Ladder" in a.name:
			Log.pr("here")
		return a
	
	var entry = activity_managers.get(curr_action)
	if typeof(entry) == TYPE_ARRAY:
		entry = entry[0]
	if entry is Dictionary:
		var path: NodePath = entry.node
		if not has_node(path):
			Log.pr("missing activityManager", path)
			return null
		return get_node(path)
	if entry is NodePath:
		if not has_node(entry):
			Log.pr("missing activityManager", entry)
			return null
		return get_node(entry)
	#Log.pr("missing activityManager", curr_action)
	return null

func get_randomized_activity_manager(act_key: String) -> ActivityManager:
	var options = activity_managers.get(act_key, [])
	if options.is_empty():
		Log.pr("missing activityManager keys", act_key)
		return null

	var prefer_a = []
	var prefer_b = []
	for opt in options:
		var node = get_node_or_null(opt.node)
		if node == null:
			Log.pr("node missing:", opt.name, opt.node)
			continue
		if "Stairs" in opt.name:
			prefer_a.append(node)
		elif "Ladder" in opt.name or "Jump" in opt.name:
			prefer_b.append(node)
	# 50/50
	if prefer_a.size() > 0 and (randf() < 0.5 or prefer_b.size() == 0):
		return prefer_a[randi() % prefer_a.size()]
	elif prefer_b.size() > 0:
		return prefer_b[randi() % prefer_b.size()]
	Log.pr("missing suitable ActivityManager for", act_key)
	return null

@export var wander_areas := {
	Util.WANDER_POOL: NodePath("PoolSide"),
}

func get_action_wander_area(curr_action):
	if wander_areas.has(curr_action):
		return get_node_or_null(wander_areas.get(curr_action))
	return null

## Clock
func _update_hands(hour_offset: float):
	var total_hours = day_end_hour - day_start_hour # Should be 6 for 9am–3pm
	var hour_angle = -90 + hour_offset * 180
	hour_hand.rotation_degrees = hour_angle

	var minute_angle = fmod(hour_offset * 360.0 * total_hours, 360.0)
	minute_hand.rotation_degrees = minute_angle

func _check_time_of_day_triggers(hr:int):
	if hr != next_state_hour and hr in TOD_HOURS:
		_show_time_icon(TOD_HOURS[hr])
		# Find next TOD phase
		var next_index = tod_states.find(TOD_HOURS[hr]) + 1
		next_state_hour = int(tod_states[next_index]) if next_index < tod_states.size() else 999 # Avoid re-trigger

func _show_time_icon(state:String):
	match state:
		"morning": time_icon.texture = preload("res://assets/icons1.png")
		"noon": time_icon.texture = preload("res://assets/icons2.png")
		"afternoon": time_icon.texture = preload("res://assets/icons3.png")
		"closing": time_icon.texture = preload("res://assets/icons4.png")
	time_icon.modulate = Color(1,1,1,1)
	time_icon.global_position.y =  $PoolUI/ClockContainer.position.y - 60 # tweak for float-up start position
	#animation_player.play("float_fade") # assumes you set keyframes: floats up & fades out for 1 sec


var money := 0
@onready var money_label := $PoolUI/MoneyContainer/MoneyLabel
@onready var guest_label = $PoolUI/GuestContainer/GuestLabel
@onready var anim_player = $PoolUI/MoneyContainer/AnimationPlayer

func change_money(amount: int):
	money += amount
	update_money_label()

func update_money_label():
	money_label.text = "$" + str(money)
	anim_player.play("money_change")

func update_swimmer_count():
	guest_label.text = "%d" % swimmers_in_scene.size()
