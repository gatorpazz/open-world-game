extends Node3D
## Debug scene for spec 003. Run with F6; Game spawns the player at "default".
##
## Manual checklist:
## - HUD prompt appears/disappears per target, with the right verb per object.
## - E takes items; taking BOTH Sack of Ore piles (6 sacks, 180 weight) flips
##   encumbrance and visibly slows movement.
## - Worn Chest: Take moves one stack, Take All empties it, contents persist
##   across close/reopen.
## - Wooden Door swings open and closed on use.
## - The purple load-door round-trips to the interior and back, landing at the
##   named spawn points; loot and skill xp survive the trip.
## - Swift: "Talk Swift" prompt, placeholder line in the output log.
