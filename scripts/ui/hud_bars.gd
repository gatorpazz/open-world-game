class_name HudBars
extends Control
## Ugly-but-functional health, stamina, and mana bars (specs 004 and 008),
## plus the ward bar — visible only while a ward holds. Pulls initial
## values on bind, then follows the component signals.

@onready var health_bar: ProgressBar = $Health
@onready var stamina_bar: ProgressBar = $Stamina
@onready var mana_bar: ProgressBar = $Mana
@onready var ward_bar: ProgressBar = $Ward


func bind(stats: StatsComponent) -> void:
	stats.health_changed.connect(_on_health_changed)
	stats.stamina_changed.connect(_on_stamina_changed)
	stats.mana_changed.connect(_on_mana_changed)
	_on_health_changed(stats.current_health, stats.sheet.get_max_health())
	_on_stamina_changed(stats.current_stamina, stats.sheet.get_max_stamina())
	_on_mana_changed(stats.current_mana, stats.sheet.get_max_mana())


func bind_ward(combat: PlayerCombat) -> void:
	combat.ward_changed.connect(_on_ward_changed)
	ward_bar.hide()  # no ward until one is cast


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current


func _on_mana_changed(current: float, max_value: float) -> void:
	mana_bar.max_value = max_value
	mana_bar.value = current


func _on_ward_changed(current: float, max_value: float) -> void:
	ward_bar.visible = current > 0.0
	ward_bar.max_value = maxf(max_value, 1.0)
	ward_bar.value = current
