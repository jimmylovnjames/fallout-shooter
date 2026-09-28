class_name SunRig
extends DirectionalLight3D
## Directional sun tuned for a top-down camera, reacting to graphics presets.
## P1+: driven by TimeOfDay. For now a fixed late-afternoon angle.

@export var elevation_deg: float = 38.0
@export var azimuth_deg: float = -140.0


func _ready() -> void:
	rotation_degrees = Vector3(-elevation_deg, azimuth_deg, 0.0)
	light_color = Color(1.0, 0.87, 0.7)
	light_energy = 1.35
	directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	directional_shadow_max_distance = 55.0
	shadow_blur = 1.2
	_apply(Settings.get_preset())
	EventBus.graphics_preset_applied.connect(_apply)


func _apply(p: GraphicsPreset) -> void:
	if p != null:
		shadow_enabled = p.sun_shadows
