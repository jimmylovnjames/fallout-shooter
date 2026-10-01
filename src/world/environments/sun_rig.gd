class_name SunRig
extends DirectionalLight3D
## Directional sun tuned for a top-down camera, reacting to graphics presets.
## P1+: driven by TimeOfDay. For now a fixed late-afternoon angle.

@export var elevation_deg: float = 42.0
## Light travels roughly along the camera's view (camera yaw 35°) so camera-facing walls are lit
## and shadows fall away from the player — readability over drama (DESIGN pillar 1).
@export var azimuth_deg: float = 75.0


func _ready() -> void:
	rotation_degrees = Vector3(-elevation_deg, azimuth_deg, 0.0)
	light_color = Color(1.0, 0.9, 0.74)
	light_energy = 1.28
	light_specular = 0.48
	light_indirect_energy = 1.1
	directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	directional_shadow_max_distance = 62.0
	directional_shadow_fade_start = 0.82
	shadow_opacity = 0.8
	shadow_blur = 1.55
	shadow_bias = 0.035
	shadow_normal_bias = 0.7
	_apply(Settings.get_preset())
	EventBus.graphics_preset_applied.connect(_apply)


func _apply(p: GraphicsPreset) -> void:
	if p != null:
		shadow_enabled = p.sun_shadows
