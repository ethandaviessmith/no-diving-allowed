class_name Pool
extends Node2D

@export var max_swimmers := 18
@export var swimmer_scene: PackedScene
@export var entrance_point: Node2D
@export var spawn_rate: float = 1.8
@export var day_start_hour := 9
@export var day_end_hour := 15
@export var day_duration_secs := 120.0
@export var endless_days := true

@onready var pool_area: Area2D = $Pool
@onready var pool_swimmers: Node2D = $PoolSwimmers
@onready var pool_dirt: Node2D = $PoolDirt

@onready var hour_hand = $PoolUI/ClockContainer/HourHand
@onready var minute_hand = $PoolUI/ClockContainer/MinuteHand
@onready var time_icon = $PoolUI/ClockContainer/TimeIcon
@onready var animation_player = $PoolUI/ClockContainer/TimeIcon/AnimationPlayer
@onready var clock_center: Vector2 = $PoolUI/ClockContainer.position
var current_hour := day_start_hour
var current_minute := 0.0
var clock_time := 0.0
var tod_phase: int = 0
var tod_states = ["morning", "noon", "afternoon", "closing"]
var TOD_HOURS = {9: tod_states[0], 11: tod_states[1], 13: tod_states[2], 15: tod_states[3]}
var next_state_hour := 9
var clock_radius := 70.0

@onready var money_label := $PoolUI/MoneyContainer/MoneyLabel
@onready var guest_label := $PoolUI/GuestContainer/GuestLabel
@onready var rule_label  := $PoolUI/RuleContainer/RuleLabel
@onready var money_anim_player := $PoolUI/MoneyContainer/AnimationPlayer


const ClipboardSummaryScene = preload("res://clipboard_summary.tscn")
var clipboard_summary: CanvasLayer

var swimmers_in_scene: Array = []
var spawn_timer: float = 0.0
var spawn_variation_strength := 1.0
var spawn_period := 10.0

var day := 0
var debt := 1000
var debt_paid := 0
var min_admission = 4.0
var money := 0
var rule_break_count: int = 0

@export var activity_managers := {
	Util.ACT_ENTRANCE: NodePath("Entrance/ActivityManager"),
	Util.ACT_LOCKER: NodePath("Locker/ActivityManager"),
	Util.ACT_SHOWER: NodePath("Shower/ActivityManager"),
	Util.ACT_SUNBATHE: NodePath("Lounger/ActivityManager"),
	Util.ACT_EXIT: NodePath("Exit/ActivityManager"),
	Util.ACT_POOL_LAPS: NodePath("PoolLaps/ActivityManager"),
	Util.ACT_POOL_SWIM: NodePath("PoolSwim/ActivityManager"),
	Util.ACT_POOL_PLAY: NodePath("PoolPlay/ActivityManager"),
	Util.ACT_POOL_DROWN: NodePath("PoolDrown/ActivityManager"),
	Util.ACT_SLIP: NodePath("Slip/ActivityManager"),
	Util.ACT_POOL_ENTER: [
		{name = "PoolStairs", node = NodePath("PoolStairsIn/ActivityManager")},
		{name = "PoolJump1", node = NodePath("PoolJump1/ActivityManager")},
		{name = "PoolJump2", node = NodePath("PoolJump2/ActivityManager")}
	],
	Util.ACT_POOL_EXIT: [
		{name = "PoolStairs", node = NodePath("PoolStairsOut/ActivityManager")},
		{name = "PoolLadder1", node = NodePath("PoolLadder1/ActivityManager")},
		{name = "PoolLadder2", node = NodePath("PoolLadder2/ActivityManager")}
	],
	Util.ACT_POOL_DIVE: [
		{name = "PoolJump1", node = NodePath("PoolJump1/ActivityManager")},
		{name = "PoolJump2", node = NodePath("PoolJump2/ActivityManager")}
	],
}

@export var wander_areas := {Util.WANDER_POOL: NodePath("PoolSide")}

func _ready():
	for swimmer in get_tree().get_nodes_in_group("swimmer"):
		if swimmer is Swimmer:
			swimmer.set_pool(self, swimmer.schedule)
			add_swimmer_to_scene(swimmer)
	start_new_day()

func start_new_day():
	get_tree().paused = false
	day += 1
	_show_time_icon("morning")
	_update_hands(0.0)
	clock_time = 0.0
	tod_phase = 0
	next_state_hour = int(tod_states[1])
	update_money_label()

func _process(delta):
	spawn_timer += delta
	if spawn_timer > spawn_rate and swimmers_in_scene.size() < max_swimmers:
		add_swimmer()
		spawn_timer = 0
	if spawn_timer > get_elastic_spawn_rate() and swimmers_in_scene.size() < max_swimmers:
		spawn_timer = 0.0
		add_swimmer()
	clock_time += delta * ((day_end_hour - day_start_hour) * 60) / day_duration_secs
	var hour_offset = clamp(clock_time / ((day_end_hour - day_start_hour) * 60), 0, 1)
	current_hour = day_start_hour + int(hour_offset * (day_end_hour - day_start_hour))
	current_minute = fmod((hour_offset * (day_end_hour - day_start_hour) * 60), 60)
	_update_hands(hour_offset)
	_check_time_of_day_triggers(current_hour)

func add_swimmer_to_scene(swimmer):
	swimmers_in_scene.append(swimmer)
	swimmer.connect("rule_broken", Callable(self, "_on_swimmer_rule_broken"))

func _on_swimmer_rule_broken(swimmer, amount):
	increment_rule_break_count(amount)

