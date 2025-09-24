# res://scripts/ui/PlayerHealthBar.gd
# Node setup (suggested):
# CanvasLayer
#  └─ Control (size anchors full)
#      └─ ProgressBar (name: "Bar", min=0, max=100)
extends Control

@export var player_path: NodePath
@onready var _bar: ProgressBar = $Bar
var _health: Health

func _ready() -> void:
	if player_path != NodePath():
		var player := get_node(player_path)
		_health = player.get_node_or_null("Health")
	if _health:
		_bar.min_value = 0
		_bar.max_value = _health.max_health
		_bar.value = _health.current
		_health.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, maxv: int) -> void:
	_bar.max_value = maxv
	_bar.value = current
