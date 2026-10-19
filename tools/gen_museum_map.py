#!/usr/bin/env python3
"""Generate the museum level layouts (linear room chains + patrol routes).

两个关卡共用同一套"房间蛇形串联"骨架，各自有独立的内容配置：

* museum          —— 城西博物馆（任务目标：青铜面具）
* british_museum  —— 大英博物馆·中国馆（任务目标：商代双羊尊）

At the game's 2x camera zoom one room fills the screen, so the player
explores one small, dense room at a time.

Writes src/levels/<level>.json which is loaded by the game at runtime.
Every generated map is validated (borders, connectivity, patrol legality,
room containment, straight patrol segments).

Tile legend:
    #  wall (solid)          W  wall with painting (solid)
    L  wall lamp (solid)     ' '  outside rock (solid)
    o  pillar (solid)        ~  carpet
    d  display case (solid)  r  rope barrier (solid)
    s  statue (solid)        v  potted plant (solid)
    p  pedestal (solid)      T  target artifact
    a  extra artifact        P  player spawn
    X  exit door             1-9  police spawns
"""
import json
import os
import sys

ROOM_W, ROOM_H = 20, 12
GAP = 2
COLS = 2

WALKABLE = ".~TapXP123456789"
SOLID = "#o.dprsvLW "


def room_origin(index):
    row, k = divmod(index, COLS)
    col = k if row % 2 == 0 else COLS - 1 - k
    return col * (ROOM_W + GAP), row * (ROOM_H + GAP)


# ---------------------------------------------------------------------------
# 关卡 1：城西博物馆（目标：青铜面具，7 间房）
# ---------------------------------------------------------------------------

