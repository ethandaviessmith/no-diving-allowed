class_name ContextButtons extends CanvasLayer

# --- ENUM DEFINITIONS ---
enum ZIconType { WHISTLE, WHISTLE2, WHISTLE3, CLEAN, BLANK }
enum XIconType { HAND, OPEN_HAND, MOP, BLANK }

# --- EXPORTED TEXTURE ARRAYS (MUST MATCH ENUM ORDER) ---
@export var z_icon_textures: Array[Texture2D] = [
	preload("res://assets/icons12.png"), # WHISTLE
	preload("res://assets/icons13.png"), # WHISTLE2
	preload("res://assets/icons14.png"), # WHISTLE3
	preload("res://assets/icons15.png"), # CLEAN
	preload("res://assets/icons11.png"), # BLANK
]

@export var x_icon_textures: Array[Texture2D] = [
	preload("res://assets/icons16.png"), # HAND
	preload("res://assets/icons17.png"), # OPEN_HAND
	preload("res://assets/icons18.png"), # MOP
	preload("res://assets/icons19.png"), # BLANK
]

const Z_LABELS = {
	ZIconType.WHISTLE: "Whistle",
	ZIconType.WHISTLE2: "Whistle",
	ZIconType.WHISTLE3: "Whistle (Double)",
	ZIconType.CLEAN: "Clean",
	ZIconType.BLANK: "",
}

const X_LABELS = {
	XIconType.HAND: "Empty",
	XIconType.OPEN_HAND: "Grab",
	XIconType.MOP: "Drop Mop",
	XIconType.BLANK: "",
}

# --- ICON/LABEL SETTER FUNCTIONS ---
func set_z(icon_type: ZIconType) -> void:
	$ZButtonIcon.texture = z_icon_textures[int(icon_type)]
	$ZButtonLabel.text = Z_LABELS[icon_type]

func set_x(icon_type: XIconType) -> void:
	$XButtonIcon.texture = x_icon_textures[int(icon_type)]
	$XButtonLabel.text = X_LABELS[icon_type]

# --- OPTIONAL: RESET/INIT ---
func reset_icons():
	set_z(ZIconType.BLANK)
	set_x(XIconType.BLANK)
