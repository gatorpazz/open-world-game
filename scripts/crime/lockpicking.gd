class_name Lockpicking
extends RefCounted
## The lock gate (spec 017): the one path a locked container or door runs
## through when the actor tries to open it. A held key opens it outright; else
## a lockpick is spent and the odds are rolled (LockRules.pick_chance) — the
## one place crime rolls dice, per the director's hybrid ruling. Impure (it
## reads the actor's inventory/skill and flashes the HUD); the odds come from
## LockRules + the balance config.

const LOCKPICK_ID := &"lockpick"


## Whether the lock yields to the actor. An unlocked target opens; a held
## matching key opens without spending a pick; otherwise one lockpick is
## consumed and the roll decides. Flashes the outcome on the actor's HUD.
static func try_open(locked: bool, difficulty: int, key_id: StringName, actor: Player) -> bool:
	if not locked:
		return true
	var items := ItemLibrary.get_items()
	var inventory := actor.inventory_component.inventory
	if key_id != &"" and items.has(key_id) and inventory.count_of(items[key_id]) > 0:
		return true
	if not items.has(LOCKPICK_ID) or inventory.count_of(items[LOCKPICK_ID]) == 0:
		actor.show_notice(HudNotice.NO_LOCKPICK)
		return false
	actor.inventory_component.remove_item(items[LOCKPICK_ID], 1)
	var security: int = actor.stats.sheet.skills.get(&"security", 0)
	var opened := randf() < LockRules.pick_chance(security, difficulty, actor.config)
	actor.show_notice(HudNotice.LOCK_PICKED if opened else HudNotice.LOCK_RESISTED)
	return opened
