# scripts/weapons/Weapon.gd
extends Node2D
class_name Weapon

@export var bullet_scene: PackedScene
@export var fire_rate: float = 7.0
@export var muzzle_path: NodePath = ^"Muzzle"
@export var spawn_forward_px: float = 6.0
@export var shooter_root_path: NodePath    # optional: set to Player in Inspector

# --- Burst/SFX sync (audio loop: 1.4s on + 0.2s off = 1.6s total) ---
@export var burst_on: float = 1.4
@export var burst_off: float = 20

var _cooldown := 0.0
var _muzzle: Marker2D
var _shooter: CollisionObject2D            # the body to ignore (Player)
var _trigger_held := false

@onready var _sfx: AudioStreamPlayer2D = $SFX_MachineGun

func _ready() -> void:
	_resolve_shooter()
	_resolve_muzzle()

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func set_shooter(node: Node) -> void:
	# Call this from Player.gd for 100% correctness
	if node is CollisionObject2D:
		_shooter = node

func set_trigger(held: bool) -> void:
	if held == _trigger_held:
		return
	_trigger_held = held
	if held:
		# Start the audio loop at phase 0 so phase == 0..burst_on aligns with firing window
		if _sfx:
			if _sfx.playing:
				_sfx.stop()
			_sfx.play(0.0)  # Audio stream should have Loop = On; file already contains the 0.2s gap
	else:
		# Stop audio when trigger released
		if _sfx and _sfx.playing:
			_sfx.stop()
		# optional: clear cooldown so next press feels snappy
		_cooldown = 0.0

func _in_burst_window() -> bool:
	if not _trigger_held:
		return false
	var cycle := burst_on + burst_off
	if _sfx and _sfx.playing and cycle > 0.0:
		var phase := fmod(_sfx.get_playback_position(), cycle)
		return phase < burst_on           # allow bullets only during the 1.4s "on"
	# If audio hasn’t started yet this frame, allow (phase ~ 0)
	return true

func try_fire() -> void:
	# --- burst gate: enforce 1.4s on / 0.2s off synced to audio ---
	if not _in_burst_window():
		return

	# --- your existing fire-rate throttle ---
	if _cooldown > 0.0 or bullet_scene == null:
		return
	_cooldown = 1.0 / max(fire_rate, 0.001)

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return
	get_tree().current_scene.add_child(bullet)

	# Fire direction from muzzle's right vector (respects flips/rotation)
	var dir := 1
	var basis_x := dir * (_muzzle.global_transform.x if _muzzle else global_transform.x).normalized()
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

	# NOTE: audio start/stop handled in set_trigger(); don't auto-play here

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
