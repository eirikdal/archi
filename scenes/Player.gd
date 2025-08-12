# scripts/actors/Player.gd
extends CharacterBody2D
class_name PlayerBase

## -- Tweakables -------------------------------------------------------------
@export var move_speed: float = 200.0
@export var jump_impulse: float = -360.0
@export var gravity: float = 1300.0
@export var slide_speed: float = 420.0
@export var slide_time: float = 0.30
@export var hero_id: String = "GENERIC"   # set per-scene in Inspector

## -- Internals --------------------------------------------------------------
var _slide_timer: float = 0.0
var _is_sliding: bool = false
var _coyote: float = 0.0                  # jump forgiveness
const RUN_THRESHOLD := 5.0                # min speed to count as "moving"

var _weapon: Weapon
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if owner == get_tree().current_scene:   # not a pooled dummy
		_play("breathe_idle")               # default

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_input(delta)
	update_animation()
	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_coyote = 0.12                      # reset coyote time

func handle_input(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if not _is_sliding:
		velocity.x = dir * move_speed
		if dir != 0:
			anim.flip_h = dir < 0

	# Jump
	if Input.is_action_just_pressed("jump") and (_coyote > 0.0 or is_on_floor()):
		velocity.y = jump_impulse
	if _coyote > 0.0:
		_coyote -= delta

	# Slide
	if Input.is_action_just_pressed("slide") and not _is_sliding:
		start_slide()

	# Shooting (optional)
	if Input.is_action_pressed("shoot") and _weapon:
		_weapon.try_fire()

func update_animation() -> void:
	# Airborne takes priority (use "jumping", fall back to "running" if missing)
	var airborne := not is_on_floor()
	if airborne and not _is_sliding:
		_play("jumping", "running")
		return

	# Sliding could have its own anim in the future; for now just use running
	if _is_sliding:
		_play("running")
		return

	# Grounded: choose running vs idle
	var moving := absf(velocity.x) > RUN_THRESHOLD
	var target := "running" if moving else "breathe_idle"
	if anim.animation != target or not anim.is_playing():
		_play(target)

func start_slide() -> void:
	_is_sliding = true
	var facing_sign := -1.0 if anim.flip_h else 1.0
	velocity.x = slide_speed * facing_sign

	$CollisionShape2D.disabled = true
	await get_tree().create_timer(slide_time).timeout
	$CollisionShape2D.disabled = false
	_is_sliding = false

# --- helpers ---------------------------------------------------------------

func _play(name: String, fallback: String = "") -> void:
	var target := name
	if anim.sprite_frames and not anim.sprite_frames.has_animation(name):
		target = fallback if (fallback != "" and anim.sprite_frames.has_animation(fallback)) else name
	if anim.animation != target or not anim.is_playing():
		anim.play(target)
