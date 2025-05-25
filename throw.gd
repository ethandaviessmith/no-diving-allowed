class_name Throw
extends Node2D

@onready var ThrowAudioStream: AudioStreamPlayer2D = $"WhistleAudioStream"
@onready var aoe_scene = preload("res://throw_aoe.tscn")

enum ThrowLevel { LEVEL_1, LEVEL_2, LEVEL_3 }
var throw_level: int = ThrowLevel.LEVEL_1
var charge_timer: float = 0.0
var charging: bool = false

enum ThrowType { WHISTLE, LIFE_SAVER }
@export var throw_type : int = ThrowType.WHISTLE # Assign at runtime depending on what's equipped

const THROW_COOLDOWN = 0.25
var throw_aoe: Area2D = null
var throw_cooldown := 0.0

var cast_velocity := Vector2.ZERO
var cast_dir := Vector2.ZERO
var cast_position := Vector2.ZERO
var cast_speed := 250
var direction: Vector2
var last_throw_press_time := -999.0
const DOUBLE_TAP_MAX = 0.22

const LEVEL_UP_TIMES = [0.0, 3.0, 6.0] # t=0->L1, 2s->L2, 4s->L3

const WHISTLE_PROPS = {
	ThrowLevel.LEVEL_1: {"radius": 50, "rotation": 0.3, "color": Color.CORNFLOWER_BLUE, "cast_speed": 200, "steps": 4 },
	ThrowLevel.LEVEL_2: {"radius": 100, "rotation": -0.4, "color": Color.CORAL, "cast_speed": 350, "steps": 6 },
	ThrowLevel.LEVEL_3: {"radius": 150, "rotation": 0.5, "color": Color.DARK_RED, "cast_speed": 500, "steps": 8 },
}
const LIFE_SAVER_PROPS = {
	ThrowLevel.LEVEL_1: {"radius": 25, "rotation": 0.1, "color": Color.FIREBRICK, "cast_speed": 230, "steps": 5 },
	ThrowLevel.LEVEL_2: {"radius": 38, "rotation": -0.2, "color": Color.DARK_RED, "cast_speed": 380, "steps": 7 },
	ThrowLevel.LEVEL_3: {"radius": 65, "rotation": 0.28, "color": Color.CRIMSON, "cast_speed": 600, "steps": 10 },
}

func get_throw_props(level: int) -> Dictionary:
	if throw_type == ThrowType.LIFE_SAVER:
		return LIFE_SAVER_PROPS.get(level, LIFE_SAVER_PROPS[ThrowLevel.LEVEL_1])
	return WHISTLE_PROPS.get(level, WHISTLE_PROPS[ThrowLevel.LEVEL_1])

func apply_throw_level():
	if is_instance_valid(throw_aoe):
		var props = get_throw_props(throw_level)
		throw_aoe.set_throw_level(throw_level, props)
		cast_speed = props["cast_speed"]

func handle_throw_pressed(throw: ThrowType = ThrowType.WHISTLE):
	throw_type = throw
	var now = Time.get_ticks_msec() / 1000.0
	if throw_cooldown <= 0.0:
		start_throw_cast()
	last_throw_press_time = now


func cancel_throw():
	# Reset charging and cooldown
	charging = false
	charge_timer = 0.0
	throw_level = ThrowLevel.LEVEL_1
	throw_cooldown = 0.0
	last_throw_press_time = -999.0

	# Reset movement-related state
	cast_velocity = Vector2.ZERO
	cast_dir = Vector2.ZERO
	cast_position = global_position

	# If there is an active area, remove it from the scene
	if is_instance_valid(throw_aoe):
		throw_aoe.queue_free()
		throw_aoe = null
	# Optionally reset last throw press time if needed
	 #last_throw_press_time = -999.0 # Uncomment if you want to fully clear double-tap state


func handle_throw_released():
	if charging:
		release_throw_cast()

func handle_throw_lifesaver():
	if charging:
		release_throw_cast()

func get_input_dir():
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	return dir.normalized()

