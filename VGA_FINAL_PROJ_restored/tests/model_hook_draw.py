# Exact integer replica of hook_draw.sv (rope cross-product test + claw bitmap)
import math, sys
from PIL import Image, ImageDraw
HW4=4; ROPE=(70,70,70); CLAW=(190,190,190); BG=(110,72,40)
CLAW_BM=["0000000000000000","0000001111000000","0000010000100000","0000010000100000",
"0000001111000000","0000000110000000","0000000110000000","0010000110000100","0010000110000100",
"0011000110001100","0001100110011000","0000111111110000","0000011111100000","0000000000000000",
"0000000000000000","0000000000000000"]
COS=[round(256*math.cos(math.radians(3*i))) for i in range(61)]
SIN=[round(256*math.sin(math.radians(3*i))) for i in range(61)]
def tip(X0,Y0,R,idx): return X0+((R*COS[idx])>>8), Y0+((R*SIN[idx])>>8)
def render(X0,Y0,R,idx):
    Xe,Ye=tip(X0,Y0,R,idx); Lx,Ly=Xe-X0,Ye-Y0
    lim=(R*HW4)>>2
    xmin,xmax=min(X0,Xe)-1,max(X0,Xe)+1; ymin,ymax=min(Y0,Ye)-1,max(Y0,Ye)+1
    rope=set(); claw=set()
    for y in range(480):
        for x in range(640):
            cx,cy=x-(Xe-7),y-(Ye-7)
            if 0<=cx<16 and 0<=cy<16 and CLAW_BM[cy][cx]=='1': claw.add((x,y)); continue
            if xmin<=x<=xmax and ymin<=y<=ymax and abs((y-Y0)*Lx-(x-X0)*Ly)<=lim: rope.add((x,y))
    return Xe,Ye,rope,claw
if __name__=="__main__":
    X0,Y0=320,164
    cases=[(0,200),(15,250),(30,300),(45,250),(60,200),(30,40)]
    tiles=[]
    for idx,R in cases:
        Xe,Ye,rope,claw=render(X0,Y0,R,idx)
        im=Image.new("RGB",(640,480),BG); px=im.load()
        for p in rope: px[p]=ROPE
        for p in claw: px[p]=CLAW
        px[X0,Y0]=(255,0,0)
        # rope width check: pixels per unit length
        print(f"angle {idx*3:3d} R={R}: tip=({Xe},{Ye}) rope px={len(rope)} (~{len(rope)/R:.2f} px wide) claw px={len(claw)} tip_is_claw={(Xe,Ye) in claw}")
        d=ImageDraw.Draw(im); d.text((8,8),f"angle {idx*3} deg, R={R}",fill=(255,255,255))
        tiles.append(im)
    # contact sheet 3x2 at half size + one zoomed claw
    sheet=Image.new("RGB",(960,480),(0,0,0))
    for i,t in enumerate(tiles): sheet.paste(t.resize((320,240)),((i%3)*320,(i//3)*240))
    sheet.save(sys.argv[1] if len(sys.argv)>1 else "preview.png")
    Xe,Ye,_,_=render(X0,Y0,250,15)
    tiles[1].crop((Xe-30,Ye-30,Xe+30,Ye+30)).resize((360,360),Image.NEAREST).save("claw_zoom.png")
