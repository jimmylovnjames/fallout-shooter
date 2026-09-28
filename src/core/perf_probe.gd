class_name PerfProbe
extends RefCounted
## Read-only snapshot of engine performance monitors. Renderer-independent numbers (draw calls,
## primitives, objects) are comparable between CI (lavapipe) and device; fps/memory are not.

const MB := 1048576.0


static func snapshot() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB,
		"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB,
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"pipeline_compiles": pipeline_compilations(),
	}


## Total pipeline compilations so far; a rising count during gameplay means shader stutter.
static func pipeline_compilations() -> int:
	return int(
		(
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
			+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
		)
	)


static func device_info() -> Dictionary:
	var mem := OS.get_memory_info()
	return {
		"model": OS.get_model_name(),
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"ram_mb": int(mem.get("physical", 0) / MB),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"engine": Engine.get_version_info().get("string", ""),
		"game_version": ProjectSettings.get_setting("application/config/version", ""),
	}
