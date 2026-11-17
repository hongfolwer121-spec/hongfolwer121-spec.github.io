class_name CatModel
extends Node3D
## The purchased rigged cat: loads the model, applies the coat texture, plays animations by
## behavior state, and layers body-language bones (ears, tail, eyelids) on top of the animation.
## The asset files live in assets/thirdparty/cat/ and are NOT in git (license), so
## CatActor falls back to the primitive placeholder when they are missing.

const DIR := "res://assets/thirdparty/cat/"
const MODEL := DIR + "cat.glb"
const SCALE := 2.0   # larger than life so the cats read well on a phone screen

## Behavior state -> animation candidates (a random one is picked on entry).
## Names as imported by Godot ("_loop" removed from the original asset names).
const STATE_ANIMS := {
	"idle": ["Idle_1", "Idle_2", "Idle_3", "Idle_4", "Idle_5", "Idle_6", "Idle_7"],
	"walk": ["Walk_F_IP"],
	"run": ["RunFast_F_IP"],
	"sleep": ["Lie_side_sleep", "Lie_belly_sleep"],
	"eat": ["Eating"],
	"wait_food": ["Sit_1"],
	"groom": ["Lick"],
	"play": ["CrouchIdle_1"],
	"approach": ["Sit_2", "Sit_3"],
	"jealous": ["Sit_2"],
	"sit_window": ["Sit_1", "Lie_belly_1"],
	"box": ["Sit_3", "Lie_belly_1"],
	"scratch": ["SharpenClaws_Vert"],
	"perch": ["Lie_belly_1"],
}
const PET_ANIMS := {"sleep": "Caress_lie", "perch": "Caress_lie", "box": "Caress_sit", "wait_food": "Caress_sit",
	"approach": "Caress_sit", "jealous": "Caress_sit", "sit_window": "Caress_sit"}

var player: AnimationPlayer
var skeleton: Skeleton3D
var overlay: CatBoneOverlay
var current_state := ""
var one_shot_left := 0.0


static func available() -> bool:
	return ResourceLoader.exists(MODEL)


func setup(coat_albedo: int, rng: RandomNumberGenerator) -> void:
	var scene: PackedScene = load(MODEL)
	var inst := scene.instantiate()
	add_child(inst)
	scale = Vector3.ONE * SCALE
	player = inst.find_child("AnimationPlayer", true, false)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	for anim_name in player.get_animation_list():
		# Godot's importer strips "_loop" from names (Sit_loop_1 -> Sit_1) and loops those itself.
		if anim_name.begins_with("Idle") or anim_name.ends_with("_IP") \
				or anim_name in ["Eating", "Drinking", "Lick", "Lie_side_sleep", "Lie_belly_sleep", "SharpenClaws_Vert", "Scratching"]:
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	player.playback_default_blend_time = 0.3
	_apply_coat(coat_albedo)
	overlay = CatBoneOverlay.new()
	add_child(overlay)
	overlay.setup(skeleton, player)
	play_state("idle", rng)


func _apply_coat(index: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(DIR + "CatSimple_Albedo_%d.png" % index)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR  # fur cards; cheaper than blending on phones
	mat.alpha_scissor_threshold = 0.45
	mat.normal_enabled = true
	mat.normal_texture = load(DIR + "CatSimple_Normal.png")
	mat.roughness_texture = load(DIR + "CatSimple_Roughness.png")
	mat.roughness = 1.0
	for m in find_children("*", "MeshInstance3D", true, false):
		m.material_override = mat


func play_state(state: String, rng: RandomNumberGenerator) -> void:
	if state == current_state and one_shot_left <= 0.0:
		return
	current_state = state
	var choices: Array = STATE_ANIMS.get(state, STATE_ANIMS["idle"])
	var anim_name: String = choices[rng.randi() % choices.size()]
	if player.has_animation(anim_name):
		player.play(anim_name)


## A short reaction (being petted) that returns to the state animation afterwards.
func play_pet(rng: RandomNumberGenerator) -> void:
	var anim_name: String = PET_ANIMS.get(current_state, "Caress_idle")
	if player.has_animation(anim_name):
		player.play(anim_name)
		one_shot_left = minf(player.get_animation(anim_name).length, 3.0)
		current_state = "_pet"


func tick(delta: float, rng: RandomNumberGenerator, state: String) -> void:
	if one_shot_left > 0.0:
		one_shot_left -= delta
		if one_shot_left > 0.0:
			return
		current_state = ""
	play_state(state, rng)
