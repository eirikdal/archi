# scripts/weapons/Bullet.gd
extends CharacterBody2D
class_name Bullet

@export var speed: float = 520.0
@export var damage: int = 1
@export var lifetime: float = 1.2          # seconds
@export var pierce: int = 0                # 0 = no pierce, >0 allows N hits before despawn

var _time: float = 0.0
var _dir: Vector2 = Vector2.RIGHT          # set by spawner

var _owner: Node = null

func setup(direction: Vector2, owner: Node = null) -> void:
	_dir = direction.normalized()
	_owner = owner
	if owner and owner is CollisionObject2D:
		add_collision_exception_with(owner)  # don't hit the shooter

func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return

	var motion := _dir * speed * delta
	var collision := move_and_collide(motion)
	if collision:
		_hit(collision)
		if pierce > 0:
			pierce -= 1
		else:
			queue_free()

func _hit(collision: KinematicCollision2D) -> void:
	var target := collision.get_collider()
	# Flexible: damage if the body has a method or is in a group
	if target and target.has_method("apply_damage"):
		target.apply_damage(damage)
	elif target and target.is_in_group("enemies"):
		if target.has_method("take_hit"):
			target.take_hit(damage)
