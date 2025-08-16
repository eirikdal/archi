# scripts/weapons/Weapon.gd
extends Node2D
class_name Weapon

@export var bullet_scene: PackedScene
@export var fire_rate: float = 8.0
@export var muzzle_path: NodePath = ^"Muzzle"
@export var spawn_forward_px: float = 6.0
@export var shooter_root_path: NodePath    # optional: set to Player in Inspector

var _cooldown := 0.0
var _muzzle: Marker2D
var _shooter: CollisionObject2D            # the body to ignore (Player)

func _ready() -> void:
	_resolve_shooter()
	_resolve_muzzle()

func _process(delta: float) -> void:
	if _cooldown > 0.0: _cooldown -= delta

func set_shooter(node: Node) -> void:
	# Call this from Player.gd for 100% correctness
	if node is CollisionObject2D:
		_shooter = node

func try_fire() -> void:
	if _cooldown > 0.0 or bullet_scene == null:
		return
	_cooldown = 1.0 / max(fire_rate, 0.001)

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return
	get_tree().current_scene.add_child(bullet)

	# Fire direction from muzzle's right vector (respects flips/rotation)
	var basis_x := -(_muzzle.global_transform.x if _muzzle else global_transform.x).normalized()
	var spawn_pos := (_muzzle.global_position if _muzzle else global_position) + basis_x * spawn_forward_px

	bullet.global_position = spawn_pos

	# Pass direction + shooter; ensure no self-collision
	if bullet.has_method("setup"):
		bullet.setup(basis_x, _shooter)
	elif bullet is CharacterBody2D:
		var b := bullet as CharacterBody2D
		b.velocity = basis_x * 520.0
		if _shooter:
			b.add_collision_exception_with(_shooter)

func _resolve_muzzle() -> void:
	_muzzle = null
	if String(muzzle_path) != "" and has_node(muzzle_path):
		_muzzle = get_node(muzzle_path) as Marker2D
	if _muzzle == null:
		var found := find_child("Muzzle", true, false)
		if found and found is Marker2D:
			_muzzle = found
	if _muzzle == null:
		push_warning('Weapon: No Muzzle found; using Weapon transform.')

func _resolve_shooter() -> void:
	# 1) Inspector override
	if shooter_root_path != NodePath() and has_node(shooter_root_path):
		var n := get_node(shooter_root_path)
		if n is CollisionObject2D:
			_shooter = n
			return

	# 2) Walk up to find the first CollisionObject2D (Player, usually)
	var p := get_parent()
	while p:
		if p is CollisionObject2D:
			_shooter = p
			return
		p = p.get_parent()

	# 3) If nothing found, warn (bullets may hit the weapon)
	_shooter = null
	push_warning("Weapon: Shooter not resolved; set shooter_root_path or call set_shooter(self) from Player.")
