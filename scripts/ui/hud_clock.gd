class_name HudClock
extends Control
## The bell + circuit-day readout on the player HUD (spec 020), bound to
## Game.time_changed. Reads the clock; never mutates it.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig

@onready var label: Label = $Label


## Binds to the clock (the HudBars.bind precedent) — the player calls this once.
func bind() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	Game.time_changed.connect(_on_time_changed)
	refresh()


func _on_time_changed(_day: int, _bell: int) -> void:
	refresh()


func refresh() -> void:
	label.text = (
		"Circuit-day %d · bell %d" % [Game.clock.circuit_day(_config), Game.clock.get_bell()]
	)
