class_name GraphicsPreset
extends Def
## One graphics quality preset (DESIGN §7). Global parts are applied by the Settings autoload;
## scene-level parts (sun shadows, glow, fog detail, foliage, outlines) are applied by scene
## controllers listening to EventBus.graphics_preset_applied.

enum Upscaler { BILINEAR, FSR1 }

@export var name_key: String = ""
## Lower sorts first in UI lists.
@export var sort_order: int = 0

@export_group("Resolution & pacing")
@export_range(0.5, 1.0, 0.05) var render_scale: float = 1.0
@export var upscaler: Upscaler = Upscaler.FSR1
@export_range(0, 240) var max_fps: int = 60
@export var msaa: Viewport.MSAA = Viewport.MSAA_DISABLED

@export_group("Shadows")
@export var sun_shadows: bool = true
@export var shadow_size: int = 2048
@export var shadow_quality: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_HARD

@export_group("Geometry & effects")
## Screen-space pixel error before switching to a lower mesh LOD. Higher = more aggressive.
@export_range(0.0, 8.0, 0.25) var mesh_lod_threshold: float = 1.0
@export var glow: bool = true
@export_range(0, 3) var fog_detail: int = 2
@export_range(0.0, 1.0, 0.05) var foliage_density: float = 1.0
@export var outlines: bool = true


func validate() -> PackedStringArray:
	var errors := super()
	if not String(id).begins_with("gfx_"):
		errors.append("graphics preset ids must start with gfx_")
	if name_key.is_empty():
		errors.append("name_key is empty")
	if render_scale < 0.5 or render_scale > 1.0:
		errors.append("render_scale %.2f outside 0.5..1.0" % render_scale)
	if max_fps != 0 and max_fps < 30:
		errors.append("max_fps %d below the 30 fps floor" % max_fps)
	if sun_shadows and shadow_size not in [1024, 2048, 4096]:
		errors.append("shadow_size must be 1024, 2048 or 4096")
	return errors
