class_name InteractionDetector
extends RayCast3D
## Camera-forward ray that reports the Interactable under the crosshair.
## Passive sensor: emits `target_changed` on change only; the player consumes
## the `interact` input and calls `try_interact()`.

signal target_changed(target: Interactable)

const BALANCE_PATH := "res://data/balance/balance_config.tres"

@export var config: BalanceConfig

var current_target: Interactable = null

## Instance id of current_target (0 = none); survives the target being freed
## so a pickup that queue_free()s still reads as a change to null.
var _current_target_id: int = 0


func _ready() -> void:
	if config == null:
		config = load(BALANCE_PATH) as BalanceConfig
	target_position = Vector3(0, 0, -config.interact_range)
	if owner is CollisionObject3D:
		add_exception(owner)


func _physics_process(_delta: float) -> void:
	_refresh_target()


## Immediate re-query for tests: raycasts otherwise only update on physics ticks.
func force_refresh() -> void:
	force_raycast_update()
	_refresh_target()


func try_interact() -> void:
	if _current_target_id != 0 and is_instance_valid(current_target):
		current_target.interact(owner)


func _refresh_target() -> void:
	var target: Interactable = null
	var collider: Object = get_collider() if is_colliding() else null
	if collider is Node:
		target = Interactable.find_in(collider)
	var target_id: int = target.get_instance_id() if target != null else 0
	if target_id == _current_target_id:
		return
	_current_target_id = target_id
	current_target = target
	target_changed.emit(target)
