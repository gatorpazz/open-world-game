class_name LockRules
extends RefCounted
## Pure lockpicking odds (spec 017): all static, no scene tree, every input
## passed in (the BarterRules/FactionRules pattern). Locks are the one place
## crime rolls dice (the director's hybrid ruling — sneak stays deterministic).
## pick_chance returns the probability; the caller rolls randf() < chance and
## spends a lockpick either way, so this module never touches RNG and its
## endpoints stay testable.


## The chance a single pick attempt opens a lock. An even 0.5 at parity
## (skill == difficulty), rising toward 1.0 as skill leads and falling toward
## 0.0 as difficulty leads; a full lock_difficulty_scale of lead in either
## direction reaches the clamp. Monotonic non-decreasing in security_skill,
## non-increasing in lock_difficulty.
static func pick_chance(security_skill: int, lock_difficulty: int, config: BalanceConfig) -> float:
	var lead := float(security_skill - lock_difficulty) / float(config.lock_difficulty_scale)
	return clampf(0.5 + 0.5 * lead, 0.0, 1.0)
