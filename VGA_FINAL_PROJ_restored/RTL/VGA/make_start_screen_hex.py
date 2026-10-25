# make_start_screen_hex.py - turns a picture into the start screen ROM (start_screen.hex)
# Gold Miner project, Oct 2026.
#
# HOW TO CHANGE THE START SCREEN:
#   1. Make a picture (any size, PNG/JPG). It is shown full screen (640x480), so 4:3 looks best.
#   2. In a terminal, in this folder (RTL/VGA):
#          pip install pillow                                  (once)
#          python make_start_screen_hex.py my_picture.png
#      -> writes start_screen.hex (overwrites the old one)
#   3. Recompile in Quartus. No logic changes are needed.
#
# What it does: scales the picture to 320x240 (start_screen draws every pixel 2x2 -> 640x480),
# converts every pixel to 8-bit RRRGGGBB (the colour format of the whole project) and writes
# one byte per line in hex, row by row (top-left first) = 76,800 lines.
import sys
from PIL import Image

src = sys.argv[1] if len(sys.argv) > 1 else "start_screen.png"
out = sys.argv[2] if len(sys.argv) > 2 else "start_screen.hex"
img = Image.open(src).convert("RGB")
if img.size != (320, 240):
    # NEAREST keeps sharp pixel-art / text edges; for a photo LANCZOS can look smoother
    img = img.resize((320, 240), Image.NEAREST)
px = img.load()
with open(out, "w") as f:
    for y in range(240):
        for x in range(320):
            r, g, b = px[x, y]
            f.write("%02X\n" % (((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6)))
print("wrote", out, "from", src, "(320x240, 76800 bytes)")
