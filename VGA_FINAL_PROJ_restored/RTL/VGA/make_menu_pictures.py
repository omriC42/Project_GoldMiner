# make_menu_pictures.py - draws the two menu pictures of Gold Miner and writes their ROM files
# Gold Miner project, Oct 2026 (Step 14). Run in RTL/VGA:   python make_menu_pictures.py
#   (needs:  pip install pillow)
#
# Writes:
#   start_screen.png / start_screen.hex       320x240, drawn 2x2 on the screen (start_screen.sv)
#   settings_screen.png / settings_screen.hex 160x120, drawn 4x4 on the screen (start_screen.sv)
#   settings_layout.svh   where every row and value word is ON THE SCREEN (640x480 pixels):
#                         the hardware draws the yellow arrow and the green frames there, so the
#                         words in the picture and the frames always line up.
# Every pixel is 8-bit RRRGGGBB; the .hex has one byte per line, row by row (top-left first).
# To change a text: edit it below and run again, then recompile. Changing the NUMBER of rows or
# values also needs the settings logic (game_settings.sv) to be changed.
import re
from PIL import Image

# ---------------- 5x7 font (bit 4 = leftmost column) ----------------
F = {
 'A':[14,17,17,31,17,17,17],'B':[30,17,17,30,17,17,30],'C':[14,17,16,16,16,17,14],'D':[30,17,17,17,17,17,30],
 'E':[31,16,16,30,16,16,31],'F':[31,16,16,30,16,16,16],'G':[14,17,16,23,17,17,15],'H':[17,17,17,31,17,17,17],
 'I':[14,4,4,4,4,4,14],'J':[7,2,2,2,2,18,12],'K':[17,18,20,24,20,18,17],'L':[16,16,16,16,16,16,31],
 'M':[17,27,21,21,17,17,17],'N':[17,25,21,19,17,17,17],'O':[14,17,17,17,17,17,14],'P':[30,17,17,30,16,16,16],
 'Q':[14,17,17,17,21,18,13],'R':[30,17,17,30,20,18,17],'S':[15,16,16,14,1,1,30],'T':[31,4,4,4,4,4,4],
 'U':[17,17,17,17,17,17,14],'V':[17,17,17,17,17,10,4],'W':[17,17,17,21,21,21,10],'X':[17,17,10,4,10,17,17],
 'Y':[17,17,10,4,4,4,4],'Z':[31,1,2,4,8,16,31],
 '0':[14,17,19,21,25,17,14],'1':[4,12,4,4,4,4,14],'2':[14,17,1,2,4,8,31],'3':[31,2,4,2,1,17,14],
 '4':[2,6,10,18,31,2,2],'5':[31,16,30,1,1,17,14],'6':[6,8,16,30,17,17,14],'7':[31,1,2,4,8,8,8],
 '8':[14,17,17,14,17,17,14],'9':[14,17,17,15,1,2,12],
 ' ':[0]*7,'+':[0,4,4,31,4,4,0],'/':[1,1,2,4,8,16,16],'=':[0,0,31,0,31,0,0],'-':[0,0,0,31,0,0,0],
 ':':[0,12,12,0,12,12,0],'*':[0,4,21,14,21,4,0],'.':[0,0,0,0,0,12,12],'!':[4,4,4,4,4,0,4],
}
def text(img, x, y, s, scale, color):
    """draw string s with its top-left at (x, y); advance = 6 font columns; returns the width"""
    px = img.load()
    for i, ch in enumerate(s):
        rows = F[ch]
        for r in range(7):
            for c in range(5):
                if rows[r] >> (4 - c) & 1:
                    for dy in range(scale):
                        for dx in range(scale):
                            px[x + (i * 6 + c) * scale + dx, y + r * scale + dy] = color
    return (len(s) * 6 - 1) * scale
def width(s, scale): return (len(s) * 6 - 1) * scale

