#!/usr/bin/env python3
"""Generate the 32x40 tan-coat gentleman-thief game sprite.

Design target: docs/art_direction/a00_src/thief_turnaround_a.png
(fedora + tan trench coat + satchel). 32x40 frames keep the player close to
the 24x32 guards in screen size while the 1280x720 AI turnaround remains the
high-resolution design reference.
"""
from pathlib import Path

from PIL import Image, ImageDraw

from PIL import Image, ImageDraw
W,H=32,40
OUT=(7,9,13,255)
HAT_D=(12,14,18,255); HAT=(24,26,32,255); HAT_L=(42,46,54,255)
BAND=(88,58,32,255); BAND_L=(128,88,48,255); GOLD=(210,164,76,255); GOLD_H=(244,214,148,255)
TAN_D=(84,58,34,255); TAN=(120,86,52,255); TAN_L=(154,114,70,255); TAN_H=(186,146,98,255)
DARK=(36,28,22,255)
SKIN_D=(176,116,84,255); SKIN=(226,166,126,255); SKIN_L=(246,204,166,255)
HAIR=(26,20,22,255)
GLOVE=(224,216,196,255); GLOVE_D=(174,166,146,255)
PANTS=(28,30,36,255); PANTS_L=(44,46,54,255)
BOOT=(52,32,18,255); BOOT_L=(94,62,34,255); BOOT_H=(138,96,50,255)
BAG=(92,60,32,255); BAG_L=(128,88,48,255); BAG_D=(64,42,24,255)
RIM_C=(104,172,190,255); RIM_W=(238,190,114,255)
EYE=(10,10,14,255)

def new(): return Image.new('RGBA',(W,H),(0,0,0,0))
def poly(im,pts,c): ImageDraw.Draw(im).polygon(pts,fill=c)
def R(im,x0,y0,x1,y1,c): ImageDraw.Draw(im).rectangle([x0,y0,x1,y1],fill=c)
def P(im,x,y,c): im.putpixel((x,y),c)

