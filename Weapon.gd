# scripts/weapons/Weapon.gd
extends Node2D
class_name Weapon

@export var fire_rate := 6.0             # rounds per second
@export var projectile_scene: PackedScene
@export var muzzle_offset := Vector2(16, 0)

var _cooldown := 0.0

func _process(delta):
	_cooldown = max(_cooldown - delta, 0.0)

func try_fire():
	if _cooldown > 0: return
	var b := projectile_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position + muzzle_offset.rotated(global_rotation)
	b.rotation = global_rotation
	_cooldown = 1.0 / fire_rate
