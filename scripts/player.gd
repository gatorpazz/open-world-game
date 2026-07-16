class_name Player
extends CharacterBody3D
## First-person player controller: WASD to move, mouse to look, Space to
## jump, E to interact, LMB to attack (while captured), Esc to release
## the mouse (click to recapture).

@export var speed := 6.0
@export var jump_velocity := 4.8
@export var mouse_sensitivity := 0.002

@onready var head: Node3D = $Head
@onready var detector: InteractionDetector = $Head/Camera3D/InteractionDetector
@onready var hud_prompt: HudPrompt = $HUD/HudPrompt
@onready var hud_bars: HudBars = $HUD/HudBars
@onready var death_overlay: DeathOverlay = $HUD/DeathOverlay
@onready var stats: StatsComponent = $Stats
@onready var inventory_component: InventoryComponent = $Inventory
@onready var combat: PlayerCombat = $Combat


## Called by Game after instantiate() and BEFORE add_child(): the child
## components consume these in their _ready(), which only builds defaults
## when the exported resource is null.
func setup_identity(sheet: CharacterSheet, player_inventory: Inventory) -> void:
	($Stats as StatsComponent).sheet = sheet
	($Inventory as InventoryComponent).inventory = player_inventory


## Flat speed scaled by encumbrance (the 001→002→003 hookup, criterion 7).
func get_move_speed() -> float:
	return speed * inventory_component.get_speed_multiplier()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	detector.target_changed.connect(hud_prompt.set_target)
	hud_bars.bind(stats)
	combat.died.connect(death_overlay.open)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw rotates the whole body, pitch only the head.
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("interact"):
		detector.try_interact()
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		combat.try_attack()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif (
		event is InputEventMouseButton
		and event.pressed
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var move_speed := get_move_speed()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
