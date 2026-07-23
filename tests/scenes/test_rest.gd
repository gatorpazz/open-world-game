extends GutTest
## Rest (spec 020, acceptance criterion 5): rest advances the clock + heals; the
## rest key is gated by a wilderness scene and no hostiles; the bed RestPoint
## rests in a settlement. Runs against the real Game.clock, saved and restored.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CREATURE_SCENE := preload("res://scenes/creatures/creature.tscn")
const REST_POINT_SCENE := preload("res://scenes/world/rest_point.tscn")
const VAULT_RAT := preload("res://data/creatures/vault_rat.tres")
const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _game: Node
var _saved_clock: WorldClock
var _root: Node3D
var _player: Player


func before_each() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_game = get_node("/root/Game")
	_saved_clock = _game.clock
	_game.clock = WorldClock.new()
	_root = Node3D.new()
	add_child_autofree(_root)
	_player = PLAYER_SCENE.instantiate()
	_root.add_child(_player)


func after_each() -> void:
	_game.clock = _saved_clock


func _total_bells() -> float:
	return _game.clock.day * _config.bells_per_day + _game.clock.bell


func _spawn_hostile() -> void:
	var creature := CREATURE_SCENE.instantiate() as Creature
	creature.def = VAULT_RAT
	_root.add_child(creature)
	creature.state = Creature.State.CHASE


func test_rest_advances_the_clock_and_heals() -> void:
	_player.stats.set_current_health(1.0)
	var before := _total_bells()
	_player.rest()
	assert_almost_eq(
		_total_bells(), before + _config.rest_bells, 0.001, "the clock advanced by a rest"
	)
	assert_gt(_player.stats.current_health, 1.0, "rest restored health")


func test_rest_key_rests_in_the_wilderness() -> void:
	_root.add_to_group(&"wild_rest")
	_player.stats.set_current_health(1.0)
	_player.try_rest()
	assert_gt(_player.stats.current_health, 1.0, "wilderness rest with no danger heals")


func test_rest_key_refused_in_a_settlement() -> void:
	# _root is not in the wild_rest group — a settlement needs a bed.
	_player.stats.set_current_health(1.0)
	_player.try_rest()
	assert_eq(_player.stats.current_health, 1.0, "no wilderness rest in a settlement")


func test_rest_refused_with_a_hostile_near() -> void:
	_root.add_to_group(&"wild_rest")
	_spawn_hostile()
	_player.stats.set_current_health(1.0)
	_player.try_rest()
	assert_true(_player.hostiles_near(), "a chasing creature is a hostile")
	assert_eq(_player.stats.current_health, 1.0, "no rest while hunted")


func test_the_bed_rests_the_player() -> void:
	var bed := REST_POINT_SCENE.instantiate() as RestPoint
	_root.add_child(bed)
	_player.stats.set_current_health(1.0)
	bed.interactable.interact(_player)
	assert_gt(_player.stats.current_health, 1.0, "the bed rests even in a settlement")
