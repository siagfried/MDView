from PIL import Image, ImageDraw, ImageFont

S = 1024
TOP = (0x3B, 0x7D, 0xF0)
BOT = (0x0E, 0x2F, 0x93)
R = int(S * 0.2237)

def gradient(size, top, bot):
    g = Image.new("RGB", (size, size)); d = ImageDraw.Draw(g)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(int(top[i] + (bot[i]-top[i]) * t) for i in range(3)))
    return g

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S-1, S-1], radius=R, fill=255)
img.paste(gradient(S, TOP, BOT), (0, 0), mask)
hl = Image.new("L", (S, S), 0)
ImageDraw.Draw(hl).rounded_rectangle([int(S*0.03), int(S*0.02), int(S*0.97), int(S*0.97)], radius=int(R*0.95), fill=22)
img.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), hl)

d = ImageDraw.Draw(img)
font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 430)
try:
    font.set_variation_by_name("Bold")           # SF 是可变字体
    print("使用 SF Bold 变体")
except Exception as e:
    print("可变字体不可用，退回默认字重:", type(e).__name__)

M = "M"
bbox = d.textbbox((0, 0), M, font=font)
mw, mtop, mbot = bbox[2]-bbox[0], bbox[1], bbox[3]
Mh = mbot - mtop

aw, ah = 196, Mh                 # 箭头总宽 / 总高（与 M 等高）
shaft_w, head_h = 68, int(Mh*0.44)
gap = 44
group_w = mw + gap + aw
x0 = (S - group_w)//2
top_y = (S - Mh)//2              # 让 M 与箭头整体在竖直方向居中

d.text((x0 - bbox[0], top_y - mtop), M, font=font, fill=(255, 255, 255, 255))
ax = x0 + mw + gap
d.rectangle([ax + (aw-shaft_w)//2, top_y, ax + (aw+shaft_w)//2, top_y + ah - head_h], fill=(255,255,255,255))
d.polygon([(ax, top_y + ah - head_h), (ax + aw, top_y + ah - head_h), (ax + aw//2, top_y + ah)], fill=(255,255,255,255))

img.save("icon_1024.png")
print("saved")
