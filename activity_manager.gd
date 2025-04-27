class_name ActivityManager extends Node2D

@export var line_positions: Array[NodePath]      # Assign Position2D/Node2D nodes for line slots in Inspector
@export var activity_position_path: NodePath     # Interaction/perform position node Path
@export var slot_count: int = 1                  # How many simultaneous swimmers can use this (default 1)

@onready var line_nodes: Array[Node2D] = []
@onready var activity_positions: Array[Node2D] = []
var current_swimmers: Array = []
var line_queue: Array = []

func _ready():
	for path in line_positions:
		var n = get_node_or_null(path)
		if n: line_nodes.append(n)
	# Support multiple activity positions if needed
	if activity_position_path != NodePath():
		var node = get_node_or_null(activity_position_path)
		if node: activity_positions.append(node)

func has_open_direct_slot() -> bool:
	return current_swimmers.size() < slot_count

func has_available_line_position() -> bool:
	return line_nodes.size() > 0 and line_queue.size() < line_nodes.size()

# Approach & slot logic
func try_queue_swimmer(swimmer) -> bool:
	# Priority: fill direct slots if possible
	if has_open_direct_slot():
		current_swimmers.append(swimmer)
		swimmer.target_activity = self
		swimmer.curr_action = null # so current matches
		# Always go to unique activity pos if provided, else fall back to self.global_position
		swimmer._begin_approach_to_activity(self)
		return true

	# Otherwise: queue if space
	if has_available_line_position():
		line_queue.append(swimmer)
		swimmer.get_in_line(line_nodes[line_queue.size() - 1].global_position)
	else:
		# Otherwise: instruct to wander
		swimmer.state = swimmer.State.WANDERING
		swimmer._setup_wander_and_go(swimmer.curr_action)
	return false

func get_interaction_pos() -> Vector2:
	if activity_positions.size() > 0:
		return activity_positions[min(current_swimmers.size(), activity_positions.size() - 1)].global_position
	return global_position

func notify_done(swimmer):
	# Swimmer finished their activity/action: remove them from slot, promote line.
	current_swimmers.erase(swimmer)
	_process_next_in_line()

func _process_next_in_line():
	if has_open_direct_slot() and line_queue.size() > 0:
		var next_swimmer = line_queue.pop_front()
		current_swimmers.append(next_swimmer)
		next_swimmer.try_leave_line_and_use_activity(self)
		_cascade_line_queue()

func _cascade_line_queue():
	# Moves line_queue swimmers forward as far as possible through open positions
	for i in range(line_queue.size()):
		if i < line_nodes.size():
			line_queue[i].get_in_line(line_nodes[i].global_position)
