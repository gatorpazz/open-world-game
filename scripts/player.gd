class_name Player
extends CharacterBody3D
## First-person player controller: WASD to move, mouse to look, Space to
## jump, E to interact, Esc to release the mouse (click to recapture).

@export var speed := 6.0
@export var jump_velocity := 4.8
@export var mouse_sensitivity := 0.002

@onready var head: Node3D = $Head
@onready var detector: InteractionDetector = $Head/Camera3D/InteractionDetector
@onready var hud_prompt: HudPrompt = $HUD/HudPrompt


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	detector.target_changed.connect(hud_prompt.set_target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw rotates the whole body, pitch only the head.
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("interact"):
		detector.try_interact()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
