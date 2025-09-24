extends Area2D
class_name TankShell

@export var speed: float = 360.0
@export var damage: int = 12
@export var lifetime: float = 2.5
@export var knockback: float = 160.0

# Assign these in the Inspector (WAV/OGG)
@export var launch_stream: AudioStream
@export var flight_stream: AudioStream     # loopable "whoosh" (optional)
@export var impact_stream: AudioStream

var _dir: Vector2
var _alive: bool = true

@onready var col: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $Lifetime
@onready var trail: AnimatedSprite2D = $Trail
@onready var boom: AnimatedSprite2D = $Explosion
@onready var sfx_launch: AudioStreamPlayer2D = $SfxLaunch
@onready var sfx_flight: AudioStreamPlayer2D = $SfxFlight
@onready var sfx_impact: AudioStreamPlayer2D = $SfxImpact

func _ready() -> void:
	# Direction
	_dir = Vector2.RIGHT.rotated(rotation)

	# VFX
	trail.visible = true
	trail.play("trail")
	boom.visible = false
	if not boom.animation_finished.is_connected(_on_boom_finished):
		boom.animation_finished.connect(_on_boom_finished)

	# Lifetime
	lifetime_timer.wait_time = lifetime
	if not lifetime_timer.timeout.is_connected(_on_Lifetime_timeout):
		lifetime_timer.timeout.connect(_on_Lifetime_timeout)
	lifetime_timer.start()

	# Collisions
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_hit):
		body_entered.connect(_on_body_hit)
	if not area_entered.is_connected(_on_area_hit):
		area_entered.connect(_on_area_hit)

	# --- Audio ---
	# Launch
	if launch_stream:
		sfx_launch.stream = launch_stream
		sfx_launch.pitch_scale = randf_range(0.98, 1.03)
		sfx_launch.play()

	# Flight (optional)
	if flight_stream:
		sfx_flight.stream = flight_stream
		# ensure your asset is looped, or set stream.loop = true on import
		sfx_flight.pitch_scale = randf_range(0.97, 1.02)
		sfx_flight.play()

func _physics_process(delta: float) -> void:
	if _alive:
		global_position += _dir * speed * delta

func _on_body_hit(body: Node) -> void:
	_hit(body)

func _on_area_hit(a: Area2D) -> void:
	if a == self: return
	_hit(a)

func _hit(target: Node) -> void:
	if not _alive: return
	_alive = false

	# Damage/knockback
	if target and target.has_method("apply_damage"):
		target.apply_damage(damage)
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity += _dir * knockback

	# Stop further collisions & visuals
	col.disabled = true
	monitoring = false
	trail.visible = false

	# Audio: stop flight, play impact
	if sfx_flight.playing:
		sfx_flight.stop()
	if impact_stream:
		sfx_impact.stream = impact_stream
		sfx_impact.pitch_scale = randf_range(0.97, 1.03)
		sfx_impact.play()

	# Explosion anim
	boom.visible = true
	boom.play("explosion")

func _on_boom_finished() -> void:
	queue_free()

func _on_Lifetime_timeout() -> void:
	queue_free()
