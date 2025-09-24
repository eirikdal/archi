# res://scripts/ui/EnemyHealthBar2D.gd
# Node setup (under enemy scene):
# Node2D (name: "HealthBar2D", script attached)
#  └─ ColorRect (name: "Back", size = Vector2(18, 3), color = Color(0,0,0,0.6))
#  └─ ColorRect (name: "Fill", size = Vector2(18, 3), color = Color(1,1,1,1))
extends Node2D

@export var target_path: NodePath = NodePath("..") # enemy root
@export var offset: Vector2 = Vector2(0, -20)
@export var hide_delay: float = 1.2

@onready var _back: ColorRect = $Back
@onready var _fill: ColorRect = $Fill
@onready var _timer: Timer = Timer.new()

var _health: Health
var _width: float

func _ready() -> void:
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_hide)

	var target := get_node_or_null(target_path)
	if target:
		_health = target.get_node_or_null("Health")
		if _health:
			_health.health_changed.connect(_on_health_changed)
			_health.damaged.connect(_on_damaged)
			_health.died.connect(_hide)

	_width = _back.size.x
	visible = false

func _process(_dt: float) -> void:
	var target := get_node_or_null(target_path)
	if target:
		global_position = target.global_position + offset

func _on_health_changed(current: int, maxv: int) -> void:
	if maxv <= 0:
		return
	var ratio := float(current) / float(maxv)
	_fill.size.x = max(0.0, _width * ratio)
	if current <= 0:
		visible = false

func _on_damaged(_amt: int) -> void:
	visible = true
	_timer.start(hide_delay)

func _hide() -> void:
	visible = false
