# scripts/actors/Player.gd
extends CharacterBody2D
class_name PlayerBase

## -- Tweakables -------------------------------------------------------------
@export var move_speed := 200.0
@export var jump_impulse := -380.0
@export var gravity := 1300.0
@export var slide_speed := 420.0
@export var slide_time := 0.30
@export var hero_id := "GENERIC"            # set per-scene in Inspector

## -- Internals --------------------------------------------------------------
var _slide_timer := 0.0
var _is_sliding := false
var _coyote := 0.0                       # jump forgiveness

var _weapon: Weapon
@onready var anim := $AnimatedSprite2D

#const GameManager = preload("res://GameManager.gd")

func _ready() -> void:
	if owner == get_tree().current_scene:        # not a pooled dummy
		#GameManager.active_hero = self
		anim.animation = "breathe_idle"
#	_weapon = $WeaponHolder.get_child(0)         # first weapon scene

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_input(delta)
	move_and_slide()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_coyote = 0.12                           # reset coyote time

func handle_input(delta):
	# Horizontal
	var dir := Input.get_axis("move_left", "move_right")
	if not _is_sliding:
		velocity.x = dir * move_speed
		#if dir != 0: $AnimatedSprite2D.scale.x = sign(dir)
	# Jump
	if Input.is_action_just_pressed("jump") and (_coyote > 0 or is_on_floor()):
		velocity.y = jump_impulse
	if _coyote > 0: _coyote -= delta

	# Wing-Slide
	if Input.is_action_just_pressed("slide") and not _is_sliding:
		start_slide()

	# Shooting
	if Input.is_action_pressed("shoot"):
		_weapon.try_fire()

	# Hero swap keys (numeric 1-3 or LB/RB etc.)
	#if Input.is_action_just_pressed("hero_1"): GameManager.swap_to("SOVA")
	#if Input.is_action_just_pressed("hero_2"): GameManager.swap_to("RYS")
	#if Input.is_action_just_pressed("hero_3"): GameManager.swap_to("BILKA")

func start_slide():
	_is_sliding = true
	velocity.x = slide_speed * sign($Sprite2D.scale.x)
	$CollisionShape2D.disabled = true          # i-frames: no hit box
	await get_tree().create_timer(slide_time).timeout
	$CollisionShape2D.disabled = false
	_is_sliding = false