func start_throw_cast():
	charging = true
	charge_timer = 0.0
	throw_level = ThrowLevel.LEVEL_1
	cast_dir = Vector2.ZERO
	cast_velocity = Vector2.ZERO
	cast_position = global_position
	throw_aoe = aoe_scene.instantiate()
	throw_aoe.connect("dome_animation_finished", Callable(self, "_on_throw_aoe_finished").bind(throw_aoe))
	# Parent as appropriate
	get_parent().get_parent().add_child(throw_aoe)
	apply_throw_level()

func release_throw_cast():
	charging = false
	throw_cooldown = THROW_COOLDOWN
	cast_velocity = Vector2.ZERO

	if is_instance_valid(throw_aoe):
		cast_speed = get_throw_props(ThrowLevel.LEVEL_1)["cast_speed"]
		if throw_aoe.has_method("get_swimmers_in_area"):
			var swimmers = throw_aoe.get_swimmers_in_area()
			for swimmer in swimmers:
				if throw_type == ThrowType.LIFE_SAVER:
					swimmer.life_saver_thrown_at()
				else:
					swimmer.whistled_at()
		throw_aoe.start_dome_animation()

	if ThrowAudioStream:
		ThrowAudioStream.pitch_scale = 1.05
		ThrowAudioStream.play()

func _on_throw_aoe_finished(emitter):
	if throw_aoe == emitter:
		throw_aoe = null

func _process(delta):
	if throw_cooldown > 0.0:
		throw_cooldown -= delta

	if charging:
		charge_timer += delta

		if is_instance_valid(throw_aoe):
			var charge_frac = clamp(charge_timer / LEVEL_UP_TIMES[2], 0.0, 1.0)
			var from_lvl := ThrowLevel.LEVEL_1 if charge_frac < 0.5 else ThrowLevel.LEVEL_2
			var to_lvl := ThrowLevel.LEVEL_2 if charge_frac < 0.5 else ThrowLevel.LEVEL_3
			var interp = charge_frac / 0.5 if charge_frac < 0.5 else (charge_frac - 0.5) / 0.5
			var props_from := get_throw_props(from_lvl)
			var props_to := get_throw_props(to_lvl)
			throw_aoe.set_throw_effects(
				lerp(props_from["radius"], props_to["radius"], interp),
				lerp(props_from["rotation"], props_to["rotation"], interp),
				props_from["color"].lerp(props_to["color"], interp)
			)

		var new_level = throw_level
		if charge_timer >= LEVEL_UP_TIMES[2]:
			new_level = ThrowLevel.LEVEL_3
		elif charge_timer >= LEVEL_UP_TIMES[1]:
			new_level = ThrowLevel.LEVEL_2
		else:
			new_level = ThrowLevel.LEVEL_1

		if new_level != throw_level:
			throw_level = new_level
			apply_throw_level()

		var input_dir = get_input_dir()
		var input_strength = input_dir.length()
		if not has_node("_cast_last_input_dir"):
			set("_cast_last_input_dir", Vector2.ZERO)
		if input_strength > 0.1:
			set("_cast_last_input_dir", input_dir)
			if cast_dir == Vector2.ZERO:
				cast_dir = input_dir.normalized()
			cast_dir = cast_dir.lerp(input_dir.normalized(), delta * 6.0 * input_strength)
		else:
			cast_velocity = cast_velocity.lerp(Vector2.ZERO, delta * 10.0)
		if cast_dir != Vector2.ZERO:
			var max_speed = get_throw_props(ThrowLevel.LEVEL_3)["cast_speed"]
			cast_speed = min(cast_speed + 350 * delta, max_speed)
			var target_velocity = -cast_dir * cast_speed
			if input_strength > 0.1:
				cast_velocity = cast_velocity.lerp(target_velocity, 0.18 + (input_strength * 0.18))
			var next_pos = cast_position + cast_velocity * delta
			var dist = (next_pos - global_position).length()
			if dist > 1000:
				next_pos = global_position + (next_pos - global_position).normalized() * 1000
				cast_velocity = Vector2.ZERO
			cast_position = next_pos
		else:
			cast_velocity = cast_velocity.lerp(Vector2.ZERO, 0.13)
		if is_instance_valid(throw_aoe):
			throw_aoe.global_position = cast_position
