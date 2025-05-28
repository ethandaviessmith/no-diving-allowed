extends Panel

@onready var reset_btn: Button = $ResetButton
@onready var slider: HSlider = $TimeScaleSlider
@onready var scale_label: Label = $TimeScaleLabel
@onready var toggle_labels_btn: Button = $ToggleLabelsButton

var _swimmer_labels_visible := true

func _ready():
	reset_btn.pressed.connect(_on_reset)
	slider.value = 1.0
	slider.value_changed.connect(_on_timescale_changed)
	toggle_labels_btn.pressed.connect(_on_toggle_swimmer_labels_pressed)
	position = Vector2(16, 16)
	_on_timescale_changed(slider.value)

func _on_reset():
	get_tree().reload_current_scene()

func _on_timescale_changed(value):
	Engine.time_scale = value
	scale_label.text = "%.1f" % value

func _on_toggle_swimmer_labels_pressed():
	_swimmer_labels_visible = not _swimmer_labels_visible
	for swimmer in get_tree().get_nodes_in_group("swimmer"):
		if swimmer.has_method("toggle_label"):
			swimmer.toggle_label(_swimmer_labels_visible)
