class_name Pool extends Node2D

@export var max_guests := 8
var guests := 0
@onready var poolArea2D:Area2D = $Pool

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
@export var spawn_rate: float = 1.8
var spawn_variation_strength := 1.0
var spawn_period := 10.0

func _ready():
	for swimmer in get_tree().get_nodes_in_group("swimmer"):
		# OR if placing as direct children:
		# for swimmer in get_children():
		if swimmer is Swimmer:
			swimmer.set_pool(self, swimmer.schedule)

func _process(delta):
	# Periodically try to add a new swimmer
	spawn_timer += delta
	if spawn_timer > spawn_rate and swimmers_in_scene.size() < max_swimmers:
		add_swimmer()
		spawn_timer = 0
	if spawn_timer > get_elastic_spawn_rate() and swimmers_in_scene.size() < max_swimmers:
		spawn_timer = 0.0
		add_swimmer()
		
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
	get_parent().add_child(swimmer)
	swimmer.global_position = entrance_point.global_position
	swimmers_in_scene.append(swimmer)
	swimmer.set_pool(self, Util.make_swim_schedule())

func on_swimmer_left_pool(swimmer):
	swimmers_in_scene.erase(swimmer)
	swimmer.queue_free() # Or pool for reuse (object pooling)


@export var swim_managers = [Util.ACT_LAPS, Util.ACT_PLAY,Util.ACT_SWIM]
func getActivityManager(curr_action) -> ActivityManager:
	
	if swim_managers.has(curr_action):
		pass
	
	var act_mng:ActivityManager = get_node_or_null("/root/Pool/" + curr_action + "/ActivityManager")
	
	return act_mng
	
