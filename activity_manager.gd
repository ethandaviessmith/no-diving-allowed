class_name ActivityManager extends Node2D

@export var line_positions: NodePath    
@export var activity_position_path: NodePath 
@export var activity_areas_path: NodePath
@export var activity_paths_path: NodePath
@export var wander_area: Area2D

@onready var line_nodes: Array = []
@onready var activity_positions: Array = []
var current_swimmers: Array[Swimmer] = []
var line_queue: Array = []

@export var bar_clean_path: NodePath
var bar_clean: TextureProgressBar

@export var clean_tick: float = 0.0  # getting dirty is off by default
@export var max_clean: float = 1.0
var clean: float = max_clean

@export var activity: Util.Anim = Util.Anim.NA
@export var finish_activity: Util.Anim = Util.Anim.NA
@export var prevent_move := false

func _process(delta):
	var was_clean = clean
	if is_being_used():
		if randf() < 0.05: # 5% chance per tick
			clean = max(0.0, clean - clean_tick)
	if clean != was_clean:
		update_clean_bar()

func get_clean_ratio() -> float:
	return clean / max_clean if max_clean > 0.0 else 1.0

func is_being_used() -> bool:
	for swimmer in current_swimmers:
		if swimmer != null and swimmer.state == Swimmer.State.ACT:
			return true
	return false
	
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
	if bar_clean_path:
		bar_clean = get_node_or_null(bar_clean_path)
		update_clean_bar()

func update_clean_bar():
	if bar_clean:
		Util.set_mood_progress(bar_clean, clean, max_clean)
		
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


func try_queue_swimmer(swimmer):
	# Random free activity slot
	var free_indices = []
	for i in activity_positions.size():
		if current_swimmers[i] == null:
			free_indices.append(i)
	# If there's a free spot: assign it
	if not free_indices.is_empty():
		var choice = free_indices[randi() % free_indices.size()]
		current_swimmers[choice] = swimmer
		swimmer.target_activity = self
		swimmer.begin_approach_to_activity(self)
		return true

	# Otherwise if line is available, use it
	if has_available_line_position():
		line_queue.append(swimmer)
		swimmer.get_in_line(line_nodes[line_queue.size() - 1].global_position)
		return true

	# Otherwise: send wandering
	swimmer.state = swimmer.State.WANDERING
	send_swimmer_to_wander(swimmer)
	return false

func get_activity_node(swimmer):
	for i in current_swimmers.size():
		if current_swimmers[i] == swimmer:
			return activity_positions[i]
	return null

func get_tween_target_for_swimmer(swimmer: Swimmer) -> Vector2:
	var node = get_activity_node(swimmer)
	if not node:
		return global_position
	if node.get_child_count() > 0:
		# Use the first child Node2D as target
		for child in node.get_children():
			if child is Node2D:
				return child.global_position
	# Fallback: current position node
	if node is Node2D:
		return node.global_position
	return node.global_position

func swimmer_attach_to_path(swimmer, path_follow: PathFollow2D) -> void:
	swimmer.path_follow = path_follow           # Keep a reference for back-and-forth logic
	swimmer.path_direction = 1                  # 1:right/forward, -1:left/back
	# Put swimmer at path start
	path_follow.progress_ratio = 0.0
	# Optionally parent the swimmer under path_follow, or update position manually
	swimmer.global_position = path_follow.global_position
	swimmer.start_lap_movement() # Let join logic trigger movement state

func send_swimmer_to_wander(swimmer):
	if wander_area:
		var count = randi_range(3, 6) if swimmer.mood.energy > 0.5 else randi_range(2, 4)
		swimmer._setup_wander_and_go_with_area(wander_area, count)
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
	if prevent_move: return swimmer.global_position
	
	# Only return lane if swimmer is in that slot
	for i in current_swimmers.size():
		if current_swimmers[i] == swimmer:
			var node = activity_positions[i]
			if node is Path2D:
				var path_follow = node.get_child(0) if node.get_child_count() > 0 else null
				if path_follow:
					return path_follow.global_position
			else:
				return node.global_position
	# If not assigned, and in line, go to currently assigned line position (optional):
	if line_queue.has(swimmer):
		var i = line_queue.find(swimmer)
		if i < line_nodes.size():
			return line_nodes[i].global_position
	return global_position # fallback


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

## Moves line_queue swimmers forward through open positions
func _cascade_line_queue():
	for i in range(line_queue.size()):
		if i < line_nodes.size():
			line_queue[i].get_in_line(line_nodes[i].global_position)

func clear_swimmer(swimmer):
	var idx = current_swimmers.find(swimmer)
	if idx != -1: current_swimmers[idx] = null
	idx = line_queue.find(swimmer)
	if idx != -1: line_queue[idx] = null
