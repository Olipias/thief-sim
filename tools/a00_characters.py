"""A-00 character sprite art (24x32) — generated source.

This module draws the player and police sheets used by tools/gen_a00_art.py.
It is intentionally self-contained and deterministic; no external assets are
needed except the standard library and Pillow.
"""

from PIL import Image, ImageDraw

W,H=24,32
OUT=(6,8,12,255)
HOOD_D=(14,28,46,255); HOOD=(24,48,74,255); HOOD_L=(40,74,108,255); HOOD_H=(74,118,158,255)
FACE=(5,8,12,255); EYE=(255,206,92,255); EYE_H=(255,246,196,255)
SCARF_D=(22,54,62,255); SCARF=(38,96,104,255); SCARF_L=(96,174,168,255)
COAT_D=(18,34,54,255); COAT=(30,56,84,255); COAT_L=(48,84,120,255); COAT_E=(66,110,150,255)
BAG_D=(72,46,24,255); BAG=(112,76,40,255); BAG_L=(156,112,62,255); BAG_H=(198,152,92,255)
BELT=(70,46,26,255); BUCKLE=(224,178,88,255); BUCKLE_H=(250,226,160,255)
GLOVE=(22,26,34,255); GLOVE_L=(56,64,76,255)
BOOT=(56,36,22,255); BOOT_L=(96,66,38,255); BOOT_H=(142,102,56,255)
RIM_C=(112,196,206,255); RIM_W=(250,206,130,255)

def new(): return Image.new('RGBA',(W,H),(0,0,0,0))
def poly(im,pts,c): ImageDraw.Draw(im).polygon(pts,fill=c)
def R(im,x0,y0,x1,y1,c): ImageDraw.Draw(im).rectangle([x0,y0,x1,y1],fill=c)
def P(im,x,y,c): im.putpixel((x,y),c)
Px = P

def rim(im):
    for (x,y,c) in [(21,15,0),(21,17,0),(20,20,0),(16,3,1),(17,4,1),(17,5,1),(16,31,2),(10,31,2)]:
        pass

def legs_down(im,lx,rx):
    poly(im,[(7+lx,21),(11+lx,21),(11+lx,29),(10+lx,31),(7+lx,31),(7+lx,28)],OUT)
    poly(im,[(8+lx,22),(10+lx,22),(10+lx,29),(9+lx,30),(8+lx,30),(8+lx,25)],COAT_D)
    P(im,8+lx,23,COAT); P(im,9+lx,27,COAT_L)
    R(im,7+lx,28,11+lx,31,OUT); R(im,8+lx,28,10+lx,30,BOOT); P(im,9+lx,28,BOOT_L); P(im,8+lx,29,BOOT_H)
    poly(im,[(13+rx,21),(17+rx,21),(17+rx,28),(16+rx,31),(13+rx,31),(13+rx,29)],OUT)
    poly(im,[(14+rx,22),(16+rx,22),(16+rx,29),(15+rx,30),(14+rx,30),(14+rx,25)],COAT_D)
    P(im,16+rx,23,COAT_L); P(im,15+rx,27,COAT)
    R(im,13+rx,28,17+rx,31,OUT); R(im,14+rx,28,16+rx,30,BOOT); P(im,16+rx,28,BOOT_L); P(im,15+rx,29,BOOT_H)

