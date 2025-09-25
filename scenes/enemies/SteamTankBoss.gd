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
func _on_health_damaged(amount: int) -> void:
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

func _recoil(px: float = 2.0) -> void:
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

func _hit_stop(duration: float = 0.06, scale: float = 0.1) -> void:
	Engine.time_scale = 1.0 - clamp(scale, 0.0, 0.9)
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
	emit_signal("defeated")
	queue_free()
