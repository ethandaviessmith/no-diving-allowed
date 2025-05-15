extends Sprite2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	animation_player.play("splash")
	animation_player.connect("animation_finished", _on_anim_done)

func _on_anim_done(anim_name):
	if anim_name == "splash":
		queue_free()
