# scripts/actors/Player.gd
extends CharacterBody2D
class_name PlayerBase

## -- Tweakables -------------------------------------------------------------
@export var move_speed: float = 140.0
@export var jump_impulse: float = -360.0
@export var gravity: float = 1300.0
@export var slide_speed: float = 420.0
@export var slide_time: float = 0.30
@export var hero_id: String = "GENERIC"   # set per-scene in Inspector

## -- Internals --------------------------------------------------------------
var _is_sliding: bool = false
var _shooting_held: bool = false          # <- hold-to-shoot flag
var _coyote: float = 0.0                  # jump forgiveness
const RUN_THRESHOLD := 5.0                 # min speed to count as "moving"

@onready var gfx: Node2D = $GFX
@onready var anim: AnimatedSprite2D = $GFX/AnimatedSprite2D
@onready var _weapon: Weapon = $GFX/WeaponHolder/Weapon

func _ready() -> void:
	if owner == get_tree().current_scene:
		gfx.scale.x = 1.0
		_play("breathe_idle")
	if _weapon:
		_weapon.set_shooter(self)
	# We no longer need animation_finished for shooting loops, but keep it if other anims rely on it
	# anim.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_input(delta)
	update_animation()
	move_and_slide()

func _on_jump():
	if $SFX_Jump.playing:
		$SFX_Jump.stop()
	$SFX_Jump.play()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_coyote = 0.12

func handle_input(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if not _is_sliding:
		velocity.x = dir * move_speed
		if dir != 0:
			gfx.scale.x = -1.0 if dir < 0 else 1.0

	# Jump
	if Input.is_action_just_pressed("jump") and (_coyote > 0.0 or is_on_floor()):
		velocity.y = jump_impulse
		_on_jump()
	if _coyote > 0.0:
		_coyote -= delta

	# Slide
	if Input.is_action_just_pressed("slide") and not _is_sliding:
		start_slide()

	# --- Shooting (automatic) ---
	_shooting_held = Input.is_action_pressed("shoot")
	if _weapon:
		_weapon.set_trigger(_shooting_held)  
		if _shooting_held:
			_weapon.try_fire()    
			
func update_animation() -> void:
	# 1) If holding shoot, force shooting loop (air or ground)
	if _shooting_held:
		if anim.animation != "shooting" or not anim.is_playing():
			_play("shooting", "running")   # 'shooting' should be Loop = On in SpriteFrames
		return

	# 2) Airborne next
	var airborne := not is_on_floor()
	if airborne and not _is_sliding:
		_play("jumping", "running")
		return

	# 3) Sliding
	if _is_sliding:
		_play("running")
		return

	# 4) Grounded locomotion
	var moving := absf(velocity.x) > RUN_THRESHOLD
	var target := "running" if moving else "breathe_idle"
	if anim.animation != target or not anim.is_playing():
		_play(target)

func start_slide() -> void:
	_is_sliding = true
	var facing_sign := -1.0 if gfx.scale.x < 0.0 else 1.0
	velocity.x = slide_speed * facing_sign

	$CollisionShape2D.disabled = true
	await get_tree().create_timer(slide_time).timeout
	$CollisionShape2D.disabled = false
	_is_sliding = false

# --- helpers ---------------------------------------------------------------

func _play(bname: String, fallback: String = "") -> void:
	var target := bname
	if anim.sprite_frames and not anim.sprite_frames.has_animation(bname):
		target = fallback if (fallback != "" and anim.sprite_frames.has_animation(fallback)) else bname
	if anim.animation != target or not anim.is_playing():
		anim.play(target)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
