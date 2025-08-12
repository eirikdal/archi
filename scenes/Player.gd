# scripts/actors/Player.gd
extends CharacterBody2D
class_name PlayerBase

## -- Tweakables -------------------------------------------------------------
@export var move_speed: float = 200.0
@export var jump_impulse: float = -380.0
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
		anim.play("breathe_idle")
		# _weapon = $WeaponHolder.get_child(0) as Weapon

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_input(delta)
	update_animation()                      # flip + pick anim based on velocity
	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_coyote = 0.12                      # reset coyote time

func handle_input(delta: float) -> void:
	# Horizontal
	var dir := Input.get_axis("move_left", "move_right")

	if not _is_sliding:
		velocity.x = dir * move_speed
		# Face the direction of input when there is input
		if dir != 0:
			anim.flip_h = dir < 0

	# Jump
	if Input.is_action_just_pressed("jump") and (_coyote > 0.0 or is_on_floor()):
		velocity.y = jump_impulse
	if _coyote > 0.0:
		_coyote -= delta

	# Wing-Slide
	if Input.is_action_just_pressed("slide") and not _is_sliding:
		start_slide()

	# Shooting (optional)
	if Input.is_action_pressed("shoot") and _weapon:
		_weapon.try_fire()

	# Hero swap keys (numeric 1-3 or LB/RB etc.)
	# if Input.is_action_just_pressed("hero_1"): GameManager.swap_to("SOVA")
	# if Input.is_action_just_pressed("hero_2"): GameManager.swap_to("RYS")
	# if Input.is_action_just_pressed("hero_3"): GameManager.swap_to("BILKA")

func update_animation() -> void:
	# Choose between idle and running using horizontal speed
	var moving := absf(velocity.x) > RUN_THRESHOLD and is_on_floor() and not _is_sliding
	var target := "running" if moving else "breathe_idle"
	if anim.animation != target or not anim.is_playing():
		anim.play(target)


func start_slide() -> void:
	_is_sliding = true
	var facing_sign := -1.0 if anim.flip_h else 1.0
	velocity.x = slide_speed * facing_sign

	$CollisionShape2D.disabled = true
	await get_tree().create_timer(slide_time).timeout
	$CollisionShape2D.disabled = false
	_is_sliding = false
