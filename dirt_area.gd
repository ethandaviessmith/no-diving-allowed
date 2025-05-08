class_name Dirt extends Area2D

enum DirtType { DIRT, PUDDLE }
var cleaning_tween: Tween = null

@export var sprite: Sprite2D
@export var type: DirtType = DirtType.DIRT
var size: int = 0
const TYPE_DATA = {
	DirtType.DIRT: { "start": 0, "min": 0, "max": 5 },
	DirtType.PUDDLE: { "start": 6, "min": 6, "max": 10 }
}
var _can_clean := true
var _clean_cooldown := 1.0


func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	if not sprite:
		sprite = $Sprite2D
	self.add_to_group("clean")
	rotation = deg_to_rad(randf_range(-40, 40))
	_update_frame()
	if type == DirtType.PUDDLE:
		var t = Timer.new()
		t.one_shot = false
		t.autostart = true
		add_child(t)
		t.timeout.connect(func(): if size - TYPE_DATA[type]["min"] < 3: shrink(1.0))
		t.start(15)

func start_clean():
	if not _can_clean:
		return
	_can_clean = false
	var clean_amount = 0.5 + randf()
	shrink(clean_amount)
	await get_tree().create_timer(_clean_cooldown).timeout
	_can_clean = true

func _on_cleaned():
	hide() # Or queue_free(), or emit a "cleaned" signal
	queue_free()

func setup(dirt_type: DirtType):
	type = dirt_type
	size = TYPE_DATA[type]["min"]
	_update_frame()

func make_bigger():
	if size < TYPE_DATA[type]["max"]:
		size += 1
		_update_frame()

func shrink(amount: float):
	size = int(size - amount)
	if size < TYPE_DATA[type]["min"]:
		_fade_and_queue_free()
	else:
		_update_frame()

func _fade_and_queue_free():
	if cleaning_tween: return # Already cleaning
	cleaning_tween = create_tween()
	cleaning_tween.tween_property(self, "modulate", Color(1,1,1,0), 0.7)
	cleaning_tween.finished.connect(_on_cleaned)

func _update_frame():
	$Sprite2D.frame = size

func interact():
	var chance = randf()
	if chance < 0.5:
		make_bigger()
		
func _on_body_entered(body):
	if body.is_in_group("swimmer"):# and body.is_wet:
		body.in_puddle = self

func _on_body_exited(body):
	if body.is_in_group("swimmer") and body.in_puddle == self:
		body.in_puddle = null
