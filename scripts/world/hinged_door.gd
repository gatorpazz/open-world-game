class_name HingedDoor
extends StaticBody3D
## A door that swings open/closed around its edge (the scene root sits at the
## hinge; mesh and collision are offset). Blocks/unblocks nav in a later spec.

@export var open_angle_degrees: float = 100.0
@export var swing_seconds: float = 0.4

@onready var interactable: Interactable = $Interactable

var is_open := false

var _tween: Tween


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)


func toggle() -> void:
	is_open = not is_open
	var target := deg_to_rad(open_angle_degrees) if is_open else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	(
		_tween
		. tween_property(self, "rotation:y", target, swing_seconds)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


func _on_interacted(_by: Node) -> void:
	toggle()
