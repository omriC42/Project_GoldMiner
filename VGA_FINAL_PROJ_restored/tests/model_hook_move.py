import math
FPS=72.58; FP=64
SW=220; SH=200; RE=300; MIN_R=40; XMIN=2; XMAX=637; YMAX=477
r=lambda n,d:(n+d//2)//d
SWS=r(SW*FP*100,3*7258); SHS=r(SH*FP*100,7258); RES=r(RE*FP*100,7258)
COS=[round(256*math.cos(math.radians(3*i))) for i in range(61)]
SIN=[round(256*math.sin(math.radians(3*i))) for i in range(61)]
def asr(v,n): return v>>n  # python >> on negative = arithmetic, like >>>
class H:
    def __init__(s,X0=320,Y0=164): s.X0,s.Y0=X0,Y0; s.st=0; s.a=30*FP; s.dir=0; s.R=MIN_R*FP
    idx=property(lambda s:s.a>>6); Rpx=property(lambda s:(s.R>>6)&2047)
    def tip(s): return s.X0+asr(s.Rpx*COS[s.idx],8), s.Y0+asr(s.Rpx*SIN[s.idx],8)
    def frame(s):
        if s.st==0:
            if s.dir:
                if s.a+SWS>=60*FP: s.a=60*FP; s.dir=0
                else: s.a+=SWS
            else:
                if s.a<=SWS: s.a=0; s.dir=1
                else: s.a-=SWS
        elif s.st==1:
            x,y=s.tip()
            if x<=XMIN or x>=XMAX or y>=YMAX: s.st=2  # border checked every clock -> before next growth
            else:
                s.R+=SHS; x,y=s.tip()
                if x<=XMIN or x>=XMAX or y>=YMAX: s.st=2   # caught on the clock right after the frame
        elif s.st==2:
            if s.R<=MIN_R*FP+RES: s.R=MIN_R*FP; s.st=0
            else: s.R-=RES
print(f"steps x64: swing {SWS} shoot {SHS} retract {RES}")
h=H()
while h.idx!=0: h.frame()
f=0;mx=0;last=0;jump=0
while True:
    h.frame(); f+=1; mx=max(mx,h.idx); jump=max(jump,abs(h.idx-last)); last=h.idx
    if h.idx==0 and mx==60: break
print(f"T2 full swing {f} frames = {f/FPS:.2f} s ({360/(f/FPS):.0f} deg/s), max jump {jump} idx")
h=H(); h.st=1
for _ in range(5): h.frame()
r0=h.Rpx
for _ in range(50): h.frame()
print(f"T3 shoot speed {(h.Rpx-r0)/50*FPS:.1f} px/s")
while h.st==1: h.frame()
print(f"T3 floor: Yend={h.tip()[1]} R={h.Rpx}")
h.frame(); r0=h.Rpx
for _ in range(20): h.frame()
print(f"T4 retract speed {(r0-h.Rpx)/20*FPS:.1f} px/s")
n=0
while h.st==2: h.frame(); n+=1
print(f"T4 back to swing, R={h.Rpx}")
for ang,name in ((0,'right'),(60,'left')):
    h=H(); h.a=ang*FP; h.st=1
    while h.st==1: h.frame()
    print(f"T8 {name} wall Xend={h.tip()[0]}")
