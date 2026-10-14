#!/usr/bin/env python3
"""Generate the museum level layout (linear room chain + patrol routes).

Level shape: seven 20x12 rooms arranged in a snake, connected by short door
corridors.  At the game's 2x camera zoom one room fills the screen, so the
player explores one small, dense room at a time.

Writes src/levels/museum_map.json which is loaded by the game at runtime.
Every generated map is validated (borders, connectivity, patrol legality,
room containment).

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
ROOM_COUNT = 7
COLS = 2
ROWS = (ROOM_COUNT + COLS - 1) // COLS
W = COLS * ROOM_W + (COLS - 1) * GAP
H = ROWS * ROOM_H + (ROWS - 1) * GAP

WALKABLE = ".~TapXP123456789"
SOLID = "#o.dprsvLW "


def room_origin(index):
    row, k = divmod(index, COLS)
    col = k if row % 2 == 0 else COLS - 1 - k
    return col * (ROOM_W + GAP), row * (ROOM_H + GAP)


# Per-room content, relative to the room's top-left corner (interior x1..18,
# y1..10).  Patrol routes stay inside their own room.
CONTENT = {
    0: {  # 门厅
        "cases": [(5, 2), (6, 2)],
        "plants": [(17, 9)],
        "statues": [],
        "carpet": [],
        "ropes": [],
        "artifacts": [(16, 2)],
        "target": None,
        "player": (2, 9),
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
        "police": {"2": [(3, 5), (16, 5)]},
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
        "police": {"3": [(4, 2), (4, 8), (15, 8), (15, 2)]},
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
        "police": {"4": [(4, 2), (4, 9), (15, 9), (15, 2)], "5": [(17, 2), (17, 9)]},
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
        "police": {"6": [(9, 2), (9, 9)]},
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
        "police": {"7": [(4, 4), (15, 4)]},
    },
}


def build():
    g = [[" " for _ in range(W)] for _ in range(H)]
    origins = [room_origin(i) for i in range(ROOM_COUNT)]
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

    def door_h(ra, rb, rel_y):
        ax, ay = origins[ra]
        bx, _ = origins[rb]
        for y in (ay + rel_y, ay + rel_y + 1):
            for x in range(ax + ROOM_W - 1, bx + 1):
                g[y][x] = "."
        floors.append([ax + ROOM_W - 1, ay + rel_y, bx - (ax + ROOM_W - 1) + 1, 2])

    def door_v(ra, rb, rel_x):
        ax, ay = origins[ra]
        _, by = origins[rb]
        for x in (ax + rel_x, ax + rel_x + 1):
            for y in range(ay + ROOM_H - 1, by + 1):
                g[y][x] = "."
        floors.append([ax + rel_x, ay + ROOM_H - 1, 2, by - (ay + ROOM_H - 1) + 1])

    door_h(0, 1, 5)
    door_v(1, 2, 9)
    door_h(3, 2, 5)
    door_v(3, 4, 9)
    door_h(4, 5, 5)
    door_v(5, 6, 9)

    for oid, content in CONTENT.items():
        ox, oy = origins[oid]
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
    for oid, content in CONTENT.items():
        ox, oy = origins[oid]
        for key, path in content["police"].items():
            abs_path = [[ox + x, oy + y] for x, y in path]
            patrols[key] = abs_path
            sx, sy = abs_path[0]
            g[sy][sx] = key

    return ["".join(row) for row in g], patrols, rects, floors


def validate(tiles, patrols, rects):
    errors = []
    if len(tiles) != H:
        errors.append(f"expected {H} rows, got {len(tiles)}")
        return errors, None
    for y, row in enumerate(tiles):
        if len(row) != W:
            errors.append(f"row {y}: expected {W} cols, got {len(row)}")
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
                if not (0 <= nx < W and 0 <= ny < H):
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
    tiles, patrols, rects, floors = build()
    errors, _ = validate(tiles, patrols, rects)
    if errors:
        print("MAP INVALID:")
        for e in errors:
            print("  -", e)
        sys.exit(1)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "levels", "museum_map.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(
            {"tile_size": 16, "rooms": rects, "floors": floors, "tiles": tiles, "patrols": patrols},
            f,
            ensure_ascii=False,
            indent=1,
        )
    print("wrote", os.path.normpath(out))
    print(f"map {W}x{H}, rooms {len(rects)}, guards {len(patrols)}")
    for i, (x, y, w, h) in enumerate(rects):
        print(f"  room {i}: tiles x{x}..{x + w - 1} y{y}..{y + h - 1}")


if __name__ == "__main__":
    main()
