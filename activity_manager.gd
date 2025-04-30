class_name ActivityManager extends Node2D

@export var line_positions: NodePath    
@onready var line_nodes: Array[Node2D] = []
@export var activity_position_path: NodePath 
@onready var activity_positions: Array[Node2D] = []
var current_swimmers: Array[Swimmer] = []
var line_queue: Array = []

@export var wander_area: NodePath
@onready var wander_area_ref: Area2D

func _ready():
	if line_positions != NodePath():
		var node = get_node_or_null(line_positions)
		if node:
			if node.get_child_count() > 0:
				line_nodes.append_array(node.get_children())
			else:
				line_nodes.append(node)
	# Support multiple activity positions if needed
	if activity_position_path != NodePath():
		var node = get_node_or_null(activity_position_path)
		if node:
			if node.get_child_count() > 0:
				activity_positions.append_array(node.get_children())
			else:
				activity_positions.append(node)
				
	current_swimmers.resize(activity_positions.size())
	for i in current_swimmers.size():
		current_swimmers[i] = null
	if wander_area != NodePath():
		wander_area_ref = get_node_or_null(wander_area)

func has_open_direct_slot() -> bool:
	return current_swimmers.size() < activity_positions.size() + 1

func has_available_line_position() -> bool:
	return line_nodes.size() > 0 and line_queue.size() < line_nodes.size()

func try_queue_swimmer(swimmer) -> bool:
	for i in current_swimmers.size():
		if current_swimmers[i] == null:
			current_swimmers[i] = swimmer
			swimmer.target_activity = self
			swimmer.begin_approach_to_activity(self)
			return true

	if has_available_line_position():
		line_queue.append(swimmer)
		swimmer.get_in_line(line_nodes[line_queue.size() - 1].global_position)
	else:
		swimmer.state = swimmer.State.WANDERING
		send_swimmer_to_wander(swimmer)
	return false

func send_swimmer_to_wander(swimmer):
	if wander_area_ref:
		swimmer._setup_wander_and_go_with_area(wander_area_ref)
	else:
		Log.pr("Missing Wander Area", name)
		pass #swimmer._setup_wander_and_go(swimmer.curr_action)


func assign_swimmer_to_slot(swimmer:Swimmer) -> int:
	for i in current_swimmers.size():
		if current_swimmers[i] == null:
			current_swimmers[i] = swimmer
			return i
	return -1 # No free slot

func release_swimmer_from_slot(swimmer:Swimmer):
	for i in current_swimmers.size():
		if current_swimmers[i] == swimmer:
			current_swimmers[i] = null
			break

func get_interaction_pos(swimmer:Swimmer) -> Vector2:
	if activity_positions.size() > 1:
		for i in current_swimmers.size():
			if current_swimmers[i] == swimmer:
				return activity_positions[i].global_position
	return global_position # Default/fallback


func notify_done(swimmer: Swimmer) -> void:
	release_swimmer_from_slot(swimmer)
	_process_next_in_line()

func _process_next_in_line() -> void:
	if line_queue.is_empty():
		return
	for i in current_swimmers.size():
		if current_swimmers[i] == null:
			var swimmer = line_queue.pop_front()
			current_swimmers[i] = swimmer
			swimmer.try_leave_line_and_use_activity(self)
			_cascade_line_queue()
			break # Only fill one free slot per call

func _cascade_line_queue():
	# Moves line_queue swimmers forward as far as possible through open positions
	for i in range(line_queue.size()):
		if i < line_nodes.size():
			line_queue[i].get_in_line(line_nodes[i].global_position)
