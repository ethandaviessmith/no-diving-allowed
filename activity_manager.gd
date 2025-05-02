class_name ActivityManager extends Node2D

@export var line_positions: NodePath    
@export var activity_position_path: NodePath 
@export var activity_areas_path: NodePath
@export var activity_paths_path: NodePath
@export var wander_area: NodePath

@onready var wander_area_ref: Node = null
@onready var line_nodes: Array = []
@onready var activity_positions: Array = []
var current_swimmers: Array[Swimmer] = []
var line_queue: Array = []




func _ready():
	line_nodes = nodes_from_path(line_positions)
	activity_positions = nodes_from_path(activity_areas_path)
	if activity_positions.is_empty():
		activity_positions = nodes_from_path(activity_paths_path)
	if activity_positions.is_empty():
		activity_positions = nodes_from_path(activity_position_path)
	
	current_swimmers.resize(activity_positions.size())
	for i in current_swimmers.size():
		current_swimmers[i] = null
	if wander_area != NodePath():
		wander_area_ref = get_node_or_null(wander_area)


func nodes_from_path(path: NodePath) -> Array:
	var result: Array = []
	if path != NodePath():
		var node = get_node_or_null(path)
		if node:
			if node.get_child_count() > 0:
				result.append_array(node.get_children())
			else:
				result.append(node)
	return result

func has_open_direct_slot() -> bool:
	return current_swimmers.size() < activity_positions.size() + 1

func has_available_line_position() -> bool:
	return line_nodes.size() > 0 and line_queue.size() < line_nodes.size()

#func try_queue_swimmer(swimmer: Swimmer) -> bool:
	#for i in current_swimmers.size():
		#if current_swimmers[i] == null:
			#current_swimmers[i] = swimmer
			#swimmer.target_activity = self
			#swimmer.begin_approach_to_activity(self)
			#return true

func try_queue_swimmer(swimmer):
	for i in activity_positions.size():
		var node = activity_positions[i]
		if node is Path2D:
			# Path2D lane: assign only if free
			var path_follow = node.get_child(0) if node.get_child_count() > 0 else null
			if path_follow and current_swimmers[i] == null:
				current_swimmers[i] = swimmer
				swimmer_attach_to_path(swimmer, path_follow)
				return true
		else:
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

func swimmer_attach_to_path(swimmer, path_follow: PathFollow2D) -> void:
	swimmer.path_follow = path_follow           # Keep a reference for back-and-forth logic
	swimmer.path_direction = 1                  # 1:right/forward, -1:left/back
	# Put swimmer at path start
	path_follow.progress_ratio = 0.0
	# Optionally parent the swimmer under path_follow, or update position manually
	swimmer.global_position = path_follow.global_position
	swimmer.start_lap_movement() # Let join logic trigger movement state




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
