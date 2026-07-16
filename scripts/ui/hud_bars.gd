class_name HudBars
extends Control
## Ugly-but-functional health and stamina bars (spec 004). Mana waits for
## spec 008. Pulls initial values on bind, then follows the stats signals.

@onready var health_bar: ProgressBar = $Health
@onready var stamina_bar: ProgressBar = $Stamina


func bind(stats: StatsComponent) -> void:
	stats.health_changed.connect(_on_health_changed)
	stats.stamina_changed.connect(_on_stamina_changed)
	_on_health_changed(stats.current_health, stats.sheet.get_max_health())
	_on_stamina_changed(stats.current_stamina, stats.sheet.get_max_stamina())


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current
