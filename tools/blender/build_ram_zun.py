"""双羊尊（ram_zun）3D 模型生成脚本。

程序化建模：两羊背对背的尊体、卷角羊首、喇叭口与口沿、扉棱、胸口饰板、
分尾、四足，配顶点色铜绿（随 glTF COLOR_0 导出）。尺寸对齐大英博物馆
馆藏数据（高约 45 cm、宽约 41 cm），风格化再现（细密雷纹未逐条建模）。

用法（需要 Blender 5.x，headless 即可，Cycles CPU）：
  # 开发预览：渲染各视角到 OUTDIR（默认 /tmp/opencode），不动项目文件
  RENDER=1 OUTDIR=/tmp/opencode blender --background --factory-startup --python tools/blender/build_ram_zun.py

  # 正式生成：写入 assets/models/（ram_zun.blend / ram_zun.glb / ram_zun_preview.png）
  FINAL=1 RENDER=1 SAMPLES=64 blender --background --factory-startup --python tools/blender/build_ram_zun.py

环境变量：
  OUTDIR   渲染图与暂存 blend 的输出目录（默认 /tmp/opencode）
  SAMPLES  Cycles 采样数（默认 24；出正式预览用 64+）
  RENDER   0 跳过渲染
  FINAL    1 = 保存到 assets/models/ 并导出 GLB + 预览图（生成物禁止手改）

改形体的入口：BODY_TABLE（器身截面）、NECK_OUTER/NECK_INNER（口沿剖面）、
HEAD_SECTIONS/JAW_SECTIONS（羊首）、build_head() 内的羊角参数、build_panel()
（胸口饰板）、build_fin()（扉棱）、build_tail()（分尾）。
"""
import bpy
import bmesh
import os
import time
from math import sin, cos, pi, radians, sqrt
from mathutils import Vector, Matrix, noise

T0 = time.time()
OUT = os.environ.get("OUTDIR", "/tmp/opencode")
SAMPLES = int(os.environ.get("SAMPLES", "24"))
RENDER = os.environ.get("RENDER", "1") == "1"
FINAL = os.environ.get("FINAL", "0") == "1"


def log(*a):
    print("[%6.1fs]" % (time.time() - T0), *a, flush=True)


# ---------------------------------------------------------------- 基础工具

def wipe_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, color, metallic, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return m


def new_obj(name, verts, faces, mat=None, fix_normals=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [list(f) for f in faces])
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat is not None:
        ob.data.materials.append(mat)
    if fix_normals:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    return ob


def revolve(profile, seg=48):
    """profile: [(r, z)] 连续折线（r=0 作极点）。"""
    verts, faces, rings = [], [], []
    for r, z in profile:
        if r <= 1e-6:
            rings.append(("p", len(verts)))
            verts.append((0.0, 0.0, z))
        else:
            idx = []
            for i in range(seg):
                a = 2 * pi * i / seg
                idx.append(len(verts))
                verts.append((r * cos(a), r * sin(a), z))
            rings.append(("r", idx))
    for k in range(len(rings) - 1):
        ta, A = rings[k]
        tb, B = rings[k + 1]
        if ta == "p" and tb == "p":
            continue
        if ta == "p":
            for i in range(seg):
                faces.append((A, B[i], B[(i + 1) % seg]))
        elif tb == "p":
            for i in range(seg):
                faces.append((A[i], A[(i + 1) % seg], B))
        else:
            for i in range(seg):
                faces.append((A[i], A[(i + 1) % seg], B[(i + 1) % seg], B[i]))
    return verts, faces


def loft(sections, cap_start=True, cap_end=True):
    """sections: 依次的闭合环（点列表，长度一致）。"""
    verts, faces, idxs = [], [], []
    for sec in sections:
        row = []
        for p in sec:
            row.append(len(verts))
            verts.append(tuple(p))
        idxs.append(row)
    n = len(idxs[0])
    for k in range(len(idxs) - 1):
        A, B = idxs[k], idxs[k + 1]
        for i in range(n):
            faces.append((A[i], A[(i + 1) % n], B[(i + 1) % n], B[i]))
    if cap_start:
        faces.append(tuple(reversed(idxs[0])))
    if cap_end:
        faces.append(tuple(idxs[-1]))
    return verts, faces


