class_name CreationForm
extends Control
## Character-creation form (spec 009): pick exactly 5 major skills and one
## favored attribute, with a live derived-stats preview. Pure UI + selection
## state — it talks to the world only through its signals; TitleScreen wires
## confirmed to Game.start_new_game. Button handlers route through the same
## public API tests call.

signal confirmed(sheet: CharacterSheet)
signal cancelled

var _config: BalanceConfig
var _selected_majors: Array[StringName] = []
var _favored: StringName = &""
var _major_buttons: Dictionary[StringName, Button] = {}
var _favored_buttons: Dictionary[StringName, Button] = {}
var _favored_group := ButtonGroup.new()

@onready var skill_columns: HBoxContainer = %SkillColumns
@onready var majors_counter: Label = %MajorsCounter
@onready var favored_row: HBoxContainer = %FavoredRow
@onready var preview_label: Label = %PreviewLabel
@onready var back_button: Button = %BackButton
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	_config = load(StatsComponent.BALANCE_PATH) as BalanceConfig
	_build_skill_columns()
	_build_favored_row()
	back_button.pressed.connect(_on_back_pressed)
	confirm_button.pressed.connect(confirm)
	_refresh()


## Selects or deselects a major. Returns false and changes nothing when the
## id is unknown or a sixth selection is attempted.
func toggle_major(skill_id: StringName) -> bool:
	if _selected_majors.has(skill_id):
		_selected_majors.erase(skill_id)
		_refresh()
		return true
	if not _major_buttons.has(skill_id):
		return false
	if _selected_majors.size() >= CharacterSheet.MAJOR_SKILL_COUNT:
		return false
	_selected_majors.append(skill_id)
	_refresh()
	return true


## Sets (replaces) the favored attribute; an unknown attribute is refused.
func set_favored(attribute: StringName) -> void:
	if not CharacterSheet.ATTRIBUTE_NAMES.has(attribute):
		push_warning("set_favored: unknown attribute '%s'" % attribute)
		return
	_favored = attribute
	_refresh()


func can_confirm() -> bool:
	return _selected_majors.size() == CharacterSheet.MAJOR_SKILL_COUNT and _favored != &""


## Builds the chosen sheet and emits confirmed. The guard is exercised by
## tests, so it warns instead of erroring.
func confirm() -> void:
	if not can_confirm():
		push_warning(
			(
				"confirm: selection incomplete (%d majors, favored '%s')"
				% [_selected_majors.size(), _favored]
			)
		)
		return
	confirmed.emit(StatsComponent.build_creation_sheet(_selected_majors, _favored))


## A scratch sheet holding config + the candidate attributes only — derived
## getters read nothing else. Drives the preview; exposed for tests.
func preview_sheet() -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.config = _config
	for attribute: StringName in CharacterSheet.ATTRIBUTE_NAMES:
		sheet.attributes[attribute] = _config.attribute_start
	if _favored != &"":
		sheet.set_attribute(_favored, _config.attribute_favored_start)
	return sheet


func _build_skill_columns() -> void:
	var defs := StatsComponent.list_skill_defs()
	for archetype: StringName in SkillDef.ARCHETYPES:
		var column := VBoxContainer.new()
		var header := Label.new()
		header.text = String(archetype).capitalize()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(header)
		for def: SkillDef in defs:
			if def.archetype != archetype:
				continue
			var button := Button.new()
			button.toggle_mode = true
			button.text = def.display_name
			button.toggled.connect(_on_major_toggled.bind(def.id))
			column.add_child(button)
			_major_buttons[def.id] = button
		skill_columns.add_child(column)


func _build_favored_row() -> void:
	for attribute: StringName in CharacterSheet.ATTRIBUTE_NAMES:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _favored_group
		button.text = String(attribute).capitalize()
		button.toggled.connect(_on_favored_toggled.bind(attribute))
		favored_row.add_child(button)
		_favored_buttons[attribute] = button


## Syncs buttons and labels to the selection state — the one render path,
## driven by the same API the buttons call (headless-safe by construction).
func _refresh() -> void:
	majors_counter.text = (
		"Majors: %d / %d" % [_selected_majors.size(), CharacterSheet.MAJOR_SKILL_COUNT]
	)
	var at_limit := _selected_majors.size() >= CharacterSheet.MAJOR_SKILL_COUNT
	for skill_id: StringName in _major_buttons:
		var button := _major_buttons[skill_id]
		var selected := _selected_majors.has(skill_id)
		button.set_pressed_no_signal(selected)
		button.disabled = at_limit and not selected
	for attribute: StringName in _favored_buttons:
		_favored_buttons[attribute].set_pressed_no_signal(attribute == _favored)
	confirm_button.disabled = not can_confirm()
	var sheet := preview_sheet()
	preview_label.text = (
		"Health %.0f   Mana %.0f   Stamina %.0f   Carry %.0f"
		% [
			sheet.get_max_health(),
			sheet.get_max_mana(),
			sheet.get_max_stamina(),
			sheet.get_carry_capacity(),
		]
	)


func _on_major_toggled(pressed: bool, skill_id: StringName) -> void:
	if pressed == _selected_majors.has(skill_id):
		return
	if not toggle_major(skill_id):
		_major_buttons[skill_id].set_pressed_no_signal(false)


func _on_favored_toggled(pressed: bool, attribute: StringName) -> void:
	if pressed:
		set_favored(attribute)


func _on_back_pressed() -> void:
	cancelled.emit()
