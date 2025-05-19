class_name Whistle
extends Node2D

@onready var WhistleAudioStream: AudioStreamPlayer2D = $"WhistleAudioStream"
@onready var aoe_scene = preload("res://whistle_aoe.tscn")

enum WhistleLevel { LEVEL_1, LEVEL_2, LEVEL_3 }
var whistle_level: int = WhistleLevel.LEVEL_1
var charge_timer: float = 0.0
var charging: bool = false

const WHISTLE_COOLDOWN = 0.25
var whistle_aoe: Area2D = null
var whistle_cooldown := 0.0

var cast_velocity := Vector2.ZERO
var cast_dir := Vector2.ZERO
var cast_position := Vector2.ZERO
var cast_speed := 250
var direction: Vector2
var last_whistle_press_time := -999.0
const DOUBLE_TAP_MAX = 0.22

const LEVEL_UP_TIMES = [0.0, 3.0, 6.0] # t=0->L1, 2s->L2, 4s->L3
const WHISTLE_PROPS = {
	WhistleLevel.LEVEL_1: {"radius": 50, "rotation": 0.3, "color": Color.CORNFLOWER_BLUE, "cast_speed": 200, "steps": 4 },
	WhistleLevel.LEVEL_2: {"radius": 100, "rotation": -0.4, "color": Color.CORAL, "cast_speed": 350, "steps": 6 },
	WhistleLevel.LEVEL_3: {"radius": 150, "rotation": 0.5, "color": Color.DARK_RED, "cast_speed": 500, "steps": 8 },
}

func get_whistle_props(level: int) -> Dictionary:
	return WHISTLE_PROPS.get(level, WHISTLE_PROPS[WhistleLevel.LEVEL_1])

func apply_whistle_level():
	if is_instance_valid(whistle_aoe):
		var props = get_whistle_props(whistle_level)
		whistle_aoe.set_whistle_level(whistle_level, props)
		cast_speed = props["cast_speed"]

func handle_whistle_pressed():
	var now = Time.get_ticks_msec() / 1000.0
	if whistle_cooldown <= 0.0:
		start_whistle_cast()
	last_whistle_press_time = now

func handle_whistle_released():
	if charging:
		release_whistle_cast()

func get_input_dir():
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	return dir.normalized()

func start_whistle_cast():
	charging = true
	charge_timer = 0.0
	whistle_level = WhistleLevel.LEVEL_1
	cast_dir = Vector2.ZERO
	cast_velocity = Vector2.ZERO
	cast_position = global_position
	whistle_aoe = aoe_scene.instantiate()
	whistle_aoe.connect("dome_animation_finished", Callable(self, "_on_whistle_aoe_finished").bind(whistle_aoe))
	# Parent as appropriate
	get_parent().get_parent().add_child(whistle_aoe)
	apply_whistle_level()

func release_whistle_cast():
	charging = false
	whistle_cooldown = WHISTLE_COOLDOWN
	cast_velocity = Vector2.ZERO
	
	if is_instance_valid(whistle_aoe):
		cast_speed = get_whistle_props(WhistleLevel.LEVEL_1)["cast_speed"]
		if whistle_aoe.has_method("get_swimmers_in_area"):
			var swimmers = whistle_aoe.get_swimmers_in_area()
			for swimmer in swimmers:
				swimmer.whistled_at()
		whistle_aoe.start_dome_animation()

	if WhistleAudioStream:
		WhistleAudioStream.pitch_scale = 1.05
		WhistleAudioStream.play()


func _on_whistle_aoe_finished(emitter):
	if whistle_aoe == emitter:
		whistle_aoe = null

func _process(delta):
	if whistle_cooldown > 0.0:
		whistle_cooldown -= delta

	if charging:
		charge_timer += delta

		if is_instance_valid(whistle_aoe):
			var charge_frac = clamp(charge_timer / LEVEL_UP_TIMES[2], 0.0, 1.0)
			var from_lvl := WhistleLevel.LEVEL_1 if charge_frac < 0.5 else WhistleLevel.LEVEL_2
			var to_lvl := WhistleLevel.LEVEL_2 if charge_frac < 0.5 else WhistleLevel.LEVEL_3
			var interp = charge_frac / 0.5 if charge_frac < 0.5 else (charge_frac - 0.5) / 0.5
			var props_from := get_whistle_props(from_lvl)
			var props_to := get_whistle_props(to_lvl)
			whistle_aoe.set_whistle_effects(
				lerp(props_from["radius"], props_to["radius"], interp),
				lerp(props_from["rotation"], props_to["rotation"], interp),
				props_from["color"].lerp(props_to["color"], interp)
			)

		var new_level = whistle_level
		if charge_timer >= LEVEL_UP_TIMES[2]:
			new_level = WhistleLevel.LEVEL_3
		elif charge_timer >= LEVEL_UP_TIMES[1]:
			new_level = WhistleLevel.LEVEL_2
		else:
			new_level = WhistleLevel.LEVEL_1

		if new_level != whistle_level:
			whistle_level = new_level
			apply_whistle_level()

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
			var max_speed = get_whistle_props(WhistleLevel.LEVEL_3)["cast_speed"]
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
		if is_instance_valid(whistle_aoe):
			whistle_aoe.global_position = cast_position