def ring_z(z, rx, ry, cx=0.0, cy=0.0, n=48):
    return [(cx + rx * cos(2 * pi * i / n), cy + ry * sin(2 * pi * i / n), z) for i in range(n)]


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def interp_table(table, z):
    """table: [(z, a, b, c...)] 按 z 升序；返回同样尾部元组的插值。"""
    if z <= table[0][0]:
        return table[0][1:]
    if z >= table[-1][0]:
        return table[-1][1:]
    for i in range(len(table) - 1):
        z0 = table[i][0]
        z1 = table[i + 1][0]
        if z0 <= z <= z1:
            t = smoothstep((z - z0) / (z1 - z0))
            a, b = table[i][1:], table[i + 1][1:]
            return tuple(a[j] + (b[j] - a[j]) * t for j in range(len(a)))
    return table[-1][1:]


def sphere(name, loc, r, mat, scale=(1, 1, 1), seg=20):
    verts, faces = revolve([(0.0, -1.0), (0.6, -0.72), (0.95, -0.3), (1.0, 0.0), (0.95, 0.3), (0.6, 0.72), (0.0, 1.0)], seg)
    verts = [(v[0] * scale[0] * r + loc[0], v[1] * scale[1] * r + loc[1], v[2] * scale[2] * r + loc[2]) for v in verts]
    return new_obj(name, verts, faces, mat)


def torus(name, loc, major, minor, mat, seg_major=48, seg_minor=8):
    verts, faces = [], []
    for i in range(seg_major):
        a = 2 * pi * i / seg_major
        for j in range(seg_minor):
            b = 2 * pi * j / seg_minor
            r = major + minor * cos(b)
            verts.append((r * cos(a) + loc[0], r * sin(a) + loc[1], minor * sin(b) + loc[2]))
    for i in range(seg_major):
        for j in range(seg_minor):
            a0 = i * seg_minor + j
            a1 = i * seg_minor + (j + 1) % seg_minor
            b0 = ((i + 1) % seg_major) * seg_minor + j
            b1 = ((i + 1) % seg_major) * seg_minor + (j + 1) % seg_minor
            faces.append((a0, a1, b1, b0))
    return new_obj(name, verts, faces, mat)


