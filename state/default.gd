@icon("res://addons/simple-state/icons/state_machine_debugger.png")
class_name StateMachine
extends State

@onready var swimmer := owner# as Swimmer
var state_class_to_mapping = {}

func _ready():
	state_class_to_mapping = build_state_mapping()
	super._ready()

func build_state_mapping() -> Dictionary:
	var mapping = {}
	for state_node in get_children():
		# Map by node name
		mapping[state_node.name] = [state_node.name, null]
		# Map by class_name
		var state_class = state_node.get_class()
		if state_class != "GDScript":
			mapping[state_class] = [state_node.name, null]

		# Substates
		for substate in state_node.get_children():
			mapping[substate.name] = [state_node.name, substate.name]
			var sub_class = substate.get_class()
			if sub_class != "GDScript":
				mapping[sub_class] = [state_node.name, substate.name]
	return mapping

func _enter() -> void:
	if debug_mode:
		print("State machine enter default")

func _update(delta: float) -> void:
	pass

func _before_exit() -> void:
	if debug_mode:
		print("Exiting default")
