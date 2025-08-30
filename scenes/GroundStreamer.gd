# res://scripts/GroundStreamer.gd
extends Node2D
class_name GroundStreamer

@export var chunk_scene: PackedScene
@export var chunk_width: int = 320           # px. If tiles are 16 px and width=20 tiles: 20*16 = 320
@export var keep_chunks_each_side: int = 3   # how far to keep around the focus
@export var focus_path: NodePath             # Player or Camera2D
@export var ground_y: float = 0.0            # vertical placement of the chunk root

var _spawned: Dictionary = {} # key: int index -> Node

func _process(_dt: float) -> void:
	if chunk_scene == null: return
	var focus := get_node_or_null(focus_path)
	if focus == null: return

	var x := int(round(focus.global_position.x))
	var center_idx := floori(x / float(chunk_width))
	_ensure_chunks(center_idx)

func _ensure_chunks(center_idx: int) -> void:
	var from_idx := center_idx - keep_chunks_each_side
	var to_idx := center_idx + keep_chunks_each_side

	# spawn missing
	for i in range(from_idx, to_idx + 1):
		if not _spawned.has(i):
			var c := chunk_scene.instantiate()
			add_child(c)
			c.position = Vector2(i * chunk_width, ground_y)
			_spawned[i] = c

	# despawn far-away
	var to_free: Array = []
	for k in _spawned.keys():
		if k < from_idx or k > to_idx:
			to_free.append(k)
	for k in to_free:
		_spawned[k].queue_free()
		_spawned.erase(k)
