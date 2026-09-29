class_name AIState
extends RefCounted
## One behaviour in the utility-scored state machine (DECISIONS D016). The brain asks every state
## for a score each think tick and runs the highest (with hysteresis for the current one).


func state_name() -> StringName:
	return &"state"


func score(_b: AIBrain) -> float:
	return 0.0


func enter(_b: AIBrain) -> void:
	pass


func exit(_b: AIBrain) -> void:
	pass


## Called at the brain's think rate (not every frame). `dt` = time since the last think.
func think(_b: AIBrain, _dt: float) -> void:
	pass
