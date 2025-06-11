extends CanvasLayer

@export var day_label: Label
@export var earnings_value: Label
@export var debt_paid_value: Label
@export var debt_bar: ProgressBar
@export var incidents_value: Label
@export var warned_value: Label
@export var messes_value: Label
@export var stars_label: Label
@export var comment_label: Label
@export var next_day_button: Button


signal next_day

	
func _ready():
	next_day_button.pressed.connect(_on_next_day_pressed)

func setup(day: int, earnings: int, debt_paid: int, debt_total: int, incidents: int, warned: int, messes: int, rating: int, comment: String):
	day_label.text = "Day %d Complete" % day
	earnings_value.text = "$%d" % earnings
	debt_paid_value.text = "$%d / $%d" % [debt_paid, debt_total]
	debt_bar.value = float(debt_paid) / float(debt_total) * 100.0 if debt_total > 0 else 0
	incidents_value.text = str(incidents)
	warned_value.text = str(warned)
	messes_value.text = str(messes)
	stars_label.text = "★".repeat(rating) + "☆".repeat(5 - rating)
	comment_label.text = '"%s"' % comment

func _on_next_day_pressed():
	next_day.emit()
	queue_free()
