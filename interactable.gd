@tool
class_name Interactable extends Area2D

signal resolved
signal swimmer_grabbed(swimmer)

var linked_swimmer: Swimmer = null
@onready var sprite: Sprite2D = $Sprite2D

enum Type { MOP, LIFE_SAVER }
@export var interactable_type: Type = Type.MOP:
	set(value):
		interactable_type = value
		_update_sprite_frame()


func _ready():
	body_entered.connect(_on_grab_area_entered)
	_update_sprite_frame()

func set_interactable_type(new_type: Type) -> void:
	interactable_type = new_type
	_update_sprite_frame()

func _update_sprite_frame() -> void:
	if sprite:
		match interactable_type:
			Type.MOP: sprite.frame = 0
			Type.LIFE_SAVER: sprite.frame = 4

func _on_grab_area_entered(body):
	if body is Swimmer and body.curr_action == Util.ACT_POOL_DROWN and !body.being_carried:
		body.life_saver_thrown_at(self)
		emit_signal("swimmer_grabbed", body)

func interact():
	modulate = Color.GREEN
	resolved.emit()

func get_type() -> Type:
	return interactable_type

func is_mop() -> bool:
	return interactable_type == Type.MOP

func is_lifesaver() -> bool:
	return interactable_type == Type.LIFE_SAVER
