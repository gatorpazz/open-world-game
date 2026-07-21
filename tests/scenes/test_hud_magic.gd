extends GutTest
## HUD bindings for magic (spec 008, criterion 9): the mana bar follows
## mana_changed, the ward bar appears/updates/hides with ward_changed, and
## HudSpell tracks the selection through cycling and learning.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _root: Node3D
var _player: Player


func before_each() -> void:
	SpellLibrary.reset()
	_root = Node3D.new()
	add_child_autofree(_root)
	_player = PLAYER_SCENE.instantiate() as Player
	_root.add_child(_player)
	_player.set_physics_process(false)
	_player.combat.set_physics_process(false)
	_player.casting.set_physics_process(false)


func test_mana_bar_pulls_initial_values_and_follows_the_signal() -> void:
	var bar: ProgressBar = _player.hud_bars.mana_bar
	assert_almost_eq(bar.max_value, float(_player.stats.sheet.get_max_mana()), 0.001)
	assert_almost_eq(bar.value, _player.stats.current_mana, 0.001)
	_player.stats.set_current_mana(10.0)
	assert_almost_eq(bar.value, 10.0, 0.001)


func test_ward_bar_appears_drains_and_hides() -> void:
	var bar: ProgressBar = _player.hud_bars.ward_bar
	assert_false(bar.visible, "hidden before any ward")
	_player.combat.apply_ward(20.0, 30.0)
	assert_true(bar.visible)
	assert_almost_eq(bar.value, 20.0, 0.001)
	_player.combat.hurt_box.take_hit(6.0, _root)
	assert_almost_eq(bar.value, 14.0, 0.001)
	_player.combat._physics_process(30.01)
	assert_false(bar.visible, "hidden again after expiry")


func test_spell_label_shows_selection_and_updates_on_cycle_and_learn() -> void:
	var hud_spell: HudSpell = _player.hud_spell
	assert_true(hud_spell.visible)
	assert_eq(hud_spell.label.text, _player.casting.get_selected().display_name)
	_player.casting.cycle()
	assert_eq(hud_spell.label.text, _player.casting.get_selected().display_name)
	# Learning refreshes the list; the label keeps tracking the selection.
	_player.stats.gain_skill_xp(&"warding", 1000000)
	assert_eq(hud_spell.label.text, _player.casting.get_selected().display_name)
