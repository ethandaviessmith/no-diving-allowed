extends CharacterBody2D

@onready var agent = $NavigationAgent2D

func _ready():
	agent.velocity_computed.connect(_on_navigation_agent_2d_velocity_computed)
	agent.set_target_position(global_position - Vector2(250, 250))
	agent.max_speed = 80  # or bigger


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	print("suggested_velocity:", safe_velocity)
	velocity = safe_velocity
	move_and_slide()
