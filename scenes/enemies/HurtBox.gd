# res://scripts/enemies/HurtboxRelay.gd
extends Area2D

@export var boss_owner: NodePath
@onready var boss := get_node(boss_owner)    # set to ".." in the Inspector

func _ready() -> void:
	# We detect player bullets which should also be Area2D
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(a: Area2D) -> void:
	# Accept either a method or a 'damage' property
	var dmg := 0
	if a.has_method("get_damage"):
		dmg = a.get_damage()
	elif "damage" in a:
		dmg = a.damage

	if dmg > 0 and boss and boss.has_method("apply_damage"):
		boss.apply_damage(dmg)

	# Optional: delete the bullet on hit
	if a.is_inside_tree():
		a.queue_free()
