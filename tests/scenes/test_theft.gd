extends GutTest
## The acquire choke (spec 017, acceptance criterion 4): taking an owned item is
## theft — always flagged stolen, and fined only when an NPC witnessed it.
## Runs against the real Game autoload's bounty ledger, saved and restored.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const SWIFT := preload("res://data/npcs/swift.tres")
const IRON_SWORD := preload("res://data/items/iron_sword.tres")  # base_value 50

var _game: Node
var _saved_bounty: BountyLedger
var _root: Node3D
var _player: Player


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_bounty = _game.bounty
	_game.bounty = BountyLedger.new()
	_root = Node3D.new()
	add_child_autofree(_root)
	_player = PLAYER_SCENE.instantiate()
	_root.add_child(_player)


func after_each() -> void:
	_game.bounty = _saved_bounty


func _spawn_witness(at: Vector3) -> void:
	var npc := NPC_SCENE.instantiate() as Npc
	npc.def = SWIFT
	npc.position = at
	_root.add_child(npc)


func _stolen_swords() -> Array[ItemStack]:
	return _player.inventory_component.inventory.stacks.filter(
		func(s: ItemStack) -> bool: return s.item == IRON_SWORD and s.stolen
	)


func test_unowned_take_is_a_clean_pickup() -> void:
	var witnessed := Theft.acquire(_player, _player.inventory_component, IRON_SWORD, 1, &"")
	assert_false(witnessed, "an unowned take is never a crime")
	assert_eq(_player.inventory_component.inventory.count_of(IRON_SWORD), 1, "the item is taken")
	assert_true(_stolen_swords().is_empty(), "and it is not flagged stolen")
	assert_eq(_game.bounty.get_bounty(&"wardens"), 0, "no bounty")


func test_owned_but_unseen_take_is_stolen_without_bounty() -> void:
	# No NPC in the world — nobody sees.
	var witnessed := Theft.acquire(_player, _player.inventory_component, IRON_SWORD, 1, &"suddel")
	assert_false(witnessed, "unseen: not witnessed")
	assert_eq(_stolen_swords().size(), 1, "the goods are hot")
	assert_eq(_game.bounty.get_bounty(&"wardens"), 0, "but no bounty — you got away with it")


func test_owned_and_witnessed_take_accrues_bounty() -> void:
	_spawn_witness(Vector3(0, 0, -3))  # in range, clear line of sight
	await get_tree().physics_frame
	await get_tree().physics_frame

	var witnessed := Theft.acquire(_player, _player.inventory_component, IRON_SWORD, 1, &"suddel")

	assert_true(witnessed, "a bystander saw it")
	assert_eq(_stolen_swords().size(), 1, "the goods are hot")
	assert_eq(
		_game.bounty.get_bounty(&"wardens"),
		CrimeRules.theft_bounty(IRON_SWORD, _player.config),
		"the bounty accrues to the jurisdiction"
	)
