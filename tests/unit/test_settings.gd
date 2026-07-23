extends GutTest
## GameSettings + SettingsPanel (spec 025, acceptance criterion 5): the
## settings.cfg round-trip, apply-to-the-master-bus, defaults on a missing file,
## and the panel's sliders updating the live values. Uses a scratch cfg path.

const PATH := "user://test_settings.cfg"
const PANEL_SCENE := preload("res://scenes/ui/settings_panel.tscn")


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()
	# Restore the live defaults so the Player look / audio bus aren't left off.
	GameSettings.mouse_sensitivity = GameSettings.DEFAULT_MOUSE_SENSITIVITY
	GameSettings.master_volume = GameSettings.DEFAULT_MASTER_VOLUME
	GameSettings.apply()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_save_then_load_round_trips() -> void:
	GameSettings.mouse_sensitivity = 0.004
	GameSettings.master_volume = 0.3
	GameSettings.save_to_disk(PATH)

	GameSettings.mouse_sensitivity = 0.0  # drift
	GameSettings.master_volume = 0.0
	GameSettings.load_from_disk(PATH)

	assert_almost_eq(GameSettings.mouse_sensitivity, 0.004, 0.0001, "sensitivity round-trips")
	assert_almost_eq(GameSettings.master_volume, 0.3, 0.001, "volume round-trips")


func test_missing_file_yields_defaults() -> void:
	GameSettings.mouse_sensitivity = 0.005  # drift
	GameSettings.load_from_disk("user://does_not_exist.cfg")
	assert_almost_eq(
		GameSettings.mouse_sensitivity,
		GameSettings.DEFAULT_MOUSE_SENSITIVITY,
		0.0001,
		"a missing file yields the default sensitivity"
	)


func test_apply_sets_the_master_bus_volume() -> void:
	GameSettings.master_volume = 0.5
	GameSettings.apply()
	var bus := AudioServer.get_bus_index("Master")
	assert_almost_eq(
		AudioServer.get_bus_volume_db(bus),
		linear_to_db(0.5),
		0.01,
		"the master bus reflects the setting"
	)


func test_panel_sliders_update_the_live_settings() -> void:
	var panel := PANEL_SCENE.instantiate() as SettingsPanel
	add_child_autofree(panel)

	panel._on_sensitivity_changed(0.003)
	panel._on_volume_changed(0.6)

	assert_almost_eq(
		GameSettings.mouse_sensitivity, 0.003, 0.0001, "the sensitivity slider applies"
	)
	assert_almost_eq(GameSettings.master_volume, 0.6, 0.001, "the volume slider applies")
	get_tree().paused = false
