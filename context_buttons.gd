class_name ContextButtons extends CanvasLayer

# --- ENUM DEFINITIONS ---
enum ZIconType {
	WHISTLE, WHISTLE2, WHISTLE3, WHISTLE_BLOW, CLEAN, FIRST_AID, THROW, REEL_IN, BLANK
}
enum XIconType {
	HAND, OPEN_HAND, MOP, LIFE_SAVER, SWIMMER, BLANK, GRAB_MOP, GRAB_LIFE_SAVER, GRAB_SWIMMER
}


# --- EXPORTED TEXTURE ARRAYS (MUST MATCH ENUM ORDER) ---
@export var z_icon_textures: Array[Texture2D] = [
	preload("res://assets/icons12.png"), # WHISTLE
	preload("res://assets/icons13.png"), # WHISTLE2
	preload("res://assets/icons14.png"), # WHISTLE3
	preload("res://assets/icons12.png"), # WHISTLEBLOW
	preload("res://assets/icons15.png"), # CLEAN
	preload("res://assets/icons19.png"), # FIRST AID
	preload("res://assets/icons20.png"), # THROW
	preload("res://assets/icons21.png"), # REEL IN
	preload("res://assets/icons11.png"), # BLANK
]

@export var x_icon_textures: Array[Texture2D] = [
	preload("res://assets/icons16.png"), # HAND
	preload("res://assets/icons17.png"), # OPEN_HAND
	preload("res://assets/icons18.png"), # MOP
	preload("res://assets/icons20.png"), # LIFE SAVER
	preload("res://assets/icons22.png"), # SWIMMER
	preload("res://assets/icons11.png"), # BLANK
	preload("res://assets/icons18.png"), # MOP
	preload("res://assets/icons20.png"), # LIFE SAVER
	preload("res://assets/icons22.png"), # SWIMMER
]

const Z_LABELS = {
	ZIconType.WHISTLE: "Whistle",
	ZIconType.WHISTLE2: "Whistle (Charge)",
	ZIconType.WHISTLE3: "Whistle (Ready)",
	ZIconType.WHISTLE_BLOW: "Whistle (Blow)",
	ZIconType.CLEAN: "Clean",
	ZIconType.FIRST_AID: "First Aid",
	ZIconType.THROW: "Throw",
	ZIconType.REEL_IN: "Reel In",
	ZIconType.BLANK: "",
}

const X_LABELS = {
	XIconType.HAND: "Empty",
	XIconType.OPEN_HAND: "Grab",
	XIconType.MOP: "Drop Mop",
	XIconType.LIFE_SAVER: "Drop Life Saver",
	XIconType.SWIMMER: "Drop Swimmer",
	XIconType.BLANK: "",
	XIconType.GRAB_MOP: "Grab Mop",
	XIconType.GRAB_LIFE_SAVER: "Grab Life Saver",
	XIconType.GRAB_SWIMMER: "Grab Swimmer"
}

func set_z(icon_type: ZIconType) -> void:
	var anim:AnimationPlayer = $ZButtonAnim
	var whistle_sprite:Sprite2D = $ZButtonAnim/Whistle_FX
	var icon:TextureRect = $ZButtonIcon
	$ZButtonLabel.text = Z_LABELS[icon_type]
	icon.texture = z_icon_textures[int(icon_type)]
	if not anim or not whistle_sprite:
		return

	match icon_type:
		ZIconType.WHISTLE:
			whistle_sprite.visible = true
			anim.play("idle")
			anim.stop()
			anim.seek(0.0, true)
		ZIconType.WHISTLE2:
			whistle_sprite.visible = true
			anim.play("idle")
		ZIconType.WHISTLE3, ZIconType.WHISTLE_BLOW:
			whistle_sprite.visible = true
			anim.play("blow")
		ZIconType.CLEAN, ZIconType.BLANK:
			whistle_sprite.visible = false

func set_x(icon_type: XIconType) -> void:
	$XButtonIcon.texture = x_icon_textures[int(icon_type)]
	$XButtonLabel.text = X_LABELS[icon_type]

func reset_icons():
	set_z(ZIconType.BLANK)
	set_x(XIconType.BLANK)
	
func set_button_background(z_down: bool, x_down: bool):
	var z_bg := $ZButtonBackground
	var x_bg := $XButtonBackground

	if z_bg and z_bg is Sprite2D:
		z_bg.frame = 1 if z_down else 0

	if x_bg and x_bg is Sprite2D:
		x_bg.frame = 1 if x_down else 0
