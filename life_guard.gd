extends CharacterBody2D

@export var speed := 200
@export var slow_speed := 100
@export var clean_timer_interval := 0.15 # seconds
var cleaning := false
var clean_timer = null

var held_item: Node = null
var held_item_offset

func _ready() -> void:
	$Sprite2D.frame = randi() % 4
	held_item_offset = $HeldItem.position.x

func _physics_process(delta):
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	velocity = dir.normalized() * (slow_speed if cleaning else speed)
	
	move_and_slide()
	
	#if dir.x != 0 and sign(scale.x) != sign(dir.x):
		#scale.x *= -1
	if held_item:
		held_item.global_position = $HeldItem.global_position

func _input(event):
	if event.is_action_pressed("grab"):
		grab_item()
	if event.is_action_pressed("interact") and held_item and held_item.is_in_group("mop"):
		if not cleaning:
			start_cleaning()
	if event.is_action_released("interact") and cleaning:
		stop_cleaning()

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
