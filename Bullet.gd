extends CharacterBody2D
class_name Bullet

@export var speed: float = 920.0
@export var damage: int = 4
@export var lifetime: float = 0.35
@export var max_trail_points: int = 6
@export var knockback: float = 80.0

var _dir: Vector2
@onready var trail: Line2D = $Trail

func _ready() -> void:
	# direction from current rotation (assumes sprite faces +X)
	_dir = Vector2.RIGHT.rotated(rotation)
	velocity = _dir * speed

	# simple trail init
	trail.clear_points()
	trail.add_point(global_position)
	trail.add_point(global_position)

	# auto-despawn
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# move fast; detect hit
	var collision := move_and_collide(velocity * delta)
	if collision:
		_on_hit(collision)
		return

	# trail update
	trail.add_point(global_position)
	while trail.get_point_count() > max_trail_points:
		trail.remove_point(0)

func _on_hit(col: KinematicCollision2D) -> void:
	var target := col.get_collider()
	if target:
		# apply damage if available
		if target.has_method("apply_damage"):
			target.apply_damage(damage)
		# optional knockback for bodies
		if target is CharacterBody2D:
			var cb := target as CharacterBody2D
			cb.velocity += _dir * knockback
	# tiny impact fx hook could go here
	queue_free()

func get_damage() -> int:
	return damage
