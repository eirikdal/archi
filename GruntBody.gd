# scripts/enemies/GruntBot.gd
extends CharacterBody2D

@export var patrol_speed := 60.0
@export var max_hp := 4
var hp := max_hp

func _physics_process(delta):
	velocity.x = patrol_speed
	move_and_slide()
	if is_on_wall(): patrol_speed = -patrol_speed; $Sprite2D.scale.x = sign(patrol_speed)

func apply_damage(dmg:int):
	hp -= dmg
	modulate = Color.WHITE          # flash
	await get_tree().create_timer(0.05).timeout
	modulate = Color(1,1,1)
	if hp <= 0: explode()

func explode():
	var boom := preload("res://scenes/fx/SmallExplosion.tscn").instantiate()
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	queue_free()
