class_name Hud
extends Control
## Gameplay HUD. Listens only to EventBus (never touches actors directly): health, weapon/ammo,
## reload progress, kill count, damage vignette, death banner.

const BAR_SIZE := Vector2(300, 18)
const VIGNETTE_DECAY_PER_S := 2.5

var _health := 1.0
var _health_max := 1.0
var _health_shown := 1.0
var _reload_until := 0.0
var _reload_duration := 0.0
var _vignette := 0.0
var _kills := 0
var _was_animating := true

var _weapon_label: Label
var _ammo_label: Label
var _kills_label: Label
var _death_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapon_label = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_ammo_label = _make_label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	_kills_label = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_death_label = _make_label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_death_label.visible = false
	_layout()
	resized.connect(_layout)
	_kills_label.text = "%s 0" % tr("HUD_KILLS")

	EventBus.player_health_changed.connect(_on_health)
	EventBus.player_damaged.connect(
		func(amount: float, _dir: Vector3) -> void: _vignette = clampf(_vignette + amount / 30.0, 0.0, 0.8)
	)
	EventBus.weapon_equipped.connect(_on_weapon)
	EventBus.ammo_changed.connect(func(n: int, m: int) -> void: _ammo_label.text = "%d / %d" % [n, m])
	EventBus.reload_started.connect(_on_reload)
	EventBus.enemy_killed.connect(_on_kill)
	EventBus.player_died.connect(
		func() -> void:
			_death_label.text = "%s\n%s" % [tr("HUD_YOU_DIED"), tr("HUD_RESPAWNING")]
			_death_label.visible = true
	)
	EventBus.player_respawned.connect(func() -> void: _death_label.visible = false)


func _layout() -> void:
	# Bottom centre: between the two thumb zones, never under a finger.
	_weapon_label.position = Vector2(size.x * 0.5 - 200, size.y - 92)
	_weapon_label.size = Vector2(400, 28)
	_ammo_label.position = Vector2(size.x * 0.5 - 200, size.y - 66)
	_ammo_label.size = Vector2(400, 44)
	_kills_label.position = Vector2(size.x * 0.5 - 150, 8)
	_kills_label.size = Vector2(300, 30)
	_death_label.position = Vector2(0, size.y * 0.35)
	_death_label.size = Vector2(size.x, 120)


func _process(delta: float) -> void:
	var animating := _vignette > 0.0 or _health_shown != _health or Time.get_ticks_msec() / 1000.0 < _reload_until
	_health_shown = move_toward(_health_shown, _health, _health_max * delta * 1.5)
	_vignette = maxf(_vignette - VIGNETTE_DECAY_PER_S * delta, 0.0)
	if animating or _was_animating:
		queue_redraw()
	_was_animating = animating


func _draw() -> void:
	# Damage vignette: a few stacked bands, still no full-screen shader.
	if _vignette > 0.0:
		for band_i in 3:
			var t := float(band_i) / 3.0
			var band := 110.0 * (1.0 - t * 0.45)
			var c := Color(0.45, 0.06, 0.02, _vignette * 0.22 * (1.0 - t))
			draw_rect(Rect2(0, 0, size.x, band), c)
			draw_rect(Rect2(0, size.y - band, size.x, band), c)
			draw_rect(Rect2(0, band, band, size.y - band * 2.0), c)
			draw_rect(Rect2(size.x - band, band, band, size.y - band * 2.0), c)
	var origin := Vector2(16, 16)
	var plate := Rect2(origin, BAR_SIZE).grow(4.0)
	draw_rect(plate, Color(0.05, 0.035, 0.025, 0.78))
	draw_rect(plate, Color(0.9, 0.58, 0.28, 0.9), false, 1.5)
	var f := clampf(_health_shown / _health_max, 0.0, 1.0)
	var col := Color(0.72, 0.18, 0.08) if f < 0.3 else Color(0.95, 0.58, 0.18)
	draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * f, BAR_SIZE.y)), col)
	if f > 0.0:
		draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * f, 3.0)), Color(1.0, 0.86, 0.55, 0.75))
	var now := Time.get_ticks_msec() / 1000.0
	if now < _reload_until and _reload_duration > 0.0:
		var p := 1.0 - (_reload_until - now) / _reload_duration
		var r := Rect2(Vector2(size.x * 0.5 - 100, size.y - 18), Vector2(200, 6))
		draw_rect(r, Color(0.04, 0.03, 0.02, 0.65))
		draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), Color(1.0, 0.72, 0.32))


func _on_health(current: float, maximum: float) -> void:
	_health = current
	_health_max = maxf(maximum, 1.0)
	if current >= maximum:
		_health_shown = current


func _on_weapon(name_key: String, in_mag: int, mag_size: int) -> void:
	_weapon_label.text = tr(name_key)
	_ammo_label.text = "%d / %d" % [in_mag, mag_size]
	_reload_until = 0.0


func _on_reload(duration: float) -> void:
	_reload_duration = duration
	_reload_until = Time.get_ticks_msec() / 1000.0 + duration


func _on_kill(_id: StringName) -> void:
	_kills += 1
	_kills_label.text = "%s %d" % [tr("HUD_KILLS"), _kills]


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.92))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
