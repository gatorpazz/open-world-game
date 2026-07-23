class_name WorldClock
extends Resource
## The in-game clock (spec 020): an absolute circuit-day and a bell-of-day,
## advanced in real time by Game and by rest. Time is reckoned in bells (the
## roofed world has no sun) within the 9-day circuit. Pure data + pure helpers
## (the NoticeLedger pattern) — held on Game, serialized by SaveCodec. Both
## tunables (bells_per_day, circuit_length) come from BalanceConfig.

## New games and migrated saves start a few bells into the first circuit-day.
const START_BELL := 3.0

@export var day: int = 1
@export var bell: float = START_BELL


## Advances the clock by `bells`, rolling over into whole days at bells_per_day.
## Carries multi-day advances (a long rest).
func advance(bells: float, config: BalanceConfig) -> void:
	bell += bells
	while bell >= config.bells_per_day:
		bell -= config.bells_per_day
		day += 1


func get_day() -> int:
	return day


## The current whole bell (the readout ticks on this, not the fractional value).
func get_bell() -> int:
	return floori(bell)


## The 1..circuit_length position within the current 9-day circuit.
func circuit_day(config: BalanceConfig) -> int:
	return (day - 1) % config.circuit_length + 1
