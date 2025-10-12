extends CharacterBody2D
class_name SteamTankBoss

# --- Tunables (Inspector) ---
@export var max_hp: int = 100
@export var move_speed: float = 18.0
@export var fire_interval: float = 1.6
@export var burst_count: int = 3
@export var projectile_scene: PackedScene
@export var muzzle_flash_frame: int = 1
@export var aim_at_player: bool = true
@export var spread_degrees: float = 2.5

# --- Physics tunables ---
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1200.0
@export var ground_snap_distance: float = 6.0
@export var horiz_friction: float = 1800.0
@export var air_drag: float = 200.0
@export var knockback_decay: float = 24.0
@export var debug_draw_floor: bool = false

signal defeated

var _shots_left: int = 0
var _fired_this_cycle: bool = false
var _state: String = "idle"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var sfx_fire: AudioStreamPlayer2D = $SfxFire
@onready var sfx_hurt: AudioStreamPlayer2D = $SfxHurt
@onready var sparks: CPUParticles2D = $HitSparks
@onready var puff:   CPUParticles2D = $PuffSmoke
@onready var smoke_l := $SmokeL
@onready var smoke_m := $SmokeM
@onready var smoke_h := $SmokeH
@onready var health: Health = $Health


# death scene
@export var death_slowmo_time: float = 0.45
@export var slowmo_scale: float = 0.25
@export var post_slowmo_pause: float = 0.6
@export var explosion_count: int = 6
@export var explosion_radius: float = 48.0
@export var loot_scene: PackedScene
@export var explosion_scene: PackedScene
@export var debris_scene: PackedScene
@export var death_sound: AudioStream
@export var death_shake_strength: float = 14.0
@export var camera_zoom_target: float = 3.5
@export var camera_zoom_time: float = 0.35


var _flash_tween: Tween
var _knockback: Vector2 = Vector2.ZERO


func _ready() -> void:
	# --- unify HP with Health component ---
	if health:
		health.max_health = max_hp
		# connect signals once
		if not health.damaged.is_connected(_on_health_damaged):
			health.damaged.connect(_on_health_damaged)
		if not health.health_changed.is_connected(_on_health_changed):
			health.health_changed.connect(_on_health_changed)
		if not health.died.is_connected(_die):
			health.died.connect(_die)
		# init VFX state
		_on_health_changed(health.current, health.max_health)

	if sprite.material == null:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/sprite_flash.gdshader")
		sprite.material = mat

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("fire"):
		sprite.sprite_frames.set_animation_loop("fire", false)

	sprite.play("idle")

	fire_timer.wait_time = fire_interval
	fire_timer.one_shot = false
	if not fire_timer.timeout.is_connected(_on_FireTimer_timeout):
		fire_timer.timeout.connect(_on_FireTimer_timeout)
	fire_timer.start()

	if not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)
	if not sprite.animation_finished.is_connected(_on_anim_finished):
		sprite.animation_finished.connect(_on_anim_finished)


func _physics_process(delta: float) -> void:
	var g := ProjectSettings.get_setting("physics/2d/default_gravity") as float
	if not is_on_floor():
		velocity.y = min(velocity.y + g * gravity_scale * delta, max_fall_speed)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	var desired_x := -move_speed
	var damp := horiz_friction if is_on_floor() else air_drag
	velocity.x = move_toward(velocity.x, desired_x, damp * delta)

	if _knockback.length() > 0.1:
		velocity += _knockback
		_knockback = _knockback.lerp(Vector2.ZERO, clamp(knockback_decay * delta, 0.0, 1.0))
	else:
		_knockback = Vector2.ZERO

	set_up_direction(Vector2.UP)
	move_and_slide()

	if debug_draw_floor:
		_debug_floor()

func _debug_floor() -> void:
	var from := global_position
	var to := from + Vector2(0, ground_snap_distance)
	get_viewport().debug_draw_line(from, to, Color.CYAN)

func _on_frame_changed() -> void:
	if _state == "firing" and sprite.animation == "fire" and sprite.frame == muzzle_flash_frame and not _fired_this_cycle:
		_fired_this_cycle = true
		_spawn_shell()
		_apply_recoil()

