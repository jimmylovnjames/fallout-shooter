extends Node3D
## P0 greybox scene: validates lighting, fog, presets and the perf HUD on device.
## Content is generated deterministically from SEED (identical every run → comparable numbers).

const SEED := 1337

var _hero: Node3D
var _t := 0.0

@onready var _env: WorldEnvironment = $WorldEnvironment
@onready var _props: Node3D = $Props


func _ready() -> void:
	# Environment is shared; duplicate so preset tweaks never leak into the resource on disk.
	_env.environment = _env.environment.duplicate(true) as Environment
	_build(RandomNumberGenerator.new())
	_apply_preset(Settings.get_preset())
	EventBus.graphics_preset_applied.connect(_apply_preset)


func _process(delta: float) -> void:
	_t += delta
	if _hero:
		_hero.rotation.y = _t * 0.8
		_hero.position.y = absf(sin(_t * 2.0)) * 0.15


func _apply_preset(p: GraphicsPreset) -> void:
	if p != null:
		_env.environment.glow_enabled = p.glow


func _build(rng: RandomNumberGenerator) -> void:
	rng.seed = SEED
	_props.add_child(GreyboxKit.ground(160.0))
	_props.add_child(GreyboxKit.box(Vector3(6, 0.05, 90), GreyboxKit.Palette.DARK, Vector3(0, 0, 0)))  # road

	# Two rows of building shells along the road.
	for side: int in [-1, 1]:
		for i in 4:
			var size := Vector3(rng.randf_range(5, 8), rng.randf_range(3, 7), rng.randf_range(5, 9))
			var pos := Vector3(side * (3.0 + 2.0 + size.x * 0.5), 0, -24 + i * 13 + rng.randf_range(-1.5, 1.5))
			_props.add_child(
				GreyboxKit.box(
					size, GreyboxKit.Palette.CONCRETE if (i + side) % 2 == 0 else GreyboxKit.Palette.RUST, pos
				)
			)

	# Scattered cover: crates, barrels, concrete barriers.
	for i in 18:
		var s := rng.randf_range(0.8, 1.2)
		var pos := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-20, 20))
		_props.add_child(GreyboxKit.box(Vector3(s, s, s), GreyboxKit.Palette.WOOD, pos, rng.randf() * 90.0))
	for i in 8:
		_props.add_child(
			GreyboxKit.cylinder(
				0.3, 0.9, GreyboxKit.Palette.RUST, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-18, 18))
			)
		)
	for i in 6:
		_props.add_child(
			GreyboxKit.box(
				Vector3(2.0, 0.9, 0.5),
				GreyboxKit.Palette.CONCRETE,
				Vector3(-2.5 + (i % 2) * 5.0, 0, -10 + i * 4),
				rng.randf_range(-10, 10)
			)
		)

	# Debris: one draw call for all of it.
	_props.add_child(GreyboxKit.scatter(GreyboxKit.rock_mesh(), GreyboxKit.Palette.CONCRETE, 600, 40.0, rng))

	# Stand-ins for the player and three hostiles (outlined actors).
	_hero = GreyboxKit.actor_dummy(GreyboxKit.Palette.ACCENT)
	add_child(_hero)
	for i in 3:
		var foe := GreyboxKit.actor_dummy(GreyboxKit.Palette.DARK)
		foe.position = Vector3(-6 + i * 6, 0, -14 + rng.randf_range(-2, 2))
		foe.rotation.y = PI
		add_child(foe)
