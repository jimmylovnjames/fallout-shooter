class_name PhysicsLayers
extends RefCounted
## Collision layer bits; names mirror project.godot [layer_names]. Use these, never raw numbers.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ACTORS := 1 << 2
const HURTBOX := 1 << 3
const PROJECTILE := 1 << 4
const INTERACTABLE := 1 << 5
const COVER := 1 << 6
const TRIGGER := 1 << 7

## What shots fired by the player / by hostiles can hit.
const PLAYER_SHOTS := WORLD | ACTORS
const HOSTILE_SHOTS := WORLD | PLAYER
## Line-of-sight checks only care about static world geometry.
const SIGHT := WORLD
