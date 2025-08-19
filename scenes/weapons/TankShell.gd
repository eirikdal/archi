extends Area2D
class_name TankShell

@export var speed: float = 180.0
@export var damage: int = 8
@export var lifetime: float = 3.0

var _dir: Vector2

func _ready() -> void:
	_dir = Vector2.RIGHT.rotated(rotation) # move in node's facing
	$Lifetime.wait_time = lifetime
	$Lifetime.start()
	body_entered.connect(_on_body_hit)

func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta

func _on_body_hit(body: Node) -> void:
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
	queue_free()

func _on_Lifetime_timeout() -> void:
	queue_free()
