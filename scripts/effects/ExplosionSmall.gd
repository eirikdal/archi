extends Node2D
class_name ExplosionSmall

@export var life: float = 0.6           # give smoke time
@export var sfx: AudioStream
@export var texture: Texture2D          # spark texture for the main burst
@export var smoke_texture: Texture2D    # NEW: smoke texture for the trail
@export var particle_amount: int = 24

@onready var p: CPUParticles2D = $Sparks        # main sparks
@onready var smoke: CPUParticles2D = $Smoke        # secondary smoke
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var light: PointLight2D = $PointLight2D

@export var flipbook_texture: Texture2D
@onready var flip: AnimatedSprite2D = $AnimatedSprite2D

func _play_flipbook(tex: Texture2D, frames: int, size: Vector2i) -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("boom")
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2i(i * size.x, 0, size.x, size.y)
		sf.add_frame("boom", at)
	flip.sprite_frames = sf
	flip.play("boom")
	flip.centered = true
	flip.offset = Vector2.ZERO
	# auto-hide once it’s done (particles timer will still free the node)
	flip.animation_finished.connect(func():
		flip.visible = false
	)
	
func _ready() -> void:
	# --- Main burst ---
	p.amount = particle_amount
	if texture: p.texture = texture
	p.one_shot = true
	p.emitting = false
	p.restart()
	p.emitting = true
	if flipbook_texture and flip:
		_play_flipbook(flipbook_texture, 5, Vector2i(16,16))

	# --- Smoke trail ---
	if smoke:
		if smoke_texture: smoke.texture = smoke_texture
		smoke.one_shot = true
		smoke.emitting = false
		smoke.restart()
		smoke.emitting = true

	# --- SFX ---
	if sfx:
		audio.stream = sfx
		audio.pitch_scale = randf_range(0.96, 1.04)
		audio.play()

	# --- Flash ---
	light.energy = 1.2
	var t := create_tween()
	t.tween_property(light, "energy", 0.0, life * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# --- Despawn after the longest particle lifetime ---
	var longest := life
	if smoke:
		longest = max(longest, smoke.lifetime)
	await get_tree().create_timer(longest, false, true, true).timeout
	queue_free()

func randf_range(a: float, b: float) -> float:
	return lerp(a, b, randf())
