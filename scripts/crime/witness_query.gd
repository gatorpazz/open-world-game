class_name WitnessQuery
extends RefCounted
## The witness primitive (spec 017): did any NPC observer see the actor commit
## an act? Deterministic — line-of-sight plus a sneak-scaled range, no RNG
## (locks roll, sneak is fixed — the director ruling). Generalized from
## creature.gd's detect/LOS logic and built ONCE here so spec 018 can reuse
## is_witnessed for witnessed-unlicensed-working enforcement. Static and
## tree-injected (the world node + its physics space), like the other pure
## rule modules — the scene passes in what geometry it can't compute.

## Line-of-sight rays test world geometry (layer 1) only — the creature.gd mask.
const LOS_MASK := 0b1
## Eye height for observer→actor rays (matches creature.gd).
const EYE_OFFSET := Vector3(0, 0.5, 0)


## The range within which an observer can see the actor. Full at sneak_skill_min,
## scaled toward sneak_skilled_radius_factor by sneak_skill_max, and multiplied
## again by sneak_crouch_factor while crouched — higher skill and a crouch both
## shrink the circle a thief has to work inside. Pure; the unit-tested core.
static func detection_radius(sneak_skill: int, crouched: bool, config: BalanceConfig) -> float:
	var span := float(config.sneak_skill_max - config.sneak_skill_min)
	var t := clampf(float(sneak_skill - config.sneak_skill_min) / span, 0.0, 1.0)
	var skill_factor := lerpf(1.0, config.sneak_skilled_radius_factor, t)
	var crouch_factor := config.sneak_crouch_factor if crouched else 1.0
	return config.sneak_base_detection_radius * skill_factor * crouch_factor


## Whether ANY NPC in the world sees the actor (the director ruling — any NPC
## reports, not only wardens). Returns true on the first observer that sees;
## false if none do or the world has no physics space (headless with no tree).
## 018 calls this too, for casting.
static func is_witnessed(
	actor: Node3D, world: Node, sneak_skill: int, sneaking: bool, config: BalanceConfig
) -> bool:
	var world_3d := actor.get_world_3d()
	if world_3d == null:
		return false
	var space_state := world_3d.direct_space_state
	if space_state == null:
		return false
	var observers: Array[Npc] = []
	_collect_npcs(world, observers)
	for observer: Npc in observers:
		if _observer_sees(observer, actor, sneak_skill, sneaking, config, space_state):
			return true
	return false


## One observer's check: within the sneak-scaled radius and with a clear
## eye-height ray. The observer's own body (and the actor's, when it has one)
## are excluded so only world geometry between them blocks the sight line.
static func _observer_sees(
	observer: Npc,
	actor: Node3D,
	sneak_skill: int,
	sneaking: bool,
	config: BalanceConfig,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	if (
		observer.global_position.distance_to(actor.global_position)
		> detection_radius(sneak_skill, sneaking, config)
	):
		return false
	var query := PhysicsRayQueryParameters3D.create(
		observer.global_position + EYE_OFFSET, actor.global_position + EYE_OFFSET, LOS_MASK
	)
	var exclude: Array[RID] = [observer.get_rid()]
	if actor is CollisionObject3D:
		exclude.append((actor as CollisionObject3D).get_rid())
	query.exclude = exclude
	return space_state.intersect_ray(query).is_empty()


## Collects every Npc descendant of the world (recursive), so a witness is any
## person in the scene, wherever the scene nests them.
static func _collect_npcs(node: Node, out: Array[Npc]) -> void:
	for child: Node in node.get_children():
		if child is Npc:
			out.append(child)
		_collect_npcs(child, out)
