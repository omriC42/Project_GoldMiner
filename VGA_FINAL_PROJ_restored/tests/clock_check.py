# Cycle-accurate Python replica of VGA_Controller.sv (counters, HS/VS, startOfFrame)
# and of hook_move.sv FSM (both merge-conflict variants). Clock = PLL outclk_0 = 31.5 MHz.
F_CLK = 31.5e6
H_FRONT,H_SYNC,H_BACK,H_ACT = 24,40,128,640
V_FRONT,V_SYNC,V_BACK,V_ACT = 9,3,28,480
H_TOTAL = H_FRONT+H_SYNC+H_BACK+H_ACT
V_TOTAL = V_FRONT+V_SYNC+V_BACK+V_ACT

def vga_sof_cycles(n_frames=4):
    H=V=0; HS=1; HS_d=1; VS=1; VS_d=0; sof=[]; cyc=0
    while len(sof) < n_frames+1:
        # combinational output this cycle
        if (not VS) and VS_d: sof.append(cyc)
        # --- horizontal always_ff (nonblocking: compute from old values)
        nH = H+1 if H < H_TOTAL else 0
        nHS = HS
        if H == H_FRONT-1: nHS = 0
        if H == H_FRONT+H_SYNC-1: nHS = 1
        nHS_d = HS
        # --- vertical always_ff
        nV, nVS = V, VS
        if (not HS_d) and HS:
            nV = V+1 if V < V_TOTAL else 0
            if V == V_FRONT-1: nVS = 0
            if V == V_FRONT+V_SYNC-1: nVS = 1
        nVS_d = VS
        H,HS,HS_d,V,VS,VS_d = nH,nHS,nHS_d,nV,nVS,nVS_d
        cyc += 1
    periods = [b-a for a,b in zip(sof,sof[1:])]
    widths = 1  # pulse is !VS && VS_d -> exactly one clock (VS_d follows VS next clock)
    return periods

p = vga_sof_cycles()
fr = F_CLK/p[0]
print(f"[VGA] clocks per line  = {H_TOTAL+1} (counter runs 0..{H_TOTAL} inclusive; nominal {H_TOTAL})")
print(f"[VGA] lines per frame  = {V_TOTAL+1} (counter runs 0..{V_TOTAL} inclusive; nominal {V_TOTAL})")
print(f"[VGA] startOfFrame period = {p[0]} clocks, all equal: {len(set(p))==1}")
print(f"[VGA] startOfFrame rate   = {fr:.2f} Hz  (code comments assume 30 Hz -> x{fr/30:.2f})")

LUT_LEN=13; MIN_R=40; DELTA_R=5
def sim_hook(gated_retract, frames_limit=2000, wall_R=None):
    """frame-level simulation; wall_R = R at which border check triggers"""
    st='SWING'; idx=6; d=0; R=MIN_R
    log=[]; t_clk=0; per=p[0]
    # swing: measure frames for a full cycle 0->12->0
    seq=[]
    for f in range(60):
        nd=d
        if idx==12 and d: nd=0
        elif idx==0 and not d: nd=1
        d=nd; idx = idx+1 if d else idx-1
        seq.append(idx)
    first0=seq.index(0); nxt0=seq.index(0,first0+1)
    swing_frames=nxt0-first0
    # shoot until wall
    R=MIN_R; f=0
    while R < wall_R: R+=DELTA_R; f+=1
    shoot_frames=f
    if gated_retract:
        rf=0
        while R>MIN_R: R-=DELTA_R; rf+=1
        retract_s = rf/fr
    else:  # upstream: R<=R-DELTA_R every clock, no startOfFrame
        rc=0
        while R>MIN_R: R-=DELTA_R; rc+=1
        retract_s = rc/F_CLK
    return swing_frames, shoot_frames, retract_s

for name,g in [("Updated-upstream variant (retract NOT gated by startOfFrame)",False),
               ("Stashed variant (retract gated by startOfFrame)",True)]:
    sw,sh,rt = sim_hook(g, wall_R=400)
    print(f"\n[{name}]")
    print(f"  swing: 15 deg per frame -> full 0->180->0 cycle = {sw} frames = {sw/fr*1000:.0f} ms  ({fr/sw:.1f} swings/s)")
    print(f"  swing angular speed = {15*fr:.0f} deg/s")
    print(f"  shoot: +{DELTA_R} px/frame = {DELTA_R*fr:.0f} px/s; 40->400 px in {sh/fr*1000:.0f} ms")
    print(f"  retract 400->40 px: {rt*1e6:.2f} us" if rt<1e-3 else f"  retract 400->40 px: {rt*1000:.0f} ms")
# reference: miner speed
print(f"\n[miner, for comparison] INITIAL_X_SPEED=40/64 px per frame = {40/64*fr:.0f} px/s")
# what the same numbers would give at the 30 Hz the comments assume
print(f"[if frames were 30 Hz] swing cycle = {24/30*1000:.0f} ms, shoot = {5*30} px/s")
