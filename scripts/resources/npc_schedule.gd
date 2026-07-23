class_name NPCSchedule
extends Resource
## An NPC's present-window (spec 020): the one bell-range they hold their post,
## shuttered outside it (canon: "between bells the counter is shuttered"). A
## sub-resource on NPCDef; a null schedule means always present. Presence is
## derived from Game.clock each bell rollover — no save blob (the
## world-state-from-clock fence). Presence-lite: one window, no pathing.

@export var present_from_bell: int = 0
@export var present_to_bell: int = 0


## Whether the NPC is at their post at this bell. A zero-width window (from ==
## to) means no restriction (present all day); a window with from > to wraps
## past a day's end.
func is_present(bell: int) -> bool:
	if present_from_bell == present_to_bell:
		return true
	if present_from_bell < present_to_bell:
		return bell >= present_from_bell and bell < present_to_bell
	return bell >= present_from_bell or bell < present_to_bell
