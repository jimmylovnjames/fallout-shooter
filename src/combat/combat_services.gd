class_name CombatServices
extends RefCounted
## Level-owned combat systems handed to actors when they're spawned (explicit dependency
## injection instead of global lookups).

var projectiles: ProjectileSystem
var tracers: TracerPool
var bursts: BurstPool
var rng := RandomNumberGenerator.new()


static func create(host: Node3D, seed_value: int = 0) -> CombatServices:
	var s := CombatServices.new()
	s.projectiles = ProjectileSystem.new()
	s.projectiles.name = "Projectiles"
	s.projectiles.capacity = 512
	s.tracers = TracerPool.new()
	s.tracers.name = "Tracers"
	s.tracers.capacity = 128
	s.bursts = BurstPool.new()
	s.bursts.name = "Bursts"
	s.bursts.capacity = 128
	host.add_child(s.projectiles)
	host.add_child(s.tracers)
	host.add_child(s.bursts)
	s.projectiles.impacted.connect(
		func(pos: Vector3, _n: Vector3, flesh: bool) -> void:
			s.bursts.spawn(pos, 0.35 if flesh else 0.25, Color(1.0, 0.3, 0.2) if flesh else Color(1.0, 0.8, 0.5))
	)
	if seed_value != 0:
		s.rng.seed = seed_value
	return s
