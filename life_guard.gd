extends CharacterBody2D

@export var speed := 200
@export var slow_speed := 100
@export var clean_timer_interval := 0.15 # seconds
var cleaning := false
var clean_timer = null

var held_item: Node = null
var held_item_offset
var lifesaver_thrown = false
var lifesaver_returning := false
@onready var rope := $Rope
@onready var whistle:Throw = $Whistle
@onready var context_buttons = $"../../PoolUI/CanvasLayer"
@onready var interact_zone: Area2D = $InteractZone

func _ready() -> void:
	$Sprite2D.frame = randi() % 4
	held_item_offset = $HeldItem.position.x

func _physics_process(delta):
	if not whistle.charging:
		velocity = get_input_dir() * (slow_speed if cleaning else speed)
		move_and_slide()
		if velocity.x != 0:
			$Sprite2D.flip_h = velocity.x < 0
	
	if held_item and not lifesaver_thrown:
		#held_item.global_position = $HeldItem.global_position
		pass

func _process(delta):
	rope.set_hand_position(get_hand_position())
	if lifesaver_thrown or lifesaver_returning:
		if held_item and rope.visible:
			rope.set_tip_position(held_item.global_position)
	else:
		rope.set_tip_position(get_hand_position())
	rope.set_thrown(lifesaver_thrown or lifesaver_returning)
	
	if whistle.charging and not Input.is_action_pressed("interact"):
		whistle.cancel_throw() # safety check
	
	update_context_buttons()

func get_hand_position():
	return $HeldItem.global_position

func _input(event):
	if event.is_action_pressed("grab"):
		grab_item()

	var action_taken := false
	if is_instance_valid(held_item) and held_item is Interactable:
		if event.is_action_pressed("interact"):
			if lifesaver_thrown:
				action_taken = true
				_on_reel_in_lifesaver()
			elif held_item.is_mop():
				if not cleaning:
					start_cleaning()
					action_taken = true
			elif held_item.is_lifesaver():
				action_taken = true
				#if held_item.global_position.distance_to($HeldItem.global_position) < 10:
				Log.pr("throw", "lifesaver")
				if not lifesaver_returning:
					whistle.handle_throw_pressed(Throw.ThrowType.LIFE_SAVER)
					action_taken = true

	if not action_taken and event.is_action_pressed("interact"):
		whistle.handle_throw_pressed(Throw.ThrowType.WHISTLE)

	if event.is_action_released("interact"):
		if is_instance_valid(held_item) and held_item is Interactable:
			if held_item.is_mop() and cleaning:
				stop_cleaning()
			elif held_item.is_lifesaver():
				if not lifesaver_thrown:
					_on_throw_lifesaver()
				elif lifesaver_thrown:
					_on_reel_in_lifesaver()
					whistle.cancel_throw()
					#if lifesaver_returning: 
		else:
			whistle.handle_throw_released()
	
	if event is InputEventKey:
		var z_down = Input.is_action_pressed("interact") # "z" action
		var x_down = Input.is_action_pressed("grab") # "x" action
		context_buttons.set_button_background(z_down, x_down)
	
	update_context_buttons()

func update_context_buttons():
	context_buttons.update_context_buttons(
	held_item,
	lifesaver_thrown,
	whistle,
	Callable(self, "is_near_mop"),
	Callable(self, "is_near_lifesaver"),
	Callable(self, "is_near_swimmer"),
	Callable(self, "is_near_first_aid_area")
)

func get_input_dir():
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	return dir.normalized()

func is_near_mop() -> bool:
	for area in interact_zone.get_overlapping_areas():
		if area.is_in_group("grab") and area is Interactable and area.is_mop():
			return true
	return false

func is_near_lifesaver() -> bool:
	for area in interact_zone.get_overlapping_areas():
		if area.is_in_group("grab") and area is Interactable and area.is_lifesaver():
			return true
	return false

func is_near_swimmer() -> bool:
	for body in interact_zone.get_overlapping_bodies():
		if body is Swimmer and body.state in [Swimmer.SwimmerState.CARRY, Swimmer.SwimmerState.SIT] and not body.being_carried:
			return true
	return false

