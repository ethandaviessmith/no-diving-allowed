class_name MoodComponent extends Node

enum Mood { GREAT, GOOD, BAD, ISSUE }
enum Misbehave { BAD, RUN, TRASH, SPLASH, SLEEP, DIVE, SLIP, DROWN }

enum PersonalityType { RANDOM, CHILD, ADULT, ATHLETE, LEISURE }
@export var personality_type: PersonalityType

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

var happy: float = 0.8
var energy: float = 10.0
var safety: float = 0.8
var clean: float = 0.8

var max_happy: float = 1.0
var max_energy: float = 10.0
var max_safety: float = 1.0
var max_clean: float = 1.0

var mood: int = Mood.GOOD
var misbehaves := {}

const MISBEHAVE_DURATION: float = 20.0
const MISBEHAVE_ICONS = {
	Misbehave.BAD:    preload("res://assets/icons5.png"),
	Misbehave.RUN:    preload("res://assets/icons6.png"),
	Misbehave.TRASH:  preload("res://assets/icons7.png"),
	Misbehave.SPLASH: preload("res://assets/icons8.png"),
	Misbehave.SLEEP:  preload("res://assets/icons9.png"),
	Misbehave.DIVE:   preload("res://assets/icons10.png"),
	Misbehave.SLIP:   preload("res://assets/icons23.png"),
	Misbehave.DROWN:  preload("res://assets/icons24.png"),
}
const MISBEHAVE_ICON_OFFSET := Vector2(32, 0)
const TIMER_INTERVAL := 2.5 # seconds - how often mood/autobehave logic runs

var tint:Color

func _ready():
	update_all_bars()
	update_mood_bar_color()
	_setup_mood_timer()
	
	# -- Subtle skin color modulate --
	# These ranges produce slightly varied, warm skin tones
	var base_color = Color(1, 0.90, 0.80, 1) # base light tan, RGBA
	var h = base_color.h + randf_range(-0.04, 0.04) # up to ~±7 deg hue shift
	var s = clamp(base_color.s + randf_range(-0.1, 0.08), 0.15, 0.40) # subtle sat change
	var v = clamp(base_color.v + randf_range(-0.07, 0.06), 0.85, 1.0) # very slight brightness
	tint = Color.from_hsv(h, s, v, 1.0)

func set_sprite(sprite: Sprite2D, frame):
	sprite.frame = frame
	if personality_type == PersonalityType.RANDOM:
		personality_type = PersonalityType.values()[randi() % PersonalityType.size()]
	if personality_type == PersonalityType.CHILD:
		sprite.scale.y = 0.7
		sprite.scale.x = 0.9
	elif personality_type == PersonalityType.ATHLETE:
		sprite.scale.x = 0.9
	elif personality_type == PersonalityType.LEISURE:
		sprite.scale.x = 1.1

	sprite.modulate = tint

func _setup_mood_timer():
	var timer := Timer.new()
	timer.name = "MoodTimer"
	timer.wait_time = TIMER_INTERVAL
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_mood_timer_timeout)

func _on_mood_timer_timeout():
	if not owner: return
	var swimmer:Swimmer = owner
	swimmer.call_update_mood() # calls mood_update with swimmer params
	process_misbehaves()

# == PER-INTERVAL MOOD EFFECTS ==
func mood_update(curr_action, state, is_swimming, in_puddle) -> void:
	var pf_child_athlete = _personality_factor([PersonalityType.CHILD, PersonalityType.ATHLETE], 0.2)
	var pf_child_leisure = _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.3)
	var amt_low = 0.13
	var amt_mid = 0.25
	var amt_high = 0.40
	if Util.is_state(state, Util.POOL_ENERGY):
		pass

	match state:
		Act:
			match curr_action:
				Util.ACT_SHOWER:
					change_clean(_personality_val(amt_low, [PersonalityType.CHILD]))
				Util.ACT_POOL_LAPS, Util.ACT_POOL_SWIM, Util.ACT_POOL_PLAY:
					change_energy(_personality_val(-amt_high, [], [PersonalityType.LEISURE]))
				Util.ACT_SUNBATHE:
					change_energy(amt_mid)
					change_happy(-amt_low)
			if randf() < 0.05 + pf_child_athlete:
				change_clean(_personality_val(-amt_low, [], [PersonalityType.CHILD, PersonalityType.ATHLETE]))
		InLine, Wandering:
			if randf() < 0.2 - pf_child_leisure:
				change_happy(-amt_low)
		Act, Approach:
			if randf() < 0.2 - pf_child_leisure:
				change_happy(amt_low)
			if randf() < 0.2:
				pass
	if randf() < 0.5:
		if in_puddle and not Util.is_state(state, InLine):
			change_safety(-0.2)
			SFX.play("puddle")
	else:
		change_safety(0.05)
		if safety == max_safety:
			if randf() < 0.5:
				pass

