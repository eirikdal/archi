# res://scripts/components/Health.gd
extends Node
class_name Health

signal health_changed(current: int, max: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 100 : set = _set_max
var current: int

@export var invuln_time: float = 0.0 # seconds
var _invuln_until_ms: int = 0

func _ready() -> void:
	current = max_health
	emit_signal("health_changed", current, max_health)

func _set_max(v: int) -> void:
	max_health = max(1, v)
	if current > max_health:
		current = max_health
	emit_signal("health_changed", current, max_health)

func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	if Time.get_ticks_msec() < _invuln_until_ms:
		return
	current = clamp(current - amount, 0, max_health)
	emit_signal("damaged", amount)
	emit_signal("health_changed", current, max_health)
	if current == 0:
		emit_signal("died")
	elif invuln_time > 0.0:
		set_invulnerable(invuln_time)

func heal(amount: int) -> void:
	if amount <= 0 or current == max_health:
		return
	current = clamp(current + amount, 0, max_health)
	emit_signal("health_changed", current, max_health)

func set_invulnerable(duration: float) -> void:
	# use ticks to avoid needing a Timer node
	_invuln_until_ms = Time.get_ticks_msec() + int(max(0.0, duration) * 1000.0)
