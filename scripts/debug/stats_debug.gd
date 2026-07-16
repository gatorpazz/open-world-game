extends Control
## Debug harness for the stats system: a button per skill grants xp, a button
## per attribute spends a point, and a live dump shows the whole sheet.
## Buttons are generated from the sheet's data, not hand-placed.

const XP_PER_CLICK := 25

@onready var stats: StatsComponent = $Stats
@onready var skill_buttons: VBoxContainer = $Layout/SkillButtons
@onready var attribute_buttons: VBoxContainer = $Layout/AttributeButtons
@onready var sheet_dump: RichTextLabel = $Layout/SheetDump


func _ready() -> void:
	stats.skill_leveled.connect(_on_stats_changed.unbind(2))
	stats.leveled_up.connect(_on_stats_changed.unbind(1))
	stats.attribute_changed.connect(_on_stats_changed.unbind(2))
	stats.health_changed.connect(_on_stats_changed.unbind(2))
	stats.mana_changed.connect(_on_stats_changed.unbind(2))
	stats.stamina_changed.connect(_on_stats_changed.unbind(2))
	_build_buttons()
	_refresh()


func _build_buttons() -> void:
	for skill_id: StringName in stats.sheet.skills:
		var button := Button.new()
		button.text = "+%d xp  %s" % [XP_PER_CLICK, String(skill_id).capitalize()]
		button.pressed.connect(_on_skill_xp_pressed.bind(skill_id))
		skill_buttons.add_child(button)
	for attribute: StringName in CharacterSheet.ATTRIBUTE_NAMES:
		var button := Button.new()
		button.text = "+1  %s" % String(attribute).capitalize()
		button.pressed.connect(_on_spend_pressed.bind(attribute))
		attribute_buttons.add_child(button)


func _on_skill_xp_pressed(skill_id: StringName) -> void:
	stats.gain_skill_xp(skill_id, XP_PER_CLICK)
	_refresh()


func _on_spend_pressed(attribute: StringName) -> void:
	stats.spend_attribute_point(attribute)
	_refresh()


func _on_stats_changed() -> void:
	_refresh()


func _refresh() -> void:
	var sheet := stats.sheet
	var lines: PackedStringArray = []
	lines.append("[b]Level %d[/b]   major level-ups: %d/%d   unspent points: %d" % [
		sheet.level, sheet.major_level_ups, sheet.config.level_up_threshold,
		sheet.unspent_attribute_points,
	])
	lines.append("")
	lines.append("[b]Attributes[/b]")
	for attribute: StringName in CharacterSheet.ATTRIBUTE_NAMES:
		lines.append("  %-12s %3d" % [attribute, sheet.attributes[attribute]])
	lines.append("")
	lines.append("[b]Derived[/b]")
	lines.append("  health   %5.1f / %5.1f" % [stats.current_health, sheet.get_max_health()])
	lines.append("  mana     %5.1f / %5.1f" % [stats.current_mana, sheet.get_max_mana()])
	lines.append("  stamina  %5.1f / %5.1f" % [stats.current_stamina, sheet.get_max_stamina()])
	lines.append("  carry    %5.1f" % sheet.get_carry_capacity())
	lines.append("")
	lines.append("[b]Skills[/b]  (* = major)")
	for skill_id: StringName in sheet.skills:
		var marker := "*" if sheet.major_skills.has(skill_id) else " "
		lines.append("%s %-12s %3d   xp %d/%d" % [
			marker, skill_id, sheet.skills[skill_id],
			sheet.skill_xp[skill_id], sheet.xp_required(skill_id),
		])
	sheet_dump.text = "\n".join(lines)