def box(name, center, half, mat):
    cx, cy, cz = center
    hx, hy, hz = half
    verts = [
        (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
    ]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return new_obj(name, verts, faces, mat)


def tube(name, points, radii, side_dir, sides, mat, ribs=0, rib_amp=0.0, twist_phase=0.0):
    """沿 points 扫掠圆管；side_dir 为截面的一个基准方向（外法线）。"""
    verts, faces = [], []
    n = len(points)
    for i in range(n):
        p = points[i]
        if i == 0:
            t = (points[1] - points[0])
        elif i == n - 1:
            t = (points[-1] - points[-2])
        else:
            t = (points[i + 1] - points[i - 1])
        t.normalize()
        d1 = side_dir - t * side_dir.dot(t)
        if d1.length < 1e-6:
            d1 = Vector((0, 0, 1)) - t * t.z
        d1.normalize()
        d2 = t.cross(d1).normalized()
        r = radii[i]
        if ribs > 0:
            tt = i / (n - 1)
            r *= (1.0 + rib_amp * sin(2 * pi * ribs * tt + twist_phase))
        for k in range(sides):
            a = 2 * pi * k / sides
            q = p + d1 * (r * cos(a)) + d2 * (r * sin(a))
            verts.append(tuple(q))
    for i in range(n - 1):
        A = i * sides
        B = (i + 1) * sides
        for k in range(sides):
            faces.append((A + k, A + (k + 1) % sides, B + (k + 1) % sides, B + k))
    # 端盖
    c0 = len(verts)
    verts.append(tuple(points[0]))
    for k in range(sides):
        faces.append((0 + (k + 1) % sides, 0 + k, c0))
    c1 = len(verts)
    verts.append(tuple(points[-1]))
    base = (n - 1) * sides
    for k in range(sides):
        faces.append((base + k, base + (k + 1) % sides, c1))
    return new_obj(name, verts, faces, mat)


def auto_smooth(obj, angle_deg=38.0):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    thr = radians(angle_deg)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            try:
                ang = e.calc_face_angle()
            except ValueError:
                ang = 0.0
            if ang is not None and ang > thr:
                e.smooth = False
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------- 材质

MAT = {}


def build_materials():
    bronze = make_mat("Bronze Patina", (0.24, 0.34, 0.24), 0.30, 0.65)    # 顶点色铜绿斑驳：斑驳颜色直接写进顶点色，导出 GLB 时随 COLOR_0 携带
    nt = bronze.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    vcol = nt.nodes.new("ShaderNodeVertexColor")
    vcol.layer_name = "Color"
    vcol.location = (-320, 120)
    nt.links.new(vcol.outputs["Color"], bsdf.inputs["Base Color"])
    print("BASE COLOR LINKED:", bsdf.inputs["Base Color"].is_linked)
    MAT["bronze"] = bronze
    MAT["dark"] = make_mat("Bronze Recess", (0.070, 0.110, 0.085), 0.30, 0.75)
    MAT["worn"] = make_mat("Bronze Worn", (0.260, 0.360, 0.260), 0.45, 0.55)


def apply_patina_colors(obj):
    me = obj.data
    attr = me.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    dark = Vector((0.030, 0.075, 0.045))
    light = Vector((0.180, 0.300, 0.170))
    for i, v in enumerate(me.vertices):
        co = v.co
        n1 = noise.noise(co * 30.0)  # 大块斑驳
        n2 = noise.noise(co * 85.0 + Vector((11.0, 7.0, 3.0)))  # 细碎颗粒
        t = 0.46 + 0.36 * n1 + 0.17 * n2
        t *= 0.62 + 0.38 * (co.z / 0.44)  # 高处磨亮、低处积绿
        t = max(0.0, min(1.0, t))
        c = dark + (light - dark) * t
        attr.data[i].color = (c.x, c.y, c.z, 1.0)


# ---------------------------------------------------------------- 几何

# 每半只羊的躯体截面表：(z, rx, ry, cx)  cx 会乘以朝向 S
BODY_TABLE = [
    (0.130, 0.040, 0.038, 0.040),
    (0.150, 0.070, 0.065, 0.042),
    (0.180, 0.095, 0.086, 0.047),
    (0.215, 0.112, 0.098, 0.052),
    (0.255, 0.120, 0.101, 0.054),
    (0.290, 0.120, 0.097, 0.048),
    (0.310, 0.112, 0.090, 0.040),
    (0.325, 0.100, 0.082, 0.026),
    (0.340, 0.062, 0.060, 0.000),
]

NECK_OUTER = [
    (0.000, 0.318),
    (0.078, 0.318),
    (0.066, 0.336),
    (0.058, 0.348),
    (0.055, 0.366),
    (0.057, 0.386),
    (0.068, 0.404),
    (0.068, 0.412),
    (0.085, 0.420),
    (0.085, 0.432),
    (0.074, 0.438),
    (0.070, 0.432),
    (0.069, 0.412),
    (0.063, 0.400),
    (0.060, 0.396),
]
NECK_INNER = [
    (0.059, 0.394),
    (0.054, 0.376),
    (0.049, 0.354),
    (0.000, 0.354),
]
NECK_R = [
    (0.336, 0.066),
    (0.348, 0.058),
    (0.366, 0.055),
    (0.386, 0.057),
    (0.404, 0.068),
    (0.412, 0.068),
    (0.416, 0.070),
]

LEG_PROFILE = [
    (0.000, 0.000),
    (0.030, 0.000),
    (0.033, 0.006),
    (0.024, 0.014),
    (0.020, 0.048),
    (0.021, 0.078),
    (0.027, 0.102),
    (0.032, 0.132),
    (0.038, 0.162),
    (0.000, 0.162),
]

HEAD_SECTIONS = [
    (0.068, 0.370, 0.052, 0.050),
    (0.100, 0.372, 0.048, 0.048),
    (0.130, 0.366, 0.042, 0.046),
    (0.152, 0.358, 0.032, 0.040),
    (0.170, 0.350, 0.024, 0.032),
    (0.186, 0.342, 0.017, 0.024),
    (0.198, 0.336, 0.011, 0.016),
    (0.206, 0.332, 0.006, 0.009),
]
JAW_SECTIONS = [
    (0.146, 0.316, 0.028, 0.013),
    (0.168, 0.311, 0.021, 0.010),
    (0.188, 0.307, 0.014, 0.008),
    (0.200, 0.304, 0.007, 0.005),
]
TAIL_OUTLINE = [
    (-0.019, 0.158), (0.019, 0.158), (0.018, 0.132), (0.016, 0.118), (0.016, 0.070),
    (0.008, 0.056), (0.006, 0.108), (-0.006, 0.108), (-0.008, 0.056), (-0.016, 0.070),
    (-0.016, 0.118), (-0.018, 0.132),
]


def rounded_rect_section(zh, yh, z):
    """(y, z) 截面：给 (zh: 中心高, yh: 半宽, z: 半径) 返回 8 边形。"""
    c = min(zh * 0.35, yh * 0.45, 0.012)
    pts = [
        (yh - c, -zh), (yh, -zh + c), (yh, zh - c), (yh - c, zh),
        (-yh + c, zh), (-yh, zh - c), (-yh, -zh + c), (-yh + c, -zh),
    ]
    return [(y, zc) for y, zc in pts]


def y_body_surface(z):
    rx, ry, cx = interp_table(BODY_TABLE, z)
    k = max(0.0, 1.0 - (cx / rx) ** 2)
    return ry * sqrt(k)


def build_neck(parts):
    v, f = revolve(NECK_OUTER, 48)
    parts.append(new_obj("neck", v, f, MAT["bronze"]))
    v, f = revolve(NECK_INNER, 48)
    parts.append(new_obj("neck_inner", v, f, MAT["dark"], fix_normals=False))
    parts.append(torus("collar", (0, 0, 0.344), 0.0665, 0.0040, MAT["worn"]))
    for i in range(12):
        a = 2 * pi * i / 12 + pi / 12
        parts.append(sphere("dot", (0.0635 * cos(a), 0.0635 * sin(a), 0.353), 0.0048, MAT["worn"], seg=10))


def build_body(parts, S):
    zs = [0.130 + i * (0.340 - 0.130) / 38 for i in range(39)]
    rings = []
    for z in zs:
        rx, ry, cx = interp_table(BODY_TABLE, z)
        rings.append(ring_z(z, rx, ry, S * cx, 0.0, 48))
    v, f = loft(rings)
    parts.append(new_obj("body_%+d" % S, v, f, MAT["bronze"]))


def build_leg(parts, sx, sy):
    v, f = revolve(LEG_PROFILE, 24)
    ry = Matrix.Rotation(radians(4.0) * (1 if sy > 0 else -1), 4, "X")
    rx = Matrix.Rotation(radians(4.0) * (-1 if sx > 0 else 1), 4, "Y")
    M = Matrix.Translation((sx, sy, 0)) @ rx @ ry
    v = [tuple(M @ Vector(p)) for p in v]
    parts.append(new_obj("leg_%+.2f_%+.2f" % (sx, sy), v, f, MAT["bronze"]))


def fin_outer(z):
    a = y_body_surface(z) + 0.007
    b = interp_table(NECK_R, z)[0] + 0.006
    if z <= 0.30:
        return a
    if z >= 0.345:
        return b
    t = smoothstep((z - 0.30) / 0.045)
    return a + (b - a) * t


def build_fin(parts, ys):
    zs = [0.180 + i * (0.416 - 0.180) / 18 for i in range(19)]
    outer = [(fin_outer(z), z) for z in zs]
    outline = outer + [(y - 0.020, z) for (y, z) in reversed(outer)]
    secs = [[(-0.0045, ys * y, z) for (y, z) in outline], [(0.0045, ys * y, z) for (y, z) in outline]]
    v, f = loft(secs)
    parts.append(new_obj("fin_%+d" % ys, v, f, MAT["bronze"]))


def build_tail(parts, S):
    secs = [[(S * 0.088 + sx, y, z) for (y, z) in TAIL_OUTLINE] for sx in (-0.006, 0.006)]
    v, f = loft(secs)
    parts.append(new_obj("tail_%+d" % S, v, f, MAT["bronze"]))


def build_panel(parts, S):
    # 胸口饰板：三层截面渐出，再整体绕 Y 微转贴合肩部
    layers = [
        (0.120, 0.036, 0.033, 0.293),  # x, yh, zh, zc
        (0.146, 0.032, 0.027, 0.293),
        (0.153, 0.029, 0.023, 0.293),
    ]
    secs = []
    for x, yh, zh, zc in layers:
        pts = rounded_rect_section(zh, yh, 0)
        secs.append([(S * x, y, zc + z) for (y, z) in pts])
    v, f = loft(secs)
    ob = new_obj("panel_%+d" % S, v, f, MAT["bronze"])
    # 绕 Y 轴轻微旋转（顶部内收），再平移
    R = Matrix.Rotation(radians(-S * 7.0), 4, "Y")
    piv = Vector((S * 0.14, 0.0, 0.293))
    vv = [tuple(piv + R @ (Vector(p) - piv)) for p in v]
    ob.data.clear_geometry()
    ob.data.from_pydata(vv, [], [list(fc) for fc in f])
    ob.data.validate()
    ob.data.update()
    parts.append(ob)
    # 乳钉
    for (yy, zz, rr) in ((0.017, 0.306, 0.0095), (-0.017, 0.306, 0.0095), (0.012, 0.281, 0.0065), (-0.012, 0.281, 0.0065)):
        p = piv + R @ (Vector((S * 0.153, yy, zz)) - piv)
        parts.append(sphere("boss", (p.x + S * 0.003, p.y, p.z), rr, MAT["worn"]))


def build_head(parts, S):
    secs = []
    for (x, zc, ry, rz) in HEAD_SECTIONS:
        secs.append([(S * x, ry * cos(2 * pi * i / 32), zc + rz * sin(2 * pi * i / 32)) for i in range(32)])
    v, f = loft(secs)
    parts.append(new_obj("head_%+d" % S, v, f, MAT["bronze"]))
    # 下颌
    secs = []
    for (x, zc, ry, rz) in JAW_SECTIONS:
        secs.append([(S * x, ry * cos(2 * pi * i / 20), zc + rz * sin(2 * pi * i / 20)) for i in range(20)])
    v, f = loft(secs)
    parts.append(new_obj("jaw_%+d" % S, v, f, MAT["bronze"]))
    # 口腔阴影
    parts.append(box("mouth_%+d" % S, (S * 0.162, 0, 0.314), (0.022, 0.014, 0.010), MAT["dark"]))
    for ys in (1, -1):
        parts.append(sphere("eye_%+d_%+d" % (S, ys), (S * 0.130, ys * 0.0435, 0.370), 0.0095, MAT["worn"], seg=14))
        parts.append(sphere("pupil_%+d_%+d" % (S, ys), (S * 0.131, ys * 0.0500, 0.369), 0.0040, MAT["dark"], seg=10))
        # 耳朵
        base = Vector((S * 0.085, ys * 0.050, 0.366))
        d = Vector((S * (-0.60), ys * 0.65, -0.45)).normalized()
        vv, ff = revolve([(0.0, 0.0), (0.009, 0.003), (0.006, 0.011), (0.0, 0.022)], 8)
        M = Matrix.Translation(base) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Diagonal((1.0, 0.50, 1.0, 1.0))
        vv = [tuple(M @ Vector(p)) for p in vv]
        parts.append(new_obj("ear_%+d_%+d" % (S, ys), vv, ff, MAT["bronze"]))
        # 羊角：螺旋平面绕前向轴外倾
        C = Vector((S * 0.103, ys * 0.038, 0.363))
        u = Vector((S, 0, 0))
        w = Vector((0, 0, 1))
        phi = radians(-10.0) * S * ys
        n0 = Vector((0, -S, 0))
        n = (Matrix.Rotation(phi, 4, u) @ n0).normalized()
        pts, radii = [], []
        N = 64
        for i in range(N):
            t = i / (N - 1)
            th = radians(100.0 + 215.0 * t)
            r = 0.058 + (0.024 - 0.058) * smoothstep(t)
            p = C + (u * cos(th) + w * sin(th)) * r
            pts.append(p)
            tr = 0.0185 + (0.0035 - 0.0185) * (t ** 1.5)
            radii.append(tr)
        parts.append(tube("horn_%+d_%+d" % (S, ys), pts, radii, n, 12, MAT["worn"], ribs=11, rib_amp=0.20))


def build_all():
    parts = []
    build_neck(parts)
    for S in (1, -1):
        build_body(parts, S)
        build_tail(parts, S)
        build_panel(parts, S)
        build_head(parts, S)
    for sx in (0.088, -0.088):
        for sy in (0.078, -0.078):
            build_leg(parts, sx, sy)
    for ys in (1, -1):
        build_fin(parts, ys)
    # 合并
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    vessel = bpy.context.view_layer.objects.active
    vessel.name = "ram_zun"
    vessel.data.name = "ram_zun"
    apply_patina_colors(vessel)
    auto_smooth(vessel, 38.0)
    return vessel


# ---------------------------------------------------------------- 影棚 / 渲染

def add_studio():
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0, 0, 0))
    ground = bpy.context.object
    ground.name = "ground"
    m = make_mat("Ground", (0.72, 0.73, 0.75), 0.0, 0.9)
    ground.data.materials.append(m)

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 78
    cam = bpy.data.objects.new("Camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    for name, loc, size, energy in (("key", (0.9, -0.9, 0.9), 1.4, 60.0), ("rim", (-0.9, 0.7, 0.8), 1.1, 28.0)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.size = size
        ld.energy = energy
        lo = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(lo)
        lo.location = loc
        look_at(lo, (0, 0, 0.23))

    sd = bpy.data.lights.new("sun", "SUN")
    sd.energy = 0.8
    sd.angle = radians(12)
    so = bpy.data.objects.new("sun", sd)
    bpy.context.scene.collection.objects.link(so)
    so.location = (0.6, -0.5, 2.2)
    look_at(so, (0, 0, 0.2))

    sc = bpy.context.scene
    sc.world = bpy.data.worlds.new("Studio")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.68, 0.71, 0.76, 1.0)
    bg.inputs[1].default_value = 0.55
    return cam


