extends GutTest
## The Persuasion orchestrator (spec 019, acceptance criterion 3): a move rolls
## against the NPC's disposition and shifts its modifier through Game; a bribe
## spends beads first and aborts if unpayable. The roll is forced deterministic
## by a duplicated config whose chance clamps are opened to [0, 1] — a chance of
## 1.0 always lands (randf() < 1.0), a chance of 0.0 never does.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const NPC := &"tansy"

var _config: BalanceConfig
var _player: Player
var _game: Node
var _saved: DispositionLedger


func before_each() -> void:
	_config = (load(BALANCE_PATH) as BalanceConfig).duplicate()
	# Open the clamps so extreme inputs give a certain 1.0 / 0.0 chance.
	_config.persuade_chance_min = 0.0
	_config.persuade_chance_max = 1.0
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_game = get_node("/root/Game")
	_saved = _game.disposition
	_game.disposition = DispositionLedger.new()


func after_each() -> void:
	_game.disposition = _saved


func _inventory() -> InventoryComponent:
	return _player.inventory_component


func test_a_certain_admire_lands_and_shifts_the_modifier() -> void:
	# High skill + warm disposition ⇒ chance clamps to 1.0 ⇒ randf() < 1.0 always.
	var line := Persuasion.attempt(DispositionRules.ADMIRE, NPC, 100, 90, _inventory(), _config)
	assert_eq(
		_game.disposition.get_modifier(NPC),
		_config.persuade_gain_admire,
		"a landed admire applies its gain"
	)
	assert_ne(line, "", "an outcome line is spoken")


func test_a_certain_failed_intimidate_backfires() -> void:
	# Zero skill + warm disposition ⇒ intimidate chance clamps to 0.0 ⇒ never lands.
	Persuasion.attempt(DispositionRules.INTIMIDATE, NPC, 0, 90, _inventory(), _config)
	assert_eq(
		_game.disposition.get_modifier(NPC),
		-_config.intimidate_backfire,
		"a failed intimidate docks the modifier"
	)


func test_bribe_spends_beads_on_a_certain_success() -> void:
	_inventory().add_gold(500)
	var before := _inventory().inventory.gold
	var cost := DispositionRules.bribe_cost(90, _config)
	Persuasion.attempt(DispositionRules.BRIBE, NPC, 100, 90, _inventory(), _config)
	assert_eq(_inventory().inventory.gold, before - cost, "the bribe spent its beads")
	assert_eq(
		_game.disposition.get_modifier(NPC),
		_config.persuade_gain_bribe,
		"a landed bribe applies its gain"
	)


func test_bribe_aborts_when_the_beads_are_short() -> void:
	# No gold ⇒ can't pay ⇒ no roll, no move.
	var line := Persuasion.attempt(DispositionRules.BRIBE, NPC, 100, 90, _inventory(), _config)
	assert_eq(_game.disposition.get_modifier(NPC), 0, "an unpayable bribe moves nothing")
	assert_eq(_inventory().inventory.gold, 0, "no beads are spent")
	assert_true(line.contains("beads"), "the line explains the shortfall")
