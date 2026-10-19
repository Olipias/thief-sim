"""渲染双羊尊转台序列（供 2D 游戏精灵管线使用）。

打开 assets/models/ram_zun.blend（含影棚灯光与相机），把器物绕 Z 轴旋转
N 个角度逐帧渲染：透明背景、384×384、Cycles CPU。

用法：
    blender --background --factory-startup --python tools/blender/render_relic_turntable.py
    FRAMES=12 SAMPLES=24 OUTDIR=/tmp/opencode/relic_turntable blender ... （可选环境变量）

输出：OUTDIR/f00.png .. f11.png 与 OUTDIR/hero.png（3/4 视角大图，用于图标与档案）
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
OUT = os.environ.get("OUTDIR", "/tmp/opencode/relic_turntable")
FRAMES = int(os.environ.get("FRAMES", "12"))
SAMPLES = int(os.environ.get("SAMPLES", "24"))
RES = int(os.environ.get("RES", "384"))


def log(*a):
    print("[%6.1fs]" % (time.time() - T0), *a, flush=True)


def look_at(obj, target):
    d = obj.location - Vector(target)
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


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

    # 转台序列
    for i in range(FRAMES):
        pivot.rotation_euler = (0.0, 0.0, 2.0 * math.pi * i / FRAMES)
        sc.render.filepath = os.path.join(OUT, "f%02d.png" % i)
        bpy.ops.render.render(write_still=True)
        log("rendered frame", i)
    log("done:", OUT)


main()