func is_near_first_aid_area() -> bool:
	for area in interact_zone.get_overlapping_areas():
		if area.is_in_group("firstaid"):
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
		return release_item()
	for area in interact_zone.get_overlapping_bodies():
		if area.is_in_group("swimmer"):
			var swimmer:Swimmer = area
			if area.state == Swimmer.SwimmerState.SIT:
				grab_swimmer(area)
				return
	for area in interact_zone.get_overlapping_areas():
		if "grab" in area.get_groups() and held_item == null:
			held_item = area
			held_item.get_parent().remove_child(held_item)
			$HeldItem.add_child(held_item)
			held_item.position = Vector2.ZERO # Snap to hand
			lifesaver_thrown = false
			if held_item.is_lifesaver():
				whistle.throw_type = Throw.ThrowType.LIFE_SAVER
				rope.visible = true
			else:
				whistle.throw_type = Throw.ThrowType.WHISTLE
	
func release_item():
	if held_item:
		if held_item is Swimmer:
			var pos = held_item.global_position
			$HeldItem.remove_child(held_item)
			get_parent().add_child(held_item)
			held_item.global_position = pos

			held_item.set_swimmer_mode(Swimmer.SwimmerState.CARRY, false)

			var on_first_aid := false
			for area in interact_zone.get_overlapping_areas():
				if area.is_in_group("firstaid"):
					on_first_aid = true
					break

			if on_first_aid:
				if held_item.has_method("enter_first_aid"):
					held_item.enter_first_aid()
				else:
					held_item.curr_action = Util.ACT_FIRSTAID
			else:
				held_item.set_swimmer_mode(Swimmer.SwimmerState.SIT, true)
		else:
			if held_item.is_mop() and cleaning:
				stop_cleaning()
			var pos = held_item.global_position
			$HeldItem.remove_child(held_item)
			get_parent().add_child(held_item)
			held_item.global_position = pos + Vector2(24, 0)
	held_item = null
	rope.visible = false

func grab_swimmer(swimmer:Swimmer):
	if held_item: release_item()
	swimmer.on_lifeguard_picks_up(self)
	held_item = swimmer

func interact_with_area():
	for area in interact_zone.get_overlapping_areas():
		if area.is_in_group("clean") and held_item != null and held_item is Interactable and held_item.is_mop():
			area.start_clean()

func _get_lifesaver() -> Node2D:
	if held_item and held_item.has_method("is_lifesaver") and held_item.is_lifesaver():
		return held_item
	return null

func _on_throw_lifesaver():
	var lifesaver = _get_lifesaver()
	if lifesaver and not lifesaver_thrown:
		lifesaver_thrown = true
		# Remove lifesaver from player hierarchy, but keep the node in the scene
		lifesaver.get_parent().remove_child(lifesaver)
		get_tree().current_scene.add_child(lifesaver) # move to world root or main container
		lifesaver.global_position = $HeldItem.global_position
		if whistle.throw_aoe:
			var throw_center = whistle.throw_aoe.global_position
			_animate_lifesaver_to(throw_center)
		# You may want to set a state variable like `can_reel_in = true`
		whistle.handle_throw_lifesaver(lifesaver)

func _animate_lifesaver_to(target_position: Vector2):
	var lifesaver = _get_lifesaver()
	var tween = create_tween()
	tween.tween_property(lifesaver, "global_position", target_position, 0.5)
	tween.tween_callback(Callable(self, "_on_lifesaver_at_aoe"))

func _on_lifesaver_at_aoe():
	# Optionally: Ready to reel in swimmers, update state, etc.
	pass

func _on_reel_in_lifesaver():
	var lifesaver = _get_lifesaver()
	if lifesaver and lifesaver_thrown and not lifesaver_returning:
		lifesaver_returning = true
		var tween = create_tween()
		tween.tween_property(lifesaver, "global_position", $HeldItem.global_position, 0.5)
		tween.tween_callback(Callable(self, "_finish_reel_in_lifesaver").bind(lifesaver))

func _finish_reel_in_lifesaver(lifesaver: Interactable):
	if lifesaver.get_parent():
		lifesaver.get_parent().remove_child(lifesaver)
	$HeldItem.add_child(lifesaver)
	lifesaver.position = Vector2.ZERO
	held_item = lifesaver
	lifesaver_thrown = false
	lifesaver_returning = false
	whistle.handle_throw_pressed(Throw.ThrowType.LIFE_SAVER)

	if "linked_swimmer" in lifesaver and is_instance_valid(lifesaver.linked_swimmer):
		var swimmer = lifesaver.linked_swimmer
		if swimmer._is_state(Swimmer.SwimmerState.CARRY) and swimmer.carry_target == lifesaver:
			grab_swimmer(swimmer)
			lifesaver.linked_swimmer = null