func _on_anim_finished() -> void:
	if sprite.animation == "fire":
		sprite.play("idle")
		_state = "idle"
		_fired_this_cycle = false

func _on_FireTimer_timeout() -> void:
	if _state != "idle":
		return
	_shots_left = burst_count
	_state = "firing"
	_play_fire_cycle()

func _play_fire_cycle() -> void:
	if _shots_left <= 0:
		_state = "idle"
		_fired_this_cycle = false
		sprite.play("idle")
		fire_timer.start()
		return

	_fired_this_cycle = false
	sprite.play("fire")
	_shots_left -= 1

	var next_delay: float = max(0.1, fire_interval * 0.35)
	get_tree().create_timer(next_delay).timeout.connect(func ():
		if _state == "firing":
			_play_fire_cycle()
	)

func _spawn_shell() -> void:
	if projectile_scene == null:
		push_warning("SteamTankBoss: projectile_scene not set")
		return
	var shell: Node2D = projectile_scene.instantiate()
	shell.global_position = muzzle.global_position

	var dir := Vector2.LEFT
	if aim_at_player:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			dir = (player.global_position - muzzle.global_position).normalized()
	var angle_offset := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	shell.rotation = dir.angle() + angle_offset

	get_tree().current_scene.add_child(shell)
	if sfx_fire.stream:
		sfx_fire.pitch_scale = randf_range(0.98, 1.03)
		sfx_fire.play()

func _apply_recoil() -> void:
	var recoil_dir := Vector2.RIGHT
	_knockback += recoil_dir * 60.0

# --- Unified damage API: forward to Health only ---
func apply_damage(amount: int) -> void:
	if health:
		health.apply_damage(amount)

# --- Effects driven by Health signals ---
func _on_health_damaged(_amount: int) -> void:
	_flash_hit()
	_emit_hit_fx(global_position + Vector2(0, -8))
	_hit_stop()
	_recoil()
	_shake_camera()
	if sfx_hurt.stream:
		sfx_hurt.play()

func _on_health_changed(current: int, maxv: int) -> void:
	var r := (float(current) / float(maxv)) if (maxv > 0) else 0.0
	_update_damage_vfx_ratio(r)

func _update_damage_vfx_ratio(ratio: float) -> void:
	smoke_l.emitting = (ratio <= 0.75)
	smoke_m.emitting = (ratio <= 0.50)
	smoke_h.emitting = (ratio <= 0.25)

func _recoil(_px: float = 2.0) -> void:
	var dir := -1.0 if (velocity.x == 0.0) else -signf(velocity.x)
	_knockback += Vector2(dir * 10.0, -10.0)

func _flash_hit() -> void:
	var m := sprite.material as ShaderMaterial
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	m.set_shader_parameter("flash_color", Color(1,1,1,1))
	m.set_shader_parameter("flash", 1.0)
	_flash_tween.tween_property(m, "shader_parameter/flash", 0.0, 0.12)

func _emit_hit_fx(at: Vector2) -> void:
	sparks.global_position = at
	puff.global_position   = at
	sparks.restart()
	puff.restart()

func _hit_stop(duration: float = 0.06, _scale: float = 0.1) -> void:
	Engine.time_scale = 1.0 - clamp(_scale, 0.0, 0.9)
	get_tree().create_timer(duration, false, true, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)

func _shake_camera(intensity := 0.4, time := 0.12) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null: return
	var t := create_tween()
	for i in 4:
		t.tween_property(cam, "offset", Vector2(randf_range(-intensity,intensity), randf_range(-intensity,intensity)), time/4.0)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func _die() -> void:
	# stop combat/ai
	if fire_timer and fire_timer.is_stopped() == false:
		fire_timer.stop()
	_state = "dead"
	set_physics_process(false)

	# safety: stop collisions if present
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	if has_node("HurtBox"):
		$HurtBox.set_process(false)

	# play SFX
	if death_sound:
		var ap := AudioStreamPlayer2D.new()
		add_child(ap)
		ap.stream = death_sound
		ap.autoplay = false
		ap.play()

	# optional death anim if you have it in SpriteFrames
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		sprite.play("idle")

	# kick off the orchestrated sequence (async)
	await _do_death_sequence()

	emit_signal("defeated")
	queue_free()

