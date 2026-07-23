class_name GameSettings
extends RefCounted
## Player settings (spec 025): mouse sensitivity + master volume, persisted to
## user://settings.cfg (a ConfigFile). Loaded and applied at boot, read by the
## Player for its look, edited in the SettingsPanel. Static — one live settings
## state; a missing file yields the defaults (so first boot changes nothing).

const PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_MOUSE_SENSITIVITY := 0.002
const DEFAULT_MASTER_VOLUME := 0.8

static var mouse_sensitivity := DEFAULT_MOUSE_SENSITIVITY
static var master_volume := DEFAULT_MASTER_VOLUME


## Reads the settings file into the live values, falling back to the defaults on
## a missing/unreadable file or a missing key.
static func load_from_disk(path := PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
		master_volume = DEFAULT_MASTER_VOLUME
		return
	mouse_sensitivity = float(
		cfg.get_value(SECTION, "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)
	)
	master_volume = float(cfg.get_value(SECTION, "master_volume", DEFAULT_MASTER_VOLUME))


## Writes the live values to the settings file (best-effort, the fire-and-forget
## save precedent).
static func save_to_disk(path := PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.save(path)


## Pushes the live values to the engine: the master audio bus volume. (Mouse
## sensitivity is read by the Player directly.)
static func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))
