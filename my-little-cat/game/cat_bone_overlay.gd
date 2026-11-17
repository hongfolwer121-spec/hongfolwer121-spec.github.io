class_name CatBoneOverlay
extends Node
## Body language on top of whatever animation is playing:
## ears flatten when annoyed, tail lashes or rises, eyelids close for slow blinks and sleep.
## Applied right after the AnimationPlayer writes its pose (mixer_applied), so the animation
## cannot overwrite it within the same frame.

var ears_back := 0.0      # 0..1
var tail_lash := 0.0      # 0..1 fast side-to-side swish
var tail_up := 0.0        # 0..1 greeting tail
var eyes_closed := 0.0    # 0..1

var skeleton: Skeleton3D
var _t := 0.0
var _bones := {}          # name -> index
var _base := {}           # index -> pose rotation written by the animation
var _written := {}        # index -> rotation we wrote last time


func setup(sk: Skeleton3D, player: AnimationPlayer) -> void:
	skeleton = sk
	for b in ["ear_1.L", "ear_1.R", "eyelid.L", "eyelid.R", "tail_01", "tail_02"]:
		_bones[b] = sk.find_bone(b)
	player.mixer_applied.connect(apply)


func _process(delta: float) -> void:
	_t += delta


func _target(bone_name: String) -> Quaternion:
	# Axes measured on the asset with close-up renders: local Z flattens ears and lowers eyelids.
	match bone_name:
		"ear_1.L", "ear_1.R":
			return Quaternion(Vector3.BACK, 0.9 * ears_back)
		"eyelid.L", "eyelid.R":
			return Quaternion(Vector3.BACK, 1.4 * eyes_closed)
		"tail_01":
			var swish := sin(_t * 9.0) * deg_to_rad(25.0) * tail_lash
			return Quaternion(Vector3.UP, swish) * Quaternion(Vector3.RIGHT, deg_to_rad(-45.0) * tail_up)
		"tail_02":
			return Quaternion(Vector3.UP, sin(_t * 9.0) * deg_to_rad(25.0) * tail_lash)
	return Quaternion.IDENTITY


func apply() -> void:
	if skeleton == null:
		return
	for bone_name in _bones:
		var idx: int = _bones[bone_name]
		if idx < 0:
			continue
		var cur := skeleton.get_bone_pose_rotation(idx)
		# If the animation did not key this bone this frame, the pose is still what we wrote:
		# reuse the previous base instead of stacking the offset again.
		if not (_written.has(idx) and cur.is_equal_approx(_written[idx])):
			_base[idx] = cur
		var out: Quaternion = _base.get(idx, cur) * _target(bone_name)
		skeleton.set_bone_pose_rotation(idx, out)
		_written[idx] = out