var _is_dying: bool = false

func _play_camera_shake(strength: float = death_shake_strength) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null: return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in 4:
		t.tween_property(cam, "offset",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			0.05)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.08)

func _zoom_camera(target_zoom: float, time_sec: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null: return
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(cam, "zoom", Vector2(target_zoom, target_zoom), time_sec)


func spawn_explosion_at(pos: Vector2, scale_override: float = 1.0) -> void:
	if explosion_scene == null:
		return
	var ex := explosion_scene.instantiate()
	get_tree().current_scene.add_child(ex)
	ex.global_position = pos

	# Prefer custom helper if present; otherwise set Node2D.scale directly
	if ex.has_method("apply_scale_multiplier"):
		ex.call("apply_scale_multiplier", scale_override)
	elif "scale" in ex and ex.scale is Vector2:
		ex.scale = ex.scale * Vector2.ONE * scale_override

	# optional: play SFX here if your explosion scene doesn't handle it

func spawn_explosions(count: int) -> void:
	for i in count:
		var off := Vector2(
			randf_range(-explosion_radius, explosion_radius),
			randf_range(-explosion_radius * 0.6, explosion_radius * 0.6)
		)
		spawn_explosion_at(global_position + off)

func spawn_debris(count: int, scattered: bool = false) -> void:
	if debris_scene == null: return
	for i in count:
		var d := debris_scene.instantiate()
		get_tree().current_scene.add_child(d)
		var lx := randf_range(-explosion_radius, explosion_radius)
		var ly := randf_range(-explosion_radius * 0.5, explosion_radius * 0.5)
		if scattered:
			lx *= 1.6
			ly *= 1.2
		d.global_position = global_position + Vector2(lx, ly)
		if d is RigidBody2D:
			var impulse := Vector2(randf_range(-180, 180), randf_range(-220, -80))
			d.apply_impulse(Vector2.ZERO, impulse)

func _stop_emitters() -> void:
	# reuse your existing smoke emitters for drama
	if smoke_h: smoke_h.emitting = false
	if smoke_m: smoke_m.emitting = false
	if smoke_l: smoke_l.emitting = false

func _start_emitters() -> void:
	if smoke_h: smoke_h.emitting = true
	if smoke_m: smoke_m.emitting = true
	if smoke_l: smoke_l.emitting = true

func _drop_loot() -> void:
	if loot_scene == null: return
	var loot := loot_scene.instantiate()
	get_tree().current_scene.add_child(loot)
	loot.global_position = global_position + Vector2(0, -12)

func _award_victory() -> void:
	# call your GameManager if you have one
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if gm.has_method("on_boss_defeated"):
			gm.call("on_boss_defeated", name)

func _restore_timescale_safely() -> void:
	Engine.time_scale = 1.0

func _play_final_boom() -> void:
	spawn_explosion_at(global_position, 1.6)
	_play_camera_shake(death_shake_strength * 1.4)

func _safe_wait(t: float) -> void:
	await get_tree().create_timer(max(t, 0.01), false, true, true).timeout

func _do_death_sequence() -> void:
	if _is_dying: return
	_is_dying = true

	_start_emitters()

	# burst while any death anim starts
	spawn_explosions(max(1, explosion_count / 2.0))
	await _safe_wait( min(0.4, 0.6) )

	# main barrage + shake + debris
	spawn_explosions(explosion_count)
	_play_camera_shake()
	spawn_debris(4)

	# slow-mo beat
	Engine.time_scale = clamp(slowmo_scale, 0.05, 1.0)
	await _safe_wait(death_slowmo_time)
	_restore_timescale_safely()

	# breath
	await _safe_wait(post_slowmo_pause)

	# punch-in and out
	_zoom_camera(camera_zoom_target, camera_zoom_time)
	await _safe_wait(camera_zoom_time + 0.05)
	_zoom_camera(3, camera_zoom_time)

	# final pop
	_play_final_boom()

	# loot + score
	_drop_loot()
	_award_victory()

	# fade out smoke then finish
	_stop_emitters()
	await _safe_wait(0.8)
