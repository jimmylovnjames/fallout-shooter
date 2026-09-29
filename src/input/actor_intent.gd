class_name ActorIntent
extends RefCounted
## What an actor wants to do this tick, in WORLD space (XZ plane). Written by PlayerController or
## AIBrain, consumed by Actor. Same type for player and AI so both drive identical movement/combat.

## Desired movement direction × throttle (length 0..1, y = 0).
var move := Vector3.ZERO
## Desired facing/aim direction (unit, y = 0). Zero = face the movement direction.
var aim := Vector3.ZERO
var fire := false
var reload := false
var swap := false


func clear() -> void:
	move = Vector3.ZERO
	aim = Vector3.ZERO
	fire = false
	reload = false
	swap = false
