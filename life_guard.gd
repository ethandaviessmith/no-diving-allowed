extends CharacterBody2D

@export var speed := 200
@export var slow_speed := 100
@export var clean_timer_interval := 0.15 # seconds
var cleaning := false
var clean_timer = null

var held_item: Node = null
var held_item_offset

@onready var whistle:Whistle = $Whistle
@onready var context_buttons = $"../../PoolUI/CanvasLayer"

func _ready() -> void:
	$Sprite2D.frame = randi() % 4
	held_item_offset = $HeldItem.position.x

func _physics_process(delta):
	if not whistle.charging:
		velocity = get_input_dir() * (slow_speed if cleaning else speed)
		move_and_slide()
	
	if held_item:
		held_item.global_position = $HeldItem.global_position

func _process(delta):
	update_context_buttons()


func _input(event):
	if event.is_action_pressed("grab"):
		grab_item()
	if event.is_action_pressed("interact"):
		if held_item and held_item.is_in_group("mop"):
			if not cleaning:
				start_cleaning()
		else:
			$Whistle.handle_whistle_pressed()
	if event.is_action_released("interact"):
		if held_item and held_item.is_in_group("mop") and cleaning:
			stop_cleaning()
		else:
			$Whistle.handle_whistle_released()
	update_context_buttons()


func get_input_dir():
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	return dir.normalized()


func update_context_buttons():
# --- Z BUTTON LOGIC ---
	if held_item:
		context_buttons.set_z(context_buttons.ZIconType.CLEAN)
	else:
		if whistle.charging:
			if not whistle.double_whistle_ready: 
				context_buttons.set_z(ContextButtons.ZIconType.WHISTLE3)
			else:
				context_buttons.set_z(ContextButtons.ZIconType.WHISTLE2)
		else:
			context_buttons.set_z(ContextButtons.ZIconType.WHISTLE)

	# --- X BUTTON LOGIC ---
	if held_item:
		if held_item.is_in_group("mop"):
			context_buttons.set_x(ContextButtons.XIconType.MOP)
		else:
			context_buttons.set_x(ContextButtons.XIconType.BLANK)
	else:
		if is_near_mop():
			context_buttons.set_x(ContextButtons.XIconType.OPEN_HAND)
		else:
			context_buttons.set_x(ContextButtons.XIconType.HAND)

# Example is_near_mop() implementation:
func is_near_mop() -> bool:
	for area in $InteractZone.get_overlapping_areas():
		if area.is_in_group("mop"):
			return true
	return false


func start_cleaning():
	cleaning = true
	play_sweep_motion()
	clean_timer = Timer.new()
	clean_timer.wait_time = clean_timer_interval
	clean_timer.one_shot = false
	clean_timer.autostart = true
	add_child(clean_timer)
	clean_timer.timeout.connect(_on_clean_tick)

	# Call instantly so it feels responsive
	interact_with_area()

func stop_cleaning():
	cleaning = false
	if clean_timer:
		clean_timer.queue_free()
		clean_timer = null
	$AnimationPlayer.play("idle") # or whatever your default pose is

func _on_clean_tick():
	interact_with_area()
	play_sweep_motion() 

func play_sweep_motion():
	$AnimationPlayer.play("sweep")

func grab_item():
	if held_item:
		$HeldItem.remove_child(held_item)
		get_parent().add_child(held_item)
		held_item.global_position = global_position + Vector2(24, 0) # Adjust offset as needed
		held_item = null
		return
	var interact_zone = $InteractZone
	for area in interact_zone.get_overlapping_areas():
		if "grab" in area.get_groups() and held_item == null:
			held_item = area
			held_item.get_parent().remove_child(held_item)
			$HeldItem.add_child(held_item)
			held_item.position = Vector2.ZERO # Snap to hand

func interact_with_area():
	var interact_zone = $InteractZone
	for area in interact_zone.get_overlapping_areas():
		if area.is_in_group("clean") and held_item != null and held_item.is_in_group("mop"):
			area.start_clean()
