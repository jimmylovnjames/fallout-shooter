class_name InputFrame
extends RefCounted
## Device-level input for one frame, in SCREEN space (+x right, +y down). Produced by InputRouter,
## converted to a world-space ActorIntent by PlayerController.

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

var device: Device = Device.KEYBOARD_MOUSE
## Movement, length 0..1.
var move := Vector2.ZERO
## Stick/touch aim, length 0..1 (ignored when aim_at_cursor).
var aim := Vector2.ZERO
## KBM: aim at the world point under the cursor instead of a stick direction.
var aim_at_cursor := false
var cursor_screen := Vector2.ZERO
var fire := false
var reload_pressed := false
var swap_pressed := false
var interact_pressed := false


func is_aiming() -> bool:
	return aim_at_cursor or aim.length_squared() > 0.0
