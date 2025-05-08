extends CharacterBody2D

@export var speed := 200
@export var slow_speed := 100
@export var clean_timer_interval := 0.15 # seconds
var cleaning := false
var clean_timer = null

var held_item: Node = null
var held_item_offset

@onready var WhistleAudioStream: AudioStreamPlayer2D = $WhistleAudioStream

func _ready() -> void:
	$Sprite2D.frame = randi() % 4
	held_item_offset = $HeldItem.position.x

func _physics_process(delta):
	if not charging:
		var dir =  get_input_dir()
		velocity = dir * (slow_speed if cleaning else speed)
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
	
	if event.is_action_pressed("whistle"):
		start_charge()
	if charging and (event.is_action("ui_right", true) or event.is_action("ui_left", true) or event.is_action("ui_down", true) or event.is_action("ui_up", true)):
		direction = get_input_dir() 
		# Only read in if dir is NOT zero; stick once
	if event.is_action_released("whistle") and charging:
		release_whistle()

func get_input_dir():
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	return dir.normalized()

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


const MIN_RADIUS = 16
const MAX_RADIUS = 128
const CAST_SPEED = 250 # px/sec or adjust to suit game
const LOCK_DELAY = 0.2

var charging := false
var direction := Vector2.ZERO
var cast_position := Vector2.ZERO
var aoe_timer := 0.0
var charge_radius := MIN_RADIUS
@onready var aoe = preload("res://whistle_aoe.tscn") # Make this scene first!
var whistle_aoe : Area2D = null

var cast_dir = Vector2.ZERO
var casting = false
var locked = false
var cast_unpress_timer = 0.0

var lock_delay_timer: float = 0.0
var can_release_whistle: bool = false


func start_charge():
	if not is_instance_valid(whistle_aoe):
		whistle_aoe = aoe.instantiate()
		whistle_aoe.position = Vector2.ZERO
		add_child(whistle_aoe)
	else:
		whistle_aoe.position = Vector2.ZERO
		whistle_aoe.show()

	charging = true
	aoe_timer = 0.0
	charge_radius = MIN_RADIUS
	direction = Vector2.ZERO
	cast_position = position

func _process(delta):
	if charging:
		var input_dir = direction

		if not locked:
			if input_dir != Vector2.ZERO:
				cast_dir = input_dir.normalized()
				cast_unpress_timer = 0.0
				casting = true
			elif casting:
				# Already casting, but no input
				cast_unpress_timer += delta
				if cast_unpress_timer >= LOCK_DELAY:
					locked = true
					casting = false # no longer moving/locked into place
			else:
				# Not moving and never casting, gradual growth in current position
				charge_radius = clamp(charge_radius + MAX_RADIUS * delta * 0.8, MIN_RADIUS, MAX_RADIUS)
				cast_position = global_position

		if casting and not locked:
			# Move and shrink with casting input pressed
			cast_position += -cast_dir * CAST_SPEED * delta
			charge_radius = max(MAX_RADIUS * 0.5, charge_radius - MAX_RADIUS * delta)
		elif locked:
			# Not casting anymore, after delay — size can grow again
			charge_radius = clamp(charge_radius + MAX_RADIUS * delta * 0.8, MIN_RADIUS, MAX_RADIUS)
			# Stay at the locked position, don't move further
		if is_instance_valid(whistle_aoe):
			whistle_aoe.global_position = cast_position
			whistle_aoe.set_radius(charge_radius)
			whistle_aoe.set_mode(false)
			whistle_aoe.show()
	else:
		_reset_cast_state()
		if is_instance_valid(whistle_aoe):
			whistle_aoe.set_mode(true)

func release_whistle():
	if is_instance_valid(whistle_aoe):
		var swimmers = whistle_aoe.get_swimmers_in_area()
		for swimmer in swimmers:
			swimmer.whistled_at()
		var old_global_pos = whistle_aoe.global_position
		whistle_aoe.get_parent().remove_child(whistle_aoe)
		get_tree().current_scene.add_child(whistle_aoe)
		whistle_aoe.global_position = old_global_pos
		whistle_aoe.release_and_fade()
		whistle_aoe = null
	if WhistleAudioStream:
		var t = inverse_lerp(MIN_RADIUS, MAX_RADIUS, charge_radius) # t: 0 at MIN_RADIUS, 1 at MAX_RADIUS
		# Set slowest pitch when fully charged, normal when smallest
		var pitch = lerp(0.7, 1.05, 1.0 - t) # big radius = low pitch/long, small = normal
		pitch += randf_range(-0.02, 0.02)
		WhistleAudioStream.pitch_scale = pitch
		WhistleAudioStream.play()
	_reset_cast_state()

func _reset_cast_state():
	cast_dir = Vector2.ZERO
	casting = false
	locked = false
	charging = false
	cast_unpress_timer = 0.0
