#!/usr/bin/env python3
"""Build an Excalidraw scene that embeds a storyboard panel as JPEG (small
enough for reliable share uploads). Usage: build_scene.py <panel.png> <out.excalidraw>"""
import base64, io, json, sys, time
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
im = im.resize((960, 720), Image.LANCZOS)
buf = io.BytesIO(); im.save(buf, 'JPEG', quality=88, optimize=True)
b64 = base64.b64encode(buf.getvalue()).decode()
now = int(time.time() * 1000)

def text(id_, x, y, s, size=20):
    return {"id": id_, "type": "text", "x": x, "y": y, "width": 960, "height": size * 1.4, "angle": 0,
            "strokeColor": "#1e1e1e", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 1,
            "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": None,
            "roundness": None, "seed": 2, "version": 1, "versionNonce": 2, "isDeleted": False,
            "boundElements": None, "updated": now, "link": None, "locked": False, "text": s,
            "fontSize": size, "fontFamily": 5, "textAlign": "left", "verticalAlign": "top",
            "containerId": None, "originalText": s, "autoResize": True, "lineHeight": 1.25}

scene = {
    "type": "excalidraw", "version": 2, "source": "https://excalidraw.com",
    "elements": [
        {"id": "panel", "type": "image", "x": 0, "y": 0, "width": 960, "height": 720, "angle": 0,
         "strokeColor": "transparent", "backgroundColor": "transparent", "fillStyle": "solid", "strokeWidth": 2,
         "strokeStyle": "solid", "roughness": 0, "opacity": 100, "groupIds": [], "frameId": None,
         "roundness": None, "seed": 1, "version": 1, "versionNonce": 1, "isDeleted": False,
         "boundElements": None, "updated": now, "link": None, "locked": False, "status": "saved",
         "fileId": "panel_jpg", "scale": [1, 1]},
        text("cap", 0, 740, "第一幕 · 第 1 张 · 签约前：线人用戒指抵款（分镜草稿）", 22),
    ],
    "appState": {"viewBackgroundColor": "#ffffff", "gridSize": None},
    "files": {"panel_jpg": {"mimeType": "image/jpeg", "id": "panel_jpg",
                            "dataURL": "data:image/jpeg;base64," + b64, "created": now, "lastRetrieved": now}},
}
json.dump(scene, open(out, 'w', encoding='utf-8'), ensure_ascii=False)
print('wrote', out, 'bytes', len(json.dumps(scene)))
