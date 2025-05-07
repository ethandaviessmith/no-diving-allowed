extends Area2D
@export var num_dots := 12
@export var dot_radius := 6
@export var growth_color: Color = Color.YELLOW
@export var cast_color: Color = Color.DODGER_BLUE

var dot_angle := 0.0
var charge_radius := 0.0 # set externally!
var is_cast := false

@onready var cshape = $CollisionShape2D

func set_radius(r: float):
	cshape.shape.radius = r
	charge_radius = r
	queue_redraw()

func set_cast(b: bool):
	is_cast = b

func _process(delta):
	dot_angle += delta * TAU * 0.2 # slow spinning (0.2 turns/sec)
	queue_redraw()

var show_outline := false

# Called from lifeguard
func set_mode(released: bool):
	show_outline = released
	queue_redraw()

func _draw():
	if show_outline:
		for i in num_dots:
			var t = float(i) / num_dots
			var a = t * TAU
			var r = cshape.shape.radius
			var base_pos = Vector2.RIGHT.rotated(a) * r
			# Base dot (main outline)
			draw_circle(base_pos, dot_radius * 1, Color.RED)
			for j in range(1, 3):
				draw_circle(base_pos - Vector2(0, 10 * j), dot_radius * 0.6, Color.RED)
	else:
		for i in num_dots:
			var t = float(i) / num_dots
			var a = dot_angle + t * TAU
			var r = cshape.shape.radius
			var pos = Vector2.RIGHT.rotated(a) * r
			draw_sphere(pos, dot_radius, cast_color if is_cast else growth_color)

func release_and_fade():
	show_outline = true
	set_process(false)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)


func draw_sphere(pos: Vector2, radius: float, base_color: Color):
	# Main base fill (dominant)
	draw_circle(pos, radius, base_color)
	
	# Subtle shadow (smaller+off to side)
	var shadow_offset = Vector2(radius * 0.2, radius * 0.23)
	var shadow_color = base_color.darkened(0.12) # light shadow
	draw_circle(pos + shadow_offset, radius * 0.85, shadow_color)
	
	# Strong highlight (small and bright)
	var highlight_offset = Vector2(-radius * 0.18, -radius * 0.20)
	var highlight_color = base_color.lightened(0.85)
	draw_circle(pos + highlight_offset, radius * 0.28, highlight_color)
