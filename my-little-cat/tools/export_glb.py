import sys, bpy
src, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src, load_ui=False, use_scripts=False)
KEEP_MESH = "Cat_LOD2"   # ~6k tris: enough for a phone, 3 cats on screen
WANT = ["Idle_1","Idle_2","Idle_3","Idle_4","Idle_5","Idle_6","Idle_7","Walk_F_IP","Trot_F_IP","Run_F_IP","RunFast_F_IP",
        "Turn_L_IP","Turn_R_IP","Sit_start","Sit_loop_1","Sit_loop_2","Sit_loop_3","Sit_end",
        "Lie_belly_start","Lie_belly_loop_1","Lie_belly_end","Lie_belly_sleep_start","Lie_belly_sleep","Lie_belly_sleep_end",
        "Lie_side_start","Lie_side_loop_1","Lie_side_end","Lie_side_sleep_start","Lie_side_sleep","Lie_side_sleep_end",
        "Trans_Sit_LieBelly","Trans_LieBelly_Sit","Trans_Sit_LieSide","Trans_LieSide_Sit",
        "EatDrink_start","Eating","Drinking","EatDrink_end","Lick","Scratching","SharpenClaws_Vert","SharpenClaws_Horiz",
        "Caress_idle","Caress_sit","Caress_lie","CrouchIdle_start","CrouchIdle_loop_1","CrouchIdle_end","Crouch_F_IP",
        "Attack_F","JumpPlace_IP","JumpUp1_end_IP","JumpStart_place_IP","JumpLand_Place","Hit_F"]
for o in list(bpy.data.objects):
    if o.type == "MESH" and o.name != KEEP_MESH:
        bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.name not in WANT:
        bpy.data.actions.remove(a)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
# one NLA track per action so the glTF exporter writes them all as separate animations
arm.animation_data_create()
for a in bpy.data.actions:
    a.use_fake_user = True
print("actions kept", len(bpy.data.actions))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="ACTIONS",
    export_animations=True, export_skins=True, export_apply=False, export_image_format="NONE")
print("WROTE", out)