# == MISBEHAVE LOGIC ==
func try_misbehave(curr_action, state, is_swimming, in_puddle, is_running):
	if randf() > safety:
		if not owner: return
		var swimmer:Swimmer = owner
		#Log.pr("misbehave tick", swimmer.name)
		var pf_child_athlete = _personality_factor([PersonalityType.CHILD, PersonalityType.ATHLETE], 0.2)
		var pf_child_leisure = _personality_factor([PersonalityType.CHILD, PersonalityType.LEISURE], 0.3)
		if not is_swimming and Util.is_state(state, InLine):
			if randf() > clean + pf_child_athlete and randf() > 0.1 + pf_child_athlete:
				swimmer.throw_trash()
		elif not is_swimming and Util.is_state(state, [Idle, Approach, Wandering]):
			if randf() > clean + pf_child_athlete and randf() > 0.3 + pf_child_athlete:
				swimmer.throw_trash()
			elif randf() > 0.5 + pf_child_leisure:
				swimmer.toggle_run()
		elif is_swimming and curr_action != Util.ACT_POOL_LAPS:
			if  energy > 0.3 and randf() < energy:
				swimmer.start_drown()
			if randf() > 0.5 + pf_child_athlete:
				swimmer.splashplay()
			else:
				swimmer.horseplay()
			SFX.play("splash")
		elif curr_action == Util.ACT_SUNBATHE and Util.is_state(state, Act):
			if randf() > happy + pf_child_leisure and randf() > 0.7 + pf_child_leisure:
				swimmer.fall_asleep()
		if in_puddle and is_running:
			swimmer.start_slip()
	update_mood()

# == UTILS FOR PERSONALITY ==
func _personality_factor(types:Array = [], base:float = 0.0) -> float:
	return base if personality_type in types else 0.0

func _personality_val(amt:float, less:Array[PersonalityType] = [], more:Array[PersonalityType] = []) -> float:
	if personality_type in less:
		return amt * 0.5
	if personality_type in more:
		return amt * 1.5
	return amt


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
	Log.pr("happy", happy, amount)
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
		remove_misbehave(Misbehave.TRASH)
	update_mood()

func get_mood_rank() -> float:
	return happy + energy / max_energy + safety + clean

func add_misbehave(type: Misbehave):
	var now = Time.get_ticks_msec() / 1000.0
	if not misbehaves.has(type) or (now - misbehaves[type]) > 10.0:
		misbehaves[type] = now
		_add_misbehave_icon(type)
		emit_signal("misbehaved", type)

func remove_misbehave(type: Misbehave):
	if misbehaves.has(type):
		misbehaves.erase(type)
		_remove_misbehave_icon(type)
		emit_signal("misbehave_removed", type)

func has_misbehave(type: Misbehave) -> bool:
	return misbehaves.has(type)

func process_misbehaves():
	var now = Time.get_ticks_msec() / 1000.0
	var to_remove := []
	for type in misbehaves.keys():
		if now - misbehaves[type] > MISBEHAVE_DURATION:
			to_remove.append(type)
	for type in to_remove:
		remove_misbehave(type)

func start_removing_misbehave_icons():
	for icon in mood_icon_stack.get_children():
		_animate_icon_removal(icon)

func count_whistle_removable_misbehaves() -> int:
	var count = 0
	for m in misbehaves:
		if m != Misbehave.SLIP and m != Misbehave.DROWN:
			count += 1
	return count

func clear_all_misbehaves_for_whistle():
	var new_misbehaves = {}
	for k in misbehaves.keys():
		if k == Misbehave.SLIP or k == Misbehave.DROWN:
			new_misbehaves[k] = misbehaves[k]
	misbehaves = new_misbehaves
	update_mood_icons()

const WHISTLE_REMOVABLES = [
	Misbehave.BAD, Misbehave.RUN, Misbehave.TRASH, Misbehave.SPLASH, Misbehave.SLEEP, Misbehave.DIVE
]
const LIFE_SAVER_REMOVABLES = [
	Misbehave.DROWN
]

func clear_misbehaves_by_filter(allowed: Array):
	for type in misbehaves.keys():
		if type in allowed:
			remove_misbehave(type)
	update_mood_icons()

func _animate_icon_removal(icon: Sprite2D):
	icon.modulate = Color(0.2, 1.0, 0.2) # Change icon to green
	var tween = get_tree().create_tween()
	tween.tween_property(icon, "position", icon.position + Vector2(0, -40), 0.8)
	tween.tween_property(icon, "modulate:a", 0.0, 0.8)
	tween.tween_callback(Callable(icon, "queue_free"))

func update_mood_icons():
	var to_show = misbehaves.keys()
	# Remove extra icons
	for icon in mood_icon_stack.get_children():
		if int(icon.name) not in to_show:
			_remove_misbehave_icon(int(icon.name))
	# Add missing icons
	for type in to_show:
		if not mood_icon_stack.has_node(str(type)):
			_add_misbehave_icon(type)

func _add_misbehave_icon(type: Misbehave):
	if mood_icon_stack.has_node(str(type)):
		return # icon already exists
	var icon = Sprite2D.new()
	icon.texture = MISBEHAVE_ICONS[type]
	icon.name = str(type)
	icon.position.x = mood_icon_stack.get_child_count() * MISBEHAVE_ICON_OFFSET.x
	icon.modulate = Color(2, 2, 2, 0) # Big & translucent to pop in
	mood_icon_stack.add_child(icon)
	var tween = get_tree().create_tween()
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.35)
	
func _remove_misbehave_icon(type: Misbehave):
	var icon = mood_icon_stack.get_node_or_null(str(type))
	if icon:
		icon.modulate = Color(0.2, 1.0, 0.2) # Reddish effect on remove
		var tween = get_tree().create_tween()
		tween.tween_property(icon, "position", icon.position + Vector2(0, -40), 0.7)
		tween.tween_property(icon, "modulate:a", 0.0, 0.7)
		tween.tween_callback(Callable(icon, "queue_free"))
