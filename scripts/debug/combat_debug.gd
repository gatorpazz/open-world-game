extends Node3D
## Debug arena for spec 004. Run with F6; Game spawns the player at "default".
##
## Manual checklist:
## - LMB swings: stamina drops per swing and regenerates; spamming faster than
##   swing_time is ignored; swinging with the bow equipped does nothing.
## - Marsh Rat dies in ~3 sword hits and leaves "Marsh Rat Remains" (pelt).
## - Bog Hound chases on sight; retreat past its leash and it trots home.
## - The wall: the thrall behind it doesn't aggro, and swings into it whiff.
## - Barrow Thrall hits hard through armor — let it kill you to see the death
##   overlay; Reload restarts the arena with xp and loot intact.
## - Watch the label: skill xp ticks on weapon hits, blocks, and armored hits.

const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const RUSTY_CLAYMORE := preload("res://data/items/rusty_claymore.tres")
const HUNTING_BOW := preload("res://data/items/hunting_bow.tres")
const WOODEN_SHIELD := preload("res://data/items/wooden_shield.tres")
const LEATHER_CUIRASS := preload("res://data/items/leather_cuirass.tres")
const IRON_HELM := preload("res://data/items/iron_helm.tres")
const WATCHED_SKILLS: Array[StringName] = [&"blades", &"block", &"light_armor", &"heavy_armor"]

var _player: Player
var _last_dealt := 0.0
var _last_taken := 0.0

@onready var debug_label: Label = $DebugHud/DebugLabel


func _ready() -> void:
	# Game injects the player one frame after the scene loads.
	await get_tree().process_frame
	_player = Game.player
	if _player == null:
		return
	_grant_starter_kit()
	_player.combat.hurt_box.hit_taken.connect(_on_player_hit)
	for creature: Creature in $Creatures.get_children():
		creature.hurt_box.hit_taken.connect(_on_creature_hit)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sheet := _player.stats.sheet
	var lines: Array[String] = [
		"health %.1f/%.1f" % [_player.stats.current_health, sheet.get_max_health()],
		"stamina %.1f/%.1f" % [_player.stats.current_stamina, sheet.get_max_stamina()],
		"last raw damage: dealt %.1f | taken %.1f" % [_last_dealt, _last_taken],
	]
	for skill_id: StringName in WATCHED_SKILLS:
		lines.append("%s L%d xp %d" % [skill_id, sheet.skills[skill_id], sheet.skill_xp[skill_id]])
	debug_label.text = "\n".join(lines)


## Equips the full starter kit once. The persistent inventory outlives a
## death-reload, so re-running _ready must not duplicate gear.
func _grant_starter_kit() -> void:
	var inv := _player.inventory_component
	if inv.get_equipped_weapon() != null:
		return
	for item: ItemDef in [IRON_SWORD, WOODEN_SHIELD, LEATHER_CUIRASS, IRON_HELM]:
		inv.add_item(item)
		inv.equip(item)
	inv.add_item(RUSTY_CLAYMORE)
	inv.add_item(HUNTING_BOW)


func _on_player_hit(raw_damage: float, _attacker: Node3D) -> void:
	_last_taken = raw_damage


func _on_creature_hit(raw_damage: float, _attacker: Node3D) -> void:
	_last_dealt = raw_damage
