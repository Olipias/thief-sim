"""渲染双羊尊转台序列（供 2D 游戏精灵管线使用）。

打开 assets/models/ram_zun.blend（含影棚灯光与相机），把器物绕 Z 轴旋转
N 个角度逐帧渲染：透明背景、384×384、Cycles CPU。

默认使用项目提供的**混元 3D 资产** `assets/models/e6b392eeb4fe60c7dd831782abaec83f.glb`
（50 万面 + 4K PBR），归一化到程序化模型的尺寸（高 0.443 m、底部 Z=0）后复用同一影棚；
`MODEL=procedural` 可退回程序化模型 `ram_zun.blend` 里的器身。

用法：
    blender --background --factory-startup --python tools/blender/render_relic_turntable.py
    MODEL=procedural blender ...        # 用程序化模型渲染
    FRAMES=12 SAMPLES=24 OUTDIR=/tmp/opencode/relic_turntable blender ... （可选环境变量）

输出：OUTDIR/f00.png .. f11.png、hero.png（图标/档案）、closeup.png（互动特写层）
"""
import math
import os
import sys
import time

import bpy
from mathutils import Vector

T0 = time.time()
PROJ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND = os.path.join(PROJ, "assets", "models", "ram_zun.blend")
SCAN_GLB = os.path.join(PROJ, "assets", "models", "e6b392eeb4fe60c7dd831782abaec83f.glb")
MODEL = os.environ.get("MODEL", "scan")  # scan（默认，混元 3D 资产）| procedural（程序化）
TARGET_HEIGHT = 0.443  # 与程序化模型一致（馆藏高 45.1 cm 的演绎尺寸）
OUT = os.environ.get("OUTDIR", "/tmp/opencode/relic_turntable")
FRAMES = int(os.environ.get("FRAMES", "12"))
SAMPLES = int(os.environ.get("SAMPLES", "24"))
RES = int(os.environ.get("RES", "384"))
CLOSEUP_RES = int(os.environ.get("CLOSEUP_RES", "768"))


def log(*a):
    print("[%6.1fs]" % (time.time() - T0), *a, flush=True)


def look_at(obj, target):
    d = obj.location - Vector(target)
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def world_bounds(meshes):
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for ob in meshes:
        for corner in ob.bound_box:
            w = ob.matrix_world @ Vector(corner)
            mins = Vector((min(mins[i], w[i]) for i in range(3)))
            maxs = Vector((max(maxs[i], w[i]) for i in range(3)))
    return mins, maxs


def import_scan_of_zun():
    """导入混元 3D 资产，缩放/居中到影棚里的标准尺寸与原点（底部 Z=0）。"""
    old = bpy.data.objects.get("ram_zun")
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=SCAN_GLB)
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "ground"]
    if not meshes:
        print("混元 3D 资产导入后没有网格", file=sys.stderr)
        sys.exit(1)
    mins, maxs = world_bounds(meshes)
    scale = TARGET_HEIGHT / max(1e-6, (maxs - mins).z)
    for ob in meshes:
        ob.scale = tuple(v * scale for v in ob.scale)
        ob.location = tuple(v * scale for v in ob.location)
    bpy.context.view_layer.update()
    mins, maxs = world_bounds(meshes)
    shift = Vector((-(mins.x + maxs.x) * 0.5, -(mins.y + maxs.y) * 0.5, -mins.z))
    for ob in meshes:
        ob.location += shift
    # 混元 3D 资产的 PBR 镜面偏强：渲染时压低高光，保留 4K 基础色的纹理细节
    for ob in meshes:
        for mat in ob.data.materials:
            if mat is None or not mat.use_nodes:
                continue
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is not None:
                bsdf.inputs["Specular IOR Level"].default_value = 0.25
    log("using scan model:", os.path.basename(SCAN_GLB), "scale %.4f" % scale,
        "bounds %.3f x %.3f x %.3f" % (maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z))


def main():
    if not os.path.exists(BLEND):
        print("缺少模型文件：", BLEND, file=sys.stderr)
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    sc = bpy.context.scene

    # 影棚设置：透明背景、CPU Cycles、固定分辨率
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"

    # 隐藏地面（精灵不要地面阴影），保留灯光与相机
    ground = bpy.data.objects.get("ground")
    if ground is not None:
        ground.hide_render = True

    # 器身来源：默认用混元 3D 资产；缺失或 MODEL=procedural 时用 blend 里的程序化模型
    if MODEL != "procedural" and os.path.exists(SCAN_GLB):
        import_scan_of_zun()
    else:
        log("using procedural model (scan missing or MODEL=procedural)")

    # 所有网格挂到原点 Empty 上，旋转 Empty 即转台
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o is not ground]
    if not meshes:
        print("blend 里没有可渲染的网格", file=sys.stderr)
        sys.exit(1)
    pivot = bpy.data.objects.new("pivot", None)
    sc.collection.objects.link(pivot)
    for ob in meshes:
        ob.parent = pivot
        ob.matrix_parent_inverse = pivot.matrix_world.inverted()
    log("mesh objects:", [o.name for o in meshes])

    cam = sc.camera
    if cam is None:
        print("blend 里没有相机", file=sys.stderr)
        sys.exit(1)

    # 3/4 视角（与预览图同机位），略微抬高以便看清双羊轮廓
    cam.location = Vector((0.72, -0.72, 0.52))
    cam.data.lens = 62
    look_at(cam, (0, 0, 0.215))

    # hero 大图（图标与档案用）
    pivot.rotation_euler = (0.0, 0.0, math.radians(35.0))
    sc.render.filepath = os.path.join(OUT, "hero.png")
    bpy.ops.render.render(write_still=True)
    log("rendered hero")

    # 电影感特写（按 E 互动后的 2.5D 特写层用）：更近的机位、更长焦
    sc.render.resolution_x = CLOSEUP_RES
    sc.render.resolution_y = CLOSEUP_RES
    pivot.rotation_euler = (0.0, 0.0, math.radians(24.0))
    cam.location = Vector((0.70, -0.70, 0.50))
    cam.data.lens = 64
    look_at(cam, (0, 0, 0.22))
    sc.render.filepath = os.path.join(OUT, "closeup.png")
    bpy.ops.render.render(write_still=True)
    log("rendered closeup")
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    cam.location = Vector((0.72, -0.72, 0.52))
    cam.data.lens = 62
    look_at(cam, (0, 0, 0.215))

    # 转台序列
    for i in range(FRAMES):
        pivot.rotation_euler = (0.0, 0.0, 2.0 * math.pi * i / FRAMES)
        sc.render.filepath = os.path.join(OUT, "f%02d.png" % i)
        bpy.ops.render.render(write_still=True)
        log("rendered frame", i)
    log("done:", OUT)


main()
