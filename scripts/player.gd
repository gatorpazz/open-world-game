class_name Player
extends CharacterBody3D
## First-person player controller: WASD to move, mouse to look, Space to
## jump, E to interact, LMB to attack and RMB to cast (while captured),
## R to cycle spells, J to read the journal, F5/F9 to quicksave/quickload,
## Esc to release the mouse (click to recapture).

const JOURNAL_PANEL_SCENE := preload("res://scenes/ui/journal_panel.tscn")

@export var speed := 6.0
@export var jump_velocity := 4.8
@export var mouse_sensitivity := 0.002

## The player's journal (spec 005) — injected identity like the sheet and
## inventory; a fresh one is built in _ready only when none was injected.
var journal: Journal

var _journal_panel: JournalPanel = null

@onready var head: Node3D = $Head
@onready var detector: InteractionDetector = $Head/Camera3D/InteractionDetector
@onready var hud_prompt: HudPrompt = $HUD/HudPrompt
@onready var hud_bars: HudBars = $HUD/HudBars
@onready var hud_notice: HudNotice = $HUD/HudNotice
@onready var death_overlay: DeathOverlay = $HUD/DeathOverlay
@onready var stats: StatsComponent = $Stats
@onready var inventory_component: InventoryComponent = $Inventory
@onready var combat: PlayerCombat = $Combat
@onready var casting: PlayerCasting = $Casting


## Called by Game after instantiate() and BEFORE add_child(): the child
## components consume these in their _ready(), which only builds defaults
## when the exported resource is null.
func setup_identity(
	sheet: CharacterSheet, player_inventory: Inventory, player_journal: Journal
) -> void:
	($Stats as StatsComponent).sheet = sheet
	($Inventory as InventoryComponent).inventory = player_inventory
	journal = player_journal


## Flat speed scaled by encumbrance (the 001→002→003 hookup, criterion 7).
func get_move_speed() -> float:
	return speed * inventory_component.get_speed_multiplier()


## Opens the journal reader (spec 005). Closing while open is the panel's
## job — it pauses the tree, so this handler never fires while it is up.
func open_journal() -> void:
	if _journal_panel != null:
		return
	_journal_panel = JOURNAL_PANEL_SCENE.instantiate()
	add_child(_journal_panel)
	_journal_panel.closed.connect(_on_journal_panel_closed)
	_journal_panel.open(journal)


func _on_journal_panel_closed() -> void:
	_journal_panel = null


func _on_cast_failed() -> void:
	show_notice(HudNotice.CAST_FAILED)


func _on_spell_learned(spell: SpellDef) -> void:
	show_notice(HudNotice.WORKING_LEARNED % spell.display_name)


## Queues a brief fading HUD line (spec 006) — for journal writes outside
## dialogue; the dialogue panel keeps its own inline transcript notices.
func show_notice(text: String) -> void:
	hud_notice.show_notice(text)


func _ready() -> void:
	if journal == null:
		journal = Journal.new()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	detector.target_changed.connect(hud_prompt.set_target)
	hud_bars.bind(stats)
	combat.died.connect(death_overlay.open)
	casting.cast_failed.connect(_on_cast_failed)
	casting.spell_learned.connect(_on_spell_learned)


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
	elif event.is_action_pressed("cast") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		casting.try_cast()
	elif event.is_action_pressed("cycle_spell"):
		casting.cycle()
	elif event.is_action_pressed("journal"):
		open_journal()
	elif event.is_action_pressed("quicksave"):
		# Calls down into the sanctioned autoload's own mutation API (the
		# TransitionDoor/DeathOverlay precedent); Game stays UI-free, so
		# the notice is ours.
		if Game.save_game():
			show_notice(HudNotice.GAME_SAVED)
	elif event.is_action_pressed("quickload"):
		if not Game.load_game():
			show_notice(HudNotice.NO_SAVE_TO_LOAD)
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
