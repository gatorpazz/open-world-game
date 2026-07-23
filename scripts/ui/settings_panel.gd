class_name SettingsPanel
extends CanvasLayer
## The settings menu (spec 025), on the JournalPanel pause-lifecycle: mouse
## sensitivity + master volume sliders bound to GameSettings. Changes apply live
## (the Player reads GameSettings each look; the audio bus updates on the volume
## slider) and persist to settings.cfg on close.

signal closed

const SENSITIVITY_MIN := 0.0005
const SENSITIVITY_MAX := 0.006
const SENSITIVITY_STEP := 0.0001
const VOLUME_STEP := 0.05

@onready var sensitivity_slider: HSlider = $Dim/Panel/Layout/Sensitivity/Slider
@onready var volume_slider: HSlider = $Dim/Panel/Layout/Volume/Slider
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	sensitivity_slider.min_value = SENSITIVITY_MIN
	sensitivity_slider.max_value = SENSITIVITY_MAX
	sensitivity_slider.step = SENSITIVITY_STEP
	sensitivity_slider.value = GameSettings.mouse_sensitivity
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = VOLUME_STEP
	volume_slider.value = GameSettings.master_volume
	# Connect after seeding the values so the initial set doesn't fire a change.
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # a hosting menu must not also close
		close()


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameSettings.save_to_disk()
	closed.emit()
	queue_free()


func _on_sensitivity_changed(value: float) -> void:
	GameSettings.mouse_sensitivity = value


func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings.apply()
