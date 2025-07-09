# scripts/weapons/Projectile.gd
extends Area2D
@export var speed := 480.0
@export var damage := 2

func _physics_process(delta):
	global_position += Vector2.RIGHT.rotated(rotation) * speed * delta
	if not get_viewport_rect().has_point(get_viewport().get_camera_2d().unproject_position(global_position)):
		queue_free()

func _on_body_entered(body):
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
	queue_free()
