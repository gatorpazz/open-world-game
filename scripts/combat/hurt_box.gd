class_name HurtBox
extends Area3D
## The one shared damage receiver (spec 004). Dumb by design: attackers
## call take_hit() with raw damage; the owner connects hit_taken and
## resolves its own defense (player: equipment; creature: def.armor).

signal hit_taken(raw_damage: float, attacker: Node3D)

## Physics layer 4 ("hurtboxes"). Set in code so every HurtBox is correct
## regardless of how its scene was authored.
const HURTBOX_LAYER := 0b1000


func _ready() -> void:
	collision_layer = HURTBOX_LAYER
	collision_mask = 0
	monitoring = false  # only ever detected, never detects


func take_hit(raw_damage: float, attacker: Node3D) -> void:
	hit_taken.emit(raw_damage, attacker)
