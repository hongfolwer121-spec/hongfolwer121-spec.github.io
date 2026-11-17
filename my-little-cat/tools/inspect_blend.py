import sys, bpy
path = sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=path, load_ui=False, use_scripts=False)
print("FILE", path)
for o in bpy.data.objects:
    extra = ""
    if o.type == "ARMATURE":
        extra = f" bones={len(o.data.bones)}"
    if o.type == "MESH":
        extra = f" tris~{sum(len(p.vertices)-2 for p in o.data.polygons)} shapekeys={len(o.data.shape_keys.key_blocks) if o.data.shape_keys else 0}"
    print("OBJ", o.type, o.name, extra)
print("ACTIONS", len(bpy.data.actions))
print("ACTION_NAMES", [a.name for a in bpy.data.actions][:200])
for im in bpy.data.images:
    print("IMG", im.name, "packed" if im.packed_file else "external", im.filepath, tuple(im.size))
arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
if arm:
    print("BONES", [b.name for b in arm.data.bones])
