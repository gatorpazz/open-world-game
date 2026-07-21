class_name SweepQuery
extends RefCounted
## Shared camera-forward shapecast query (spec 008 extraction from
## PlayerCombat): melee swings and spell bolts resolve targets the same
## way — nearest contact wins, so a wall in front of a target eats the hit.

## The sweep hits world geometry (layer 1) and hurtboxes (layer 4):
## walls block; creature bodies (layer 3) are invisible to it.
const SWEEP_MASK := 0b1001


## Sweeps the shapecast forward to the given reach and returns the hit
## HurtBox, or null on a whiff (nothing in reach, or something solid
## was nearer).
static func nearest_hurt_box(sweep: ShapeCast3D, reach: float) -> HurtBox:
	sweep.target_position = Vector3(0, 0, -reach)
	sweep.force_shapecast_update()
	var nearest: Object = null
	var nearest_distance := INF
	for i: int in sweep.get_collision_count():
		var distance := sweep.global_position.distance_to(sweep.get_collision_point(i))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = sweep.get_collider(i)
	return nearest as HurtBox
