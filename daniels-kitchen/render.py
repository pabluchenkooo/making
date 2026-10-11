"""Build a Blender scene from export/*.stl and render it.

    ./export.sh                                   # OpenSCAD -> export/*.stl
    blender -b -P render.py                       # render both views to renders/
    blender -b -P render.py -- --no-render        # only build kitchen.blend
    blender -b -P render.py -- --samples 32       # quicker, noisier
    blender -b -P render.py -- --video            # walk-through -> renders/walkthrough.mp4
    blender -b -P render.py -- --only wall_counter,wall_opposite   # just these cameras

Opens nicely afterwards with: open kitchen.blend
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export")
RENDERS = os.path.join(HERE, "renders")

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DO_RENDER = "--no-render" not in args
DO_VIDEO = "--video" in args
SAMPLES = int(args[args.index("--samples") + 1]) if "--samples" in args else 128
ONLY = args[args.index("--only") + 1].split(",") if "--only" in args else None

# room, in metres (same numbers as kitchen.scad, /100)
ROOM_X0, ROOM_X1 = -5.22, -2.125
ROOM_Y0, ROOM_Y1 = -1.43, 0.58
CEILING = 2.655


# ---------------------------------------------------------------- materials
def principled(name, color, rough=0.5, metal=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
    return m, b


def noisy(name, light, dark, scale, rough=0.5, bump=0.05):
    """Principled material whose colour is streaky noise between two tones."""
    m, b = principled(name, light, rough)
    nt = m.node_tree
    n = nt.nodes
    coord = n.new("ShaderNodeTexCoord")
    mapping = n.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.0
    noise.inputs["Detail"].default_value = 10.0
    noise.inputs["Roughness"].default_value = 0.6
    ramp = n.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (*light, 1)
    bmp = n.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = bump
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(noise.outputs["Fac"], bmp.inputs["Height"])
    nt.links.new(bmp.outputs["Normal"], b.inputs["Normal"])
    return m


def make_materials():
    # birch plywood: pale, low-contrast grain stretched along Z
    ply = noisy("Birch plywood", (0.56, 0.44, 0.27), (0.46, 0.35, 0.20), (25, 25, 2), rough=0.6, bump=0.02)
    ply_back = noisy("Birch plywood (inside)", (0.48, 0.37, 0.22), (0.40, 0.30, 0.17), (25, 25, 2), rough=0.65, bump=0.02)
    # countertop: matte charcoal linoleum
    top = noisy("Charcoal linoleum", (0.032, 0.034, 0.036), (0.024, 0.025, 0.027), (40, 40, 40), rough=0.55, bump=0.005)
    floor = noisy("Floor", (0.26, 0.25, 0.23), (0.20, 0.19, 0.18), (3, 3, 3), rough=0.7, bump=0.02)
    # export/<name>.stl -> material (names come from the colors in kitchen.scad)
    return {
        "oak": ply,
        "oak_dk": ply_back,
        "stone": top,
        "floor": floor,
        "wall": principled("Plaster", (0.62, 0.60, 0.56), 0.9)[0],
        "column": principled("Plaster column", (0.62, 0.60, 0.56), 0.9)[0],
        "door": principled("Door paint", (0.70, 0.70, 0.68), 0.4)[0],
        "black": principled("Matte black", (0.02, 0.02, 0.02), 0.45)[0],
        "steel": principled("Steel", (0.75, 0.75, 0.76), 0.28, metal=1.0)[0],
        "white": principled("Appliance white", (0.75, 0.75, 0.74), 0.2, coat=0.3)[0],
        "glass": principled("Black glass", (0.01, 0.01, 0.012), 0.05, coat=1.0)[0],
    }


# ---------------------------------------------------------------- geometry
def import_parts(mats):
    for f in sorted(os.listdir(EXPORT)):
        if not f.endswith(".stl"):
            continue
        name = f[:-4]
        bpy.ops.wm.stl_import(filepath=os.path.join(EXPORT, f), global_scale=0.01)
        ob = bpy.context.selected_objects[0]
        ob.name = name
        ob.data.materials.clear()
        ob.data.materials.append(mats.get(name, mats["wall"]))
        if name in ("oak", "oak_dk", "stone", "white", "black", "door"):
            bev = ob.modifiers.new("bevel", "BEVEL")
            bev.width = 0.002
            bev.segments = 2
            bev.limit_method = "ANGLE"


# Window at the window end: NOT in the SketchUp model, size is a guess.
WINDOW_Y = (-0.75, 0.40)   # from/to along the wall
WINDOW_Z = (1.00, 2.35)    # sill / top


def add_box(name, x0, x1, y0, y1, z0, z1, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    o.data.materials.append(mat)
    return o


def add_window_wall(wall, frame):
    x0, x1 = ROOM_X0 - 0.25, ROOM_X0
    (wy0, wy1), (wz0, wz1) = WINDOW_Y, WINDOW_Z
    ys, ye = ROOM_Y0 - 0.18, ROOM_Y1 + 0.18
    add_box("win_wall_l", x0, x1, ys, wy0, 0, CEILING, wall)
    add_box("win_wall_r", x0, x1, wy1, ye, 0, CEILING, wall)
    add_box("win_wall_b", x0, x1, wy0, wy1, 0, wz0, wall)
    add_box("win_wall_t", x0, x1, wy0, wy1, wz1, CEILING, wall)
    f = 0.05   # black frame, like the reference
    xf0, xf1 = ROOM_X0 - 0.12, ROOM_X0 - 0.06
    add_box("frame_b", xf0, xf1, wy0, wy1, wz0, wz0 + f, frame)
    add_box("frame_t", xf0, xf1, wy0, wy1, wz1 - f, wz1, frame)
    add_box("frame_l", xf0, xf1, wy0, wy0 + f, wz0, wz1, frame)
    add_box("frame_r", xf0, xf1, wy1 - f, wy1, wz0, wz1, frame)
    mid = (wy0 + wy1) / 2
    add_box("frame_m", xf0, xf1, mid - f / 2, mid + f / 2, wz0, wz1, frame)
    add_box("sill", ROOM_X0 - 0.12, ROOM_X0 + 0.02, wy0, wy1, wz0 - 0.03, wz0, wall)


def add_ceiling(mat):
    bpy.ops.mesh.primitive_plane_add(size=1, location=((ROOM_X0 + ROOM_X1) / 2, (ROOM_Y0 + ROOM_Y1) / 2, CEILING))
    c = bpy.context.object
    c.name = "ceiling"
    c.scale = (ROOM_X1 - ROOM_X0 + 0.4, ROOM_Y1 - ROOM_Y0 + 0.4, 1)
    c.data.materials.append(mat)


# ---------------------------------------------------------------- light + camera
def look_at(ob, target):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def add_lights():
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.78, 0.86, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.6

    # daylight through the (open) window end
    bpy.ops.object.light_add(type="SUN", location=(ROOM_X0 - 2, 0, 3))
    sun = bpy.context.object
    sun.data.energy = 2.0
    sun.data.angle = math.radians(3)
    sun.rotation_euler = Vector((1, 0.35, -0.55)).to_track_quat("-Z", "Y").to_euler()

    # big soft fill where the window is
    (wy0, wy1), (wz0, wz1) = WINDOW_Y, WINDOW_Z
    bpy.ops.object.light_add(type="AREA", location=(ROOM_X0 - 0.13, (wy0 + wy1) / 2, (wz0 + wz1) / 2))
    win = bpy.context.object
    win.visible_camera = False
    win.data.shape = "RECTANGLE"
    win.data.size, win.data.size_y = wy1 - wy0, wz1 - wz0
    win.data.energy = 80
    win.data.color = (0.9, 0.95, 1.0)
    look_at(win, (ROOM_X1, (ROOM_Y0 + ROOM_Y1) / 2, 1.2))

    # warm recessed ceiling spots
    for x in (-4.6, -3.7, -2.8):
        bpy.ops.object.light_add(type="AREA", location=(x, -0.45, CEILING - 0.02))
        s = bpy.context.object
        s.data.shape = "DISK"
        s.data.size = 0.1
        s.data.energy = 25
        s.data.color = (1.0, 0.86, 0.7)


def add_camera(name, loc, target, lens=19, clip_start=0.1):
    cam = bpy.data.cameras.new(name)
    cam.lens = lens
    cam.clip_start = clip_start
    ob = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    look_at(ob, target)
    return ob


def add_wall_camera(name, wall_y, cut_y):
    """Straight-on view of one long wall from outside the room. Everything
    between the camera and cut_y (the other wall and its furniture) is clipped
    away, so the wall is seen as if the room were cut open."""
    dist = 4.2
    side = 1 if wall_y > cut_y else -1
    cx, cz = (ROOM_X0 + ROOM_X1) / 2, CEILING / 2
    ob = add_camera(name, (cx, wall_y - side * dist, cz), (cx, wall_y, cz),
                    lens=38, clip_start=abs(cut_y - (wall_y - side * dist)))
    ob["resolution"] = (1600, 1300)  # about the wall's proportions
    return ob


# Objects left out of a camera's render, e.g. the open door hides the tall shelf.
HIDE = {"wall_opposite": ["door"]}


# Walk-through: (frame, camera position, point looked at), eye height 1.62 m.
# Counter wall is at +y, sideboard wall at -y.
# Look targets stay near eye height so walls stay vertical with the wide lens.
WALK = [
    (1,   (-1.85, -0.62, 1.62), (-5.2, -0.40, 1.52)),   # in the doorway
    (60,  (-2.60, -0.48, 1.62), (-5.2, -0.30, 1.52)),   # step in
    (120, (-3.05, -0.45, 1.62), (-3.90, 0.58, 1.52)),   # look at sink / counter
    (180, (-3.45, -0.45, 1.62), (-4.10, -1.43, 1.52)),  # turn to sideboard + coffee
    (240, (-4.15, -0.40, 1.62), (-5.22, -0.15, 1.52)),  # towards the window
    (285, (-4.25, -0.42, 1.62), (-4.30, -1.43, 1.52)),  # turn via the side wall...
    (340, (-4.25, -0.42, 1.62), (-2.10, -0.90, 1.52)),  # ...back to the door + tall shelf
]


def add_walk():
    target = bpy.data.objects.new("walk_target", None)
    bpy.context.scene.collection.objects.link(target)
    cam = add_camera("walk", WALK[0][1], WALK[0][2], lens=20)
    track = cam.constraints.new("TRACK_TO")
    track.target = target
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    for frame, pos, look in WALK:
        cam.location = pos
        target.location = look
        cam.keyframe_insert("location", frame=frame)
        target.keyframe_insert("location", frame=frame)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, WALK[-1][0] + 20
    sc.render.fps = 24
    return cam


def render_video(cam):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.use_raytracing = True
    except AttributeError:
        pass
    sc.eevee.taa_render_samples = 32
    sc.render.resolution_x, sc.render.resolution_y = 1280, 800
    s = sc.render.image_settings
    if hasattr(s, "media_type"):
        s.media_type = "VIDEO"
    s.file_format = "FFMPEG"
    sc.render.ffmpeg.format = "MPEG4"
    sc.render.ffmpeg.codec = "H264"
    sc.render.ffmpeg.constant_rate_factor = "HIGH"
    sc.render.filepath = os.path.join(RENDERS, "walkthrough.mp4")
    bpy.ops.render.render(animation=True)
    print("wrote", sc.render.filepath)


# ---------------------------------------------------------------- render
def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.view_settings.exposure = -0.5
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:
        print("GPU not available, using CPU:", e)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    import_parts(mats)
    add_ceiling(mats["wall"])
    add_window_wall(mats["wall"], mats["black"])
    add_lights()
    setup_render()

    mid_y = (ROOM_Y0 + ROOM_Y1) / 2
    cams = [
        add_camera("from_door", (ROOM_X1 - 0.12, mid_y - 0.05, 1.62), (ROOM_X0, mid_y + 0.05, 1.05)),
        add_camera("from_window", (ROOM_X0 + 0.15, mid_y, 1.62), (ROOM_X1, mid_y, 1.05)),
        # counter fronts end at y -0.06, opposite furniture at y -0.78: cut in between
        add_wall_camera("wall_counter", ROOM_Y1, -0.45),
        add_wall_camera("wall_opposite", ROOM_Y0, -0.40),
    ]
    walk = add_walk()
    bpy.context.scene.camera = cams[0]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "kitchen.blend"))

    if DO_VIDEO:
        os.makedirs(RENDERS, exist_ok=True)
        render_video(walk)
    elif DO_RENDER:
        os.makedirs(RENDERS, exist_ok=True)
        for cam in cams:
            if ONLY and cam.name not in ONLY:
                continue
            sc = bpy.context.scene
            sc.render.resolution_x, sc.render.resolution_y = cam.get("resolution", (1600, 1000))
            for ob in sc.objects:
                ob.hide_render = ob.name in HIDE.get(cam.name, [])
            bpy.context.scene.camera = cam
            bpy.context.scene.render.filepath = os.path.join(RENDERS, cam.name + ".png")
            bpy.ops.render.render(write_still=True)
            print("wrote", bpy.context.scene.render.filepath)


main()
