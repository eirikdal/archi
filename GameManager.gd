# scripts/GameManager.gd
extends Node

## --- HERO ROSTER -----------------------------------------------------------
#const HERO_SCENES := {
#	"SOVA": preload("res://scenes/actors/Sova.tscn"),
#	"RYS":  preload("res://scenes/actors/Rys.tscn"),
#	"BILKA": preload("res://scenes/actors/Bilka.tscn"),
#}

var active_hero: Node2D                   # current hero instance
var swap_cooldown := 0.0                  # seconds left before next swap
const SWAP_DELAY := 3.0

func _process(delta: float) -> void:
	if swap_cooldown > 0.0:
		swap_cooldown -= delta

## Call from Player to request a hero change -------------------------------
#func swap_to(hero_id: String) -> void:
#	if swap_cooldown > 0.0 or HERO_SCENES[hero_id] == null: return
#	var pos := active_hero.global_position
#	var facing := active_hero.scale.x
#	active_hero.queue_free()

#	active_hero = HERO_SCENES[hero_id].instantiate()
#	get_tree().current_scene.add_child(active_hero)
#	active_hero.global_position = pos
#	active_hero.scale.x = facing
#	swap_cooldown = SWAP_DELAY
