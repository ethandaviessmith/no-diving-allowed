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

func update_context_buttons(
		held_item,
		lifesaver_thrown,
		whistle,
		is_near_mop_func,
		is_near_lifesaver_func,
		is_near_swimmer_func,
		is_near_first_aid_area_func):

	# --- Z BUTTON LOGIC ---
	if held_item:
		if held_item is Interactable and held_item.is_lifesaver():
			set_z(ZIconType.REEL_IN if lifesaver_thrown else ZIconType.THROW)
		elif held_item is Interactable and held_item.is_mop():
			set_z(ZIconType.CLEAN)
		elif held_item is Swimmer:
			set_z(ZIconType.FIRST_AID if is_near_first_aid_area_func.call() else ZIconType.BLANK)
		else:
			set_z(ZIconType.BLANK)
	else:
		if whistle.throw_aoe and is_instance_valid(whistle.throw_aoe) and whistle.throw_aoe.dome_active:
			set_z(ZIconType.WHISTLE3)
		elif whistle.charging:
			set_z(ZIconType.WHISTLE2)
		else:
			set_z(ZIconType.WHISTLE)

	# --- X BUTTON LOGIC ---
	if held_item:
		if held_item is Interactable and held_item.is_mop():
			set_x(XIconType.MOP)
		elif held_item is Interactable and held_item.is_lifesaver():
			set_x(XIconType.LIFE_SAVER)
		elif held_item is Swimmer:
			set_x(XIconType.SWIMMER)
		else:
			set_x(XIconType.BLANK)
	else:
		if is_near_mop_func.call():
			set_x(XIconType.GRAB_MOP)
		elif is_near_lifesaver_func.call():
			set_x(XIconType.GRAB_LIFE_SAVER)
		elif is_near_swimmer_func.call():
			set_x(XIconType.GRAB_SWIMMER)
		else:
			set_x(XIconType.HAND)

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
