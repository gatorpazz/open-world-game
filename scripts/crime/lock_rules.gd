class_name LockRules
extends RefCounted
## Pure lockpicking odds (spec 017): all static, no scene tree, every input
## passed in (the BarterRules/FactionRules pattern). Locks are the one place
## crime rolls dice (the director's hybrid ruling — sneak stays deterministic).
## pick_chance returns the probability; the caller rolls randf() < chance and
## spends a lockpick either way, so this module never touches RNG and its
## endpoints stay testable.


## The chance a single pick attempt opens a lock: 1 - difficulty / reach, where
## reach = security_skill + base_competence. A lock well inside your reach opens
## reliably (even a novice picks easy locks), it falls off fast as difficulty
## climbs toward your reach, and a lock at or beyond your reach is 0.0 — it
## cannot be forced without more skill. Monotonic non-decreasing in
## security_skill, non-increasing in lock_difficulty; clamped to [0, 1].
static func pick_chance(security_skill: int, lock_difficulty: int, config: BalanceConfig) -> float:
	var reach := float(security_skill + config.lock_base_competence)
	return clampf(1.0 - float(lock_difficulty) / reach, 0.0, 1.0)
