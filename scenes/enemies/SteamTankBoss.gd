extends CharacterBody2D
class_name SteamTankBoss

# --- Tunables (Inspector) ---
@export var max_hp: int = 60
@export var move_speed: float = 18.0         # slow creep
@export var fire_interval: float = 1.6       # seconds between shots
@export var burst_count: int = 1             # change to 3 for volleys
@export var recoil_pixels: float = 4.0
@export var projectile_scene: PackedScene    # assign TankShell.tscn
@export var muzzle_flash_frame: int = 1      # frame index in 'fire' that should spawn shell

# Optional: drop reference to the player if you want auto-aim later
@export var aim_at_player: bool = false
@export var spread_degrees: float = 2.5

signal defeated

var hp: int
var _shots_left: int = 0
var _fired_this_cycle: bool = false
var _state: String = "idle"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var fire_timer: Timer = $FireTimer
@onready var sfx_fire: AudioStreamPlayer2D = $SfxFire
@onready var sfx_hurt: AudioStreamPlayer2D = $SfxHurt

func _ready() -> void:
	hp = max_hp
	sprite.play("idle")
	fire_timer.wait_time = fire_interval
	fire_timer.start()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_anim_finished)

func _physics_process(delta: float) -> void:
	# Simple left-to-right patrol creep; replace with your level script if needed
	velocity.x = -move_speed
	move_and_slide()

func _on_frame_changed() -> void:
	if sprite.animation == "fire" and sprite.frame == muzzle_flash_frame and not _fired_this_cycle:
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
		fire_timer.start()
		return
	_fired_this_cycle = false
	sprite.play("fire")
	_shots_left -= 1
	# If volley >1, queue next shot slightly later than anim length
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

	# Face left by default; rotate slightly for spread if enabled
	var dir := Vector2.LEFT
	if aim_at_player:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			dir = (player.global_position - muzzle.global_position).normalized()
	var angle_offset := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	shell.rotation = dir.angle() + angle_offset

	get_tree().current_scene.add_child(shell)
	if sfx_fire.stream:
		sfx_fire.play()

func _apply_recoil() -> void:
	global_position.x += recoil_pixels

# --- Damage / death API used by bullets etc. ---
func apply_damage(amount: int) -> void:
	hp -= amount
	if sfx_hurt.stream:
		sfx_hurt.play()
	if hp <= 0:
		_die()

func _die() -> void:
	emit_signal("defeated")
	queue_free()
