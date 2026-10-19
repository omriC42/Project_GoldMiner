"""Headless run of BMPConverter_V21.py's math (no Tk window).
Same steps as pressing: open image -> Scale N -> MODE 0 -> 8-bit -> Create Output Files.
Quantize_8 / Quantize_4 / colorbyte and the SV / MIF formats are copied from the course file."""
import os, sys
from datetime import datetime
from PIL import Image

def Quantize_8(v):
    return [0,0,48,48,96,96,128,128,160,160,192,192,224,224,255,255][int(v/16)]

def Quantize_4(v):
    return [0,0,96,96,160,160,255,255][int(v/32)]

def convert(path, scale_val, out_root):
    img = Image.open(path).convert("RGB")
    FileName = os.path.splitext(os.path.basename(path))[0]
    base_w, base_h = (256, 256)                       # work_base_size
    ratio = max(1, 2 ** scale_val)
    target_w, target_h = max(1, base_w // ratio), max(1, base_h // ratio)
    imgBMP = img.resize((target_w, target_h), resample=0)   # MODE 0 = NEAREST
    pixels = imgBMP.load()
    w, h = imgBMP.size
    for x in range(w):
        for y in range(h):
            rr, gg, bb = pixels[x, y]
            pixels[x, y] = (Quantize_8(rr), Quantize_8(gg), Quantize_4(bb))

    out_dir = os.path.join(out_root, f"output_{FileName}_{w}x{h}")
    os.makedirs(out_dir, exist_ok=True)
    imgBMP.save(os.path.join(out_dir, f"{FileName}_out.png"))

    with open(os.path.join(out_dir, f"{FileName}.mif"), "w") as f:
        f.write("--\n-- Generated automatically by BMPConverter_V21.py ("
                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')})\n--\n")
        f.write(f"DEPTH = {w*h};\nWIDTH = 8;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n")
        digits = ((w*h - 1).bit_length() + 3) // 4
        for y in range(h):
            for x in range(w):
                rr, gg, bb = pixels[x, y]
                colorbyte = (rr//32)*32 + (gg//32)*4 + (bb//64)
                f.write(f"{hex(y*w + x)[2:].upper().zfill(digits)}: {colorbyte:02X};\n")
        f.write("END;\n")

    rows = []
    with open(os.path.join(out_dir, f"{FileName}BitMap.SV"), "w") as f:
        f.write("// Auto-generated bitmap\n// Mode: 8-bit\n\n")
        f.write(f"localparam int OBJECT_WIDTH_X = {w};\nlocalparam int OBJECT_HEIGHT_Y = {h};\n\n")
        f.write("logic [0:OBJECT_HEIGHT_Y-1][0:OBJECT_WIDTH_X-1][7:0] object_colors = {\n")
        for y in range(h):
            vals = []
            for x in range(w):
                rr, gg, bb = pixels[x, y]
                vals.append((rr//32)*32 + (gg//32)*4 + (bb//64))
            rows.append(vals)
            row_str = ",".join(f"8'h{v:02X}" for v in vals)
            f.write(f"\t{{{row_str}}}" + (",\n" if y < h - 1 else "\n"))
        f.write("};\n")

    with open(os.path.join(out_dir, "log.txt"), "w") as log:
        log.write(f"File: {FileName}\nTime: {datetime.now()}\nMode: 8-bit\n"
                  f"Resolution: {w}x{h}\nScale: {scale_val} (from 256x256)\nOutput dir: {out_dir}\n")
    return rows, out_dir

if __name__ == "__main__":
    convert(sys.argv[1], int(sys.argv[2]), sys.argv[3])
