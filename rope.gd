class_name Rope extends Line2D

# Rope end positions (global, set by lifeguard/user)
var hand_pos: Vector2
var tip_pos: Vector2
var rope_thrown := false

const COIL_RADIUS = 16
const COIL_TURNS = 4
const COIL_POINTS = 20


func _ready():
	pass

func set_hand_position(pos: Vector2):
	hand_pos = pos

func set_tip_position(pos: Vector2):
	tip_pos = pos

func set_thrown(thrown: bool):
	rope_thrown = thrown

func _process(_delta):
	update_rope()

func update_rope():
	if rope_thrown:
		points = [to_local(hand_pos), to_local(tip_pos)]
	else:
		var _points: Array[Vector2] = []
		for i in range(COIL_TURNS * COIL_POINTS):
			var angle = lerp(0.0, COIL_TURNS * TAU, float(i) / (COIL_TURNS * COIL_POINTS))
			var r = COIL_RADIUS
			_points.append(to_local(hand_pos + Vector2(sin(angle), -cos(angle)) * r))
		_points.append(to_local(hand_pos + Vector2(0, -COIL_RADIUS * 2)))
		points = _points
