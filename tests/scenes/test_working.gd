extends GutTest
## The casting enforcement choke (spec 018, acceptance criteria 3-5): an
## unlicensed working draws notice; a witnessed one also draws a warden bounty;
## overcast is always seen and its crossing docks reputation once. Drives
## Working.report directly (the Theft-test pattern) against the real Game
## ledgers, saved and restored.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const SWIFT := preload("res://data/npcs/swift.tres")
const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _game: Node
var _saved_notice: NoticeLedger
var _saved_bounty: BountyLedger
var _saved_standing: FactionStanding
var _root: Node3D
var _player: Player
var _hearth_charm: SpellDef  # minor_bolt — min_skill 0, no order
var _unlicensed: SpellDef  # greater_bolt — ordained flame, no charter obtainable


func before_each() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_game = get_node("/root/Game")
	_saved_notice = _game.notice
	_saved_bounty = _game.bounty
	_saved_standing = _game.faction_standing
	_game.notice = NoticeLedger.new()
	_game.bounty = BountyLedger.new()
	_game.faction_standing = FactionStanding.new()
	_root = Node3D.new()
	add_child_autofree(_root)
	_player = PLAYER_SCENE.instantiate()
	_root.add_child(_player)
	var spells := SpellLibrary.get_spells()
	_hearth_charm = spells[&"minor_bolt"]
	_unlicensed = spells[&"greater_bolt"]


func after_each() -> void:
	_game.notice = _saved_notice
	_game.bounty = _saved_bounty
	_game.faction_standing = _saved_standing


func _spawn_witness(at: Vector3) -> void:
	var npc := NPC_SCENE.instantiate() as Npc
	npc.def = SWIFT
	npc.position = at
	_root.add_child(npc)


func test_a_hearth_charm_working_is_free() -> void:
	var witnessed := Working.report(_player, _hearth_charm)
	assert_false(witnessed, "hearth-charm is never a crime")
	assert_eq(_game.notice.get_notice(), 0, "and draws no notice")
	assert_eq(_game.bounty.get_bounty(&"wardens"), 0, "and no bounty")


func test_an_unlicensed_working_unseen_draws_notice_only() -> void:
	# No NPC in the world — nobody sees the working.
	var witnessed := Working.report(_player, _unlicensed)
	assert_false(witnessed, "unseen: not witnessed")
	assert_eq(_game.notice.get_notice(), _config.notice_per_unlicensed_working, "notice accrues")
	assert_eq(_game.bounty.get_bounty(&"wardens"), 0, "but no bounty")


func test_a_witnessed_unlicensed_working_draws_a_bounty() -> void:
	_spawn_witness(Vector3(0, 0, -3))  # in range, clear line of sight
	await get_tree().physics_frame
	await get_tree().physics_frame

	var witnessed := Working.report(_player, _unlicensed)

	assert_true(witnessed, "a bystander saw the working")
	assert_eq(_game.notice.get_notice(), _config.notice_per_unlicensed_working, "notice accrues")
	assert_eq(
		_game.bounty.get_bounty(&"wardens"),
		_config.unlicensed_working_fine,
		"and a warden fine lands"
	)


func test_the_hud_shows_notice_and_lights_the_beacon() -> void:
	_game.notice.add(30)
	_player.refresh_notice()
	assert_true(_player.hud_bars.notice_bar.visible, "the notice bar shows once regard is drawn")
	assert_eq(_player.hud_bars.notice_bar.value, 30.0, "at the drawn value")
	assert_false(_player.hud_bars.overcast_label.visible, "the beacon is dark below the threshold")

	_game.notice.add(_config.overcast_threshold)  # now overcast
	_player.refresh_notice()
	assert_true(_player.hud_bars.overcast_label.visible, "the beacon lights at overcast")


func test_overcast_is_always_witnessed() -> void:
	# Already overcast, and no NPC present — the sky still has your measure.
	_game.notice.add(_config.overcast_threshold)
	var witnessed := Working.report(_player, _unlicensed)
	assert_true(witnessed, "an overcast caster is always seen")
	assert_eq(
		_game.bounty.get_bounty(&"wardens"), _config.unlicensed_working_fine, "so a fine lands"
	)


func test_crossing_into_overcast_docks_reputation_once() -> void:
	# A warden member (adjust_reputation is a no-op otherwise), one notice step
	# below the threshold.
	_game.faction_standing.seed_if_absent(&"wardens", 1, 100)
	_game.notice.add(_config.overcast_threshold - 1)
	var dock := _config.crime_reputation_dock

	# This cast crosses: it is witnessed (now overcast) AND a first-time crossing,
	# so both the report-working dock and the one-time crossing dock apply.
	Working.report(_player, _unlicensed)
	assert_eq(
		_game.faction_standing.get_reputation(&"wardens"),
		100 - 2 * dock,
		"the crossing cast docks twice (witnessed + the one-time crossing)"
	)

	# A later cast is already overcast — witnessed dock only, no repeat crossing.
	Working.report(_player, _unlicensed)
	assert_eq(
		_game.faction_standing.get_reputation(&"wardens"),
		100 - 3 * dock,
		"a subsequent overcast cast docks once (no repeated crossing dock)"
	)
