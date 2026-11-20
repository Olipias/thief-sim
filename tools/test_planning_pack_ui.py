#!/usr/bin/env python3
"""Drive an unpacked Linux release with XTest in a private Xvfb (no source scene overrides).

Usage: python3 tools/test_planning_pack_ui.py /absolute/path/thief-sim.x86_64 /tmp/qa-output
Uses existing local Xvfb, libX11/libXtst and Pillow; does not install dependencies.
"""
import ctypes as C
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from PIL import ImageChops, ImageGrab

binary = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
local = Path.home() / '.local/opt/xvfb_env'
display = next(f':{i}' for i in range(95, 180) if not Path(f'/tmp/.X{i}-lock').exists() and not Path(f'/tmp/.X11-unix/X{i}').exists())
env = dict(os.environ, DISPLAY=display, XDG_DATA_HOME=str(out / f'userdata-{time.time_ns()}'))
env.pop('WAYLAND_DISPLAY', None)
xenv = dict(env, LD_LIBRARY_PATH=str(local / 'usr/lib/x86_64-linux-gnu'))
xvfb = subprocess.Popen([str(local / 'usr/bin/Xvfb.patched'), display, '-screen', '0', '1280x720x24', '-ac', '-nolisten', 'tcp', '-noreset'], env=xenv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
game = None
d = None
checks = []
try:
    time.sleep(.5)
    log = (out / 'game.log').open('w')
    game = subprocess.Popen([str(binary), '--display-driver', 'x11', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', '--windowed', '--position', '0,0', '--resolution', '1280x720'], cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT)
    x = C.CDLL('libX11.so.6')
    xt = C.CDLL('libXtst.so.6')
    x.XOpenDisplay.argtypes = [C.c_char_p]; x.XOpenDisplay.restype = C.c_void_p
    x.XStringToKeysym.argtypes = [C.c_char_p]; x.XStringToKeysym.restype = C.c_ulong
    x.XKeysymToKeycode.argtypes = [C.c_void_p, C.c_ulong]; x.XKeysymToKeycode.restype = C.c_uint
    x.XFlush.argtypes = [C.c_void_p]
    x.XCloseDisplay.argtypes = [C.c_void_p]
    x.XDefaultRootWindow.argtypes = [C.c_void_p]; x.XDefaultRootWindow.restype = C.c_ulong
    x.XQueryTree.argtypes = [C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_ulong), C.POINTER(C.POINTER(C.c_ulong)), C.POINTER(C.c_uint)]
    x.XFetchName.argtypes = [C.c_void_p, C.c_ulong, C.POINTER(C.c_char_p)]
    x.XSetInputFocus.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_ulong]
    x.XFree.argtypes = [C.c_void_p]
    xt.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
    xt.XTestFakeButtonEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
    xt.XTestFakeMotionEvent.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_ulong]
    d = x.XOpenDisplay(display.encode())
    assert d, '无法连接专用Xvfb'

    def key(name, held=.06):
        code = x.XKeysymToKeycode(d, x.XStringToKeysym(name.encode()))
        xt.XTestFakeKeyEvent(d, code, True, 0); x.XFlush(d)
        time.sleep(held)
        xt.XTestFakeKeyEvent(d, code, False, 0); x.XFlush(d)
        time.sleep(.06)

    def click(px, py):
        xt.XTestFakeMotionEvent(d, -1, px, py, 0)
        xt.XTestFakeButtonEvent(d, 1, True, 0); x.XFlush(d)
        time.sleep(.06)
        xt.XTestFakeButtonEvent(d, 1, False, 0); x.XFlush(d)
        time.sleep(.15)

    def shot(name):
        assert game.poll() is None, '游戏提前退出'
        img = ImageGrab.grab(xdisplay=display)
        img.save(out / f'{name}.png')
        return img

    def changed(a, b, box):
        return sum(1 for px in ImageChops.difference(a.crop(box).convert('RGB'), b.crop(box).convert('RGB')).get_flattened_data() if max(px) > 8)

    def check(ok, message):
        checks.append({'passed': bool(ok), 'message': message})
        print(('PASS ' if ok else 'FAIL ') + message, flush=True)

    time.sleep(1.5)
    root_win = C.c_ulong(); parent_win = C.c_ulong(); children = C.POINTER(C.c_ulong)(); count = C.c_uint()
    x.XQueryTree(d, x.XDefaultRootWindow(d), C.byref(root_win), C.byref(parent_win), C.byref(children), C.byref(count))
    focused = False
    for i in range(count.value):
        name = C.c_char_p()
        if x.XFetchName(d, children[i], C.byref(name)) and name.value:
            if '小偷模拟器' in name.value.decode(errors='replace'):
                x.XSetInputFocus(d, children[i], 2, 0); x.XFlush(d); focused = True
            x.XFree(name)
    if children: x.XFree(children)
    assert focused, '未找到实际游戏窗口，拒绝继续做无效输入'
    shot('01-title')
    click(1040, 384)  # 当前640x360标题菜单，2倍显示，首次开始游戏
    key('Return')  # 某些X11启动首个点击只获取焦点；Enter确认当前开始按钮。
    time.sleep(.4)
    cg = shot('02-cg')
    gold = sum(r > 200 and g > 170 and b < 170 for r, g, b in cg.crop((20, 10, 350, 75)).convert('RGB').get_flattened_data())
    check(gold > 30, '发布包已通过真实按钮进入CG，未停留在标题页')
    assert gold > 30, '没有进入CG，停止后续检查'
    click(1144, 40)  # CG Skip
    time.sleep(.7)
    for _ in range(12):
        key('e')
    time.sleep(4)
    tutorial = shot('03-tutorial')
    white = sum(min(px) > 180 for px in tutorial.crop((5, 5, 600, 55)).convert('RGB').get_flattened_data())
    check(white > 100, '发布包已实际进入有任务HUD的教学关卡')
    assert white > 100, '没有进入教学，停止后续检查'
    key('Tab')
    frozen_a = shot('04-planning-before')
    key('d', .3); key('w', .2)
    frozen_b = shot('05-planning-after-movement')
    player = (110, 65, 235, 215)
    guards = (240, 470, 1150, 623)
    check(changed(frozen_a, frozen_b, player) == 0, '发布包规划中真实方向键不移动玩家')
    check(changed(frozen_a, frozen_b, guards) == 0, '发布包规划中守卫与世界画面保持冻结')
    click(288, 160)
    key('space')
    time.sleep(1.2)
    executed = shot('06-executed')
    check(changed(frozen_b, executed, player) > 40, '发布包Space执行后玩家确实移动')
    check(changed(frozen_b, executed, guards) > 40, '发布包执行后真实守卫恢复行动')
    key('Tab'); click(288, 288); key('space')
    key('s', .12)
    taken_a = shot('07-takeover')
    time.sleep(1.2)
    taken_b = shot('08-takeover-guard-continues')
    check(changed(taken_a, taken_b, guards) > 40, '发布包方向键接管后守卫继续行动')
    report = {'binary': str(binary), 'checks': checks, 'failures': sum(not c['passed'] for c in checks)}
    (out / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    if report['failures']:
        raise SystemExit(1)
finally:
    if game is not None:
        game.terminate()
        try: game.wait(timeout=5)
        except subprocess.TimeoutExpired: game.kill(); game.wait()
    if d: x.XCloseDisplay(d)
    xvfb.terminate()
    xvfb.wait(timeout=5)