def front():
    im=new()
    # legs
    poly(im,[(12,30),(16,30),(16,37),(15,39),(11,39),(11,37)],OUT)
    poly(im,[(12,31),(15,31),(15,37),(14,38),(12,38),(12,36)],PANTS)
    R(im,11,36,16,39,OUT); R(im,12,36,15,38,BOOT); P(im,15,36,BOOT_L)
    poly(im,[(17,30),(21,30),(22,37),(21,39),(17,39),(16,37)],OUT)
    poly(im,[(17,31),(20,31),(20,37),(19,38),(17,38),(17,36)],PANTS)
    R(im,16,36,22,39,OUT); R(im,17,36,21,38,BOOT); P(im,21,36,BOOT_L)
    # coat tails
    poly(im,[(5,28),(11,30),(11,37),(8,39),(4,35),(4,30)],OUT)
    poly(im,[(6,29),(10,31),(10,36),(8,37),(5,34),(5,30)],TAN)
    P(im,6,31,TAN_L); P(im,8,35,TAN_D)
    poly(im,[(21,30),(27,28),(28,30),(28,35),(24,39),(21,37)],OUT)
    poly(im,[(21,31),(26,29),(27,31),(27,34),(23,37),(21,36)],TAN)
    P(im,26,31,TAN_L); P(im,24,35,TAN_D)
    # torso coat
    poly(im,[(8,15),(24,15),(26,18),(26,25),(24,31),(8,31),(6,25),(6,18)],OUT)
    poly(im,[(9,16),(23,16),(25,19),(25,24),(23,29),(9,29),(7,24),(7,19)],TAN)
    # shading
    poly(im,[(9,16),(11,16),(11,29),(9,29),(7,24),(7,19)],TAN_D)
    poly(im,[(22,16),(24,17),(25,20),(25,24),(23,28),(21,29)],TAN_L)
    # dark inner V / lapels
    poly(im,[(12,16),(20,16),(19,21),(18,23),(14,21)],DARK)
    poly(im,[(9,16),(13,16),(16,21),(12,20)],HAT_D)
    poly(im,[(23,16),(19,16),(17,21),(21,20)],HAT_D)
    P(im,15,18,TAN_H); P(im,17,18,TAN_H)
    # thin belt (no gold)
    R(im,9,24,24,25,OUT); R(im,10,24,23,24,BAND)
    # satchel strap
    for i in range(11):
        x=22-i; y=17+i
        P(im,x,y,BAND)
        if i%3==0: P(im,x,y-1,BAND_L)
    # satchel left hip
    poly(im,[(1,23),(7,22),(8,27),(7,32),(2,32),(1,29)],OUT)
    poly(im,[(2,24),(6,23),(7,27),(6,31),(3,31),(2,29)],BAG)
    poly(im,[(2,24),(6,23),(6,26),(5,27),(2,27)],BAG_L)
    P(im,4,27,GOLD); P(im,3,28,GOLD); P(im,5,28,GOLD); P(im,4,29,GOLD)
    # arms
    poly(im,[(7,17),(10,17),(9,27),(8,30),(5,29),(5,24),(6,20)],OUT)
    poly(im,[(7,18),(9,18),(8,26),(7,28),(6,27),(6,23),(7,20)],TAN_D)
    R(im,5,28,9,31,OUT); R(im,6,28,8,30,GLOVE); P(im,8,28,GLOVE_D)
    poly(im,[(23,17),(26,17),(27,20),(27,25),(26,30),(22,29),(22,27),(23,20)],OUT)
    poly(im,[(23,18),(25,18),(26,21),(26,25),(25,28),(23,27),(23,24),(24,20)],TAN_L)
    R(im,23,28,27,31,OUT); R(im,24,28,26,30,GLOVE); P(im,26,28,GLOVE_D)
    # head
    poly(im,[(10,7),(22,7),(23,12),(21,16),(16,17),(11,16),(9,12)],OUT)
    poly(im,[(11,8),(21,8),(22,12),(20,15),(16,16),(12,15),(10,12)],SKIN_D)
    poly(im,[(12,9),(20,9),(21,12),(19,15),(16,15),(13,15),(11,12)],SKIN)
    # hair sides / shadow under brim
    poly(im,[(10,8),(13,8),(12,14),(10,12)],HAIR)
    poly(im,[(20,8),(22,8),(22,12),(20,14)],HAIR)
    R(im,12,9,20,9,SKIN_D)
    # eyes / nose / mouth (subtle)
    P(im,13,11,HAIR); P(im,18,11,HAIR)
    P(im,13,12,EYE); P(im,18,12,EYE)
    P(im,13,12,SKIN_L); P(im,18,12,SKIN_L)
    P(im,15,13,SKIN_D); P(im,16,13,SKIN_D)
    R(im,14,14,17,14,(150,92,74,255))
    # hat brim
    poly(im,[(4,6),(9,4),(12,3),(20,3),(24,4),(28,6),(25,8),(7,8)],OUT)
    poly(im,[(6,6),(10,5),(13,4),(19,4),(23,5),(26,6),(24,7),(8,7)],HAT)
    poly(im,[(6,6),(10,5),(13,4),(15,4),(12,6),(8,7)],HAT_L)
    # crown
    poly(im,[(10,0),(22,0),(23,5),(9,5)],OUT)
    poly(im,[(11,1),(21,1),(22,4),(10,4)],HAT)
    R(im,11,1,14,1,HAT_L)
    # band
    R(im,9,4,23,6,OUT); R(im,10,4,22,5,BAND); R(im,10,4,15,4,BAND_L)
    R(im,15,4,18,6,OUT); R(im,15,4,18,5,GOLD); P(im,16,4,GOLD_H)
    # rim
    for (x,y,c) in [(22,10,RIM_W),(23,12,RIM_W),(26,19,RIM_W),(27,24,RIM_W),(21,38,BOOT_L)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: P(im,x,y,c)
    for (x,y,c) in [(9,12,RIM_C),(6,22,RIM_C),(5,27,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: P(im,x,y,c)
    return im



def back():
    im=new()
    # legs
    poly(im,[(12,30),(16,30),(16,37),(15,39),(11,39),(11,37)],OUT)
    poly(im,[(12,31),(15,31),(15,37),(14,38),(12,38),(12,36)],PANTS)
    R(im,11,36,16,39,OUT); R(im,12,36,15,38,BOOT); P(im,15,36,BOOT_L)
    poly(im,[(17,30),(21,30),(22,37),(21,39),(17,39),(16,37)],OUT)
    poly(im,[(17,31),(20,31),(20,37),(19,38),(17,38),(17,36)],PANTS)
    R(im,16,36,22,39,OUT); R(im,17,36,21,38,BOOT); P(im,21,36,BOOT_L)
    # coat tails
    poly(im,[(5,28),(11,30),(11,37),(8,39),(4,35),(4,30)],OUT)
    poly(im,[(6,29),(10,31),(10,36),(8,37),(5,34),(5,30)],TAN)
    poly(im,[(21,30),(27,28),(28,30),(28,35),(24,39),(21,37)],OUT)
    poly(im,[(21,31),(26,29),(27,31),(27,34),(23,37),(21,36)],TAN)
    # torso back
    poly(im,[(8,15),(24,15),(26,18),(26,25),(24,31),(8,31),(6,25),(6,18)],OUT)
    poly(im,[(9,16),(23,16),(25,19),(25,24),(23,29),(9,29),(7,24),(7,19)],TAN)
    poly(im,[(9,16),(11,16),(11,29),(9,29),(7,24),(7,19)],TAN_D)
    poly(im,[(22,16),(24,17),(25,20),(25,24),(23,28),(21,29)],TAN_L)
    # back seam / yoke
    R(im,15,16,16,28,TAN_D); P(im,16,20,TAN_L)
    R(im,9,18,23,19,TAN_L); P(im,15,18,TAN_D)
    # thin belt
    R(im,9,24,24,25,OUT); R(im,10,24,23,24,BAND)
    # satchel bag at left hip
    poly(im,[(1,23),(7,22),(8,27),(7,32),(2,32),(1,29)],OUT)
    poly(im,[(2,24),(6,23),(7,27),(6,31),(3,31),(2,29)],BAG)
    poly(im,[(2,24),(6,23),(6,26),(5,27),(2,27)],BAG_L)
    P(im,4,27,GOLD); P(im,3,28,GOLD); P(im,5,28,GOLD); P(im,4,29,GOLD)
    # strap across back
    for i in range(12):
        x=22-i; y=17+i
        P(im,x,y,BAND)
        if i%3==0: P(im,x,y-1,BAND_L)
    # arms
    poly(im,[(7,17),(10,17),(9,27),(8,30),(5,29),(5,24),(6,20)],OUT)
    poly(im,[(7,18),(9,18),(8,26),(7,28),(6,27),(6,23),(7,20)],TAN_D)
    R(im,5,28,9,31,OUT); R(im,6,28,8,30,GLOVE); P(im,8,28,GLOVE_D)
    poly(im,[(23,17),(26,17),(27,20),(27,25),(26,30),(22,29),(22,27),(23,20)],OUT)
    poly(im,[(23,18),(25,18),(26,21),(26,25),(25,28),(23,27),(23,24),(24,20)],TAN_L)
    R(im,23,28,27,31,OUT); R(im,24,28,26,30,GLOVE); P(im,26,28,GLOVE_D)
    # head back
    poly(im,[(10,7),(22,7),(23,12),(21,16),(16,17),(11,16),(9,12)],OUT)
    poly(im,[(11,8),(21,8),(22,12),(20,15),(16,16),(12,15),(10,12)],HAIR)
    poly(im,[(12,9),(20,9),(21,12),(19,15),(16,15),(13,15),(11,12)],(36,28,30,255))
    # nape / neck / collar
    R(im,14,14,18,17,SKIN_D); R(im,15,14,17,16,SKIN)
    R(im,9,15,24,16,TAN_L); P(im,16,15,BAND)
    # hat brim
    poly(im,[(4,6),(9,4),(12,3),(20,3),(24,4),(28,6),(25,8),(7,8)],OUT)
    poly(im,[(6,6),(10,5),(13,4),(19,4),(23,5),(26,6),(24,7),(8,7)],HAT)
    poly(im,[(6,6),(10,5),(13,4),(15,4),(12,6),(8,7)],HAT_L)
    # crown
    poly(im,[(10,0),(22,0),(23,5),(9,5)],OUT)
    poly(im,[(11,1),(21,1),(22,4),(10,4)],HAT)
    R(im,11,1,14,1,HAT_L)
    # band (back, no buckle)
    R(im,9,4,23,6,OUT); R(im,10,4,22,5,BAND); R(im,10,4,15,4,BAND_L)
    # rim
    for (x,y,c) in [(22,10,RIM_W),(23,12,RIM_W),(26,19,RIM_W),(27,24,RIM_W),(21,38,BOOT_L)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: P(im,x,y,c)
    for (x,y,c) in [(9,12,RIM_C),(6,22,RIM_C),(5,27,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: P(im,x,y,c)
    return im

def side():
    im=new()
    # legs: back/front slight offset
    poly(im,[(11,30),(15,30),(15,37),(14,39),(10,39),(10,37)],OUT)
    poly(im,[(11,31),(14,31),(14,37),(13,38),(11,38),(11,36)],PANTS)
    R(im,10,36,15,39,OUT); R(im,11,36,14,38,BOOT); P(im,14,36,BOOT_L)
    poly(im,[(16,30),(21,30),(22,37),(21,39),(16,39),(16,37)],OUT)
    poly(im,[(17,31),(20,31),(20,37),(19,38),(17,38),(17,36)],PANTS)
    R(im,16,36,22,39,OUT); R(im,17,36,21,38,BOOT); P(im,21,36,BOOT_L)
    # coat tail back
    poly(im,[(5,27),(11,30),(11,37),(8,39),(4,35),(4,30)],OUT)
    poly(im,[(6,28),(10,31),(10,36),(8,37),(5,34),(5,30)],TAN)
    # torso profile
    poly(im,[(8,15),(22,15),(25,18),(25,24),(23,31),(8,31),(6,25),(6,18)],OUT)
    poly(im,[(9,16),(21,16),(24,19),(24,24),(22,29),(9,29),(7,24),(7,19)],TAN)
    poly(im,[(9,16),(11,16),(11,29),(9,29),(7,24),(7,19)],TAN_D)
    poly(im,[(20,16),(23,18),(24,21),(24,24),(22,28),(20,29)],TAN_L)
    # belt
    R(im,9,24,24,25,OUT); R(im,10,24,23,24,BAND)
    # satchel back
    poly(im,[(1,23),(7,22),(8,27),(7,32),(2,32),(1,29)],OUT)
    poly(im,[(2,24),(6,23),(7,27),(6,31),(3,31),(2,29)],BAG)
    poly(im,[(2,24),(6,23),(6,26),(5,27),(2,27)],BAG_L)
    P(im,4,27,GOLD); P(im,3,28,GOLD); P(im,5,28,GOLD); P(im,4,29,GOLD)
    # strap
    for i in range(11):
        x=22-i; y=17+i
        P(im,x,y,BAND)
    # near arm
    poly(im,[(22,17),(26,17),(27,21),(27,26),(26,30),(22,29),(22,26)],OUT)
    poly(im,[(23,18),(25,18),(26,22),(26,26),(25,28),(23,27),(23,24)],TAN_L)
    R(im,23,28,27,31,OUT); R(im,24,28,26,30,GLOVE); P(im,26,28,GLOVE_D)
    # head profile
    poly(im,[(10,7),(21,7),(24,10),(25,13),(23,16),(20,17),(11,16),(9,12)],OUT)
    poly(im,[(11,8),(20,8),(22,11),(24,13),(22,15),(20,16),(12,15),(10,12)],SKIN_D)
    poly(im,[(15,9),(20,9),(22,11),(23,13),(21,15),(19,15),(13,14),(12,12)],SKIN)
    # hair
    poly(im,[(10,8),(15,8),(14,15),(11,16),(9,12)],HAIR)
    # eye/brow/nose/mouth
    R(im,18,10,21,10,HAIR); R(im,19,11,21,12,EYE); P(im,19,11,SKIN_L)
    P(im,24,12,SKIN_D); P(im,24,13,SKIN_L); P(im,23,14,SKIN_D)
    R(im,20,15,22,15,(150,92,74,255))
    # collar
    R(im,12,15,22,16,TAN_L); P(im,16,15,BAND)
    # hat brim profile
    poly(im,[(4,6),(9,4),(12,3),(20,3),(25,4),(29,6),(26,8),(7,8)],OUT)
    poly(im,[(6,6),(10,5),(13,4),(19,4),(24,5),(27,6),(24,7),(8,7)],HAT)
    poly(im,[(6,6),(10,5),(13,4),(15,4),(12,6),(8,7)],HAT_L)
    # crown
    poly(im,[(10,0),(22,0),(23,5),(9,5)],OUT)
    poly(im,[(11,1),(21,1),(22,4),(10,4)],HAT)
    R(im,11,1,14,1,HAT_L)
    # band
    R(im,9,4,23,6,OUT); R(im,10,4,22,5,BAND); R(im,10,4,15,4,BAND_L)
    R(im,15,4,18,6,OUT); R(im,15,4,18,5,GOLD); P(im,16,4,GOLD_H)
    # rim
    for (x,y,c) in [(24,12,RIM_W),(25,13,RIM_W),(26,20,RIM_W),(27,25,RIM_W),(21,38,BOOT_L)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: P(im,x,y,c)
    for (x,y,c) in [(9,12,RIM_C),(6,22,RIM_C),(5,27,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: P(im,x,y,c)
    return im



def frame(base, col):
    if col < 2:
        return base
    out = base.copy()
    out.paste((0, 0, 0, 0), (0, 34, 32, 40))
    region = base.crop((0, 34, 32, 40))
    out.alpha_composite(region, (-1 if col == 2 else 1, 34))
    return out


def main():
    outdir = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "chars"
    docdir = Path(__file__).resolve().parent.parent / "docs" / "art_direction"
    outdir.mkdir(parents=True, exist_ok=True)
    docdir.mkdir(parents=True, exist_ok=True)
    views = {"front": front(), "back": back(), "side": side()}
    for name, im in views.items():
        im.save(outdir / f"thief32_{name}.png")
    turn = Image.new("RGBA", (32 * 3, 40), (0, 0, 0, 0))
    for i, name in enumerate(["front", "side", "back"]):
        turn.alpha_composite(views[name], (i * 32, 0))
    turn.save(outdir / "thief32_turnaround.png")
    sheet = Image.new("RGBA", (32 * 4, 40 * 3), (0, 0, 0, 0))
    for r, name in enumerate(["front", "back", "side"]):
        for c in range(4):
            sheet.alpha_composite(frame(views[name], c), (c * 32, r * 40))
    sheet.save(outdir / "player_sheet_v2.png")
    turn.resize((32 * 3 * 10, 40 * 10), Image.NEAREST).save(docdir / "A00_thief32_turnaround.png")
    sheet.resize((32 * 4 * 8, 40 * 3 * 8), Image.NEAREST).save(docdir / "A00_thief32_sheet.png")
    print("wrote thief32 front/back/side, turnaround, 128x120 player_sheet_v2")


if __name__ == "__main__":
    main()
