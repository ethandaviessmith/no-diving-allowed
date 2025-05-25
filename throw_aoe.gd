extends Area2D

@export var num_dots := 10
@export var dot_radius := 8

@onready var cshape = $CollisionShape2D

var is_cast := false
var show_outline := false
var rotation_speed := 0.2
var dot_angle := 0.0
var fade_active := false
var double_buff_data = {}
var current_color: Color = Color.WHITE  # Always set from the throw

var dome_anim_time := 0.0
var dome_anim_duration := 0.3
var dome_base_angle := 0.0
var dome_active := false

var throw_level := Throw.ThrowLevel.LEVEL_1
var current_props : Dictionary = {}
var steps_per_level: Array[int] = [4, 6, 8] 

const DOME_HEIGHT_FACTOR := 0.6 
@export var aspect_ratio: float = 0.6

signal dome_animation_finished

func set_throw_level(level: int, props: Dictionary) -> void:
	throw_level = level
	current_props = props
	set_throw_effects(current_props["radius"], current_props["rotation"], current_props["color"])

func get_steps() -> int:
	return current_props.get("steps", 4)

func _ready() -> void:
	Log.pr("land aoe ready")

func start_dome_animation():
	Log.pr("land dome")
	dome_anim_time = 0.0
	dome_active = true
	dome_base_angle = dot_angle
	queue_redraw()

func set_throw_effects(r: float, rot: float, col: Color) -> void:
	cshape.shape.radius = r
	rotation_speed = rot
	current_color = col
	modulate = col
	queue_redraw()

func set_cast(b: bool): is_cast = b

func release_and_fade():
	if fade_active: return
	Log.pr("land fade")
	fade_active = true
	if get_tree().is_debugging_collisions_hint(): modulate = Color(1,1,1,1) # for hot reloading
	var t = create_tween()
	t.tween_property(self, "modulate", Color(1,1,1,0), 0.5)
	t.tween_callback(_on_faded_out)

func _on_faded_out():
	emit_signal("dome_animation_finished")
	queue_free()

func _process(delta):
	if dome_active:
		dome_anim_time += delta
		if dome_anim_time >= dome_anim_duration:
			dome_anim_time = dome_anim_duration
			dome_active = false
			release_and_fade()
	elif not fade_active:
		dot_angle += delta * TAU * rotation_speed
	queue_redraw()

func set_mode(released: bool):
	show_outline = released
	queue_redraw()
	
func _draw():
	if double_buff_data.size() > 0:
		var spin = double_buff_data.spin_speed
		var t = double_buff_data.t
		var r = double_buff_data.radius
		var flash = (int(Time.get_ticks_msec() / 60) % 2 == 0)
		var col = Color.WHITE if flash else current_color
		for i in num_dots:
			var a = t + float(i) / num_dots * TAU
			draw_sphere(Vector2.RIGHT.rotated(a) * r, dot_radius, col)
		return
	var r = cshape.shape.radius
	for i in num_dots:
		var a = (float(i) / num_dots) * TAU if show_outline else (dot_angle + float(i)/num_dots * TAU)
		var col = (Color.WHITE if is_cast and int(Time.get_ticks_msec()/60 % 2)==0 else current_color) if show_outline else current_color
		draw_sphere(Vector2.RIGHT.rotated(a) * r, dot_radius, col)
	if dome_active and dome_anim_duration > 0.0:
		var progress := dome_anim_time / dome_anim_duration
		var R = cshape.shape.radius
		var steps:int = get_steps()

		for i in num_dots:
			var base_angle := dome_base_angle + float(i) / num_dots * TAU
			for j in steps:
				var t := float(j) / steps
				if t > progress:
					break
				# Top hemisphere: theta sweeps 0 (edge) to -PI/2 (top)
				var theta := -t * (PI / 2.0)
				var sphere_radius = R * cos(theta)   # radius shrinks as dot ascends
				var height = -R * sin(theta) * DOME_HEIGHT_FACTOR
				var pos_on_ring = Vector2.RIGHT.rotated(base_angle) * sphere_radius
				var dome_dot_pos = pos_on_ring + Vector2(0, -height)
				var dot_size = lerp(dot_radius * 0.9, dot_radius * 0.32, t)
				draw_sphere(dome_dot_pos, dot_size, current_color)
		return

func draw_sphere(pos: Vector2, radius: float, base_color: Color):
	draw_circle(pos, radius, base_color.darkened(0.23))
	draw_circle(pos, radius * 0.9, base_color)
	draw_circle(pos, radius * 0.7, base_color.lightened(0.18).lerp(Color.WHITE, 0.3))
	var specular = Color(1, 1, 1, 0.58)
	draw_circle(pos + Vector2(radius * 0.32, -radius * 0.33), radius * 0.24, specular)
	var secondary = Color(0.4, 0.7, 1.0, 0.22)
	draw_circle(pos + Vector2(-radius * 0.18, radius * 0.19), radius * 0.19, secondary)
	
func get_swimmers_in_area() -> Array:
	var swimmers := []
	for body in get_overlapping_bodies():
		if body.is_in_group("swimmer"):
			swimmers.append(body)
	return swimmers
