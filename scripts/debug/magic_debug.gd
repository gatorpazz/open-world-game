extends Node3D
## Debug arena for spec 008. Run with F6; Game spawns the player at "default".
##
## Manual checklist:
## - RMB casts Flamespark: mana drops 8 and trickles back; the vault rat
##   dies in 2 bolts; a bolt into the wall whiffs (mana still spent).
## - R cycles Flamespark -> Tidemend -> Stoneroof; the HUD label follows.
## - Stoneroof, then a scar-hound bite: the ward bar drains before health.
## - Keys 1/2/3 pump evocation/mending/warding xp: warding 25 announces
##   "New working: Greatroof"; evocation 50 announces Flamelash.
## - Casting on an empty pool shows "Nothing left to draw."
## - F5/F9: skills persist, selection resets to Flamespark, ward is gone.

const XP_PER_PRESS := 50
const PUMP_KEYS: Dictionary[int, StringName] = {
	KEY_1: &"evocation",
	KEY_2: &"mending",
	KEY_3: &"warding",
}
const WATCHED_SKILLS: Array[StringName] = [&"evocation", &"mending", &"warding"]

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
	_player.combat.hurt_box.hit_taken.connect(_on_player_hit)
	for creature: Creature in $Creatures.get_children():
		creature.hurt_box.hit_taken.connect(_on_creature_hit)


func _unhandled_key_input(event: InputEvent) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if PUMP_KEYS.has(key.keycode):
		_player.stats.gain_skill_xp(PUMP_KEYS[key.keycode], XP_PER_PRESS)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sheet := _player.stats.sheet
	var selected := _player.casting.get_selected()
	var castable: Array[String] = []
	for spell: SpellDef in _player.casting.get_castable():
		castable.append(spell.display_name)
	var lines: Array[String] = [
		"health %.1f/%.1f" % [_player.stats.current_health, sheet.get_max_health()],
		"mana %.1f/%.1f" % [_player.stats.current_mana, sheet.get_max_mana()],
		"ward %.1f (%.1fs)" % [_player.combat.get_ward(), _player.combat.get_ward_seconds()],
		"selected: %s" % (selected.display_name if selected != null else "-"),
		"castable: %s" % ", ".join(castable),
		"last raw damage: dealt %.1f | taken %.1f" % [_last_dealt, _last_taken],
	]
	for skill_id: StringName in WATCHED_SKILLS:
		lines.append("%s L%d xp %d" % [skill_id, sheet.skills[skill_id], sheet.skill_xp[skill_id]])
	debug_label.text = "\n".join(lines)


func _on_player_hit(raw_damage: float, _attacker: Node3D) -> void:
	_last_taken = raw_damage


func _on_creature_hit(raw_damage: float, _attacker: Node3D) -> void:
	_last_dealt = raw_damage
