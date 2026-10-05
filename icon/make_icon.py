# Generates icon/AppIcon.png and icon/AppIcon.icns for asmtone: piano keys on a deep
# violet-to-teal squircle, with sound rings rising from them. Needs Pillow.
from PIL import Image, ImageDraw, ImageFilter
import os

S = 2048                                   # draw at 2x, downsample for smooth edges
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
m, r = int(S * 100 / 1024), int(S * 185 / 1024)   # the macOS icon grid
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
top, bot = (46, 22, 92), (12, 128, 140)
for y in range(S):
    t = y / S
    gd.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)) + (255,))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], r, fill=255)
img.paste(grad, (0, 0), mask)

layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
body = S - 2 * m
# sound rings above the keys
cx, cy = S / 2, m + body * 0.40
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
for k, a in ((0.16, 230), (0.25, 160), (0.34, 95)):
    rr = body * k
    g.arc([cx - rr, cy - rr, cx + rr, cy + rr], 200, 340, fill=(140, 240, 255, a), width=int(S * 0.022))
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.004))
layer = Image.alpha_composite(layer, glow)
d = ImageDraw.Draw(layer)
# a single note rising from the keys
nx, ny = cx, cy + body * 0.02
d.ellipse([nx - body*0.055, ny - body*0.035, nx + body*0.035, ny + body*0.045], fill=(255, 255, 255, 255))
d.rectangle([nx + body*0.022, ny - body*0.20, nx + body*0.036, ny + body*0.01], fill=(255, 255, 255, 255))
d.polygon([(nx + body*0.036, ny - body*0.20), (nx + body*0.10, ny - body*0.15),
           (nx + body*0.10, ny - body*0.11), (nx + body*0.036, ny - body*0.155)], fill=(255, 255, 255, 255))
# the keyboard: seven white keys, five black
kx0, kx1 = m + body * 0.14, m + body * 0.86
ky0, ky1 = m + body * 0.58, m + body * 0.86
kw = (kx1 - kx0) / 7
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle([kx0, ky0 + S*0.01, kx1, ky1 + S*0.02], S*0.02, fill=(0, 0, 0, 110))
shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.012))
layer = Image.alpha_composite(shadow, layer)
d = ImageDraw.Draw(layer)
for i in range(7):
    x = kx0 + i * kw
    d.rounded_rectangle([x + S*0.004, ky0, x + kw - S*0.004, ky1], S*0.012, fill=(250, 250, 255, 255))
for i in (0, 1, 3, 4, 5):
    x = kx0 + (i + 1) * kw - kw * 0.30
    d.rounded_rectangle([x, ky0, x + kw * 0.60, ky0 + (ky1 - ky0) * 0.60], S*0.008, fill=(28, 22, 48, 255))

clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
clipped.paste(layer, (0, 0), mask)
img = Image.alpha_composite(img, clipped)
out = img.resize((1024, 1024), Image.LANCZOS)
here = os.path.dirname(os.path.abspath(__file__))
out.save(os.path.join(here, "AppIcon.png"))
out.save(os.path.join(here, "AppIcon.icns"), sizes=[(16,16),(32,32),(64,64),(128,128),(256,256),(512,512),(1024,1024)])
print("wrote AppIcon.png and AppIcon.icns")
