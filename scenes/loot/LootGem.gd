# res://scripts/loot/LootGem.gd
extends Area2D
class_name LootGem

@export var score_value: int = 250
@export var heal_amount: int = 0
@export var pickup_sfx: AudioStream
@export var texture: Texture2D                 # e.g. res://art/placeholder/gem.png
@export var magnet_radius: float = 96.0
@export var magnet_accel: float = 260.0

@onready var spr: Sprite2D = $Sprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _vel: Vector2 = Vector2.ZERO
var _spawn_y: float

func _ready() -> void:
	if texture:
		spr.texture = texture
	_spawn_y = global_position.y
	col.disabled = false
	set_process(true)

	# simple bob animation
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", position.y - 2.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position:y", position.y + 2.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	# mild magnet to nearest player
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var to_p:Vector2 = (player.global_position - global_position)
		if to_p.length() <= magnet_radius:
			_vel += to_p.normalized() * magnet_accel * delta
			_vel = _vel.limit_length(220.0)
			global_position += _vel * delta

func _on_body_entered(body: Node) -> void:
	_pickup(body)

func _on_area_entered(area: Area2D) -> void:
	_pickup(area)

func _pickup(_who: Node) -> void:
	# only once
	if col.disabled: return
	col.disabled = true

	# award via GameManager (score/health)
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if gm.has_method("on_loot_collected"):
			gm.call("on_loot_collected", score_value, "gem")
		if heal_amount > 0 and gm.has_method("heal_player"):
			gm.call("heal_player", heal_amount)

	# sfx
	if pickup_sfx:
		audio.stream = pickup_sfx
		audio.play()

	# tiny pop + fade
	var t := create_tween()
	t.tween_property(spr, "scale", spr.scale * 1.25, 0.08)
	t.tween_property(spr, "modulate:a", 0.0, 0.18).set_delay(0.06)

	# free after sfx or tween
	await get_tree().create_timer(0.25).timeout
	queue_free()