def rgb8(c):            # (r,g,b) -> RRRGGGBB byte
    r, g, b = c
    return ((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6)
def from8(v):           # RRRGGGBB -> (r,g,b), the same expansion the testbenches use for .bmp
    r, g, b = v >> 5, (v >> 2) & 7, v & 3
    return ((r << 5) | (r << 2) | (r >> 1), (g << 5) | (g << 2) | (g >> 1), b * 85)

BLACK, WHITE, GOLD, YELLOW, GREY, CYAN = from8(0x00), from8(0xFF), from8(0xF4), from8(0xFC), from8(0x92), from8(0x1F)

# ---------------- the 6 object sprites (object_sprites.svh), for decoration ----------------
def sprites():
    s = open('object_sprites.svh').read()
    out = {}
    for name, n in [('gold_small', 16), ('gold_medium', 32), ('gold_large', 64), ('rock_small', 16), ('rock_medium', 32), ('rock_large', 64)]:
        i = s.index(name + '_colors'); j = s.index('};', i)
        vals = re.findall(r"8'h([0-9A-Fa-f]{2})", s[s.index('{', s.index('=', i)):j])
        out[name] = (n, [int(v, 16) for v in vals])
    return out
def put_sprite(img, x0, y0, spr):
    n, v = spr; px = img.load()
    for k, c in enumerate(v):
        if c != 0xFF: px[x0 + k % n, y0 + k // n] = from8(c)

# ======================= START SCREEN (320x240, drawn 2x2) =======================
start = Image.new('RGB', (320, 240), BLACK)
title = 'GOLD MINER'
text(start, (320 - width(title, 4)) // 2, 22, title, 4, GOLD)
sp = sprites()
put_sprite(start, 24,  72, sp['rock_large'])
put_sprite(start, 104, 88, sp['gold_medium'])
put_sprite(start, 152, 104, sp['gold_small'])
put_sprite(start, 184, 88, sp['rock_medium'])
put_sprite(start, 232, 72, sp['gold_large'])
for x in range(320):                       # a thin brown "ground" line under the objects
    for y in (138, 139): start.putpixel((x, y), from8(0x88))
l1, l2 = 'PRESS ENTER TO PLAY', 'PRESS + FOR SETTINGS'
text(start, (320 - width(l1, 2)) // 2, 162, l1, 2, YELLOW)
text(start, (320 - width(l2, 2)) // 2, 190, l2, 2, CYAN)

# ======================= SETTINGS SCREEN (160x120, drawn 4x4) =======================
# rows: label + its values (the order of the values = the code the logic uses: 0, 1, 2)
# every row has two lines: the label (white), and under it the values (grey, the chosen one framed)
ROWS = [('DIFFICULTY', ['EASY', 'NORMAL', 'HARD']),
        ('TIME PER LEVEL', ['30 S', '60 S', '90 S']),
        ('SOUND', ['ON', 'OFF']),
        ('CHEATS', ['ON', 'OFF'])]
S = 4                                  # screen pixels per picture pixel
setp = Image.new('RGB', (160, 120), BLACK)
t = 'SETTINGS'
text(setp, (160 - width(t, 2)) // 2, 2, t, 2, GOLD)
ROW_Y0, ROW_DY, LABEL_X, VALUE_X, VALUE_DY, GAP = 21, 20, 8, 20, 9, 8
layout = []                            # per row: (screen y of the VALUES line, [(screen x0, x1) per value])
for r, (label, vals) in enumerate(ROWS):
    y = ROW_Y0 + r * ROW_DY
    text(setp, LABEL_X, y, label, 1, WHITE)
    x = VALUE_X; boxes = []
    for v in vals:
        w = text(setp, x, y + VALUE_DY, v, 1, GREY)
        boxes.append((x * S, (x + w) * S))   # screen pixels [x0, x1)
        x += w + GAP
    assert x - GAP <= 156, label
    layout.append(((y + VALUE_DY) * S, boxes))
h1, h2 = '8/2 ROW    4/6 CHANGE', 'PRESS ENTER TO START'
text(setp, (160 - width(h1, 1)) // 2, 103, h1, 1, CYAN)
text(setp, (160 - width(h2, 1)) // 2, 112, h2, 1, CYAN)

# ---------------- write the files ----------------
def save(img, name):
    img.save(name + '.png')
    px = img.load()
    with open(name + '.hex', 'w') as f:
        for y in range(img.size[1]):
            for x in range(img.size[0]):
                f.write('%02X\n' % rgb8(px[x, y]))
save(start, 'start_screen'); save(setp, 'settings_screen')
with open('settings_layout.svh', 'w') as f:
    f.write('// settings_layout.svh - WRITTEN BY make_menu_pictures.py, do not edit by hand.\n')
    f.write('// Where the rows and the value words of settings_screen.png are ON THE SCREEN (640x480).\n')
    f.write('// The text is %d screen pixels high (7 font rows x %d).\n' % (7 * S, S))
    f.write('localparam int SET_ROWS   = %d;\n' % len(ROWS))
    f.write('localparam int SET_TEXT_H = %d;\n' % (7 * S))
    f.write('localparam int SET_ARROW_X = %d;            // left edge of the cursor arrow (16 wide, at the LABEL line)\n' % 8)
    f.write('localparam int SET_LABEL_DY = %d;          // the label line is this much above the values line\n' % (VALUE_DY * S))
    f.write("localparam int SET_ROW_Y [0:%d] = '{%s};   // top of the VALUES line of each row\n" % (len(ROWS) - 1, ', '.join(str(y) for y, _ in layout)))
    f.write("localparam int SET_NUM_VALUES [0:%d] = '{%s};\n" % (len(ROWS) - 1, ', '.join(str(len(b)) for _, b in layout)))
    for k, nm in [(0, 'SET_VAL_X0'), (1, 'SET_VAL_X1')]:
        rows = []
        for _, b in layout:
            b2 = b + [(0, 0)] * (3 - len(b))
            rows.append("'{%s}" % ', '.join(str(bb[k]) for bb in b2))
        f.write("localparam int %s [0:%d][0:2] = '{%s};   // value words: %s\n" % (nm, len(ROWS) - 1, ', '.join(rows), 'left edge' if k == 0 else 'right edge (excluded)'))
print('layout (screen px):', layout)
