# LifeGuard.gd
extends CharacterBody2D
@export var speed := 200

func _ready() -> void:
	$Sprite2D.frame = randi() % 4

func _physics_process(delta):
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	velocity = dir.normalized() * speed
	move_and_slide()
	
	if held_item:
		held_item.global_position = $HeldItem.global_position


func _input(event):
	if event.is_action_pressed("grab"):
		grab_item()
	if event.is_action_pressed("interact"):
		interact_with_area()

func interact():
	var interact_zone:Area2D = $InteractZone
	for area in interact_zone.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact()


var held_item: Node = null

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
