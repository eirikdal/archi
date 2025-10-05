# res://scripts/effects/DebrisPiece.gd
extends RigidBody2D
class_name DebrisPiece

@export var lifetime: float = 2.2
@export var sprite_frames: SpriteFrames       # optional flipbook, else single texture
@export var texture: Texture2D                # e.g. res://art/placeholder/debris.png
@export var spin_min: float = -12.0
@export var spin_max: float = 12.0

@onready var spr: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var smoke: CPUParticles2D = $TrailSmoke

func _ready() -> void:
	freeze = false
	contact_monitor = true
	max_contacts_reported = 2
	angular_velocity = randf_range(spin_min, spin_max)

	if sprite_frames:
		spr.sprite_frames = sprite_frames
		spr.play()
	elif texture:
		spr.sprite_frames = SpriteFrames.new()
		var frames := spr.sprite_frames
		var anim := "single"
		frames.add_animation(anim)
		frames.add_frame(anim, texture)
		spr.play(anim)

	smoke.emitting = true
	await get_tree().create_timer(lifetime, false, true, true).timeout
	queue_free()

func randf_range(a: float, b: float) -> float:
	return lerp(a, b, randf())