MUSEUM_CONTENT = {
    0: {  # 门厅
        "cases": [(5, 2), (6, 2)],
        "plants": [(17, 9)],
        "statues": [],
        "carpet": [],
        "ropes": [],
        "artifacts": [(16, 2)],
        "target": None,
        "player": (2, 2),
        "exit": None,
        "lamps": [4, 10, 16],
        "paintings": [7, 13],
        "police": {"1": [(4, 9), (16, 9)]},
    },
    1: {  # 画廊 A
        "cases": [(16, 2)],
        "plants": [],
        "statues": [(3, 7)],
        "carpet": [(6, 4, 13, 7)],
        "ropes": [],
        "artifacts": [(3, 2), (16, 7)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [3, 10, 17],
        "paintings": [6, 13],
        "police": {"2": [(16, 4), (16, 8)]},
    },
    2: {  # 陈列室
        "cases": [(9, 5)],
        "plants": [(17, 9), (2, 2)],
        "statues": [],
        "carpet": [],
        "ropes": [(8, 4), (9, 4), (10, 4), (8, 5), (10, 5), (8, 6), (10, 6)],
        "artifacts": [(3, 8), (16, 3)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [4, 15],
        "paintings": [8, 12],
        "police": {"3": [(4, 8), (15, 8)]},
    },
    3: {  # 中央大厅（目标）
        "cases": [],
        "plants": [],
        "statues": [(3, 8), (16, 3)],
        "carpet": [(5, 3, 14, 8)],
        "ropes": [(8, 6), (9, 6), (10, 6)],
        "artifacts": [(3, 3), (15, 8)],
        "target": (9, 4),
        "player": None,
        "exit": None,
        "lamps": [2, 17],
        "paintings": [5, 14],
        "police": {"4": [(4, 3), (12, 3)], "5": [(2, 2), (2, 8)]},
    },
    4: {  # 库房
        "cases": [(4, 3), (5, 3), (4, 4), (5, 4), (13, 6), (14, 6), (13, 7), (14, 7)],
        "plants": [(17, 9)],
        "statues": [],
        "carpet": [],
        "ropes": [],
        "artifacts": [(2, 8), (17, 3)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [11],
        "paintings": [6, 13],
        "police": {"6": [(4, 9), (15, 9)]},
    },
    5: {  # 画廊 B（喘息间）
        "cases": [(3, 8)],
        "plants": [],
        "statues": [(16, 8)],
        "carpet": [(4, 3, 11, 7)],
        "ropes": [],
        "artifacts": [(15, 2)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [6, 14],
        "paintings": [9],
        "police": {},
    },
    6: {  # 后门厅（出口）
        "cases": [],
        "plants": [(2, 9), (17, 2)],
        "statues": [],
        "carpet": [],
        "ropes": [],
        "artifacts": [(3, 2)],
        "target": None,
        "player": None,
        "exit": (16, 9),
        "lamps": [5, 12],
        "paintings": [8, 16],
        "police": {"7": [(4, 6), (15, 6)]},
    },
}

# ---------------------------------------------------------------------------
# 关卡 2：大英博物馆·中国馆（目标：商代双羊尊，6 间房）
# ---------------------------------------------------------------------------

BM_CONTENT = {
    0: {  # 中国馆入口
        "cases": [(5, 2), (6, 2)],
        "plants": [(17, 9)],
        "statues": [(9, 9)],
        "carpet": [],
        "ropes": [],
        "artifacts": [(16, 2)],
        "target": None,
        "player": (2, 9),
        "exit": None,
        "lamps": [4, 10, 16],
        "paintings": [7, 13],
        "police": {"1": [(3, 7), (13, 7)]},
    },
    1: {  # 青铜器馆
        "cases": [(4, 3), (5, 3), (4, 4), (5, 4), (13, 6), (14, 6)],
        "plants": [],
        "statues": [(2, 2), (17, 8)],
        "carpet": [],
        "ropes": [],
        "artifacts": [(9, 8), (17, 2)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [6, 13],
        "paintings": [3, 16],
        "police": {"2": [(6, 2), (6, 8)]},
    },
    2: {  # 玉器馆
        "cases": [(9, 5)],
        "plants": [],
        "statues": [(3, 8), (16, 3)],
        "carpet": [(5, 3, 14, 8)],
        "ropes": [(8, 4), (9, 4), (10, 4), (8, 5), (10, 5), (8, 6), (10, 6)],
        "artifacts": [(3, 3), (15, 8)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [2, 17],
        "paintings": [5, 14],
        "police": {"3": [(5, 2), (5, 9), (15, 9), (15, 2)]},
    },
    3: {  # 中央展廊（目标：双羊尊）
        "cases": [],
        "plants": [(2, 9), (17, 2)],
        "statues": [(3, 3), (16, 8)],
        "carpet": [(4, 3, 15, 8)],
        "ropes": [(8, 6), (9, 6), (10, 6)],
        "artifacts": [(2, 2), (17, 9)],
        "target": (9, 4),
        "player": None,
        "exit": None,
        "lamps": [5, 14],
        "paintings": [3, 16],
        "police": {"4": [(4, 2), (4, 9)], "5": [(13, 2), (13, 7)]},
    },
    4: {  # 库房通道
        "cases": [(4, 3), (5, 3), (4, 4), (5, 4), (13, 6), (14, 6), (13, 7), (14, 7)],
        "plants": [(2, 9)],
        "statues": [],
        "carpet": [],
        "ropes": [],
        "artifacts": [(3, 2), (16, 9)],
        "target": None,
        "player": None,
        "exit": None,
        "lamps": [12],
        "paintings": [6, 13],
        "police": {"6": [(4, 9), (14, 9)]},
    },
    5: {  # 装卸区（出口）
        "cases": [],
        "plants": [(2, 2), (17, 9)],
        "statues": [],
        "carpet": [],
        "ropes": [],
        "artifacts": [(3, 2)],
        "target": None,
        "player": None,
        "exit": (16, 9),
        "lamps": [5, 12],
        "paintings": [8, 16],
        "police": {"7": [(6, 4), (15, 4)]},
    },
}

LEVELS = {
    "museum": {
        "name": "城西博物馆",
        "content": MUSEUM_CONTENT,
        "out": "museum_map.json",
    },
    "british_museum": {
        "name": "大英博物馆·中国馆",
        "content": BM_CONTENT,
        "out": "british_museum.json",
    },
}


def level_size(content):
    rooms = len(content)
    rows = (rooms + COLS - 1) // COLS
    w = COLS * ROOM_W + (COLS - 1) * GAP
    h = rows * ROOM_H + (rows - 1) * GAP
    return w, h


def build(level_id="museum"):
    content_by_room = LEVELS[level_id]["content"]
    room_count = len(content_by_room)
    w, h = level_size(content_by_room)
    g = [[" " for _ in range(w)] for _ in range(h)]
    origins = [room_origin(i) for i in range(room_count)]
    rects = []

    def rect(x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = ch

    def put(oid, x, y, ch, expect=".~"):
        ox, oy = origins[oid]
        assert g[oy + y][ox + x] in expect, f"room {oid} cell {(x, y)} busy: {g[oy + y][ox + x]}"
        g[oy + y][ox + x] = ch

    for i, (ox, oy) in enumerate(origins):
        rect(ox, oy, ox + ROOM_W - 1, oy + ROOM_H - 1, "#")
        rect(ox + 1, oy + 1, ox + ROOM_W - 2, oy + ROOM_H - 2, ".")
        rects.append([ox, oy, ROOM_W, ROOM_H])

    floors = [[ox + 1, oy + 1, ROOM_W - 2, ROOM_H - 2] for ox, oy in origins]

    room_doors = {i: [] for i in range(room_count)}

    def door_h(ra, rb, rel_y):
        ax, ay = origins[ra]
        bx, _ = origins[rb]
        for y in (ay + rel_y, ay + rel_y + 1):
            for x in range(ax + ROOM_W - 1, bx + 1):
                g[y][x] = "."
        floors.append([ax + ROOM_W - 1, ay + rel_y, bx - (ax + ROOM_W - 1) + 1, 2])
        # 门口两侧房间内相邻的格子（玩家进出时踩到的位置）
        room_doors[ra].append((ax + ROOM_W - 2, ay + rel_y))
        room_doors[ra].append((ax + ROOM_W - 2, ay + rel_y + 1))
        room_doors[rb].append((bx + 1, ay + rel_y))
        room_doors[rb].append((bx + 1, ay + rel_y + 1))

    def door_v(ra, rb, rel_x):
        ax, ay = origins[ra]
        _, by = origins[rb]
        for x in (ax + rel_x, ax + rel_x + 1):
            for y in range(ay + ROOM_H - 1, by + 1):
                g[y][x] = "."
        floors.append([ax + rel_x, ay + ROOM_H - 1, 2, by - (ay + ROOM_H - 1) + 1])
        room_doors[ra].append((ax + rel_x, ay + ROOM_H - 2))
        room_doors[ra].append((ax + rel_x + 1, ay + ROOM_H - 2))
        room_doors[rb].append((ax + rel_x, by + 1))
        room_doors[rb].append((ax + rel_x + 1, by + 1))

    # 蛇形串联：偶数行从左到右，奇数行从右到左
    for i in range(room_count - 1):
        row_a = i // COLS
        row_b = (i + 1) // COLS
        if row_a == row_b:
            if row_a % 2 == 0:
                door_h(i, i + 1, 5)
            else:
                door_h(i + 1, i, 5)
        else:
            door_v(i, i + 1, 9)

    for oid, content in content_by_room.items():
        for x in content["lamps"]:
            put(oid, x, 0, "L", "#")
        for x in content["paintings"]:
            put(oid, x, 0, "W", "#")
        for x0, y0, x1, y1 in content["carpet"]:
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    put(oid, x, y, "~")
        for x, y in content["cases"]:
            put(oid, x, y, "d")
        for x, y in content["plants"]:
            put(oid, x, y, "v")
        for x, y in content["statues"]:
            put(oid, x, y, "s")
        for x, y in content["ropes"]:
            put(oid, x, y, "r")
        for x, y in content["artifacts"]:
            put(oid, x, y, "a")
        if content["target"] is not None:
            tx, ty = content["target"]
            put(oid, tx, ty, "T")
            put(oid, tx, ty + 1, "p")
        if content["player"] is not None:
            put(oid, *content["player"], "P")
        if content["exit"] is not None:
            put(oid, *content["exit"], "X")

    patrols = {}
    for oid, content in content_by_room.items():
        ox, oy = origins[oid]
        for key, path in content["police"].items():
            abs_path = [[ox + x, oy + y] for x, y in path]
            patrols[key] = abs_path
            sx, sy = abs_path[0]
            g[sy][sx] = key

    return ["".join(row) for row in g], patrols, rects, floors, room_doors


def validate(tiles, patrols, rects, room_doors=None):
    errors = []
    w, h = len(tiles[0]), len(tiles)
    for y, row in enumerate(tiles):
        if len(row) != w:
            errors.append(f"row {y}: expected {w} cols, got {len(row)}")
    for y, row in enumerate(tiles):
        for x, ch in enumerate(row):
            if ch not in WALKABLE + SOLID:
                errors.append(f"unknown char {ch!r} at {(x, y)}")

    def in_room(x, y):
        for i, (rx, ry, rw, rh) in enumerate(rects):
            if rx <= x < rx + rw and ry <= y < ry + rh:
                return i
        return -1

    def reachable_from(start):
        seen = {start}
        stack = [start]
        while stack:
            x, y = stack.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                if (nx, ny) in seen or tiles[ny][nx] not in WALKABLE:
                    continue
                seen.add((nx, ny))
                stack.append((nx, ny))
        return seen

    start = None
    for y, row in enumerate(tiles):
        for x, ch in enumerate(row):
            if ch == "P":
                start = (x, y)
    if start is None:
        errors.append("no player spawn 'P'")
        return errors, None
    seen = reachable_from(start)
    for y, row in enumerate(tiles):
        for x, ch in enumerate(row):
            if ch in "TXa123456789" and (x, y) not in seen:
                errors.append(f"{ch!r} at {(x, y)} not reachable from player spawn")
    # 教学/公平性规则：巡逻路线（含线段采样点）不得靠近本房间的门口格子，
    # 否则玩家一进门就撞上手电光锥（试玩反馈：容错太低）。
    if room_doors is not None:
        min_door_distance = 3.5
        for key, path in patrols.items():
            room_of_path = in_room(path[0][0], path[0][1])
            doors = room_doors.get(room_of_path, [])
            samples = []
            for a, b in zip(path, path[1:]):
                ax, ay = a
                bx, by = b
                steps = max(abs(bx - ax), abs(by - ay))
                for i in range(steps + 1):
                    samples.append((
                        round(ax + (bx - ax) * i / steps) if steps else ax,
                        round(ay + (by - ay) * i / steps) if steps else ay,
                    ))
            if not samples:
                samples = [tuple(path[0])]
            for sx, sy in samples:
                for dx, dy in doors:
                    dist = ((sx - dx) ** 2 + (sy - dy) ** 2) ** 0.5
                    if dist < min_door_distance:
                        errors.append(
                            "patrol %s: 巡逻点 (%d,%d) 距门口 (%d,%d) 仅 %.1f 格（需 >= %.1f）"
                            % (key, sx, sy, dx, dy, dist, min_door_distance)
                        )
                        break

    for key, path in patrols.items():
        room_of_spawn = in_room(path[0][0], path[0][1])
        if room_of_spawn < 0:
            errors.append(f"patrol {key}: spawn {path[0]} not inside any room")
        for x, y in path:
            if tiles[y][x] not in WALKABLE:
                errors.append(f"patrol {key}: waypoint {(x, y)} not walkable ({tiles[y][x]!r})")
            elif (x, y) not in seen:
                errors.append(f"patrol {key}: waypoint {(x, y)} unreachable")
            elif in_room(x, y) != room_of_spawn:
                errors.append(f"patrol {key}: waypoint {(x, y)} leaves its room")
        # guards walk in straight lines; every segment must stay walkable
        for a, b in zip(path, path[1:]):
            ax, ay = a
            bx, by = b
            steps = max(abs(bx - ax), abs(by - ay))
            for i in range(steps + 1):
                x = round(ax + (bx - ax) * i / steps) if steps else ax
                y = round(ay + (by - ay) * i / steps) if steps else ay
                if tiles[y][x] not in WALKABLE:
                    errors.append(f"patrol {key}: segment {a}->{b} blocked at {(x, y)} ({tiles[y][x]!r})")
                    break
    return errors, seen


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "levels")
    failed = False
    for level_id, info in LEVELS.items():
        tiles, patrols, rects, floors, room_doors = build(level_id)
        errors, _ = validate(tiles, patrols, rects, room_doors)
        if errors:
            failed = True
            print(f"[{level_id}] MAP INVALID:")
            for e in errors:
                print("  -", e)
            continue
        out = os.path.join(out_dir, info["out"])
        with open(out, "w", encoding="utf-8") as f:
            json.dump(
                {"tile_size": 16, "rooms": rects, "floors": floors, "tiles": tiles, "patrols": patrols},
                f,
                ensure_ascii=False,
                indent=1,
            )
        print(f"[{level_id}] {info['name']} → {os.path.normpath(out)}")
        print(f"  map {len(tiles[0])}x{len(tiles)}, rooms {len(rects)}, guards {len(patrols)}")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
