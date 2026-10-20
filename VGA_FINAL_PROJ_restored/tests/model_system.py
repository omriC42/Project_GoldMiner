# Frame-level model of the Step 3 scenario: hook_move + hook_draw + gold object (claw AND gold)
import math
from model_hook_move import H, FPS, MIN_R, XMAX, YMAX
from model_hook_draw import CLAW_BM, COS, SIN
X0,Y0=320,164
def claw_pixels(Xe,Ye):
    return {(Xe-7+cx,Ye-7+cy) for cy in range(16) for cx in range(16) if CLAW_BM[cy][cx]=='1'}
def rope_pixels(h):
    Xe,Ye=h.tip(); R=h.Rpx; Lx,Ly=Xe-X0,Ye-Y0
    return {(x,y) for y in range(min(Y0,Ye)-1,max(Y0,Ye)+2) for x in range(min(X0,Xe)-1,max(X0,Xe)+2)
            if abs((y-Y0)*Lx-(x-X0)*Ly)<=R}
def frame(h,gold=None):
    h.frame()
    if gold and h.st==1:
        g=gold
        if any(g[0]<=x<=g[2] and g[1]<=y<=g[3] for x,y in claw_pixels(*h.tip())):
            h.st=2; return True
    return False
h=H(); f=0
print("T1 reset: state",h.st,"angle",h.idx*3)
while h.idx!=0: frame(h); f+=1
n=0;mx=0
while True:
    frame(h); n+=1; mx=max(mx,h.idx)
    if h.idx==0 and mx==60: break
print(f"T2 swing cycle {n} frames = {n/FPS:.2f}s")
w=0
while not (19<=h.idx<=21): frame(h); w+=1
a=h.idx; h.st=1; n=0; maxR=0
while h.st==1: frame(h); n+=1; maxR=max(maxR,h.Rpx)
print(f"T3 shoot at {a*3} deg after waiting {w} frames: {n} frames shooting, tip at retract {h.tip()}, R={h.Rpx}")
m=0
while h.st==2: frame(h); m+=1
print(f"T3 retract {m} frames, back to swing R={h.Rpx}, angle {h.idx*3}")
gold=(300,330,340,360); w=0
while not (29<=h.idx<=31): frame(h); w+=1
a=h.idx; h.st=1; n=0; hit=False
while h.st==1 and n<500:
    hit=frame(h,gold); n+=1
print(f"T4 shoot at {a*3} deg: collision={hit} after {n} frames, tip at {h.tip()}, R={h.Rpx}")
m=0
while h.st==2: frame(h); m+=1
print(f"T4 retract {m} frames")
gold=(316,180,324,188); rope_hits=0; claw_hits=0
for i in range(130):
    frame(h)
    rp=rope_pixels(h); cp=claw_pixels(*h.tip())
    g=lambda p:316<=p[0]<=324 and 180<=p[1]<=188
    if any(g(p) for p in rp-cp): rope_hits+=1
    if any(g(p) for p in cp): claw_hits+=1
print(f"T5 130 swing frames: rope over gold in {rope_hits} frames, claw over gold in {claw_hits} frames, state {h.st}")