def player_down(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    lx=0 if pose not in (2,3) else (-1 if pose==2 else 1)
    rx=0 if pose not in (2,3) else (1 if pose==2 else -1)
    # back coat tails
    poly(im,[(5,20),(8,21),(8,27),(6,26),(5,28),(4,24),(3,22)],OUT)
    poly(im,[(5,21),(7,22),(7,25),(6,24),(5,26),(5,23)],COAT_D)
    poly(im,[(16,21),(19,20),(21,22),(20,26),(18,25),(17,27),(16,26)],OUT)
    poly(im,[(16,22),(18,21),(19,23),(19,25),(17,24),(16,25)],COAT)
    P(im,19,23,COAT_L); P(im,18,24,COAT_E)
    legs_down(im,lx,rx)
    # torso
    poly(im,[(9,10+bob),(14,10+bob),(17,12+bob),(18,17+bob),(18,21+bob),(15,25+bob),(8,25+bob),(5,21+bob),(5,17+bob),(6,12+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(16,13+bob),(17,17+bob),(17,20+bob),(15,23+bob),(9,23+bob),(6,20+bob),(6,17+bob),(7,13+bob)],COAT)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(9,23+bob),(6,20+bob),(6,17+bob),(7,13+bob)],COAT_D)
    poly(im,[(14,11+bob),(16,13+bob),(17,17+bob),(17,20+bob),(15,22+bob),(14,21+bob)],COAT_L)
    R(im,11,17+bob,12,22+bob,COAT_D); P(im,12,18+bob,COAT_E); P(im,11,21+bob,COAT_L)
    # belt
    R(im,7,18+bob,16,20+bob,BELT); R(im,7,20+bob,16,20+bob,(96,64,34,255))
    R(im,11,18+bob,13,20+bob,BUCKLE); P(im,12,19+bob,BUCKLE_H)
    # scarf
    poly(im,[(8,10+bob),(15,10+bob),(16,12+bob),(14,13+bob),(9,13+bob),(8,12+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(15,12+bob),(13,12+bob),(10,12+bob)],SCARF)
    P(im,10,11+bob,SCARF_L); P(im,12,11+bob,SCARF_L); P(im,13,12+bob,SCARF_D)
    poly(im,[(14,12+bob),(16,13+bob),(16,18+bob),(14,18+bob),(14,14+bob)],OUT)
    poly(im,[(14,13+bob),(15,14+bob),(15,17+bob),(14,17+bob)],SCARF_D)
    P(im,15,14+bob,SCARF); P(im,15,16+bob,SCARF_L)
    # strap
    for i in range(9):
        x=13-i; y=12+i
        P(im,x,y,BAG_D)
        if i%2==0: P(im,x,y-1,BAG)
    # satchel
    poly(im,[(1,16+bob),(5,15+bob),(6,19+bob),(5,24+bob),(2,24+bob),(1,20+bob)],OUT)
    poly(im,[(2,17+bob),(5,16+bob),(5,19+bob),(4,23+bob),(3,23+bob),(2,20+bob)],BAG)
    poly(im,[(2,17+bob),(5,16+bob),(5,18+bob),(4,19+bob),(2,19+bob)],BAG_L)
    R(im,3,20+bob,4,21+bob,BUCKLE); P(im,3,20+bob,BUCKLE_H)
    # arms
    poly(im,[(5,12+bob),(7,12+bob),(7,21+bob),(6,23+bob),(4,22+bob),(3,18+bob),(4,14+bob)],OUT)
    poly(im,[(5,13+bob),(6,13+bob),(6,21+bob),(5,22+bob),(4,20+bob),(4,15+bob)],COAT_D)
    P(im,5,14+bob,COAT); P(im,5,18+bob,COAT)
    R(im,4,21+bob,6,23+bob,OUT); R(im,4,22+bob,5,22+bob,GLOVE); P(im,4,22+bob,GLOVE_L)
    poly(im,[(17,12+bob),(19,12+bob),(21,14+bob),(21,18+bob),(20,22+bob),(18,23+bob),(17,21+bob),(18,13+bob)],OUT)
    poly(im,[(17,13+bob),(18,13+bob),(20,15+bob),(20,18+bob),(19,21+bob),(18,22+bob),(18,20+bob)],COAT_L)
    P(im,19,14+bob,COAT); P(im,19,18+bob,COAT)
    R(im,18,21+bob,20,23+bob,OUT); R(im,18,22+bob,19,22+bob,GLOVE); P(im,19,22+bob,GLOVE_L)
    # head/hood
    poly(im,[(11,0+bob),(14,0+bob),(16,2+bob),(18,5+bob),(17,9+bob),(15,11+bob),(9,11+bob),(7,9+bob),(6,5+bob),(8,2+bob)],OUT)
    poly(im,[(11,1+bob),(14,1+bob),(15,3+bob),(17,5+bob),(16,8+bob),(14,10+bob),(10,10+bob),(8,8+bob),(7,5+bob),(9,3+bob)],HOOD)
    poly(im,[(11,1+bob),(12,1+bob),(11,10+bob),(10,10+bob),(8,8+bob),(7,5+bob),(9,3+bob)],HOOD_D)
    poly(im,[(14,1+bob),(15,3+bob),(17,5+bob),(16,8+bob),(14,10+bob),(13,9+bob),(14,4+bob)],HOOD_L)
    R(im,10,1+bob,13,1+bob,HOOD_H)
    poly(im,[(9,4+bob),(14,4+bob),(15,6+bob),(15,8+bob),(13,10+bob),(10,10+bob),(8,8+bob),(8,6+bob)],FACE)
    P(im,10,6+bob,EYE); P(im,13,6+bob,EYE)
    P(im,10,6+bob,EYE_H); P(im,13,6+bob,EYE_H)
    P(im,11,8+bob,(14,26,36,255)); P(im,12,8+bob,(14,26,36,255))
    P(im,8,6+bob,HOOD_L); P(im,8,7+bob,HOOD_L); P(im,15,6+bob,HOOD_H); P(im,15,7+bob,HOOD_H)
    R(im,9,10+bob,13,10+bob,SCARF)
    # rim
    for (x,y,c) in [(16,3+bob,RIM_W),(17,4+bob,RIM_W),(17,5+bob,RIM_W),(21,15+bob,RIM_W),(21,17+bob,RIM_W),(20,20+bob,RIM_W),(16,31,BOOT_H),(10,31,BOOT_H)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(6,5+bob,RIM_C),(7,6+bob,RIM_C),(3,16+bob,RIM_C),(4,19+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im

def player_up(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    lx=0 if pose not in (2,3) else (-1 if pose==2 else 1)
    rx=0 if pose not in (2,3) else (1 if pose==2 else -1)
    # back coat tails
    poly(im,[(5,20),(8,21),(8,27),(6,26),(5,28),(4,24),(3,22)],OUT)
    poly(im,[(5,21),(7,22),(7,25),(6,24),(5,26),(5,23)],COAT_D)
    poly(im,[(16,21),(19,20),(21,22),(20,26),(18,25),(17,27),(16,26)],OUT)
    poly(im,[(16,22),(18,21),(19,23),(19,25),(17,24),(16,25)],COAT)
    P(im,19,23,COAT_L)
    legs_down(im,lx,rx)
    # torso back
    poly(im,[(9,10+bob),(14,10+bob),(17,12+bob),(18,17+bob),(18,21+bob),(15,25+bob),(8,25+bob),(5,21+bob),(5,17+bob),(6,12+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(16,13+bob),(17,17+bob),(17,20+bob),(15,23+bob),(9,23+bob),(6,20+bob),(6,17+bob),(7,13+bob)],COAT)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(9,23+bob),(6,20+bob),(6,17+bob),(7,13+bob)],COAT_D)
    poly(im,[(14,11+bob),(16,13+bob),(17,17+bob),(17,20+bob),(15,22+bob),(14,21+bob)],COAT_L)
    # center seam
    R(im,11,11+bob,12,17+bob,COAT_D); P(im,12,14+bob,COAT_E)
    # strap across back
    for i in range(9):
        x=13-i; y=12+i
        P(im,x,y,BAG_D)
        if i%2==0: P(im,x,y-1,BAG)
    # belt
    R(im,7,18+bob,16,20+bob,BELT); R(im,7,20+bob,16,20+bob,(96,64,34,255))
    # satchel at left hip
    poly(im,[(1,16+bob),(5,15+bob),(6,19+bob),(5,24+bob),(2,24+bob),(1,20+bob)],OUT)
    poly(im,[(2,17+bob),(5,16+bob),(5,19+bob),(4,23+bob),(3,23+bob),(2,20+bob)],BAG)
    poly(im,[(2,17+bob),(5,16+bob),(5,18+bob),(4,19+bob),(2,19+bob)],BAG_L)
    # scarf back
    poly(im,[(8,10+bob),(15,10+bob),(16,12+bob),(14,13+bob),(9,13+bob),(8,12+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(15,12+bob),(13,12+bob),(10,12+bob)],SCARF_D)
    P(im,10,11+bob,SCARF); P(im,12,11+bob,SCARF)
    # arms
    poly(im,[(5,12+bob),(7,12+bob),(7,21+bob),(6,23+bob),(4,22+bob),(3,18+bob),(4,14+bob)],OUT)
    poly(im,[(5,13+bob),(6,13+bob),(6,21+bob),(5,22+bob),(4,20+bob),(4,15+bob)],COAT_D)
    P(im,5,14+bob,COAT)
    R(im,4,21+bob,6,23+bob,OUT); R(im,4,22+bob,5,22+bob,GLOVE); P(im,4,22+bob,GLOVE_L)
    poly(im,[(17,12+bob),(19,12+bob),(21,14+bob),(21,18+bob),(20,22+bob),(18,23+bob),(17,21+bob),(18,13+bob)],OUT)
    poly(im,[(17,13+bob),(18,13+bob),(20,15+bob),(20,18+bob),(19,21+bob),(18,22+bob),(18,20+bob)],COAT_L)
    P(im,19,14+bob,COAT); P(im,19,18+bob,COAT)
    R(im,18,21+bob,20,23+bob,OUT); R(im,18,22+bob,19,22+bob,GLOVE); P(im,19,22+bob,GLOVE_L)
    # hood back
    poly(im,[(11,0+bob),(14,0+bob),(16,2+bob),(18,5+bob),(17,9+bob),(15,11+bob),(9,11+bob),(7,9+bob),(6,5+bob),(8,2+bob)],OUT)
    poly(im,[(11,1+bob),(14,1+bob),(15,3+bob),(17,5+bob),(16,8+bob),(14,10+bob),(10,10+bob),(8,8+bob),(7,5+bob),(9,3+bob)],HOOD)
    poly(im,[(11,1+bob),(12,1+bob),(11,10+bob),(10,10+bob),(8,8+bob),(7,5+bob),(9,3+bob)],HOOD_D)
    poly(im,[(14,1+bob),(15,3+bob),(17,5+bob),(16,8+bob),(14,10+bob),(13,9+bob),(14,4+bob)],HOOD_L)
    R(im,10,1+bob,13,1+bob,HOOD_H)
    # hood folds
    R(im,11,3+bob,12,9+bob,HOOD_D); P(im,12,4+bob,HOOD_L); P(im,10,7+bob,HOOD_L)
    # scarf collar back
    R(im,9,10+bob,14,10+bob,SCARF_D)
    # rim
    for (x,y,c) in [(16,3+bob,RIM_W),(17,4+bob,RIM_W),(17,5+bob,RIM_W),(21,15+bob,RIM_W),(21,17+bob,RIM_W),(20,20+bob,RIM_W),(16,31,BOOT_H),(10,31,BOOT_H)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(6,5+bob,RIM_C),(7,6+bob,RIM_C),(3,16+bob,RIM_C),(4,19+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im

def player_side(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    stride=0 if pose<2 else (2 if pose==2 else -2)
    # legs (profile): back leg left, front leg right
    poly(im,[(7,21),(11,21),(11,29),(10,31),(7,31),(7,28)],OUT)
    poly(im,[(8,22),(10,22),(10,29),(9,30),(8,30),(8,25)],COAT_D)
    R(im,7,28,11,31,OUT); R(im,8,28,10,30,BOOT); P(im,10,28,BOOT_L); P(im,8,29,BOOT_H)
    poly(im,[(11+stride,21),(15+stride,21),(15+stride,29),(14+stride,31),(11+stride,31),(11+stride,28)],OUT)
    poly(im,[(12+stride,22),(14+stride,22),(14+stride,29),(13+stride,30),(12+stride,30),(12+stride,25)],COAT_D)
    P(im,14+stride,23,COAT_L)
    R(im,11+stride,28,15+stride,31,OUT); R(im,12+stride,28,14+stride,30,BOOT); P(im,14+stride,28,BOOT_L); P(im,12+stride,29,BOOT_H)
    # coat back tail
    poly(im,[(5,19),(8,21),(8,27),(6,27),(5,29),(4,24)],OUT)
    poly(im,[(5,20),(7,22),(7,25),(6,26),(5,27),(5,22)],COAT_D)
    # torso profile
    poly(im,[(8,10+bob),(15,10+bob),(17,12+bob),(18,16+bob),(17,21+bob),(15,24+bob),(9,24+bob),(7,21+bob),(7,16+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(16,13+bob),(17,16+bob),(16,20+bob),(14,23+bob),(10,23+bob),(8,20+bob),(8,16+bob)],COAT)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(10,23+bob),(8,20+bob),(8,16+bob),(9,13+bob)],COAT_D)
    poly(im,[(14,11+bob),(16,13+bob),(17,16+bob),(16,20+bob),(14,22+bob),(13,21+bob)],COAT_L)
    # belt
    R(im,9,18+bob,16,20+bob,BELT); R(im,9,20+bob,16,20+bob,(96,64,34,255))
    R(im,12,18+bob,14,20+bob,BUCKLE); P(im,13,19+bob,BUCKLE_H)
    # scarf tail back
    poly(im,[(8,10+bob),(14,10+bob),(14,12+bob),(12,14+bob),(9,13+bob)],OUT)
    poly(im,[(9,11+bob),(13,11+bob),(13,12+bob),(11,13+bob),(9,12+bob)],SCARF)
    P(im,10,11+bob,SCARF_L)
    poly(im,[(7,12+bob),(9,13+bob),(8,17+bob),(6,16+bob)],OUT)
    poly(im,[(7,13+bob),(8,14+bob),(7,16+bob),(7,15+bob)],SCARF_D)
    # satchel on back
    poly(im,[(2,15+bob),(6,14+bob),(7,18+bob),(6,23+bob),(3,23+bob),(2,20+bob)],OUT)
    poly(im,[(3,16+bob),(6,15+bob),(6,18+bob),(5,22+bob),(4,22+bob),(3,20+bob)],BAG)
    poly(im,[(3,16+bob),(6,15+bob),(6,17+bob),(4,18+bob),(3,18+bob)],BAG_L)
    R(im,4,19+bob,5,20+bob,BUCKLE)
    # arm near side (right side of body, towards viewer)
    poly(im,[(15,12+bob),(17,12+bob),(18,15+bob),(18,20+bob),(17,23+bob),(15,22+bob),(15,17+bob)],OUT)
    poly(im,[(16,13+bob),(17,13+bob),(17,15+bob),(17,20+bob),(16,21+bob),(16,17+bob)],COAT_L)
    R(im,16,21+bob,18,23+bob,OUT); R(im,16,22+bob,17,22+bob,GLOVE); P(im,17,22+bob,GLOVE_L)
    # head profile, facing right
    poly(im,[(9,0+bob),(13,0+bob),(16,2+bob),(18,5+bob),(19,8+bob),(18,10+bob),(16,11+bob),(9,11+bob),(7,9+bob),(7,5+bob)],OUT)
    poly(im,[(10,1+bob),(13,1+bob),(15,3+bob),(17,5+bob),(18,8+bob),(17,9+bob),(15,10+bob),(10,10+bob),(8,8+bob),(8,5+bob)],HOOD)
    poly(im,[(10,1+bob),(11,1+bob),(11,10+bob),(10,10+bob),(8,8+bob),(8,5+bob)],HOOD_D)
    poly(im,[(13,1+bob),(15,3+bob),(17,5+bob),(18,8+bob),(17,9+bob),(15,10+bob),(14,9+bob),(14,4+bob)],HOOD_L)
    R(im,11,1+bob,13,1+bob,HOOD_H)
    # face void profile
    poly(im,[(13,4+bob),(17,4+bob),(18,6+bob),(18,8+bob),(16,10+bob),(13,10+bob),(12,8+bob),(12,6+bob)],FACE)
    P(im,15,6+bob,EYE); P(im,15,6+bob,EYE_H)
    P(im,17,7+bob,(14,26,36,255))  # nose
    P(im,16,9+bob,(14,26,36,255))
    # hood rim
    P(im,12,5+bob,HOOD_L); P(im,18,6+bob,HOOD_H); P(im,18,8+bob,HOOD_H)
    # scarf across chin
    R(im,13,10+bob,16,10+bob,SCARF)
    # rim
    for (x,y,c) in [(18,3+bob,RIM_W),(18,4+bob,RIM_W),(18,5+bob,RIM_W),(17,21+bob,RIM_W),(16,31,BOOT_H),(14,31,BOOT_H)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(8,5+bob,RIM_C),(8,6+bob,RIM_C),(3,16+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im



def player_side(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    stride=0 if pose<2 else (2 if pose==2 else -2)
    # back leg
    bx=0 if pose<2 else (-1 if pose==2 else 1)
    fx=0 if pose<2 else (2 if pose==2 else -1)
    poly(im,[(6+bx,21),(9+bx,21),(9+bx,29),(8+bx,31),(5+bx,31),(5+bx,28)],OUT)
    poly(im,[(7+bx,22),(8+bx,22),(8+bx,29),(7+bx,30),(6+bx,30),(6+bx,25)],COAT_D)
    R(im,5+bx,28,9+bx,31,OUT); R(im,6+bx,28,8+bx,30,BOOT); Px(im,8+bx,28,BOOT_L); Px(im,6+bx,29,BOOT_H)
    # front leg
    poly(im,[(12+fx,21),(15+fx,21),(15+fx,29),(14+fx,31),(11+fx,31),(11+fx,28)],OUT)
    poly(im,[(12+fx,22),(14+fx,22),(14+fx,29),(13+fx,30),(12+fx,30),(12+fx,25)],COAT_D)
    Px(im,14+fx,23,COAT_L)
    R(im,11+fx,28,15+fx,31,OUT); R(im,12+fx,28,14+fx,30,BOOT); Px(im,14+fx,28,BOOT_L); Px(im,12+fx,29,BOOT_H)
    # coat back tail
    poly(im,[(3,19),(7,21),(7,27),(5,27),(4,29),(2,24),(2,21)],OUT)
    poly(im,[(4,20),(6,22),(6,25),(5,26),(4,27),(3,23)],COAT_D)
    Px(im,4,24,COAT)
    # torso profile
    poly(im,[(8,10+bob),(14,10+bob),(17,12+bob),(18,16+bob),(17,21+bob),(14,24+bob),(9,24+bob),(7,21+bob),(7,16+bob)],OUT)
    poly(im,[(9,11+bob),(13,11+bob),(16,13+bob),(17,16+bob),(16,20+bob),(13,23+bob),(10,23+bob),(8,20+bob),(8,16+bob)],COAT)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(10,23+bob),(8,20+bob),(8,16+bob),(9,13+bob)],COAT_D)
    poly(im,[(13,11+bob),(16,13+bob),(17,16+bob),(16,20+bob),(13,22+bob),(13,21+bob)],COAT_L)
    # belt
    R(im,9,18+bob,16,20+bob,BELT); R(im,9,20+bob,16,20+bob,(96,64,34,255))
    R(im,12,18+bob,14,20+bob,BUCKLE); Px(im,13,19+bob,BUCKLE_H)
    # scarf tail back
    poly(im,[(8,10+bob),(14,10+bob),(14,12+bob),(11,14+bob),(8,13+bob)],OUT)
    poly(im,[(9,11+bob),(13,11+bob),(13,12+bob),(10,13+bob),(9,12+bob)],SCARF)
    Px(im,10,11+bob,SCARF_L)
    poly(im,[(6,12+bob),(9,13+bob),(8,17+bob),(5,16+bob)],OUT)
    poly(im,[(6,13+bob),(8,14+bob),(7,16+bob),(6,15+bob)],SCARF_D)
    # satchel on back
    poly(im,[(1,15+bob),(5,14+bob),(6,18+bob),(5,23+bob),(2,23+bob),(1,20+bob)],OUT)
    poly(im,[(2,16+bob),(5,15+bob),(5,18+bob),(4,22+bob),(3,22+bob),(2,20+bob)],BAG)
    poly(im,[(2,16+bob),(5,15+bob),(5,17+bob),(4,18+bob),(2,18+bob)],BAG_L)
    R(im,3,19+bob,4,20+bob,BUCKLE)
    # near arm (front side)
    poly(im,[(14,12+bob),(16,12+bob),(18,15+bob),(18,20+bob),(17,23+bob),(15,22+bob),(14,17+bob)],OUT)
    poly(im,[(15,13+bob),(16,13+bob),(17,15+bob),(17,20+bob),(16,21+bob),(15,21+bob),(15,17+bob)],COAT_L)
    R(im,15,21+bob,17,23+bob,OUT); R(im,15,22+bob,16,22+bob,GLOVE); Px(im,16,22+bob,GLOVE_L)
    # head profile, facing right; hood point at back left
    poly(im,[(10,0+bob),(14,1+bob),(17,3+bob),(19,6+bob),(19,8+bob),(18,10+bob),(15,11+bob),(9,11+bob),(6,9+bob),(5,6+bob),(6,2+bob)],OUT)
    poly(im,[(10,1+bob),(13,2+bob),(16,4+bob),(18,6+bob),(18,8+bob),(17,9+bob),(14,10+bob),(10,10+bob),(7,8+bob),(6,6+bob),(7,3+bob)],HOOD)
    poly(im,[(10,1+bob),(11,1+bob),(10,10+bob),(9,10+bob),(7,8+bob),(6,6+bob),(7,3+bob)],HOOD_D)
    poly(im,[(13,2+bob),(16,4+bob),(18,6+bob),(18,8+bob),(17,9+bob),(14,10+bob),(13,9+bob),(13,4+bob)],HOOD_L)
    R(im,10,1+bob,13,1+bob,HOOD_H)
    # face opening profile
    poly(im,[(13,4+bob),(17,4+bob),(18,6+bob),(18,8+bob),(16,10+bob),(13,10+bob),(12,8+bob),(12,6+bob)],FACE)
    Px(im,15,6+bob,EYE); Px(im,15,6+bob,EYE_H)
    Px(im,17,7+bob,(14,26,36,255)); Px(im,16,9+bob,(14,26,36,255))
    # hood rim around face
    Px(im,12,5+bob,HOOD_L); Px(im,18,6+bob,HOOD_H); Px(im,18,8+bob,HOOD_H)
    # scarf across chin
    R(im,13,10+bob,16,10+bob,SCARF)
    # rim
    for (x,y,c) in [(18,3+bob,RIM_W),(18,4+bob,RIM_W),(18,5+bob,RIM_W),(17,21+bob,RIM_W),(14+fx,31,BOOT_H),(8+bx,31,BOOT_H)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(6,3+bob,RIM_C),(6,4+bob,RIM_C),(2,16+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im



W,H=24,32
OUT=(5,8,14,255)
CAP_D=(14,26,44,255); CAP=(24,42,68,255); CAP_L=(38,62,94,255)
UNI_D=(20,40,64,255); UNI=(32,60,94,255); UNI_L=(48,84,126,255); UNI_E=(66,108,152,255)
SKIN_D=(172,108,76,255); SKIN=(220,152,108,255); SKIN_L=(244,194,150,255)
BELT=(18,22,28,255); BELT_L=(40,46,54,255); BUCKLE=(196,204,212,255); BUCKLE_H=(238,244,246,255)
BRASS=(214,166,76,255); BRASS_H=(248,218,146,255)
BOOT=(12,14,20,255); BOOT_L=(38,42,52,255)
FLASH=(96,104,112,255); FLASH_L=(148,156,164,255); LENS=(255,208,112,255); LENS_H=(255,246,196,255)
RIM_W=(248,202,126,255); RIM_C=(108,176,198,255); EYE=(8,10,14,255); HAIR=(46,30,20,255)

def new(): return Image.new('RGBA',(W,H),(0,0,0,0))
def poly(im,pts,c): ImageDraw.Draw(im).polygon(pts,fill=c)
def R(im,x0,y0,x1,y1,c): ImageDraw.Draw(im).rectangle([x0,y0,x1,y1],fill=c)
def P(im,x,y,c): im.putpixel((x,y),c)

def legs(im,lx,rx):
    poly(im,[(7+lx,21),(11+lx,21),(11+lx,29),(10+lx,31),(7+lx,31),(7+lx,28)],OUT)
    poly(im,[(8+lx,22),(10+lx,22),(10+lx,29),(9+lx,30),(8+lx,30),(8+lx,25)],UNI_D)
    P(im,8+lx,23,UNI)
    R(im,7+lx,28,11+lx,31,OUT); R(im,8+lx,28,10+lx,30,BOOT); P(im,9+lx,28,BOOT_L); P(im,8+lx,29,BOOT_L)
    poly(im,[(13+rx,21),(17+rx,21),(17+rx,28),(16+rx,31),(13+rx,31),(13+rx,29)],OUT)
    poly(im,[(14+rx,22),(16+rx,22),(16+rx,29),(15+rx,30),(14+rx,30),(14+rx,25)],UNI_D)
    P(im,16+rx,23,UNI_L)
    R(im,13+rx,28,17+rx,31,OUT); R(im,14+rx,28,16+rx,30,BOOT); P(im,16+rx,28,BOOT_L); P(im,15+rx,29,BOOT_L)

def police_down(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    lx=0 if pose not in (2,3) else (-1 if pose==2 else 1)
    rx=0 if pose not in (2,3) else (1 if pose==2 else -1)
    legs(im,lx,rx)
    # torso
    poly(im,[(8,10+bob),(15,10+bob),(18,12+bob),(18,17+bob),(18,21+bob),(16,24+bob),(8,24+bob),(6,21+bob),(6,17+bob),(7,12+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(17,13+bob),(17,17+bob),(17,20+bob),(15,23+bob),(9,23+bob),(7,20+bob),(7,17+bob),(8,13+bob)],UNI)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(9,23+bob),(7,20+bob),(7,17+bob),(8,13+bob)],UNI_D)
    poly(im,[(14,11+bob),(17,13+bob),(17,17+bob),(17,20+bob),(15,22+bob),(14,21+bob)],UNI_L)
    # buttons
    P(im,10,13+bob,BRASS); P(im,14,13+bob,BRASS); P(im,10,16+bob,BRASS); P(im,14,16+bob,BRASS)
    # badge
    R(im,8,12+bob,9,13+bob,BRASS); P(im,8,12+bob,BRASS_H)
    # radio on left chest
    R(im,15,12+bob,16,15+bob,(26,30,36,255)); P(im,16,12+bob,(80,220,120,255))
    # belt
    R(im,7,18+bob,17,20+bob,BELT); R(im,7,20+bob,17,20+bob,BELT_L)
    R(im,11,18+bob,13,20+bob,BUCKLE); P(im,12,19+bob,BUCKLE_H)
    # arms
    poly(im,[(5,12+bob),(7,12+bob),(7,21+bob),(6,23+bob),(4,22+bob),(3,18+bob),(4,14+bob)],OUT)
    poly(im,[(5,13+bob),(6,13+bob),(6,21+bob),(5,22+bob),(4,20+bob),(4,15+bob)],UNI_D)
    P(im,5,14+bob,UNI)
    R(im,4,21+bob,6,23+bob,OUT); R(im,4,22+bob,5,22+bob,SKIN); P(im,4,22+bob,SKIN_L)
    poly(im,[(17,12+bob),(19,12+bob),(21,14+bob),(21,18+bob),(20,22+bob),(18,23+bob),(17,21+bob),(18,13+bob)],OUT)
    poly(im,[(17,13+bob),(18,13+bob),(20,15+bob),(20,18+bob),(19,21+bob),(18,22+bob),(18,20+bob)],UNI_L)
    P(im,19,14+bob,UNI); P(im,19,18+bob,UNI)
    R(im,18,21+bob,20,23+bob,OUT); R(im,18,22+bob,19,22+bob,SKIN); P(im,19,22+bob,SKIN_L)
    # flashlight in right hand (down, hanging)
    R(im,19,22+bob,21,26+bob,OUT); R(im,19,22+bob,20,25+bob,FLASH); P(im,20,22+bob,FLASH_L); P(im,20,26+bob,LENS); P(im,21,26+bob,LENS_H)
    # head/cap
    poly(im,[(9,1+bob),(15,1+bob),(16,3+bob),(16,5+bob),(15,6+bob),(9,6+bob),(8,5+bob),(8,3+bob)],OUT)
    poly(im,[(9,2+bob),(15,2+bob),(15,4+bob),(14,5+bob),(10,5+bob),(9,4+bob)],CAP)
    R(im,9,2+bob,14,2+bob,CAP_L); R(im,10,3+bob,14,3+bob,CAP_L)
    # visor
    R(im,8,6+bob,16,6+bob,OUT); R(im,9,6+bob,15,6+bob,CAP_D); P(im,10,6+bob,CAP_L)
    # cap badge
    R(im,11,2+bob,12,3+bob,BRASS); P(im,11,2+bob,BRASS_H)
    # face
    R(im,9,7+bob,15,10+bob,OUT)
    R(im,9,7+bob,15,9+bob,SKIN)
    R(im,9,7+bob,10,9+bob,SKIN_D)
    P(im,10,7+bob,SKIN_L); P(im,11,7+bob,SKIN_L)
    # eyebrows/eyes
    R(im,10,7+bob,11,7+bob,HAIR); R(im,13,7+bob,14,7+bob,HAIR)
    P(im,10,8+bob,EYE); P(im,13,8+bob,EYE)
    P(im,10,8+bob,(220,240,240,255)); P(im,13,8+bob,(220,240,240,255))
    # nose/mustache/mouth
    P(im,12,8+bob,SKIN_D)
    R(im,10,9+bob,13,9+bob,(96,58,40,255))
    P(im,11,10+bob,(120,70,56,255)); P(im,12,10+bob,(120,70,56,255))
    # chin
    R(im,9,10+bob,15,11+bob,OUT); R(im,10,10+bob,14,10+bob,SKIN_D)
    # shoulders/collar
    R(im,9,11+bob,14,11+bob,UNI_E); P(im,9,11+bob,BRASS)
    # rim
    for (x,y,c) in [(16,3+bob,RIM_W),(17,4+bob,RIM_W),(21,15+bob,RIM_W),(21,17+bob,RIM_W),(20,20+bob,RIM_W),(16,31,BOOT_L),(10,31,BOOT_L)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(6,4+bob,RIM_C),(7,5+bob,RIM_C),(4,16+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im



W,H=24,32


def police_up(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    lx=0 if pose not in (2,3) else (-1 if pose==2 else 1)
    rx=0 if pose not in (2,3) else (1 if pose==2 else -1)
    legs(im,lx,rx)
    # torso back
    poly(im,[(8,10+bob),(15,10+bob),(18,12+bob),(18,17+bob),(18,21+bob),(16,24+bob),(8,24+bob),(6,21+bob),(6,17+bob),(7,12+bob)],OUT)
    poly(im,[(9,11+bob),(14,11+bob),(17,13+bob),(17,17+bob),(17,20+bob),(15,23+bob),(9,23+bob),(7,20+bob),(7,17+bob),(8,13+bob)],UNI)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(9,23+bob),(7,20+bob),(7,17+bob),(8,13+bob)],UNI_D)
    poly(im,[(14,11+bob),(17,13+bob),(17,17+bob),(17,20+bob),(15,22+bob),(14,21+bob)],UNI_L)
    # center seam
    R(im,11,12+bob,12,18+bob,UNI_D); Px(im,12,15+bob,UNI_E)
    # belt
    R(im,7,18+bob,17,20+bob,BELT); R(im,7,20+bob,17,20+bob,BELT_L)
    # radio back? keys
    R(im,8,21+bob,9,23+bob,(28,32,38,255)); Px(im,9,21+bob,BRASS)
    # arms
    poly(im,[(5,12+bob),(7,12+bob),(7,21+bob),(6,23+bob),(4,22+bob),(3,18+bob),(4,14+bob)],OUT)
    poly(im,[(5,13+bob),(6,13+bob),(6,21+bob),(5,22+bob),(4,20+bob),(4,15+bob)],UNI_D)
    Px(im,5,14+bob,UNI)
    R(im,4,21+bob,6,23+bob,OUT); R(im,4,22+bob,5,22+bob,SKIN); Px(im,4,22+bob,SKIN_L)
    poly(im,[(17,12+bob),(19,12+bob),(21,14+bob),(21,18+bob),(20,22+bob),(18,23+bob),(17,21+bob),(18,13+bob)],OUT)
    poly(im,[(17,13+bob),(18,13+bob),(20,15+bob),(20,18+bob),(19,21+bob),(18,22+bob),(18,20+bob)],UNI_L)
    Px(im,19,14+bob,UNI); Px(im,19,18+bob,UNI)
    R(im,18,21+bob,20,23+bob,OUT); R(im,18,22+bob,19,22+bob,SKIN); Px(im,19,22+bob,SKIN_L)
    # flashlight hanging
    R(im,19,22+bob,21,26+bob,OUT); R(im,19,22+bob,20,25+bob,FLASH); Px(im,20,22+bob,FLASH_L); Px(im,20,26+bob,LENS); Px(im,21,26+bob,LENS_H)
    # cap back
    poly(im,[(9,1+bob),(15,1+bob),(16,3+bob),(16,5+bob),(15,6+bob),(9,6+bob),(8,5+bob),(8,3+bob)],OUT)
    poly(im,[(9,2+bob),(15,2+bob),(15,4+bob),(14,5+bob),(10,5+bob),(9,4+bob)],CAP)
    poly(im,[(9,2+bob),(11,2+bob),(11,5+bob),(10,5+bob),(9,4+bob)],CAP_D)
    R(im,10,2+bob,14,2+bob,CAP_L)
    # back band / brass button
    R(im,9,5+bob,15,6+bob,CAP_D); Px(im,12,5+bob,BRASS); Px(im,12,5+bob,BRASS_H)
    # neck
    R(im,10,6+bob,14,8+bob,SKIN_D); R(im,10,6+bob,13,7+bob,SKIN)
    # collar
    R(im,9,8+bob,14,9+bob,UNI_E); Px(im,9,8+bob,BRASS)
    # rim
    for (x,y,c) in [(16,3+bob,RIM_W),(17,4+bob,RIM_W),(21,15+bob,RIM_W),(21,17+bob,RIM_W),(20,20+bob,RIM_W),(16,31,BOOT_L),(10,31,BOOT_L)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(6,4+bob,RIM_C),(7,5+bob,RIM_C),(4,16+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im

def police_side(pose=0):
    im=new(); bob=1 if pose==1 else (1 if pose in (2,3) else 0)
    bx=0 if pose<2 else (-1 if pose==2 else 1)
    fx=0 if pose<2 else (2 if pose==2 else -1)
    # back leg
    poly(im,[(6+bx,21),(9+bx,21),(9+bx,29),(8+bx,31),(5+bx,31),(5+bx,28)],OUT)
    poly(im,[(7+bx,22),(8+bx,22),(8+bx,29),(7+bx,30),(6+bx,30),(6+bx,25)],UNI_D)
    R(im,5+bx,28,9+bx,31,OUT); R(im,6+bx,28,8+bx,30,BOOT); Px(im,8+bx,28,BOOT_L)
    # front leg
    poly(im,[(12+fx,21),(15+fx,21),(15+fx,29),(14+fx,31),(11+fx,31),(11+fx,28)],OUT)
    poly(im,[(12+fx,22),(14+fx,22),(14+fx,29),(13+fx,30),(12+fx,30),(12+fx,25)],UNI_D)
    Px(im,14+fx,23,UNI_L)
    R(im,11+fx,28,15+fx,31,OUT); R(im,12+fx,28,14+fx,30,BOOT); Px(im,14+fx,28,BOOT_L)
    # torso profile
    poly(im,[(8,10+bob),(14,10+bob),(17,12+bob),(18,16+bob),(17,21+bob),(14,24+bob),(9,24+bob),(7,21+bob),(7,16+bob)],OUT)
    poly(im,[(9,11+bob),(13,11+bob),(16,13+bob),(17,16+bob),(16,20+bob),(13,23+bob),(10,23+bob),(8,20+bob),(8,16+bob)],UNI)
    poly(im,[(9,11+bob),(11,11+bob),(11,23+bob),(10,23+bob),(8,20+bob),(8,16+bob),(9,13+bob)],UNI_D)
    poly(im,[(13,11+bob),(16,13+bob),(17,16+bob),(16,20+bob),(13,22+bob),(13,21+bob)],UNI_L)
    # badge + buttons
    R(im,13,13+bob,14,14+bob,BRASS); Px(im,13,13+bob,BRASS_H)
    Px(im,10,14+bob,BRASS); Px(im,10,17+bob,BRASS)
    # belt
    R(im,9,18+bob,16,20+bob,BELT); R(im,9,20+bob,16,20+bob,BELT_L)
    R(im,12,18+bob,14,20+bob,BUCKLE); Px(im,13,19+bob,BUCKLE_H)
    # arm near side, holding flashlight forward
    poly(im,[(14,12+bob),(16,12+bob),(18,15+bob),(18,19+bob),(17,22+bob),(15,21+bob),(14,17+bob)],OUT)
    poly(im,[(15,13+bob),(16,13+bob),(17,15+bob),(17,19+bob),(16,20+bob),(15,20+bob),(15,17+bob)],UNI_L)
    R(im,16,19+bob,19,22+bob,OUT); R(im,16,20+bob,18,21+bob,SKIN)
    # flashlight forward
    R(im,18,19+bob,21,21+bob,OUT); R(im,18,19+bob,20,20+bob,FLASH); Px(im,19,19+bob,FLASH_L); Px(im,21,20+bob,LENS); Px(im,20,20+bob,LENS_H)
    # head/cap profile, facing right
    poly(im,[(9,1+bob),(14,1+bob),(16,2+bob),(18,4+bob),(19,6+bob),(18,7+bob),(16,7+bob),(16,8+bob),(9,8+bob),(8,6+bob),(8,3+bob)],OUT)
    poly(im,[(9,2+bob),(14,2+bob),(16,3+bob),(17,4+bob),(18,6+bob),(17,7+bob),(15,7+bob),(15,8+bob),(10,8+bob),(9,6+bob),(9,3+bob)],CAP)
    poly(im,[(9,2+bob),(10,2+bob),(10,8+bob),(9,6+bob),(9,3+bob)],CAP_D)
    R(im,10,2+bob,13,2+bob,CAP_L)
    # visor
    R(im,15,6+bob,20,7+bob,OUT); R(im,16,6+bob,19,6+bob,CAP_D); Px(im,18,6+bob,CAP_L)
    # cap badge
    R(im,11,2+bob,12,3+bob,BRASS); Px(im,11,2+bob,BRASS_H)
    # face profile
    R(im,11,7+bob,18,10+bob,OUT); R(im,11,7+bob,17,9+bob,SKIN)
    R(im,11,7+bob,12,9+bob,SKIN_D)
    Px(im,15,7+bob,HAIR); Px(im,15,8+bob,EYE); Px(im,15,8+bob,(220,240,240,255))
    Px(im,17,8+bob,SKIN_D)  # nose
    R(im,13,9+bob,16,9+bob,(96,58,40,255))  # mustache
    Px(im,14,10+bob,(120,70,56,255)); Px(im,15,10+bob,(120,70,56,255))
    # collar
    R(im,11,10+bob,15,10+bob,UNI_E); Px(im,11,10+bob,BRASS)
    # rim
    for (x,y,c) in [(19,3+bob,RIM_W),(19,4+bob,RIM_W),(19,5+bob,RIM_W),(17,21+bob,RIM_W),(14+fx,31,BOOT_L),(8+bx,31,BOOT_L)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    for (x,y,c) in [(8,3+bob,RIM_C),(8,4+bob,RIM_C)]:
        if 0<=x<W and 0<=y<H and im.getpixel((x,y))[3]>0: im.putpixel((x,y),c)
    return im



def build_player_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (W * 4, H * 3), (0, 0, 0, 0))
    for row, fn in enumerate([player_down, player_up, player_side]):
        for col in range(4):
            sheet.alpha_composite(fn(col), (col * W, row * H))
    return sheet


def build_police_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (W * 4, H * 3), (0, 0, 0, 0))
    for row, fn in enumerate([police_down, police_up, police_side]):
        for col in range(4):
            sheet.alpha_composite(fn(col), (col * W, row * H))
    return sheet
