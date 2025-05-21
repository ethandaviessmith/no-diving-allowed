class_name MoodComponent extends Node

enum Mood { GREAT, GOOD, BAD, ISSUE }
enum Misbehave { BAD, RUN, TRASH, SPLASH, SLEEP, DIVE }

@export var bar_happy: TextureProgressBar
@export var bar_energy: TextureProgressBar
@export var bar_safety: TextureProgressBar
@export var bar_clean: TextureProgressBar
@export var bar_mood: ColorRect
@export var mood_icon_stack: Node
@export var mood_color_great: Color
@export var mood_color_good: Color
@export var mood_color_bad: Color
@export var mood_color_issue: Color

signal mood_changed(new_mood)
signal misbehaved(type)
signal misbehave_removed(type)

var happy: float = 1.0
var energy: float = 10.0
var safety: float = 1.0
var clean: float = 1.0

var max_happy: float = 1.0
var max_energy: float = 10.0
var max_safety: float = 1.0
var max_clean: float = 1.0

var mood: int = Mood.GOOD

var misbehaves := {}

const MISBEHAVE_DURATION: float = 8.0
const MISBEHAVE_ICONS = {
	Misbehave.BAD:    preload("res://assets/icons5.png"),
	Misbehave.RUN:    preload("res://assets/icons6.png"),
	Misbehave.TRASH:  preload("res://assets/icons7.png"),
	Misbehave.SPLASH: preload("res://assets/icons8.png"),
	Misbehave.SLEEP:  preload("res://assets/icons9.png"),
	Misbehave.DIVE:   preload("res://assets/icons10.png"),
}
const MISBEHAVE_ICON_OFFSET := Vector2(16, 0)

func _ready():
	update_all_bars()
	update_mood_bar_color()

func update_mood():
	var last_mood = mood
	if happy > 0.8 and energy > 7.5 and safety > 0.6 and clean > 0.5:
		mood = Mood.GREAT
	elif happy > 0.5 and energy > 5.0 and safety > 0.45 and clean > 0.4:
		mood = Mood.GOOD
	elif happy < 0.25 or energy < 2.0 or safety < 0.3:
		mood = Mood.BAD
	else:
		mood = Mood.ISSUE
	update_mood_bar_color()
	update_all_bars()
	if mood != last_mood:
		emit_signal("mood_changed", mood)

func update_all_bars():
	if bar_happy: Util.set_mood_progress(bar_happy, happy, max_happy)
	if bar_energy: Util.set_mood_progress(bar_energy, energy, max_energy)
	if bar_safety: Util.set_mood_progress(bar_safety, safety, max_safety)
	if bar_clean: Util.set_mood_progress(bar_clean, clean, max_clean)

func update_mood_bar_color():
	if not bar_happy: return
	match mood:
		Mood.GREAT: bar_mood.color = mood_color_great
		Mood.GOOD:  bar_mood.color = mood_color_good
		Mood.BAD:   bar_mood.color = mood_color_bad
		Mood.ISSUE: bar_mood.color = mood_color_issue

func change_happy(amount: float):
	happy = clamp(happy + amount, 0.0, max_happy)
	update_mood()

func change_energy(amount: float):
	energy = clamp(energy + amount, 0.0, max_energy)
	update_mood()


func change_safety(amount: float):
	safety = clamp(safety + amount, 0.0, max_safety)
	update_mood()

func change_clean(amount: float, target_activity: ActivityManager = null):
	var ratio := 1.0
	if target_activity and "get_clean_ratio" in target_activity:
		var clean_ratio = target_activity.get_clean_ratio()
		if amount > 0: ratio = lerp(0.5, 1.5, clean_ratio)
		else: ratio = lerp(1.5, 0.5, clean_ratio)
	clean = clamp(clean + amount * ratio, 0.0, 1.0)
	if clean == max_clean:
		remove_misbehave(MoodComponent.Misbehave.TRASH)

func get_mood_rank() -> float:
	return happy + energy / max_energy + safety + clean


func add_misbehave(type: Misbehave):
	var now = Time.get_ticks_msec() / 1000.0
	# Only add if not present or if more than 10 seconds have passed
	if not misbehaves.has(type) or (now - misbehaves[type]) > 10.0:
		misbehaves[type] = now
		var icon = Sprite2D.new()
		icon.texture = MISBEHAVE_ICONS[type]
		icon.name = str(type)
		icon.position.x = mood_icon_stack.get_child_count() * MISBEHAVE_ICON_OFFSET.x
		mood_icon_stack.add_child(icon)
		emit_signal("misbehaved", type)

func remove_misbehave(type: Misbehave):
	if misbehaves.has(type):
		misbehaves.erase(type)
		var icon = mood_icon_stack.get_node_or_null(str(type))
		if icon: icon.queue_free()
		emit_signal("misbehave_removed", type)

func has_misbehave(type: Misbehave) -> bool:
	return misbehaves.has(type)

func process_misbehaves():
	var now = Time.get_ticks_msec() / 1000.0
	for type in misbehaves.keys():
		if now - misbehaves[type] > MISBEHAVE_DURATION:
			remove_misbehave(type)
			
func start_removing_misbehave_icons():
	for icon in mood_icon_stack.get_children():
		_animate_icon_removal(icon)

func _animate_icon_removal(icon: Sprite2D):
	# Change icon to green
	icon.modulate = Color(0.2, 1.0, 0.2) # or use a green icon if you want
	# Animate: float up & fade out
	var tween = get_tree().create_tween()
	tween.tween_property(icon, "position", icon.position + Vector2(0, -40), 0.8)
	tween.tween_property(icon, "modulate:a", 0.0, 0.8)
	tween.tween_callback(Callable(icon, "queue_free"))