func increment_rule_break_count(amount: int = 1):
	rule_break_count += amount
	rule_label.text = str(rule_break_count)

func get_elastic_spawn_rate() -> float:
	var t := Time.get_unix_time_from_system()
	var t_mod := float(int(t) % int(spawn_period))
	var phase := t_mod / spawn_period
	var variance := sin(phase * TAU) * spawn_variation_strength
	return max(0.5, spawn_rate + variance)

func add_swimmer():
	var swimmer: Swimmer = swimmer_scene.instantiate()
	pool_swimmers.add_child(swimmer)
	swimmer.global_position = entrance_point.global_position
	add_swimmer_to_scene(swimmer)
	swimmer.set_pool(self, Util.get_schedule_enter(swimmer))
	update_swimmer_count()

func on_swimmer_left_pool(swimmer):
	var mood_rank = swimmer.get_mood_rank()
	var max_tip = 10.0
	var donation = round(lerp(min_admission, max_tip * randf(), mood_rank))
	change_money(donation)
	swimmers_in_scene.erase(swimmer)
	update_swimmer_count()

func getActivityManager(curr_action: String, swimmer: Node = null) -> ActivityManager:
	if curr_action in [Util.ACT_POOL_ENTER, Util.ACT_POOL_EXIT, Util.ACT_POOL_DIVE] and swimmer:
		return get_randomized_activity_manager(curr_action)
	var entry = activity_managers.get(curr_action)
	if typeof(entry) == TYPE_ARRAY:
		entry = entry[0]
	if entry is Dictionary:
		var path: NodePath = entry.node
		if not has_node(path):
			return null
		return get_node(path)
	if entry is NodePath:
		if not has_node(entry):
			return null
		return get_node(entry)
	return null

func get_randomized_activity_manager(act_key: String) -> ActivityManager:
	var options = activity_managers.get(act_key, [])
	if options.is_empty():
		return null
	var prefer_a = []
	var prefer_b = []
	for opt in options:
		var node = get_node_or_null(opt.node)
		if node == null:
			continue
		if "Stairs" in opt.name:
			prefer_a.append(node)
		elif "Ladder" in opt.name or "Jump" in opt.name:
			prefer_b.append(node)
	if prefer_a.size() > 0 and (randf() < 0.5 or prefer_b.size() == 0):
		return prefer_a[randi() % prefer_a.size()]
	elif prefer_b.size() > 0:
		return prefer_b[randi() % prefer_b.size()]
	return null

func get_action_wander_area(curr_action):
	if wander_areas.has(curr_action):
		return get_node_or_null(wander_areas.get(curr_action))
	return null

func _show_time_icon(state: String):
	var hour = int(current_hour)
	var hour_index = hour - day_start_hour
	var total_hours = day_end_hour - day_start_hour
	var angle_per_hour = PI / (total_hours - 1)
	var angle = PI + hour_index * angle_per_hour
	var icon_offset = Vector2(cos(angle), sin(angle)) * clock_radius
	time_icon.global_position = clock_center + icon_offset
	match state:
		"morning":   time_icon.texture = preload("res://assets/icons1.png")
		"noon":      time_icon.texture = preload("res://assets/icons2.png")
		"afternoon": time_icon.texture = preload("res://assets/icons3.png")
		"closing":   time_icon.texture = preload("res://assets/icons4.png")
	time_icon.modulate = Color(1, 1, 1, 1)

func _update_hands(hour_offset: float):
	var total_hours = day_end_hour - day_start_hour
	var hour_angle = -90 + hour_offset * 180
	hour_hand.rotation_degrees = hour_angle
	var minute_angle = fmod(hour_offset * 360.0 * total_hours, 360.0)
	minute_hand.rotation_degrees = minute_angle

func _check_time_of_day_triggers(hr: int):
	if hr != next_state_hour and hr in TOD_HOURS:
		_show_time_icon(TOD_HOURS[hr])
		var next_index = tod_states.find(TOD_HOURS[hr]) + 1
		next_state_hour = int(tod_states[next_index]) if next_index < tod_states.size() else 999

		if not endless_days and TOD_HOURS[hr] == "closing":
			set_end_of_day()

		  
func change_money(amount: int):
	money += amount
	update_money_label()

func update_money_label():
	money_label.text = "$" + str(money)
	money_anim_player.play("money_change")

func update_swimmer_count():
	guest_label.text = "%d" % swimmers_in_scene.size()

func set_end_of_day():
	var stats = {
		"day": day,
		"earnings": money,
		"debt_paid": debt_paid,
		"debt_total": debt,
		"incidents": rule_break_count,
		"warned": 0,
		"messes": 0,
		"rating": 4,
		"comment": "Crowd was happy!"
	}
	show_end_of_day_summary(stats)

func show_end_of_day_summary(stats: Dictionary):
	if clipboard_summary:
		clipboard_summary.queue_free()
	clipboard_summary = ClipboardSummaryScene.instantiate()
	add_child(clipboard_summary)
	clipboard_summary.setup(
		stats.day,
		stats.earnings,
		stats.debt_paid,
		stats.debt_total,
		stats.incidents,
		stats.warned,
		stats.messes,
		stats.rating,
		stats.comment
	)
	clipboard_summary.next_day.connect(start_new_day)
	clipboard_summary.show()
	Log.pr("temp removing swimmers for simplicity")
	for swimmer in get_tree().get_nodes_in_group("swimmer"):
		if swimmer is Swimmer:
			on_swimmer_left_pool(swimmer)
			swimmer.remove_from_pool()
	get_tree().paused = true