def look_at(obj, target):
    d = obj.location - Vector(target)
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def setup_render(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = 820
    sc.render.resolution_y = 820
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"


def render_views(cam, tag=""):
    views = {
        "34": ((0.72, -0.72, 0.50), 62, (0, 0, 0.215)),
        "profile": ((0.02, -1.30, 0.34), 76, (0, 0, 0.215)),
        "ram": ((1.30, 0.04, 0.34), 76, (0, 0, 0.215)),
        "detail_neck": ((0.42, -0.42, 0.52), 120, (0.0, -0.06, 0.36)),
        "detail_tail": ((0.38, -0.38, 0.18), 100, (0.09, 0.0, 0.10)),
    }
    for name, (loc, lens, tgt) in views.items():
        cam.location = loc
        cam.data.lens = lens
        look_at(cam, tgt)
        bpy.context.scene.render.filepath = os.path.join(OUT, "ram_zun_%s%s.png" % (name, tag))
        bpy.ops.render.render(write_still=True)
        log("rendered", name)


# ---------------------------------------------------------------- 主流程

def main():
    wipe_scene()
    log("scene wiped")
    build_materials()
    vessel = build_all()
    log("built vessel: verts=%d faces=%d" % (len(vessel.data.vertices), len(vessel.data.polygons)))
    bb = [v.co for v in vessel.data.vertices]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    dim = mx - mn
    log("bbox dims: %.3f x %.3f x %.3f m (高 %.3f)" % (dim.x, dim.y, dim.z, dim.z))

    cam = add_studio()
    setup_render(SAMPLES)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "ram_zun_dev.blend"))
    if RENDER:
        render_views(cam)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "ram_zun_dev.blend"))
    log("saved dev blend")

    if FINAL:
        proj = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        models = os.path.join(proj, "assets", "models")
        blend_path = os.path.join(models, "ram_zun.blend")
        glb_path = os.path.join(models, "ram_zun.glb")
        os.makedirs(models, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
        bpy.ops.object.select_all(action="DESELECT")
        vessel.select_set(True)
        bpy.context.view_layer.objects.active = vessel
        bpy.ops.export_scene.gltf(
            filepath=glb_path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
        )
        preview_src = os.path.join(OUT, "ram_zun_34.png")
        if os.path.exists(preview_src):
            import shutil
            shutil.copyfile(preview_src, os.path.join(models, "ram_zun_preview.png"))
            log("preview copied to assets/models/ram_zun_preview.png")
        log("saved FINAL:", blend_path, glb_path)


main()
