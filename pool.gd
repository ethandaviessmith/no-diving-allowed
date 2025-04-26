extends Node2D

@export var max_guests := 8
var guests := 0

func _on_spawn_timer_timeout():
	if guests < max_guests: # Capacity Check
		spawn_guest()

func spawn_guest():
	var s = preload("res://swimmer.tscn").instantiate()
	s.global_position = $EntranceArea.global_position
	add_child(s)
	guests += 1
	s.connect("ready_to_leave", Callable(self, "_on_guest_leave").bind(s))

func _on_guest_leave(swimmer):
	# animate out etc
	guests -= 1
	swimmer.queue_free()
	# Spawn new only if >1min left - example using another Timer
	if $GameTimer.time_left > 60:
		spawn_guest()


var base_payment = 10
#var tip = int(base_payment * swimmer.mood)
#add_money(tip)


@export var swimmer_scene: PackedScene
@export var entrance_point: Node2D
@export var exit_point: Node2D
@export var max_swimmers := 12

var swimmers_in_scene: Array = []
var spawn_timer: float = 0.0
@export var spawn_rate: float = 3.0 # seconds

func _process(delta):
	# Periodically try to add a new swimmer
	spawn_timer += delta
	if spawn_timer > spawn_rate and swimmers_in_scene.size() < max_swimmers:
		add_swimmer()
		spawn_timer = 0

func add_swimmer():
	var swimmer = swimmer_scene.instantiate()
	get_parent().add_child(swimmer)
	swimmer.global_position = entrance_point.global_position
	swimmers_in_scene.append(swimmer)
	swimmer.schedule = make_swim_schedule()
	swimmer.left_pool.connect(_on_swimmer_left_pool.bind(swimmer))

func _on_swimmer_left_pool(swimmer):
	swimmers_in_scene.erase(swimmer)
	swimmer.queue_free() # Or pool for reuse (object pooling)
	
func make_swim_schedule() -> Array:
	var schedule = Util.POOL_ENTER
	var activities = Util.POOL_ACTIVITIES.duplicate()
	activities.shuffle()
	
	for i in range(randi() % 2 + 1):
		schedule.append(activities[i])

	schedule.append_array(Util.POOL_EXIT)
	return schedule
