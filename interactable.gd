extends Area2D

signal resolved

func interact():
	modulate = Color.GREEN
	resolved.emit()
	# after short cooldown, can enable again if wanted
