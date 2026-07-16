extends GutTest
## Targeting via camera raycast (spec 003, acceptance criterion 1).

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _root: Node3D
var _camera: Camera3D
var _detector: InteractionDetector


func before_each() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_root = Node3D.new()
	_camera = Camera3D.new()
	_root.add_child(_camera)
	_detector = InteractionDetector.new()
	_camera.add_child(_detector)
	_detector.owner = _root
	add_child_autofree(_root)


## A 1m cube StaticBody3D with an Interactable child, centered at -z on the ray.
func _add_target(z: float, with_interactable := true, display_name := "Test Prop") -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	if with_interactable:
		var interactable := Interactable.new()
		interactable.display_name = display_name
		body.add_child(interactable)
	body.position = Vector3(0, 0, z)
	_root.add_child(body)
	return body


## Physics bodies only join the space on a physics tick; settle before raycasting.
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_detector.force_refresh()


func test_ray_length_sourced_from_balance_config() -> void:
	assert_almost_eq(_detector.target_position.length(), _config.interact_range, 0.001)


func test_reports_interactable_within_range() -> void:
	var body := _add_target(-1.5)
	await _settle()
	assert_eq(_detector.current_target, Interactable.find_in(body))


func test_target_changed_fires_exactly_on_change() -> void:
	var body := _add_target(-1.5)
	watch_signals(_detector)
	await _settle()
	_detector.force_refresh()
	_detector.force_refresh()
	assert_signal_emit_count(_detector, "target_changed", 1)
	assert_signal_emitted_with_parameters(_detector, "target_changed",
			[Interactable.find_in(body)])
	body.position = Vector3(0, 0, -100.0)
	await _settle()
	assert_signal_emit_count(_detector, "target_changed", 2)
	assert_null(_detector.current_target)


func test_no_target_beyond_interact_range() -> void:
	# Cube face sits half a meter nearer than its center; keep it past the ray tip.
	_add_target(-(_config.interact_range + 1.0))
	await _settle()
	assert_null(_detector.current_target)


func test_occluder_blocks_target() -> void:
	_add_target(-2.0)
	_add_target(-1.0, false)
	await _settle()
	assert_null(_detector.current_target)


func test_try_interact_reaches_target_with_owner() -> void:
	var body := _add_target(-1.5)
	var interactable := Interactable.find_in(body)
	await _settle()
	watch_signals(interactable)
	_detector.try_interact()
	assert_signal_emitted_with_parameters(interactable, "interacted", [_root])


func test_try_interact_without_target_is_noop() -> void:
	await _settle()
	assert_null(_detector.current_target)
	_detector.try_interact()
	pass_test("no crash with no target")
