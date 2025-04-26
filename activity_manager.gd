class_name ActivityManager extends Node2D

@export var max_slots := 1
var occupied_slots := []
var queue:Array[Swimmer] = []

func request_slot(swimmer: Swimmer):
	if occupied_slots.size() < max_slots:
		occupied_slots.append(swimmer)
		return true
	else:
		if swimmer not in queue:
			queue.append(swimmer)
		return false

func release_slot(swimmer: Swimmer):
	if swimmer in occupied_slots:
		occupied_slots.erase(swimmer)
		if queue.size() > 0:
			var next:Swimmer = queue.pop_front()
			occupied_slots.append(next)
			next.in_line = false
			next.on_granted_slot(global_position_for_queue_position(occupied_slots.size() - 1))
		# Cascade everyone in the queue forward
			for i in queue.size():
				var queued_swimmer = queue[i]
				var new_pos = global_position_for_queue_position(i)
				queued_swimmer.on_assigned_queue_position(new_pos)

func global_position_for_queue_position(idx:int) -> Vector2:
	return global_position + Vector2(-60, 0) * (idx + 1) # Tweak as needed for a lineup
