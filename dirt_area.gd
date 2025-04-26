extends Area2D

var cleaning_tween: Tween = null

func _ready():
	self.add_to_group("clean")

func start_clean():
	if cleaning_tween: return # Already cleaning
	cleaning_tween = create_tween()
	cleaning_tween.tween_property(self, "modulate", Color(1,1,1,0), 0.7)
	cleaning_tween.finished.connect(_on_cleaned)

func _on_cleaned():
	hide() # Or queue_free(), or emit a "cleaned" signal
	queue_free()
